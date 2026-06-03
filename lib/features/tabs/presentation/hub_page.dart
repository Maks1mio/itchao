import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/itch_colors.dart';
import '../../../domain/use_cases/providers.dart';
import '../itch_url.dart';
import '../models/tab_entry.dart';
import '../tabs_controller.dart';
import 'tab_content_view.dart';

class HubPage extends ConsumerWidget {
  const HubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabsAsync = ref.watch(tabsControllerProvider);
    final tabs = ref.read(tabsControllerProvider.notifier);

    return tabsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Ошибка вкладок: $error')),
      ),
      data: (tabsState) => _buildHub(context, ref, tabsState, tabs),
    );
  }

  Widget _buildHub(
    BuildContext context,
    WidgetRef ref,
    TabsState tabsState,
    TabsController tabs,
  ) {
    final active = tabsState.activeTab;
    final canPopTab = tabs.canPopActiveTab();

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        if (tabs.popActiveTab()) {
          return;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (scaffoldContext) => IconButton(
              icon: Icon(canPopTab ? Icons.arrow_back : Icons.menu),
              onPressed: () {
                if (canPopTab) {
                  tabs.popActiveTab();
                } else {
                  Scaffold.of(scaffoldContext).openDrawer();
                }
              },
            ),
          ),
          title: Text(active?.label ?? 'Вкладки'),
          actions: [
            if (active != null && ItchUrl.parse(active.url).page == 'library')
              IconButton(
                onPressed: () => ref.read(fetchLibraryUseCaseProvider).call(),
                icon: const Icon(Icons.refresh),
              ),
            IconButton(
              onPressed: tabs.newTab,
              tooltip: 'Новая вкладка',
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        drawer: Drawer(
          child: Builder(
            builder: (drawerContext) => SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'ВКЛАДКИ',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: ItchColors.zambezi,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final tab in tabsState.openTabs)
                        ListTile(
                          selected: tab.id == tabsState.activeTabId,
                          leading: Icon(_iconForUrl(tab.url)),
                          title: Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: tabsState.openTabs.length > 1
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () => tabs.closeTab(tab.id),
                                )
                              : null,
                          onTap: () {
                            tabs.focusTab(tab.id);
                            Navigator.pop(drawerContext);
                          },
                        ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('Обзор'),
                  onTap: () {
                    tabs.openTab('itch://featured');
                    Navigator.pop(drawerContext);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.favorite),
                  title: const Text('Игротека'),
                  onTap: () {
                    tabs.openTab('itch://library');
                    Navigator.pop(drawerContext);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.video_library_outlined),
                  title: const Text('Коллекции'),
                  onTap: () {
                    tabs.openTab('itch://collections');
                    Navigator.pop(drawerContext);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('История'),
                  onTap: () {
                    tabs.openTab('itch://history');
                    Navigator.pop(drawerContext);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Скачивания'),
                  onTap: () {
                    Navigator.pop(drawerContext);
                    context.push('/downloads');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Настройки'),
                  onTap: () {
                    Navigator.pop(drawerContext);
                    context.push('/settings');
                  },
                ),
              ],
            ),
          ),
          ),
        ),
        body: active == null
            ? const Center(child: CircularProgressIndicator())
            : TabContentView(key: ValueKey(active.id + active.url), url: active.url),
      ),
    );
  }

  IconData _iconForUrl(String url) {
    final page = ItchUrl.parse(url).page;
    switch (page) {
      case 'new-tab':
        return Icons.tab_outlined;
      case 'library':
        return Icons.favorite;
      case 'featured':
        return Icons.public;
      case 'collections':
        return Icons.video_library_outlined;
      case 'history':
        return Icons.history;
      case 'downloads':
        return Icons.download_outlined;
      case 'preferences':
        return Icons.settings_outlined;
      default:
        return Icons.web_outlined;
    }
  }
}
