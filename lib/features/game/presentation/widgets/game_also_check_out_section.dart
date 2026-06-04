import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/game_page_models.dart';
import '../../../../data/game_page_theme.dart';
import 'game_promo_card_loader.dart';

/// Секция «Also check out» как на itch.io desktop.
class GameAlsoCheckOutSection extends ConsumerWidget {
  const GameAlsoCheckOutSection({
    required this.games,
    this.theme,
    super.key,
  });

  final List<GamePromoCard> games;
  final GamePageTheme? theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (games.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = theme?.textColor ?? const Color(0xFFD4CECE);
    final linkColor = theme?.linkColor ?? const Color(0xFFFA5C5C);
    final buttonBg = theme?.buttonColor ?? linkColor;
    final buttonFg = theme?.buttonForegroundColor ?? Colors.white;
    final borderColor = theme?.borderColor ?? const Color(0xFF262626);
    final cardBackground = theme?.innerColumnColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Also check out',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final game in games) ...[
            GamePromoCardLoader(
              game: game,
              textColor: textColor,
              linkColor: linkColor,
              buttonBg: buttonBg,
              buttonFg: buttonFg,
              borderColor: borderColor,
              cardBackground: cardBackground,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
