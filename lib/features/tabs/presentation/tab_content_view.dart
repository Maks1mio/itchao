import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../downloads/presentation/downloads_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../itch_url.dart';
import '../itch_web_urls.dart';
import 'new_tab_page.dart';
import 'pages/collection_detail_page.dart';
import 'pages/collections_page.dart';
import 'pages/itch_browser_page.dart';
import 'pages/history_page.dart';
import 'pages/owned_library_page.dart';

class TabContentView extends ConsumerWidget {
  const TabContentView({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsed = ItchUrl.parse(url);
    switch (parsed.page) {
      case 'new-tab':
        return const NewTabPage();
      case 'history':
        return const HistoryPage();
      case 'library':
        return const OwnedLibraryPage();
      case 'downloads':
        return const DownloadsPage();
      case 'preferences':
        return const SettingsPage();
      case 'collections':
        if (parsed.segment != null) {
          final id = int.tryParse(parsed.segment!);
          if (id != null) {
            return CollectionDetailPage(
              collectionId: id,
              title: ItchUrl.labelFor(url),
            );
          }
        }
        return const CollectionsPage();
      case 'featured':
      case 'dashboard':
      case 'upload':
      case 'browser':
        return ItchBrowserPage(initialUrl: itchUrlToWebUrl(url));
      default:
        if (parsed.isExternal) {
          return ItchBrowserPage(initialUrl: parsed.externalUrl!);
        }
        return ItchBrowserPage(initialUrl: itchUrlToWebUrl(url));
    }
  }
}
