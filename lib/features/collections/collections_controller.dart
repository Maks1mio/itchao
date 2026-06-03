import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/debug/butler_debug_log.dart';
import '../../data/api_exception.dart';
import '../../data/collection_web_fetcher.dart';
import '../../data/itch_api_client.dart';
import '../../data/models.dart';
import '../auth/auth_controller.dart';

enum CollectionSortField { title, updatedAt }

enum CollectionsDisplayMode { native, webFallback }

class CollectionsState {
  const CollectionsState({
    required this.items,
    required this.mode,
    this.limitedAccess = false,
    this.loadingPreviews = false,
    this.pendingPreviewCount = 0,
    this.hint,
  });

  final List<CollectionWithPreview> items;
  final CollectionsDisplayMode mode;
  final bool limitedAccess;
  final bool loadingPreviews;
  final int pendingPreviewCount;
  final String? hint;
}

final collectionsControllerProvider =
    AsyncNotifierProvider<CollectionsController, CollectionsState>(
      CollectionsController.new,
    );

class CollectionsController extends AsyncNotifier<CollectionsState> {
  static const _previewLimit = 8;
  static const _maxConcurrent = 3;
  static const _retryRounds = 2;

  CollectionSortField sortField = CollectionSortField.updatedAt;
  var sortReverse = true;
  String searchQuery = '';
  List<CollectionWithPreview> _cached = const [];
  final Map<int, List<LibraryGame>> _gamesByCollectionId = {};
  int _loadGeneration = 0;

  Map<int, List<LibraryGame>> get gamesByCollectionId => _gamesByCollectionId;

  List<LibraryGame>? cachedGamesFor(int collectionId) => _gamesByCollectionId[collectionId];

  @override
  Future<CollectionsState> build() async {
    return _load();
  }

  Future<CollectionsState> _load() async {
    final generation = ++_loadGeneration;
    final token = await ref.read(authControllerProvider.notifier).readApiKey();
    if (token == null || token.isEmpty) {
      return const CollectionsState(items: [], mode: CollectionsDisplayMode.native);
    }
    final fullToken = await ref.read(authControllerProvider.notifier).readFullApiKey();
    final hasFullKey = fullToken != null && fullToken.isNotEmpty;
    final client = ref.read(itchApiClientProvider);
    final webFetcher = ref.read(collectionWebFetcherProvider);

    final profileId = ref.read(authControllerProvider).valueOrNull?.id;
    butlerRcall(
      profileId != null && profileId > 0
          ? 'Calling Fetch.ProfileCollections (profileId: $profileId)'
          : 'Calling Fetch.ProfileCollections → GET /profile/collections',
    );

    List<ItchCollection> collections;
    try {
      collections = await client.fetchCollections(token: token);
    } catch (_) {
      return const CollectionsState(
        items: [],
        mode: CollectionsDisplayMode.webFallback,
        hint: 'Не удалось загрузить коллекции через API. Открываем itch.io в браузере.',
      );
    }

    if (generation != _loadGeneration) {
      return state.value ?? const CollectionsState(items: [], mode: CollectionsDisplayMode.native);
    }

    _gamesByCollectionId.clear();
    _cached = collections
        .map(
          (c) => CollectionWithPreview(
            collection: c,
            previewGames: const [],
            previewLoading: true,
          ),
        )
        .toList();
    _publish(generation: generation);

    await _loadAllPreviews(
      generation: generation,
      collections: collections,
      token: token,
      fullToken: fullToken,
      hasFullKey: hasFullKey,
      client: client,
      webFetcher: webFetcher,
      profileId: profileId,
    );

    if (generation != _loadGeneration) {
      return state.value ?? const CollectionsState(items: [], mode: CollectionsDisplayMode.native);
    }

    return _finalState(hasFullKey: hasFullKey);
  }

  Future<void> _loadAllPreviews({
    required int generation,
    required List<ItchCollection> collections,
    required String token,
    required String? fullToken,
    required bool hasFullKey,
    required ItchApiClient client,
    required CollectionWebFetcher webFetcher,
    required int? profileId,
  }) async {
    await _runPreviewPool(
      generation: generation,
      collections: collections,
      token: token,
      fullToken: fullToken,
      hasFullKey: hasFullKey,
      client: client,
      webFetcher: webFetcher,
      profileId: profileId,
    );

    for (var round = 0; round < _retryRounds; round++) {
      if (generation != _loadGeneration) {
        return;
      }
      final missing = _cached
          .where((e) => !e.previewLoading && e.previewGames.isEmpty)
          .map((e) => e.collection)
          .toList();
      if (missing.isEmpty) {
        break;
      }
      await Future.delayed(Duration(milliseconds: 800 * (round + 1)));
      if (generation != _loadGeneration) {
        return;
      }
      for (final c in missing) {
        _setPreviewLoading(c.id, loading: true);
      }
      _publish(generation: generation);
      await _runPreviewPool(
        generation: generation,
        collections: missing,
        token: token,
        fullToken: fullToken,
        hasFullKey: hasFullKey,
        client: client,
        webFetcher: webFetcher,
        profileId: profileId,
        isRetry: true,
      );
    }
  }

  Future<void> _runPreviewPool({
    required int generation,
    required List<ItchCollection> collections,
    required String token,
    required String? fullToken,
    required bool hasFullKey,
    required ItchApiClient client,
    required CollectionWebFetcher webFetcher,
    required int? profileId,
    bool isRetry = false,
  }) async {
    var index = 0;
    final workers = List.generate(_maxConcurrent.clamp(1, collections.length), (_) async {
      while (index < collections.length) {
        if (generation != _loadGeneration) {
          return;
        }
        final collection = collections[index++];
        butlerRcall(
          'Calling Fetch.Collection.Games (collectionId: ${collection.id}, limit: $_previewLimit'
          '${isRetry ? ', retry' : ''}'
          '${profileId != null && profileId > 0 ? ', profileId: $profileId' : ''})',
        );
        final games = await _fetchPreviewGames(
          collection: collection,
          token: token,
          fullToken: fullToken,
          hasFullKey: hasFullKey,
          client: client,
          webFetcher: webFetcher,
        );
        if (generation != _loadGeneration) {
          return;
        }
        _applyPreviewResult(collection.id, games);
        _publish(generation: generation);
      }
    });
    await Future.wait(workers);
  }

  Future<List<LibraryGame>> _fetchPreviewGames({
    required ItchCollection collection,
    required String token,
    required String? fullToken,
    required bool hasFullKey,
    required ItchApiClient client,
    required CollectionWebFetcher webFetcher,
  }) async {
    try {
      if (hasFullKey) {
        try {
          final games = await client.fetchCollectionGames(
            token: token,
            fullAccessToken: fullToken,
            collectionId: collection.id,
            perPage: _previewLimit,
          );
          if (games.isNotEmpty) {
            return games;
          }
        } on ApiException catch (error) {
          if (!error.isCollectionViewDenied) {
            rethrow;
          }
        }
      }
      butlerRcall(
        'Fetch.Collection.Games fallback → HTML itch.io/c/${collection.id}/hello',
      );
      return await webFetcher.fetchPreviewGames(
        collectionId: collection.id,
        limit: _previewLimit,
      );
    } catch (_) {
      return const [];
    }
  }

  void _applyPreviewResult(int collectionId, List<LibraryGame> games) {
    _gamesByCollectionId[collectionId] = games;
    _cached = [
      for (final item in _cached)
        if (item.collection.id == collectionId)
          CollectionWithPreview(
            collection: item.collection,
            previewGames: games,
            previewLoading: false,
          )
        else
          item,
    ];
  }

  void _setPreviewLoading(int collectionId, {required bool loading}) {
    _cached = [
      for (final item in _cached)
        if (item.collection.id == collectionId)
          CollectionWithPreview(
            collection: item.collection,
            previewGames: item.previewGames,
            previewLoading: loading,
          )
        else
          item,
    ];
  }

  void _publish({required int generation}) {
    if (generation != _loadGeneration) {
      return;
    }
    final current = state.value;
    state = AsyncData(
      CollectionsState(
        items: _applyFilters(_cached),
        mode: current?.mode ?? CollectionsDisplayMode.native,
        limitedAccess: current?.limitedAccess ?? false,
        loadingPreviews: _cached.any((e) => e.previewLoading),
        pendingPreviewCount: _cached.where((e) => e.previewLoading).length,
        hint: current?.hint,
      ),
    );
  }

  CollectionsState _finalState({required bool hasFullKey}) {
    final filtered = _applyFilters(_cached);
    final anyLoaded = filtered.any((item) => item.previewGames.isNotEmpty);
    final allEmpty = filtered.isNotEmpty && filtered.every((item) => item.previewGames.isEmpty);
    final limitedAccess = !hasFullKey && allEmpty;

    return CollectionsState(
      items: filtered,
      mode: CollectionsDisplayMode.native,
      limitedAccess: limitedAccess,
      loadingPreviews: false,
      pendingPreviewCount: 0,
      hint: limitedAccess && !anyLoaded
          ? 'Обложки не загрузились. Войди через WebView на itch.io или добавь полный API key в настройках.'
          : null,
    );
  }

  List<CollectionWithPreview> _applyFilters(List<CollectionWithPreview> items) {
    var filtered = items;
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      filtered = filtered
          .where((e) => e.collection.title.toLowerCase().contains(q))
          .toList();
    }
    filtered = [...filtered];
    filtered.sort((a, b) {
      final cmp = switch (sortField) {
        CollectionSortField.title => a.collection.title.compareTo(b.collection.title),
        CollectionSortField.updatedAt =>
          a.collection.updatedAt.compareTo(b.collection.updatedAt),
      };
      return sortReverse ? -cmp : cmp;
    });
    return filtered;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> setSearch(String query) async {
    searchQuery = query;
    if (_cached.isEmpty) {
      await refresh();
      return;
    }
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(
      CollectionsState(
        items: _applyFilters(_cached),
        mode: current.mode,
        limitedAccess: current.limitedAccess,
        loadingPreviews: _cached.any((e) => e.previewLoading),
        pendingPreviewCount: _cached.where((e) => e.previewLoading).length,
        hint: current.hint,
      ),
    );
  }

  Future<void> setSort(CollectionSortField field, {required bool reverse}) async {
    sortField = field;
    sortReverse = reverse;
    if (_cached.isEmpty) {
      await refresh();
      return;
    }
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(
      CollectionsState(
        items: _applyFilters(_cached),
        mode: current.mode,
        limitedAccess: current.limitedAccess,
        loadingPreviews: _cached.any((e) => e.previewLoading),
        pendingPreviewCount: _cached.where((e) => e.previewLoading).length,
        hint: current.hint,
      ),
    );
  }
}

