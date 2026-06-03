import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models.dart';
import '../../../collections/collection_detail_notifier.dart';
import '../../../collections/collections_controller.dart';
import '../tab_chrome_provider.dart';
import '../widgets/itch_game_card.dart';
import '../widgets/tab_chrome_toolbars.dart';

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
  var _subtitle = '';
  ProviderSubscription<AsyncValue<CollectionDetailState>>? _detailSubscription;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindChrome());
    _detailSubscription = ref.listenManual<AsyncValue<CollectionDetailState>>(
      collectionDetailProvider(widget.collectionId),
      (prev, next) => _onDetailChanged(next),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _detailSubscription?.close();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _bindChrome() {
    if (!mounted) {
      return;
    }
    final hint = _subtitle.isEmpty ? 'Фильтр…' : 'Фильтр… · $_subtitle';
    ref.read(tabChromeProvider.notifier).setAppBarContent(
      title: CollectionDetailAppBarTitle(
        searchController: _searchController,
        hintText: hint,
        onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
      ),
    );
  }

  void _onDetailChanged(AsyncValue<CollectionDetailState> next) {
    next.whenData((state) {
      final total = state.expectedCount > 0 ? state.expectedCount : state.games.length;
      final subtitle = state.expectedCount > 0 && state.games.length < state.expectedCount
          ? '${state.games.length} / $total игр'
          : '$total игр';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _applySubtitle(subtitle);
        if (state.hasMore && !state.isLoadingMore) {
          _requestLoadMore();
        }
      });
    });
  }

  void _applySubtitle(String subtitle) {
    if (_subtitle == subtitle) {
      return;
    }
    setState(() => _subtitle = subtitle);
    _bindChrome();
  }

  bool _shouldLoadMore() {
    if (!_scrollController.hasClients || _loadMoreRequested) {
      return false;
    }
    final state = ref.read(collectionDetailProvider(widget.collectionId)).valueOrNull;
    if (state == null || !state.hasMore || state.isLoadingMore) {
      return false;
    }
    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      return true;
    }
    final runway = position.maxScrollExtent - position.pixels;
    return runway < 480 || position.maxScrollExtent <= 0;
  }

  void _onScroll() {
    if (_shouldLoadMore()) {
      _requestLoadMore();
    }
  }

  void _requestLoadMore() {
    if (_loadMoreRequested) {
      return;
    }
    _loadMoreRequested = true;
    ref
        .read(collectionDetailProvider(widget.collectionId).notifier)
        .loadMore()
        .whenComplete(() {
          if (!mounted) {
            return;
          }
          setState(() => _loadMoreRequested = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _shouldLoadMore()) {
              _requestLoadMore();
            }
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(collectionDetailProvider(widget.collectionId));

    return detail.when(
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
          final expected = ref
              .read(collectionsControllerProvider)
              .valueOrNull
              ?.items
              .where((e) => e.collection.id == widget.collectionId)
              .map((e) => e.collection.gamesCount)
              .firstOrNull;
          return _buildGamesList(
            context,
            CollectionDetailState(
              games: cached,
              expectedCount: expected ?? 0,
              hasMore: true,
              isLoadingMore: true,
            ),
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

    final showFooter = state.hasMore;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(collectionDetailProvider(widget.collectionId));
        await ref.read(collectionDetailProvider(widget.collectionId).future);
      },
      child: ItchGameListView(
        controller: _scrollController,
        games: games,
        footer: showFooter
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: state.isLoadingMore
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: _requestLoadMore,
                          child: const Text('Загрузить ещё'),
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
