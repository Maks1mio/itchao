import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tabs_controller.dart';

class _NewTabItem {
  const _NewTabItem({required this.label, required this.icon, required this.url});
  final String label;
  final IconData icon;
  final String url;
}

const _primaryItems = [
  _NewTabItem(label: 'Обзор', icon: Icons.public, url: 'itch://featured'),
  _NewTabItem(label: 'Игротека', icon: Icons.favorite, url: 'itch://library'),
  _NewTabItem(label: 'Коллекции', icon: Icons.video_library_outlined, url: 'itch://collections'),
  _NewTabItem(label: 'История', icon: Icons.history, url: 'itch://history'),
  _NewTabItem(label: 'Мои творения', icon: Icons.inventory_2_outlined, url: 'itch://dashboard'),
  _NewTabItem(label: 'Публикация', icon: Icons.upload_outlined, url: 'itch://upload'),
];

const _secondaryItems = [
  _NewTabItem(label: 'Случайные игры', icon: Icons.shuffle, url: 'https://itch.io/randomizer'),
  _NewTabItem(label: 'Распродажа', icon: Icons.shopping_cart_outlined, url: 'https://itch.io/games/on-sale'),
  _NewTabItem(label: 'Самые продаваемые', icon: Icons.star_outline, url: 'https://itch.io/games/top-sellers'),
  _NewTabItem(label: 'Дневники разработчиков', icon: Icons.local_fire_department_outlined, url: 'https://itch.io/devlogs'),
];

class NewTabPage extends ConsumerWidget {
  const NewTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Новая вкладка',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _buildGrid(context, ref, _primaryItems),
        const SizedBox(height: 8),
        _buildGrid(context, ref, _secondaryItems),
      ],
    );
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref, List<_NewTabItem> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final item in items)
          SizedBox(
            width: 150,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  final tabs = ref.read(tabsControllerProvider.notifier);
                  if (item.url.startsWith('https://')) {
                    tabs.navigateActiveTab(item.url);
                  } else {
                    tabs.navigateActiveTab(item.url);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(item.icon, size: 40),
                      const SizedBox(height: 12),
                      Text(item.label, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
