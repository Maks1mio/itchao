import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/itch_colors.dart';
import '../../../collections/collections_controller.dart';

/// Поле поиска + сортировка в одной строке AppBar (между меню и ⋯).
class CollectionsListAppBarTitle extends ConsumerWidget {
  const CollectionsListAppBarTitle({required this.searchController, super.key});

  final TextEditingController searchController;

  static const _fieldStyle = TextStyle(color: ItchColors.ivory, fontSize: 14);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(collectionsControllerProvider);
    final controller = ref.read(collectionsControllerProvider.notifier);
    final sortField = controller.sortField;
    final sortReverse = controller.sortReverse;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: searchController,
            style: _fieldStyle,
            decoration: InputDecoration(
              hintText: 'Поиск коллекций',
              hintStyle: TextStyle(color: ItchColors.zambezi.withValues(alpha: 0.95), fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: ItchColors.secondaryText, size: 20),
              filled: true,
              fillColor: ItchColors.item.withValues(alpha: 0.85),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: controller.setSearch,
          ),
        ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          icon: Icon(
            sortReverse ? Icons.arrow_downward : Icons.arrow_upward,
            color: Colors.white,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
          ),
          tooltip: 'Сортировка',
          color: ItchColors.item,
          onSelected: (value) {
            switch (value) {
              case 'title_asc':
                controller.setSort(CollectionSortField.title, reverse: false);
              case 'title_desc':
                controller.setSort(CollectionSortField.title, reverse: true);
              case 'updated_desc':
                controller.setSort(CollectionSortField.updatedAt, reverse: true);
              case 'updated_asc':
                controller.setSort(CollectionSortField.updatedAt, reverse: false);
              case 'refresh':
                controller.refresh();
            }
          },
          itemBuilder: (context) => [
            _sortItem(
              value: 'title_asc',
              label: 'По названию (А→Я)',
              checked: sortField == CollectionSortField.title && !sortReverse,
            ),
            _sortItem(
              value: 'title_desc',
              label: 'По названию (Я→А)',
              checked: sortField == CollectionSortField.title && sortReverse,
            ),
            _sortItem(
              value: 'updated_desc',
              label: 'Сначала новые',
              checked: sortField == CollectionSortField.updatedAt && sortReverse,
            ),
            _sortItem(
              value: 'updated_asc',
              label: 'Сначала старые',
              checked: sortField == CollectionSortField.updatedAt && !sortReverse,
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'refresh',
              child: ListTile(
                leading: Icon(Icons.refresh),
                title: Text('Обновить'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static PopupMenuEntry<String> _sortItem({
    required String value,
    required String label,
    required bool checked,
  }) {
    return CheckedPopupMenuItem(
      value: value,
      checked: checked,
      child: Text(label),
    );
  }
}

/// Фильтр игр в коллекции — в строке AppBar.
class CollectionDetailAppBarTitle extends StatelessWidget {
  const CollectionDetailAppBarTitle({
    required this.searchController,
    required this.hintText,
    required this.onChanged,
    super.key,
  });

  final TextEditingController searchController;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: searchController,
      style: const TextStyle(color: ItchColors.ivory, fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: ItchColors.zambezi.withValues(alpha: 0.95), fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: ItchColors.secondaryText, size: 20),
        filled: true,
        fillColor: ItchColors.item.withValues(alpha: 0.85),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: onChanged,
    );
  }
}
