import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/debug/butler_debug_log.dart';
import '../../data/api_exception.dart';
import '../../data/itch_api_client.dart';
import '../../data/models.dart';
import '../auth/auth_controller.dart';
import '../game/game_catalog_cache.dart';
import 'collections_api_token.dart';

enum CollectionSortField { title, updatedAt }

class CollectionsState {
  const CollectionsState({
    required this.items,
    this.loadingPreviews = false,
    this.pendingPreviewCount = 0,
  });

  final List<CollectionWithPreview> items;
  final bool loadingPreviews;
  final int pendingPreviewCount;
}

final collectionsControllerProvider =
    AsyncNotifierProvider<CollectionsController, CollectionsState>(
      CollectionsController.new,
    );

/// Список коллекций + превью игр через API (`profile/collections`, `collection-games`).
class CollectionsController extends AsyncNotifier<CollectionsState> {
  /// Как itch desktop `GameStripe` — limit 12.
  static const previewLimit = 12;
  static const _maxConcurrent = 4;

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
    final token = await readCollectionsApiToken(ref);
    if (token == null || token.isEmpty) {
      return const CollectionsState(items: []);
    }

    final profileId = ref.read(authControllerProvider).valueOrNull?.id;
    butlerRcall(
      profileId != null && profileId > 0
          ? 'Fetch.ProfileCollections (profileId: $profileId)'
          : 'Fetch.ProfileCollections',
    );

    final client = ref.read(itchApiClientProvider);
    final collections = await client.fetchCollections(token: token);

    if (generation != _loadGeneration) {
      return state.value ?? const CollectionsState(items: []);
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
      client: client,
      profileId: profileId,
    );

    if (generation != _loadGeneration) {
      return state.value ?? const CollectionsState(items: []);
    }

    return CollectionsState(
      items: _applyFilters(_cached),
      loadingPreviews: false,
      pendingPreviewCount: 0,
    );
  }

  Future<void> _loadAllPreviews({
    required int generation,
    required List<ItchCollection> collections,
    required String token,
    required ItchApiClient client,
    required int? profileId,
  }) async {
    var index = 0;
    final workers = List.generate(_maxConcurrent.clamp(1, collections.length), (_) async {
      while (index < collections.length) {
        if (generation != _loadGeneration) {
          return;
        }
        final collection = collections[index++];
        butlerRcall(
          'Fetch.Collection.Games (collectionId: ${collection.id}, limit: $previewLimit'
          '${profileId != null && profileId > 0 ? ', profileId: $profileId' : ''})',
        );
        final games = await _fetchPreviewGames(
          token: token,
          collectionId: collection.id,
          client: client,
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
    required String token,
    required int collectionId,
    required ItchApiClient client,
  }) async {
    try {
      return await client.fetchCollectionGames(
        token: token,
        collectionId: collectionId,
        perPage: previewLimit,
      );
    } on ApiException catch (error) {
      butlerRcall('Fetch.Collection.Games failed ($collectionId): $error');
      return const [];
    } catch (error) {
      butlerRcall('Fetch.Collection.Games error ($collectionId): $error');
      return const [];
    }
  }

  void _applyPreviewResult(int collectionId, List<LibraryGame> games) {
    _gamesByCollectionId[collectionId] = games;
    ref.read(gameCatalogCacheProvider.notifier).putAll(games);
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

  void _publish({required int generation}) {
    if (generation != _loadGeneration) {
      return;
    }
    Future.microtask(() {
      if (generation != _loadGeneration) {
        return;
      }
      state = AsyncData(
        CollectionsState(
          items: _applyFilters(_cached),
          loadingPreviews: _cached.any((e) => e.previewLoading),
          pendingPreviewCount: _cached.where((e) => e.previewLoading).length,
        ),
      );
    });
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

  static bool _defaultReverse(CollectionSortField field) {
    return switch (field) {
      CollectionSortField.title => false,
      CollectionSortField.updatedAt => true,
    };
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
        loadingPreviews: _cached.any((e) => e.previewLoading),
        pendingPreviewCount: _cached.where((e) => e.previewLoading).length,
      ),
    );
  }

  Future<void> setSort(CollectionSortField field, {bool? reverse}) async {
    if (sortField == field && reverse == null) {
      sortReverse = !sortReverse;
    } else {
      sortField = field;
      sortReverse = reverse ?? _defaultReverse(field);
    }
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
        loadingPreviews: _cached.any((e) => e.previewLoading),
        pendingPreviewCount: _cached.where((e) => e.previewLoading).length,
      ),
    );
  }
}
