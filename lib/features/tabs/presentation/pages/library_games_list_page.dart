import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/itch_colors.dart';
import '../../../../data/models.dart';
import '../widgets/itch_game_card.dart';

/// Полный список купленных или установленных игр («Показать все…»).
class LibraryGamesListPage extends ConsumerWidget {
  const LibraryGamesListPage({
    required this.title,
    required this.games,
    super.key,
  });

  final String title;
  final List<LibraryGame> games;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (games.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Список пуст',
            style: TextStyle(color: ItchColors.secondaryText),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: games.length,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: ItchGameCard(game: games[index]),
        );
      },
    );
  }
}
