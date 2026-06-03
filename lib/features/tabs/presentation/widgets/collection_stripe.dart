import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/itch_colors.dart';
import '../../../../core/utils/time_ago.dart';
import '../../../../data/models.dart';
import '../../tabs_controller.dart';
import 'itch_game_card.dart';

class CollectionStripe extends ConsumerWidget {
  const CollectionStripe({required this.item, super.key});

  final CollectionWithPreview item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coll = item.collection;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    coll.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  formatProjectsCountRu(coll.gamesCount),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Обновлена ${formatTimeAgoRu(coll.updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: ItchGameCoverSize.stripeHeight,
            child: item.previewLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      height: ItchGameCoverSize.stripeHeight,
                      child: ColoredBox(
                        color: ItchColors.itemLoadingOverlay,
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                  )
                : item.previewGames.isEmpty
                ? _LimitedAccessPreview(
                    gamesCount: coll.gamesCount,
                    onOpen: () {
                      ref.read(tabsControllerProvider.notifier).navigateActiveTab(
                        'itch://collections/${coll.id}',
                        label: coll.title,
                      );
                    },
                  )
                : Stack(
                    children: [
                      ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: item.previewGames.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final game = item.previewGames[index];
                          return ItchGameCard(game: game, compact: true);
                        },
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Material(
                          elevation: 4,
                          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                          child: InkWell(
                            onTap: () {
                              ref.read(tabsControllerProvider.notifier).navigateActiveTab(
                                'itch://collections/${coll.id}',
                                label: coll.title,
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Center(child: Text('Показать все...')),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _LimitedAccessPreview extends StatelessWidget {
  const _LimitedAccessPreview({required this.gamesCount, required this.onOpen});

  final int gamesCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${formatProjectsCountRu(gamesCount)} — обложки не подгрузились. «Показать все» откроет список в приложении',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const Text('Открыть →'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

