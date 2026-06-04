import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/itch_colors.dart';
import '../../../install/game_install_status_provider.dart';
import '../../../../core/utils/itch_cached_network_image.dart';
import '../../../../data/game_page_models.dart';
import '../../../../data/game_page_theme.dart';
import 'game_also_check_out_section.dart';
import 'game_more_info_panel.dart';
import 'game_screenshot_gallery.dart';
import 'itch_formatted_description.dart';

/// Страница игры в стиле itch.io: фон `.wrapper` скроллится вместе с контентом.
class ItchGameDetailView extends StatelessWidget {
  const ItchGameDetailView({
    required this.detail,
    required this.displayTitle,
    required this.owned,
    required this.onPrimaryAction,
    super.key,
  });

  final GameDetail detail;
  final String displayTitle;
  final bool owned;
  final VoidCallback onPrimaryAction;

  /// `.inner_column` — полупрозрачный, сквозь него виден фон `.wrapper`.
  Color _panelColor(GamePageTheme? theme) {
    return theme?.innerColumnColor ?? ItchColors.item.withValues(alpha: 0.67);
  }

  @override
  Widget build(BuildContext context) {
    final theme = detail.theme;
    final pageBg = theme?.backgroundColor ?? ItchColors.background;
    final panelBg = _panelColor(theme);
    final textColor = theme?.textColor ?? ItchColors.ivory;
    final linkColor = theme?.linkColor ?? ItchColors.accentLight;
    final btnBg = theme?.buttonColor ?? ItchColors.accent;
    final btnFg = theme?.buttonForegroundColor ?? ItchColors.ivory;
    final bgUrl = theme?.backgroundImageUrl;

    final pageDecoration = BoxDecoration(
      color: pageBg,
      image: bgUrl != null
          ? DecorationImage(
              image: NetworkImage(bgUrl),
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              repeat: ImageRepeat.repeatX,
            )
          : null,
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(decoration: pageDecoration),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CoverHeader(
                    detail: detail,
                    owned: owned,
                    panelColor: panelBg,
                    title: displayTitle,
                    textColor: textColor,
                    linkColor: linkColor,
                  ),
                  Container(
                    color: panelBg,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PrimaryActionButton(
                          gameId: detail.id,
                          onPressed: onPrimaryAction,
                          background: btnBg,
                          foreground: btnFg,
                        ),
                      ],
                    ),
                  ),
                  if (detail.screenshots.isNotEmpty)
                    Container(
                      color: panelBg,
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: GameScreenshotStrip(
                        items: detail.screenshots,
                        titleColor: textColor,
                      ),
                    ),
                  Container(
                    color: panelBg,
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DescriptionBlock(
                          detail: detail,
                          textColor: textColor,
                        ),
                        if (detail.descriptionFooterHtml.trim().isNotEmpty)
                          ItchFormattedDescription(
                            html: detail.descriptionFooterHtml,
                            theme: theme,
                          ),
                        if (detail.relatedGames.isNotEmpty)
                          GameAlsoCheckOutSection(
                            games: detail.relatedGames,
                            theme: theme,
                          ),
                      ],
                    ),
                  ),
                  if (detail.infoEntries.isNotEmpty)
                    Container(
                      color: panelBg,
                      child: GameMoreInfoPanel(
                        entries: detail.infoEntries,
                        textColor: textColor,
                        theme: theme,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CoverHeader extends StatelessWidget {
  const _CoverHeader({
    required this.detail,
    required this.owned,
    required this.panelColor,
    required this.title,
    required this.textColor,
    required this.linkColor,
  });

  final GameDetail detail;
  final bool owned;
  final Color panelColor;
  final String title;
  final Color textColor;
  final Color linkColor;

  @override
  Widget build(BuildContext context) {
    final cover = detail.headerCoverUrl ?? detail.heroImageUrl ?? detail.coverUrl;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cover != null && cover.isNotEmpty)
          Stack(
            alignment: Alignment.topCenter,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  return ItchCachedNetworkImage(
                    url: cover,
                    width: w,
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                    filterQuality: FilterQuality.medium,
                    errorWidget: SizedBox(height: 120 + topInset),
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: topInset + 80,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          SizedBox(height: topInset),
        ColoredBox(
          color: panelColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (detail.developerName != null && detail.developerName!.isNotEmpty)
                  Text(
                    detail.developerName!.toUpperCase(),
                    style: TextStyle(
                      color: linkColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                if (detail.developerName != null && detail.developerName!.isNotEmpty)
                  const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 14),
                _MetaLine(
                  detail: detail,
                  owned: owned,
                  textColor: textColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.detail,
    required this.owned,
    required this.textColor,
  });

  final GameDetail detail;
  final bool owned;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (detail.ratingAverage != null) {
      final c = detail.ratingCount;
      parts.add('★ ${detail.ratingAverage!.toStringAsFixed(1).replaceAll('.', ',')}${c != null ? ' ($c)' : ''}');
    }
    if (detail.platforms.isNotEmpty) {
      parts.add(detail.platforms.join(', '));
    }
    if (detail.statusLabel != null && detail.statusLabel!.isNotEmpty) {
      parts.add(detail.statusLabel!);
    }
    if (owned) {
      parts.add('В библиотеке');
    }
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      parts.join('  ·  '),
      style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 13, height: 1.35),
    );
  }
}

class _PrimaryActionButton extends ConsumerWidget {
  const _PrimaryActionButton({
    required this.gameId,
    required this.onPressed,
    required this.background,
    required this.foreground,
  });

  final int gameId;
  final VoidCallback onPressed;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = gameId > 0
        ? gameInstallUiStateFromSnapshot(
            ref.watch(
              gameInstallUiStateProvider(gameId).select(gameInstallUiSnapshot),
            ),
          )
        : const GameInstallUiState(action: GamePrimaryAction.install);
    final isDownloading = uiState.action == GamePrimaryAction.downloading;
    final progress = uiState.downloadProgress?.clamp(0.0, 1.0);

    final (icon, label) = switch (uiState.action) {
      GamePrimaryAction.install => (Icons.download_rounded, 'Установить'),
      GamePrimaryAction.play => (Icons.play_arrow_rounded, 'Играть'),
      GamePrimaryAction.update => (Icons.system_update_rounded, 'Обновить'),
      GamePrimaryAction.downloading => (
          Icons.download_rounded,
          _downloadLabel(progress),
        ),
    };

    final button = _ProgressActionButton(
      icon: icon,
      label: label,
      hint: isDownloading ? 'Открыть загрузки' : null,
      onPressed: onPressed,
      background: background,
      foreground: foreground,
      progress: isDownloading ? progress : null,
    );

    if (uiState.updateAvailable &&
        !isDownloading &&
        uiState.latestVersion != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          button,
          const SizedBox(height: 6),
          Text(
            'Доступна версия ${uiState.latestVersion}',
            style: TextStyle(color: foreground.withValues(alpha: 0.85), fontSize: 12),
          ),
        ],
      );
    }
    return button;
  }

  static String _downloadLabel(double? progress) {
    if (progress == null || progress <= 0) {
      return 'Скачивание…';
    }
    return 'Скачивание ${(progress * 100).round()}%';
  }
}

class _ProgressActionButton extends StatelessWidget {
  const _ProgressActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.background,
    required this.foreground,
    this.hint,
    this.progress,
  });

  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback onPressed;
  final Color background;
  final Color foreground;
  final double? progress;

  static const _height = 48.0;
  static const _radius = 24.0;

  @override
  Widget build(BuildContext context) {
    if (progress == null && hint == null) {
      return Material(
        color: background,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: _height,
            width: double.infinity,
            child: _ButtonContent(
              icon: icon,
              label: label,
              foreground: foreground,
            ),
          ),
        ),
      );
    }

    final trackColor = Color.alphaBlend(
      foreground.withValues(alpha: 0.12),
      background.withValues(alpha: 0.45),
    );
    final fillFactor = progress == null || progress! <= 0
        ? null
        : progress!.clamp(0.06, 1.0);

    return Material(
      color: trackColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
        side: BorderSide(color: foreground.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: _height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (fillFactor != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: fillFactor,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: background,
                        boxShadow: [
                          BoxShadow(
                            color: background.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (hint != null)
                _IndeterminateFill(color: background),
              _ButtonContent(
                icon: icon,
                label: label,
                hint: hint,
                foreground: foreground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.icon,
    required this.label,
    required this.foreground,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String? hint;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    height: 1.1,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground.withValues(alpha: 0.78),
                      fontSize: 11,
                      height: 1.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hint != null)
            Icon(
              Icons.chevron_right_rounded,
              color: foreground.withValues(alpha: 0.85),
              size: 22,
            ),
        ],
      ),
    );
  }
}

class _IndeterminateFill extends StatefulWidget {
  const _IndeterminateFill({required this.color});

  final Color color;

  @override
  State<_IndeterminateFill> createState() => _IndeterminateFillState();
}

class _IndeterminateFillState extends State<_IndeterminateFill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.28,
            heightFactor: 1,
            child: FractionalTranslation(
              translation: Offset(_controller.value * 2.6, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.color.withValues(alpha: 0.15),
                      widget.color,
                      widget.color.withValues(alpha: 0.15),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DescriptionBlock extends StatelessWidget {
  const _DescriptionBlock({required this.detail, required this.textColor});

  final GameDetail detail;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final hasHtml = detail.descriptionHtml.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Описание',
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (hasHtml)
          ItchFormattedDescription(
            html: detail.descriptionHtml,
            theme: detail.theme,
          )
        else if (detail.description.trim().isNotEmpty || detail.shortText.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              detail.description.trim().isNotEmpty
                  ? detail.description
                  : detail.shortText,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.9),
                height: 1.5,
                fontSize: 14,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Описание загрузится с itch.io (нужен интернет).',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}
