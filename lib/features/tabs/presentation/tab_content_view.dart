import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models.dart';
import '../../downloads/presentation/downloads_page.dart';
import '../../install/installed_games_controller.dart';
import '../../install/installed_library_games.dart';
import '../../library/library_controller.dart';
import '../../settings/presentation/settings_page.dart';
import '../itch_url.dart';
import '../itch_web_urls.dart';
import 'tab_chrome_provider.dart';
import 'new_tab_page.dart';
import 'pages/collection_detail_page.dart';
import 'pages/collections_page.dart';
import 'pages/itch_browser_page.dart';
import '../../game/presentation/game_detail_page.dart';
import 'pages/history_page.dart';
import 'pages/library_games_list_page.dart';
import 'pages/owned_library_page.dart';
import 'widgets/itch_tab_body.dart';

class TabContentView extends ConsumerStatefulWidget {
  const TabContentView({required this.url, super.key});

  final String url;

  @override
  ConsumerState<TabContentView> createState() => _TabContentViewState();
}

class _LibraryGamesListTab extends ConsumerWidget {
  const _LibraryGamesListTab({required this.segment});

  final String segment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryControllerProvider).valueOrNull ?? const <LibraryGame>[];
    final installed = ref.watch(installedGamesProvider);
    final (title, games) = switch (segment) {
      'installed' => (
        'Установленные',
        buildInstalledLibraryGames(installed: installed, library: library),
      ),
      _ => ('Купленные', library),
    };
    return LibraryGamesListPage(title: title, games: games);
  }
}

class _TabContentViewState extends ConsumerState<TabContentView> {
  @override
  void initState() {
    super.initState();
    _scheduleResetChromeForUrl(widget.url);
  }

  @override
  void didUpdateWidget(covariant TabContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _scheduleResetChromeForUrl(widget.url);
    }
  }

  void _scheduleResetChromeForUrl(String url) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _resetChromeForUrl(url);
    });
  }

  /// Сбрасываем поиск/фильтр и нижнюю панель браузера при смене URL вкладки.
  void _resetChromeForUrl(String url) {
    final parsed = ItchUrl.parse(url);
    final notifier = ref.read(tabChromeProvider.notifier);
    notifier.clearAppBarContent();

    final isBrowser = parsed.isExternal ||
        parsed.page == 'browser' ||
        parsed.page == 'featured' ||
        parsed.page == 'dashboard' ||
        parsed.page == 'upload';
    final showTitle = switch (parsed.page) {
      'games' || 'browser' || 'collections' => false,
      _ => !parsed.isExternal,
    };
    notifier.clearPageMenu(showTitle: isBrowser ? false : showTitle);
  }

  @override
  Widget build(BuildContext context) {
    final parsed = ItchUrl.parse(widget.url);
    switch (parsed.page) {
      case 'new-tab':
        return const ItchTabBody(child: NewTabPage());
      case 'history':
        return const ItchTabBody(child: HistoryPage());
      case 'library':
        final segment = parsed.segment;
        if (segment == 'purchased' || segment == 'installed') {
          return ItchTabBody(
            child: _LibraryGamesListTab(segment: segment!),
          );
        }
        return const ItchTabBody(child: OwnedLibraryPage());
      case 'downloads':
        return const ItchTabBody(child: DownloadsPage());
      case 'preferences':
        return const ItchTabBody(child: SettingsPage());
      case 'collections':
        if (parsed.segment != null) {
          final id = int.tryParse(parsed.segment!);
          if (id != null) {
            return ItchTabBody(
              child: CollectionDetailPage(
                collectionId: id,
                title: ItchUrl.labelFor(widget.url),
              ),
            );
          }
        }
        return const ItchTabBody(child: CollectionsPage());
      case 'games':
        final gameId = int.tryParse(parsed.segment ?? '');
        if (gameId != null && gameId > 0) {
          return GameDetailPage(
            gameId: gameId,
            fallbackTitle: parsed.displayLabel,
          );
        }
        return const ItchTabBody(child: NewTabPage());
      case 'featured':
      case 'dashboard':
      case 'upload':
      case 'browser':
        return ItchBrowserPage(initialUrl: itchUrlToWebUrl(widget.url));
      default:
        if (parsed.isExternal) {
          return ItchBrowserPage(initialUrl: parsed.externalUrl!);
        }
        return ItchBrowserPage(initialUrl: itchUrlToWebUrl(widget.url));
    }
  }
}
