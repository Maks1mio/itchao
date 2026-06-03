import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/itch_colors.dart';
import '../../../../core/utils/time_ago.dart';
import '../../browsing_history_controller.dart';
import '../../game_page_url.dart';
import '../../tabs_controller.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(browsingHistoryProvider);

    return history.when(
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'История пуста.\nОткрытые страницы и игры появятся здесь.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ItchColors.secondaryText,
                ),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'История',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.read(browsingHistoryProvider.notifier).clear(),
                    child: const Text('Очистить'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    leading: Icon(
                      _iconForUrl(entry.url),
                      color: ItchColors.secondaryText,
                    ),
                    title: Text(
                      entry.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${_formatUrl(entry.url)} · ${formatTimeAgoRu(entry.visitedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ItchColors.zambezi,
                      ),
                    ),
                    onTap: () {
                      final tabUrl = itchGameTabUrlFromHistory(entry.url) ?? entry.url;
                      ref.read(tabsControllerProvider.notifier).navigateActiveTab(
                        tabUrl,
                        label: entry.label,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
    );
  }

  static IconData _iconForUrl(String url) {
    if (url.startsWith('itch://library')) {
      return Icons.favorite;
    }
    if (url.startsWith('itch://collections')) {
      return Icons.video_library_outlined;
    }
    if (url.startsWith('itch://featured')) {
      return Icons.public;
    }
    if (url.startsWith('itch://games') || itchGameTabUrlFromHistory(url) != null) {
      return Icons.sports_esports_outlined;
    }
    return Icons.history;
  }

  static String _formatUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return url;
    }
    if (uri.scheme == 'itch') {
      return url.replaceFirst('itch://', '');
    }
    return uri.host;
  }
}
