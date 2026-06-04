import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/itch_colors.dart';
import '../../../../core/utils/itch_cached_network_image.dart';
import '../../../../core/utils/time_ago.dart';
import '../../../downloads/downloads_controller.dart';
import '../../../downloads/presentation/widgets/download_prime_card.dart';
import '../../../play_history/models/last_played_game.dart';
import '../../../play_history/play_history_controller.dart';
import '../../itch_url.dart';
import '../../models/tab_entry.dart';
import '../../tabs_controller.dart';

/// Боковая панель в стиле itch desktop: вкладки, недавняя игра, скачивания, настройки.
class HubDrawer extends ConsumerStatefulWidget {
  const HubDrawer({super.key});

  @override
  ConsumerState<HubDrawer> createState() => _HubDrawerState();
}

class _HubDrawerState extends ConsumerState<HubDrawer> {
  List<TabEntry> _openTabs = const [];
  String _activeTabId = '';
  ProviderSubscription<TabsState?>? _tabsSubscription;

  @override
  void initState() {
    super.initState();
    _syncFromProvider();
    _tabsSubscription = ref.listenManual<TabsState?>(
      tabsControllerProvider.select((async) => async.asData?.value),
      (_, next) {
        if (next != null) {
          _applyState(next);
        }
      },
    );
  }

  @override
  void dispose() {
    _tabsSubscription?.close();
    super.dispose();
  }

  void _syncFromProvider() {
    final next = ref.read(tabsControllerProvider).asData?.value;
    if (next != null) {
      _applyState(next);
    }
  }

  void _applyState(TabsState state) {
    final tabs = state.openTabs;
    final activeId = state.activeTabId;
    if (_openTabs.length == tabs.length &&
        _activeTabId == activeId &&
        _tabsContentEqual(_openTabs, tabs)) {
      return;
    }
    setState(() {
      _openTabs = List<TabEntry>.from(tabs);
      _activeTabId = activeId;
    });
  }

  bool _tabsContentEqual(List<TabEntry> a, List<TabEntry> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].url != b[i].url || a[i].label != b[i].label) {
        return false;
      }
    }
    return true;
  }

  void _closeDrawer(BuildContext context) {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ref.read(tabsControllerProvider.notifier);
    final lastPlayed = ref.watch(playHistoryProvider).valueOrNull;
    final activeDownload = ref.watch(activeDownloadProvider);

    return RepaintBoundary(
      child: Drawer(
        width: 300,
        elevation: 8,
        backgroundColor: ItchColors.bread,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 4, 4),
                child: Row(
                  children: [
                    const Text(
                      'ВКЛАДКИ',
                      style: TextStyle(
                        color: ItchColors.zambezi,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: ItchColors.secondaryText,
                      tooltip: 'Закрыть все вкладки',
                      onPressed: () {
                        tabs.closeAllTabs();
                        _closeDrawer(context);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 22),
                      color: ItchColors.secondaryText,
                      tooltip: 'Новая вкладка',
                      onPressed: () {
                        tabs.newTab();
                        _closeDrawer(context);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: _openTabs.length,
                  itemExtent: 44,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  itemBuilder: (context, index) {
                    final tab = _openTabs[index];
                    return _TabDrawerRow(
                      tab: tab,
                      selected: tab.id == _activeTabId,
                      onSelect: () {
                        tabs.focusTab(tab.id);
                        _closeDrawer(context);
                      },
                      onClose: () => tabs.closeTab(tab.id),
                    );
                  },
                ),
              ),
              if (activeDownload != null) ...[
                const Divider(height: 1, color: ItchColors.border),
                DownloadPrimeCard(
                  task: activeDownload,
                  onTap: () {
                    _closeDrawer(context);
                    context.push('/downloads');
                  },
                ),
              ] else if (lastPlayed != null) ...[
                const Divider(height: 1, color: ItchColors.border),
                _RecentGameCard(
                  game: lastPlayed,
                  onOpen: () {
                    final url = lastPlayed.tabUrl ?? 'itch://games/${lastPlayed.gameId}';
                    tabs.navigateActiveTab(url, label: lastPlayed.title);
                    _closeDrawer(context);
                  },
                ),
              ],
              const Divider(height: 1, color: ItchColors.border),
              _DrawerFooterButton(
                icon: Icons.download_outlined,
                label: 'Скачивания',
                onTap: () {
                  _closeDrawer(context);
                  context.push('/downloads');
                },
              ),
              _DrawerFooterButton(
                icon: Icons.settings_outlined,
                label: 'Настройки',
                onTap: () {
                  _closeDrawer(context);
                  context.push('/settings');
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

}

class _RecentGameCard extends StatelessWidget {
  const _RecentGameCard({required this.game, required this.onOpen});

  final LastPlayedGame game;
  final VoidCallback onOpen;

  static const _coverAspect = 215 / 170;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ItchColors.item,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: AspectRatio(
          aspectRatio: _coverAspect,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (game.coverUrl != null && game.coverUrl!.isNotEmpty)
                ItchCachedNetworkImage(
                  url: game.coverUrl!,
                  fit: BoxFit.cover,
                )
              else
                const ColoredBox(color: ItchColors.darkMineShaft),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
              const Center(
                child: Icon(Icons.play_circle_fill, size: 52, color: Colors.white70),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      game.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ItchColors.ivory,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.2,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Последний раз в игре ${formatTimeAgoRu(game.lastPlayedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ItchColors.secondaryText,
                        fontSize: 11,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
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

class _DrawerFooterButton extends StatelessWidget {
  const _DrawerFooterButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ItchColors.secondaryText),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(color: ItchColors.ivory, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _TabDrawerRow extends StatelessWidget {
  const _TabDrawerRow({
    required this.tab,
    required this.selected,
    required this.onSelect,
    required this.onClose,
  });

  final TabEntry tab;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  static IconData _iconForUrl(String url) {
    final page = ItchUrl.parse(url).page;
    if (page == 'games') {
      return Icons.nightlight_round;
    }
    switch (page) {
      case 'new-tab':
        return Icons.tab_outlined;
      case 'library':
        return Icons.favorite_border;
      case 'featured':
        return Icons.public;
      case 'collections':
        return Icons.video_library_outlined;
      case 'history':
        return Icons.history;
      case 'dashboard':
      case 'upload':
        return Icons.folder_outlined;
      default:
        if (url.contains(':\\') || url.startsWith('file://')) {
          return Icons.folder_outlined;
        }
        return Icons.language;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0x1FFFFFFF) : Colors.transparent;
    return Material(
      color: bg,
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.only(left: 10, right: 2),
          child: Row(
            children: [
              Icon(_iconForUrl(tab.url), size: 18, color: ItchColors.secondaryText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? ItchColors.ivory : ItchColors.secondaryText,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                color: ItchColors.zambezi,
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
