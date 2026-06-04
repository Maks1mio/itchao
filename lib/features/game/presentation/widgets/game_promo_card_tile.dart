import 'package:flutter/material.dart';

import '../../../../core/utils/itch_cached_network_image.dart';
import '../../../../data/game_page_models.dart';

/// Горизонтальная промо-карточка itch.io (embed / Also check out).
class GamePromoCardTile extends StatelessWidget {
  const GamePromoCardTile({
    required this.game,
    required this.textColor,
    required this.linkColor,
    required this.buttonBg,
    required this.buttonFg,
    required this.borderColor,
    this.embedBorderColor,
    this.embedBorderWidth = 1,
    this.cardBackground,
    this.ctaLabel = 'Подробнее',
    this.onTap,
    super.key,
  });

  final GamePromoCard game;
  final Color textColor;
  final Color linkColor;
  final Color buttonBg;
  final Color buttonFg;
  final Color borderColor;
  final Color? embedBorderColor;
  final double embedBorderWidth;
  final Color? cardBackground;
  final String ctaLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardBorder = embedBorderColor ?? borderColor;
    final cardBorderWidth = embedBorderColor != null ? embedBorderWidth : 1.0;
    final shellBg =
        cardBackground ?? Colors.black.withValues(alpha: 0.35);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: cardBorder, width: cardBorderWidth),
        color: shellBg,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(coverUrl: game.coverUrl, borderColor: borderColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            game.title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (game.platforms.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _PlatformIcons(
                            platforms: game.platforms,
                            iconColor: textColor.withValues(alpha: 0.55),
                          ),
                        ],
                      ],
                    ),
                    if (game.author != null && game.author!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                          children: [
                            const TextSpan(text: 'by '),
                            TextSpan(
                              text: game.author,
                              style: TextStyle(
                                color: linkColor,
                                decoration: TextDecoration.underline,
                                decorationColor: linkColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (game.summary != null && game.summary!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        game.summary!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.85),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: buttonBg,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            ctaLabel,
                            style: TextStyle(
                              color: buttonFg,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.coverUrl, required this.borderColor});

  final String? coverUrl;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    return SizedBox(
      width: size,
      height: size * 0.79,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          color: Colors.black26,
        ),
        child: coverUrl != null && coverUrl!.isNotEmpty
            ? ItchCachedNetworkImage(
                url: coverUrl!,
                width: size,
                height: size * 0.79,
                fit: BoxFit.cover,
                errorWidget: const ColoredBox(color: Colors.black26),
              )
            : const ColoredBox(color: Colors.black26),
      ),
    );
  }
}

class _PlatformIcons extends StatelessWidget {
  const _PlatformIcons({required this.platforms, required this.iconColor});

  final List<String> platforms;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final platform in platforms.take(4))
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Icon(
              _iconFor(platform),
              size: 14,
              color: iconColor,
            ),
          ),
      ],
    );
  }

  IconData _iconFor(String platform) {
    switch (platform) {
      case 'windows':
        return Icons.desktop_windows_outlined;
      case 'osx':
        return Icons.apple;
      case 'linux':
        return Icons.terminal;
      case 'android':
        return Icons.android;
      default:
        return Icons.videogame_asset_outlined;
    }
  }
}
