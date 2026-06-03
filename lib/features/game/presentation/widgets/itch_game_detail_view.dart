import 'package:flutter/material.dart';

import '../../../../core/theme/itch_colors.dart';
import '../../../install/game_install_status_provider.dart';
import '../../../../core/utils/itch_cached_network_image.dart';
import '../../../../data/game_page_models.dart';
import '../../../../data/game_page_theme.dart';
import 'itch_formatted_description.dart';

/// Страница игры в стиле itch.io: фон `.wrapper` скроллится вместе с контентом.
class ItchGameDetailView extends StatelessWidget {
  const ItchGameDetailView({
    required this.detail,
    required this.displayTitle,
    required this.owned,
    required this.uiState,
    required this.onPrimaryAction,
    super.key,
  });

  final GameDetail detail;
  final String displayTitle;
  final bool owned;
  final GameInstallUiState uiState;
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
                          uiState: uiState,
                          onPressed: onPrimaryAction,
                          background: btnBg,
                          foreground: btnFg,
                        ),
                      ],
                    ),
                  ),
                  if (detail.screenshots.length > 1)
                    Container(
                      color: panelBg,
                      padding: const EdgeInsets.only(top: 12),
                      child: _ScreenshotCarousel(
                        items: detail.screenshots,
                        titleColor: textColor,
                      ),
                    ),
                  Container(
                    color: panelBg,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: _DescriptionBlock(
                      detail: detail,
                      textColor: textColor,
                    ),
                  ),
                  if (detail.tags.isNotEmpty)
                    Container(
                      color: panelBg,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _TagRow(tags: detail.tags, theme: theme),
                    ),
                  if (detail.infoRows.isNotEmpty)
                    Container(
                      color: panelBg,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      child: _InfoPanel(
                        detail: detail,
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

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.uiState,
    required this.onPressed,
    required this.background,
    required this.foreground,
  });

  final GameInstallUiState uiState;
  final VoidCallback onPressed;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final (icon, label, enabled) = switch (uiState.action) {
      GamePrimaryAction.install => (Icons.download_rounded, 'Установить', true),
      GamePrimaryAction.play => (Icons.play_arrow_rounded, 'Играть', true),
      GamePrimaryAction.update => (Icons.system_update_rounded, 'Обновить', true),
      GamePrimaryAction.downloading => (Icons.downloading, 'Скачивание…', false),
    };

    final child = FilledButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, color: foreground, size: 20),
      label: Text(
        label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w600, fontSize: 15),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: background,
        minimumSize: const Size(double.infinity, 48),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: const StadiumBorder(),
      ),
    );

    if (uiState.action == GamePrimaryAction.downloading &&
        uiState.downloadProgress != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child,
          const SizedBox(height: 8),
          LinearProgressIndicator(value: uiState.downloadProgress),
        ],
      );
    }
    if (uiState.updateAvailable && uiState.latestVersion != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child,
          const SizedBox(height: 6),
          Text(
            'Доступна версия ${uiState.latestVersion}',
            style: TextStyle(color: foreground.withValues(alpha: 0.85), fontSize: 12),
          ),
        ],
      );
    }
    return child;
  }
}

class _ScreenshotCarousel extends StatelessWidget {
  const _ScreenshotCarousel({required this.items, required this.titleColor});

  final List<GameMediaItem> items;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Скриншоты',
            style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final url = items[index].url;
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: ItchCachedNetworkImage(
                  url: url,
                  width: 240,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        ),
      ],
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
        Text(
          'Описание',
          style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        if (hasHtml)
          ItchFormattedDescription(
            html: detail.descriptionHtml,
            theme: detail.theme,
          )
        else if (detail.description.trim().isNotEmpty || detail.shortText.trim().isNotEmpty)
          Text(
            detail.description.trim().isNotEmpty ? detail.description : detail.shortText,
            style: TextStyle(color: textColor.withValues(alpha: 0.9), height: 1.5, fontSize: 14),
          )
        else
          Text(
            'Описание загрузится с itch.io (нужен интернет).',
            style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 13),
          ),
      ],
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tags, this.theme});

  final List<String> tags;
  final GamePageTheme? theme;

  @override
  Widget build(BuildContext context) {
    final fg = theme?.textColor ?? ItchColors.filterTagText;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: theme?.borderColor ?? ItchColors.border),
          ),
          child: Text(tag, style: TextStyle(color: fg, fontSize: 12)),
        );
      }).toList(),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.detail, required this.textColor, this.theme});

  final GameDetail detail;
  final Color textColor;
  final GamePageTheme? theme;

  @override
  Widget build(BuildContext context) {
    final rows = detail.infoRows.entries
        .where((e) => !{'Платформы', 'Platforms'}.contains(e.key))
        .take(8)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Информация', style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 8),
        for (final row in rows) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  row.key,
                  style: TextStyle(color: textColor.withValues(alpha: 0.55), fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  row.value,
                  style: TextStyle(color: textColor.withValues(alpha: 0.9), fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
        ],
      ],
    );
  }
}
