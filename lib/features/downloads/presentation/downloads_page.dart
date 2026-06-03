import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../downloads_controller.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(downloadsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Скачивания'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: items.isEmpty
          ? const Center(child: Text('Пока нет загрузок'))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item.gameTitle),
                  subtitle: LinearProgressIndicator(value: item.progress),
                  trailing: Text(item.status.name),
                );
              },
            ),
    );
  }
}
