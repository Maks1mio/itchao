import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/debug/butler_debug_log.dart';
import '../../data/models.dart';
import '../auth/auth_controller.dart';
import '../game/game_catalog_cache.dart';
import 'collections_api_token.dart';
import 'collections_controller.dart';

class CollectionDetailState {
  const CollectionDetailState({
    required this.games,
    this.expectedCount = 0,
    this.isLoadingMore = false,
    this.hasMore = false,
  });

  final List<LibraryGame> games;
  final int expectedCount;
  final bool isLoadingMore;
  final bool hasMore;

  CollectionDetailState copyWith({
    List<LibraryGame>? games,
    int? expectedCount,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return CollectionDetailState(
      games: games ?? this.games,
      expectedCount: expectedCount ?? this.expectedCount,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

final collectionDetailProvider =
    AsyncNotifierProvider.family<CollectionDetailNotifier, CollectionDetailState, int>(
      CollectionDetailNotifier.new,
    );

/// Игры коллекции через API с постраничной подгрузкой (itch API: per_page до 100).
class CollectionDetailNotifier extends FamilyAsyncNotifier<CollectionDetailState, int> {
  static const pageSize = 100;

  int get _collectionId => arg;

  int _apiPage = 0;
  bool _fetchInFlight = false;

  @override
  Future<CollectionDetailState> build(int collectionId) async {
    _apiPage = 0;
    _fetchInFlight = false;

    final expected = await _resolveExpectedCount(collectionId);
    final cached =
        ref.read(collectionsControllerProvider.notifier).cachedGamesFor(collectionId) ??
        const <LibraryGame>[];

    var games = List<LibraryGame>.from(cached);

    final token = await readCollectionsApiToken(ref);
    if (token == null || token.isEmpty) {
      return CollectionDetailState(games: games, expectedCount: expected, hasMore: false);
    }

    butlerRcall('Fetch.Collection.Games detail (id: $collectionId, page: 1, expected: $expected)');

    final batch = await ref.read(itchApiClientProvider).fetchCollectionGames(
      token: token,
      collectionId: collectionId,
      page: 1,
      perPage: pageSize,
    );

    final merged = _merge(games, batch);
    games = merged.games;
    _apiPage = 1;

    final hasMore = _hasMoreAfterBatch(
      batchSize: batch.length,
      added: merged.added,
      total: games.length,
      expected: expected,
    );

    butlerRcall('Collection page 1: ${games.length}/$expected games, hasMore: $hasMore');

    ref.read(gameCatalogCacheProvider.notifier).putAll(games);

    return CollectionDetailState(
      games: games,
      expectedCount: expected,
      hasMore: hasMore,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || _fetchInFlight || current.isLoadingMore || !current.hasMore) {
      return;
    }

    final token = await readCollectionsApiToken(ref);
    if (token == null || token.isEmpty) {
      return;
    }

    _fetchInFlight = true;
    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final nextPage = _apiPage + 1;
      final batch = await ref.read(itchApiClientProvider).fetchCollectionGames(
        token: token,
        collectionId: _collectionId,
        page: nextPage,
        perPage: pageSize,
      );
      _apiPage = nextPage;

      final merged = _merge(current.games, batch);
      var hasMore = _hasMoreAfterBatch(
        batchSize: batch.length,
        added: merged.added,
        total: merged.games.length,
        expected: current.expectedCount,
      );
      if (merged.added == 0 && batch.isNotEmpty) {
        butlerRcall('Collection page $nextPage: no new games, stop pagination');
        hasMore = false;
      }

      butlerRcall(
        'Collection page $nextPage: +${merged.added} (total ${merged.games.length}/${current.expectedCount}, hasMore: $hasMore)',
      );

      ref.read(gameCatalogCacheProvider.notifier).putAll(merged.games);

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

  /// Продолжаем, пока не набрали [expected] или API вернул пустую страницу.
  bool _hasMoreAfterBatch({
    required int batchSize,
    required int added,
    required int total,
    required int expected,
  }) {
    if (batchSize == 0) {
      return false;
    }
    if (expected > 0) {
      return total < expected;
    }
    return added > 0 || batchSize >= pageSize;
  }

  Future<int> _resolveExpectedCount(int collectionId) async {
    final fromCache = _expectedGamesCountFromList(collectionId);
    if (fromCache > 0) {
      return fromCache;
    }

    final token = await readCollectionsApiToken(ref);
    if (token == null || token.isEmpty) {
      return 0;
    }

    try {
      final collection = await ref.read(itchApiClientProvider).findCollectionById(
        token: token,
        collectionId: collectionId,
      );
      return collection?.gamesCount ?? 0;
    } catch (error) {
      butlerRcall('Fetch collection meta failed ($collectionId): $error');
      return 0;
    }
  }

  int _expectedGamesCountFromList(int collectionId) {
    final collections = ref.read(collectionsControllerProvider).valueOrNull?.items ?? const [];
    for (final item in collections) {
      if (item.collection.id == collectionId) {
        return item.collection.gamesCount;
      }
    }
    return 0;
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
