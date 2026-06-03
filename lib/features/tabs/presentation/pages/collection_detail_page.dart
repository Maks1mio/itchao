import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models.dart';
import '../../../collections/collection_detail_notifier.dart';
import '../../../collections/collections_controller.dart';
import '../widgets/itch_game_card.dart';

class CollectionDetailPage extends ConsumerStatefulWidget {
  const CollectionDetailPage({required this.collectionId, required this.title, super.key});

  final int collectionId;
  final String title;

  @override
  ConsumerState<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends ConsumerState<CollectionDetailPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  var _query = '';
  var _loadMoreRequested = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadMoreRequested) {
      return;
    }
    final state = ref.read(collectionDetailProvider(widget.collectionId)).valueOrNull;
    if (state == null || !state.hasMore || state.isLoadingMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 320) {
      return;
    }
    _loadMoreRequested = true;
    ref.read(collectionDetailProvider(widget.collectionId).notifier).loadMore().whenComplete(() {
      if (mounted) {
        setState(() => _loadMoreRequested = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(collectionDetailProvider(widget.collectionId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: detail.maybeWhen(
            data: (state) {
              final total = state.expectedCount > 0 ? state.expectedCount : state.games.length;
              final subtitle = state.isLoadingMore && state.expectedCount > 0
                  ? '${state.games.length} / $total'
                  : '$total игр';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              );
            },
            orElse: () => Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Фильтр…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: detail.when(
            data: (state) => _buildGamesList(context, state),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Ошибка: $e', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.invalidate(collectionDetailProvider(widget.collectionId)),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),
            loading: () {
              final cached =
                  ref.read(collectionsControllerProvider.notifier).cachedGamesFor(widget.collectionId);
              if (cached != null && cached.isNotEmpty) {
                return _buildGamesList(
                  context,
                  CollectionDetailState(games: cached, hasMore: true, isLoadingMore: true),
                );
              }
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Загрузка игр коллекции…'),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGamesList(BuildContext context, CollectionDetailState state) {
    final games = _filterGames(state.games);
    if (games.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Не удалось загрузить игры коллекции', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(collectionDetailProvider(widget.collectionId)),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    final showFooter = state.hasMore && state.isLoadingMore;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(collectionDetailProvider(widget.collectionId));
        await ref.read(collectionDetailProvider(widget.collectionId).future);
      },
      child: ItchGameListView(
        controller: _scrollController,
        games: games,
        footer: showFooter
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  List<LibraryGame> _filterGames(List<LibraryGame> games) {
    if (_query.isEmpty) {
      return games;
    }
    return games
        .where(
          (g) =>
              g.title.toLowerCase().contains(_query) ||
              (g.shortText?.toLowerCase().contains(_query) ?? false),
        )
        .toList();
  }
}
