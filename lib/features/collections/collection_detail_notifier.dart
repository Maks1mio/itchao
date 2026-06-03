import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/debug/butler_debug_log.dart';
import '../../data/api_exception.dart';
import '../../data/models.dart';
import '../auth/auth_controller.dart';
import 'collections_controller.dart';

class CollectionDetailState {
  const CollectionDetailState({
    required this.games,
    this.expectedCount = 0,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.source = CollectionGamesSource.none,
  });

  final List<LibraryGame> games;
  final int expectedCount;
  final bool isLoadingMore;
  final bool hasMore;
  final CollectionGamesSource source;

  CollectionDetailState copyWith({
    List<LibraryGame>? games,
    int? expectedCount,
    bool? isLoadingMore,
    bool? hasMore,
    CollectionGamesSource? source,
  }) {
    return CollectionDetailState(
      games: games ?? this.games,
      expectedCount: expectedCount ?? this.expectedCount,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      source: source ?? this.source,
    );
  }
}

enum CollectionGamesSource { none, api, web }

final collectionDetailProvider =
    AsyncNotifierProvider.family<CollectionDetailNotifier, CollectionDetailState, int>(
      CollectionDetailNotifier.new,
    );

class CollectionDetailNotifier extends FamilyAsyncNotifier<CollectionDetailState, int> {
  static const _pageSize = 30;

  int get _collectionId => arg;

  int _apiPage = 0;
  int _webPage = 0;
  String? _webPath;
  bool _useApi = false;
  bool _fetchInFlight = false;

  @override
  Future<CollectionDetailState> build(int collectionId) async {
    _apiPage = 0;
    _webPage = 0;
    _webPath = null;
    _useApi = false;
    _fetchInFlight = false;

    final expected = _expectedGamesCount(collectionId);
    final cached =
        ref.read(collectionsControllerProvider.notifier).cachedGamesFor(collectionId) ??
        const <LibraryGame>[];

    var games = List<LibraryGame>.from(cached);
    var source = CollectionGamesSource.none;
    var hasMore = false;

    final token = await ref.read(authControllerProvider.notifier).readApiKey();
    if (token == null || token.isEmpty) {
      return CollectionDetailState(games: games, expectedCount: expected, hasMore: false);
    }

    final fullToken = await ref.read(authControllerProvider.notifier).readFullApiKey();
    final client = ref.read(itchApiClientProvider);

    butlerRcall('Collection detail load (id: $collectionId, expected: $expected)');

    try {
      final batch = await client.fetchCollectionGames(
        token: token,
        fullAccessToken: fullToken,
        collectionId: collectionId,
        page: 1,
        perPage: _pageSize,
      );
      if (batch.isNotEmpty) {
        _useApi = true;
        _apiPage = 1;
        final merged = _merge(games, batch);
        games = merged.games;
        source = CollectionGamesSource.api;
        hasMore = _shouldLoadMore(
          added: merged.added,
          total: games.length,
          expected: expected,
          batchSize: batch.length,
          htmlHasNext: false,
        );
        butlerRcall('Collection API page 1: +${merged.added} (total ${games.length})');
      }
    } on ApiException catch (error) {
      if (!error.isCollectionViewDenied) {
        rethrow;
      }
      butlerRcall('Collection API denied → HTML pages');
    }

    if (!_useApi) {
      final page = await ref.read(collectionWebFetcherProvider).fetchGamesPage(
        collectionId: collectionId,
        page: 1,
      );
      _webPath = page.collectionPath;
      _webPage = 1;
      if (page.games.isNotEmpty) {
        final merged = _merge(games, page.games);
        games = merged.games;
        source = CollectionGamesSource.web;
        hasMore = _shouldLoadMore(
          added: merged.added,
          total: games.length,
          expected: expected,
          batchSize: page.games.length,
          htmlHasNext: page.hasNextPage,
        );
        butlerRcall(
          'Collection HTML page 1: +${merged.added} (total ${games.length}, path: ${_webPath ?? "?"})',
        );
      }
    }

    while (hasMore) {
      final page = await _fetchNextPage();
      final merged = _merge(games, page.games);
      games = merged.games;
      hasMore = _shouldLoadMore(
        added: merged.added,
        total: games.length,
        expected: expected,
        batchSize: page.games.length,
        htmlHasNext: page.hasMore,
      );
      if (!hasMore) {
        butlerRcall('Collection load complete: ${games.length} games');
      }
    }

    return CollectionDetailState(
      games: games,
      expectedCount: expected,
      hasMore: false,
      source: source,
    );
  }

  /// Догрузка при скролле вниз (только если ещё есть что грузить).
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || _fetchInFlight || current.isLoadingMore || !current.hasMore) {
      return;
    }

    _fetchInFlight = true;
    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final page = await _fetchNextPage();
      final merged = _merge(current.games, page.games);
      final hasMore = _shouldLoadMore(
        added: merged.added,
        total: merged.games.length,
        expected: current.expectedCount,
        batchSize: page.games.length,
        htmlHasNext: page.hasMore,
      );

      if (merged.added > 0) {
        butlerRcall('Collection +${merged.added} (total ${merged.games.length})');
      } else {
        butlerRcall('Collection end of list (${merged.games.length} games)');
      }

      state = AsyncData(
        current.copyWith(
          games: merged.games,
          isLoadingMore: false,
          hasMore: hasMore,
        ),
      );
    } catch (error) {
      butlerRcall('Collection loadMore error: $error');
      state = AsyncData(current.copyWith(isLoadingMore: false, hasMore: false));
    } finally {
      _fetchInFlight = false;
    }
  }

  Future<({List<LibraryGame> games, bool hasMore})> _fetchNextPage() async {
    final token = await ref.read(authControllerProvider.notifier).readApiKey();
    if (token == null || token.isEmpty) {
      return (games: const <LibraryGame>[], hasMore: false);
    }

    final expected = state.valueOrNull?.expectedCount ?? _expectedGamesCount(_collectionId);

    if (_useApi) {
      final nextPage = _apiPage + 1;
      if (_isPastMaxPage(nextPage, expected)) {
        return (games: const <LibraryGame>[], hasMore: false);
      }
      final fullToken = await ref.read(authControllerProvider.notifier).readFullApiKey();
      final batch = await ref.read(itchApiClientProvider).fetchCollectionGames(
        token: token,
        fullAccessToken: fullToken,
        collectionId: _collectionId,
        page: nextPage,
        perPage: _pageSize,
      );
      _apiPage = nextPage;
      return (games: batch, hasMore: batch.isNotEmpty);
    }

    final nextPage = _webPage + 1;
    if (_isPastMaxPage(nextPage, expected)) {
      return (games: const <LibraryGame>[], hasMore: false);
    }
    final page = await ref.read(collectionWebFetcherProvider).fetchGamesPage(
      collectionId: _collectionId,
      page: nextPage,
      collectionPath: _webPath,
    );
    _webPage = nextPage;
    _webPath = page.collectionPath ?? _webPath;
    return (games: page.games, hasMore: page.hasNextPage);
  }

  int _expectedGamesCount(int collectionId) {
    final collections = ref.read(collectionsControllerProvider).valueOrNull?.items ?? const [];
    for (final item in collections) {
      if (item.collection.id == collectionId) {
        return item.collection.gamesCount;
      }
    }
    return 0;
  }

  bool _isPastMaxPage(int page, int expected) {
    if (expected <= 0) {
      return page > 32;
    }
    return page > (expected + _pageSize - 1) ~/ _pageSize + 1;
  }

  bool _shouldLoadMore({
    required int added,
    required int total,
    required int expected,
    required int batchSize,
    required bool htmlHasNext,
  }) {
    if (added == 0) {
      return false;
    }
    if (expected > 0 && total >= expected) {
      return false;
    }
    if (_useApi) {
      return batchSize >= _pageSize && (expected == 0 || total < expected);
    }
    return htmlHasNext && (expected == 0 || total < expected);
  }

  ({List<LibraryGame> games, int added}) _merge(List<LibraryGame> existing, List<LibraryGame> batch) {
    if (batch.isEmpty) {
      return (games: existing, added: 0);
    }
    final seen = existing.map((g) => g.id).toSet();
    final merged = List<LibraryGame>.from(existing);
    var added = 0;
    for (final game in batch) {
      if (seen.add(game.id)) {
        merged.add(game);
        added++;
      }
    }
    return (games: merged, added: added);
  }
}
