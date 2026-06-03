import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/itch_colors.dart';
import '../../../../data/models.dart';
import '../../tabs_controller.dart';
import 'itch_game_card.dart';

/// Горизонтальная полоса игр в игротеке (как itch desktop: Купленные / Установленные).
class LibraryGameStripe extends ConsumerWidget {
  const LibraryGameStripe({
    required this.title,
    required this.games,
    required this.showAllUrl,
    this.showAllLabel,
    super.key,
  });

  final String title;
  final List<LibraryGame> games;
  final String showAllUrl;
  final String? showAllLabel;

  static const _previewLimit = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = games.take(_previewLimit).toList();
    final hasMore = games.length > preview.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: ItchColors.ivory,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: ItchGameCoverSize.stripeHeight,
            child: games.isEmpty
                ? _EmptyStripe(message: 'Пока пусто')
                : Stack(
                    children: [
                      ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: preview.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          return ItchGameCard(game: preview[index], compact: true);
                        },
                      ),
                      if (hasMore || games.isNotEmpty)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: Material(
                            elevation: 6,
                            color: ItchColors.background.withValues(alpha: 0.94),
                            child: InkWell(
                              onTap: () {
                                ref.read(tabsControllerProvider.notifier).navigateActiveTab(
                                  showAllUrl,
                                  label: showAllLabel ?? title,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                child: Center(
                                  child: Text(
                                    'Показать все…',
                                    style: TextStyle(
                                      color: ItchColors.secondaryText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
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

class _EmptyStripe extends StatelessWidget {
  const _EmptyStripe({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _PlaceholderCover(),
          const SizedBox(width: 10),
          _PlaceholderCover(),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: ItchColors.zambezi, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: ItchGameCoverSize.stripeWidth,
        height: ItchGameCoverSize.stripeHeight,
        child: const ColoredBox(color: ItchColors.darkMineShaft),
      ),
    );
  }
}
