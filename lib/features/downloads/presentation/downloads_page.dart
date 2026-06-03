import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/itch_colors.dart';
import '../../../data/models.dart';
import '../download_history_controller.dart';
import '../downloads_controller.dart';
import 'widgets/download_row.dart';

/// Страница скачиваний в стиле itch desktop (`DownloadsPage/index.tsx`).
class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({this.standalone = false, super.key});

  /// `true` при открытии через `/downloads` — показываем AppBar с «назад».
  final bool standalone;

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(downloadsControllerProvider.notifier).reconcileActiveTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(downloadsControllerProvider);
    final historyAsync = ref.watch(downloadHistoryProvider);

    return historyAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: ItchColors.accent),
      ),
      error: (e, _) => Center(child: Text('Ошибка: $e', style: const TextStyle(color: ItchColors.ivory))),
      data: (history) {
        final activeTasks = active.where((t) => t.isActive).toList();
        final recent = history
            .where((e) => e.status == DownloadStatus.completed || e.status == DownloadStatus.failed)
            .map((e) => e.toDisplayTask())
            .toList();
        final hasContent = activeTasks.isNotEmpty || recent.isNotEmpty;

        final body = !hasContent
            ? const _EmptyState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(10, 15, 20, 20),
                children: [
                  if (activeTasks.isNotEmpty) ...[
                    _SectionBar(title: 'Активные'),
                    DownloadRow(
                      task: activeTasks.first,
                      isFirst: true,
                      onDismiss: () => ref
                          .read(downloadsControllerProvider.notifier)
                          .cancelActive(activeTasks.first.id),
                    ),
                    if (activeTasks.length > 1) ...[
                      _SectionBar(
                        title: 'В очереди',
                        trailing: _TextAction(
                          label: 'Отменить все',
                          onPressed: () => ref
                              .read(downloadsControllerProvider.notifier)
                              .cancelAllActive(),
                        ),
                      ),
                      for (var i = 1; i < activeTasks.length; i++)
                        DownloadRow(
                          task: activeTasks[i],
                          isQueued: true,
                          onDismiss: () => ref
                              .read(downloadsControllerProvider.notifier)
                              .cancelActive(activeTasks[i].id),
                        ),
                    ],
                  ],
                  if (recent.isNotEmpty) ...[
                    _SectionBar(
                      title: 'Последняя активность',
                      trailing: _TextAction(
                        label: 'Скрыть все',
                        onPressed: () =>
                            ref.read(downloadHistoryProvider.notifier).clearAll(),
                      ),
                    ),
                    for (final task in recent)
                      DownloadRow(
                        task: task,
                        isFinished: true,
                        onDismiss: () => ref
                            .read(downloadHistoryProvider.notifier)
                            .remove(task.id),
                      ),
                  ],
                ],
              );

        if (!widget.standalone) {
          return ColoredBox(color: ItchColors.background, child: body);
        }

        return Scaffold(
          backgroundColor: ItchColors.background,
          appBar: AppBar(
            backgroundColor: ItchColors.background,
            foregroundColor: ItchColors.ivory,
            title: const Text('Скачивания'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          body: body,
        );
      },
    );
  }
}

class _SectionBar extends StatelessWidget {
  const _SectionBar({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 20, 0, 0),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ItchColors.ivory,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: ItchColors.secondaryText,
            fontSize: 14,
            decoration: TextDecoration.underline,
            decorationColor: ItchColors.zambezi,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_outlined,
              size: 64,
              color: ItchColors.zambezi.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 20),
            const Text(
              'Нет активных загрузок',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ItchColors.ivory,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Когда вы установите игру, она появится здесь.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ItchColors.secondaryText,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
