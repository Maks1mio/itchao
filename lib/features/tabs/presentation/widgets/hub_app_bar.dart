import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/itch_colors.dart';
import '../../../../domain/use_cases/providers.dart';
import '../../itch_url.dart';
import '../tab_chrome_provider.dart';
import '../../tabs_controller.dart';
import 'itch_transparent_app_bar.dart';

class HubAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const HubAppBar({required this.scaffoldKey, super.key});

  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Size get preferredSize => const Size.fromHeight(TabChromeState.appBarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chrome = ref.watch(tabChromeProvider);
    final activeLabel = ref.watch(
      tabsControllerProvider.select((async) => async.asData?.value.activeTab?.label),
    );
    final activePage = ref.watch(
      tabsControllerProvider.select((async) {
        final url = async.asData?.value.activeTab?.url;
        return url == null ? null : ItchUrl.parse(url).page;
      }),
    );

    Widget? title;
    if (chrome.appBarTitle != null) {
      title = chrome.appBarTitle;
    } else if (chrome.showTitle && activeLabel != null) {
      title = Text(activeLabel, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return ItchTransparentAppBar(
      centerTitle: false,
      titleSpacing: 8,
      leading: IconButton(
        icon: const Icon(Icons.menu),
        tooltip: 'Меню',
        onPressed: () => scaffoldKey.currentState?.openDrawer(),
      ),
      title: title,
      actions: [
        ...chrome.extraActions,
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'Ещё',
          color: ItchColors.item,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onSelected: (id) => _onOverflowSelected(context, ref, id, activePage),
          itemBuilder: (context) => _overflowMenuEntries(chrome, activePage),
        ),
      ],
    );
  }

  static List<PopupMenuEntry<String>> _overflowMenuEntries(
    TabChromeState chrome,
    String? activePage,
  ) {
    final entries = <PopupMenuEntry<String>>[];

    for (final item in chrome.menuItems) {
      entries.add(PopupMenuItem(value: item.id, child: Text(item.label)));
    }

    if (activePage == 'library') {
      entries.add(const PopupMenuItem(value: 'refresh_library', child: Text('Обновить библиотеку')));
    }

    entries.add(const PopupMenuItem(value: 'new_tab', child: Text('Новая вкладка')));

    return entries;
  }

  static void _onOverflowSelected(
    BuildContext context,
    WidgetRef ref,
    String id,
    String? activePage,
  ) {
    final tabs = ref.read(tabsControllerProvider.notifier);
    switch (id) {
      case 'new_tab':
        tabs.newTab();
        return;
      case 'refresh_library':
        if (activePage == 'library') {
          ref.read(fetchLibraryUseCaseProvider).call();
        }
        return;
      default:
        ref.read(tabChromeProvider.notifier).invoke(id);
    }
  }
}
