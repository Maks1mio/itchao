import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/itch_colors.dart';
import '../../../../data/models.dart';
import '../../game_page_url.dart';
import '../../tabs_controller.dart';

/// Размер обложки как в itch desktop (`StandardGameCover`: 215×170 × 0.9).
abstract final class ItchGameCoverSize {
  static const baseWidth = 215.0;
  static const baseHeight = 170.0;

  static const listWidth = 120.0;
  static const listHeight = listWidth * (baseHeight / baseWidth);

  static const stripeWidth = 164.0;
  static const stripeHeight = stripeWidth * (baseHeight / baseWidth);
}

/// Вертикальная карточка в стиле Google Play + обложка itch.
class ItchGameCard extends ConsumerWidget {
  const ItchGameCard({
    required this.game,
    super.key,
    this.compact = false,
  });

  final LibraryGame game;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compact) {
      return SizedBox(
        width: ItchGameCoverSize.stripeWidth,
        child: _StripeTile(
          game: game,
          onOpen: () => _openGamePage(ref),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _openGamePage(ref),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _CoverThumb(game: game),
                  const SizedBox(width: 14),
                  Expanded(child: _GameInfo(game: game)),
                ],
              ),
            ),
          ),
          _InstallIconButton(
            onPressed: () => _queueInstall(context),
          ),
        ],
      ),
    );
  }

  void _openGamePage(WidgetRef ref) {
    ref.read(tabsControllerProvider.notifier).openTab(
      itchGamePageUrl(game),
      label: game.title,
    );
  }

  void _queueInstall(BuildContext context) {
    context.push(
      '/downloads/new/${game.id}?title=${Uri.encodeComponent(game.title)}',
    );
  }
}

class _GameInfo extends StatelessWidget {
  const _GameInfo({required this.game});

  final LibraryGame game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          game.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: ItchColors.ivory,
            height: 1.25,
          ),
        ),
        if (game.shortText != null && game.shortText!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            game.shortText!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: ItchColors.secondaryText,
              height: 1.35,
            ),
          ),
        ],
        if (game.platforms.isNotEmpty || game.classification.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                _classificationLabel(game.classification),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: ItchColors.zambezi,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 6),
              ...game.platforms.take(4).map(
                (p) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    _platformIcon(p),
                    size: 15,
                    color: ItchColors.zambezi,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _InstallIconButton extends StatelessWidget {
  const _InstallIconButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: IconButton(
        onPressed: onPressed,
        tooltip: 'Установить',
        icon: const Icon(Icons.download_rounded),
        style: IconButton.styleFrom(
          backgroundColor: ItchColors.accent,
          foregroundColor: ItchColors.ivory,
          fixedSize: const Size(44, 44),
          padding: EdgeInsets.zero,
          elevation: 0,
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

String _classificationLabel(String value) {
  return switch (value.toLowerCase()) {
    'tool' => 'Инструмент',
    'comic' => 'Комикс',
    'asset' => 'Ассет',
    'book' => 'Книга',
    _ => 'Игра',
  };
}

IconData _platformIcon(String platform) {
  return switch (platform) {
    'windows' => Icons.desktop_windows_outlined,
    'osx' => Icons.laptop_mac_outlined,
    'linux' => Icons.terminal,
    'android' => Icons.android,
    _ => Icons.devices,
  };
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.game});

  final LibraryGame game;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: ItchGameCoverSize.listWidth,
          height: ItchGameCoverSize.listHeight,
          child: _CoverImage(game: game),
        ),
      ),
    );
  }
}

class _StripeTile extends StatelessWidget {
  const _StripeTile({required this.game, required this.onOpen});

  final LibraryGame game;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(10),
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: ItchGameCoverSize.stripeWidth,
            height: ItchGameCoverSize.stripeHeight,
            child: _CoverImage(game: game),
          ),
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.game});

  final LibraryGame game;

  @override
  Widget build(BuildContext context) {
    final url = game.coverUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (_, _, _) => const _CoverPlaceholder(),
      );
    }
    return const _CoverPlaceholder();
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: ItchColors.darkMineShaft,
      child: Center(
        child: Icon(
          Icons.videogame_asset_outlined,
          size: 32,
          color: ItchColors.zambezi,
        ),
      ),
    );
  }
}

/// Вертикальный список карточек.
class ItchGameListView extends StatelessWidget {
  const ItchGameListView({
    required this.games,
    super.key,
    this.controller,
    this.padding,
    this.footer,
  });

  final List<LibraryGame> games;
  final ScrollController? controller;
  final EdgeInsets? padding;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final footerWidget = footer;
    return ListView.separated(
      controller: controller,
      padding: padding ?? const EdgeInsets.only(bottom: 8),
      separatorBuilder: (context, index) {
        if (footerWidget != null && index >= games.length - 1) {
          return const SizedBox.shrink();
        }
        return const Divider(height: 1, indent: 16, endIndent: 16);
      },
      itemCount: games.length + (footerWidget != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (footerWidget != null && index == games.length) {
          return footerWidget;
        }
        return ItchGameCard(game: games[index]);
      },
    );
  }
}
