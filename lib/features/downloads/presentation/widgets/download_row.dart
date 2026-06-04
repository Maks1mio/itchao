import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/itch_colors.dart';
import '../../../../core/utils/download_format.dart';
import '../../../../core/utils/itch_cached_network_image.dart';
import '../../../../core/utils/time_ago.dart';
import '../../../../data/models.dart';
import '../../../../domain/use_cases/launch_game_use_case.dart';
import '../../downloads_controller.dart';
import 'download_speed_chart.dart';

/// Карточка загрузки — компактный мобильный layout.
class DownloadRow extends ConsumerWidget {
  const DownloadRow({
    required this.task,
    this.isFirst = false,
    this.isQueued = false,
    this.isFinished = false,
    this.onDismiss,
    super.key,
  });

  final DownloadTask task;
  final bool isFirst;
  final bool isQueued;
  final bool isFinished;
  final VoidCallback? onDismiss;

  static const _coverWidth = 72.0;
  static const _coverHeight = 54.0;

  static double? _safeProgress(double value) {
    if (!value.isFinite || value < 0) {
      return null;
    }
    if (value >= 1) {
      return 1;
    }
    if (value <= 0) {
      return null;
    }
    return value;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInstalling = task.status == DownloadStatus.installing;
    final isAwaitingInstall = task.status == DownloadStatus.awaitingInstall;
    final isDownloading =
        !isFinished && (task.status == DownloadStatus.running || task.status == DownloadStatus.queued);
    final isInstallPhase = isAwaitingInstall || isInstalling;
    final hasOperation = isDownloading && !isQueued;
    final progress = _safeProgress(
      isInstallPhase || task.status == DownloadStatus.completed ? 1.0 : task.progress,
    );
    final dimmed = isQueued;

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: hasOperation || isInstallPhase ? ItchColors.lightMineShaft : ItchColors.item,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasOperation || isInstallPhase
                ? ItchColors.borderFocused
                : Colors.transparent,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (isFirst && isDownloading)
              Positioned.fill(
                child: DownloadSpeedChart(samples: task.speedSamples),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Cover(
                        url: task.coverUrl,
                        dimmed: task.status == DownloadStatus.failed,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatsBlock(
                          task: task,
                          isFirst: isFirst,
                          isDownloading: isDownloading,
                          isInstallPhase: isInstallPhase,
                        ),
                      ),
                      _DismissButton(
                        task: task,
                        isDownloading: isDownloading,
                        isInstallPhase: isInstallPhase,
                        onDismiss: onDismiss,
                      ),
                    ],
                  ),
                ),
                if (isDownloading && task.status == DownloadStatus.running)
                  _DownloadProgressSection(progress: progress),
                if (isInstallPhase)
                  _InstallActionSection(
                    task: task,
                    isInstalling: isInstalling,
                    onInstall: () => unawaited(_installApk(context, ref)),
                  ),
                if (isFinished && task.status == DownloadStatus.completed)
                  _PlayActionSection(
                    onLaunch: () => unawaited(_launchGame(context, ref)),
                  ),
                if (isFirst && isDownloading)
                  _BottomProgress(value: progress),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _installApk(BuildContext context, WidgetRef ref) async {
    if (task.status == DownloadStatus.installing) {
      return;
    }
    try {
      await ref.read(downloadsControllerProvider.notifier).beginInstall(task.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _launchGame(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(launchGameUseCaseProvider).call(
        gameId: task.gameId,
        title: task.gameTitle,
        coverUrl: task.coverUrl,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }
}

class _Cover extends StatelessWidget {
  const _Cover({this.url, this.dimmed = false});

  final String? url;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: DownloadRow._coverWidth,
        height: DownloadRow._coverHeight,
        child: ColorFiltered(
          colorFilter: dimmed
              ? const ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0, 0, 0, 1, 0,
                ])
              : ColorFilter.mode(Colors.transparent, BlendMode.dst),
          child: url != null && url!.isNotEmpty
              ? ItchCachedNetworkImage(
                  url: url!,
                  width: DownloadRow._coverWidth,
                  height: DownloadRow._coverHeight,
                  fit: BoxFit.cover,
                )
              : const ColoredBox(
                  color: ItchColors.darkMineShaft,
                  child: Center(
                    child: Icon(
                      Icons.videogame_asset_outlined,
                      color: ItchColors.zambezi,
                      size: 24,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _StatsBlock extends StatelessWidget {
  const _StatsBlock({
    required this.task,
    required this.isFirst,
    required this.isDownloading,
    required this.isInstallPhase,
  });

  final DownloadTask task;
  final bool isFirst;
  final bool isDownloading;
  final bool isInstallPhase;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.gameTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: ItchColors.ivory,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            height: 1.25,
          ),
        ),
        if (task.filename != null) ...[
          const SizedBox(height: 4),
          Text(
            task.filename!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ItchColors.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 6),
        if (task.status == DownloadStatus.failed)
          Text(
            task.errorMessage ?? 'Ошибка загрузки',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ItchColors.error, fontSize: 13, height: 1.35),
          )
        else if (isInstallPhase)
          _InstallStatusLine(task: task)
        else if (isDownloading)
          _ActiveStatusLine(task: task, isFirst: isFirst)
        else
          _FinishedStatusLine(task: task),
      ],
    );
  }
}

class _ActiveStatusLine extends StatelessWidget {
  const _ActiveStatusLine({required this.task, required this.isFirst});

  final DownloadTask task;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final status = _statusText(task);
    final speed = isFirst && task.status == DownloadStatus.running
        ? formatDownloadSpeedLine(
            bytesPerSecond: task.bytesPerSecond,
            etaSeconds: task.etaSeconds,
          )
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          status,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: ItchColors.secondaryText, fontSize: 13),
        ),
        if (speed.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            speed,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ItchColors.zambezi, fontSize: 12),
          ),
        ],
      ],
    );
  }

  static String _statusText(DownloadTask task) {
    if (task.status == DownloadStatus.queued) {
      return 'В очереди';
    }
    if (task.status == DownloadStatus.running) {
      final percent = (task.progress * 100).clamp(0, 100).round();
      return 'Загрузка $percent%';
    }
    final when = task.startedAt != null ? formatTimeAgoRu(task.startedAt!) : '';
    final reason = downloadReasonLabelRu(task.reason);
    if (when.isEmpty) {
      return 'Начато — $reason';
    }
    return 'Начато $when — $reason';
  }
}

class _InstallStatusLine extends StatelessWidget {
  const _InstallStatusLine({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final message = switch (task.status) {
      DownloadStatus.installing => 'Установка на устройство…',
      _ => task.errorMessage ?? 'Скачано — готово к установке',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: task.errorMessage != null ? ItchColors.error : ItchColors.secondaryText,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _FinishedStatusLine extends StatelessWidget {
  const _FinishedStatusLine({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final when = task.startedAt != null ? formatTimeAgoRu(task.startedAt!) : '';
    final outcome = task.status == DownloadStatus.completed ? 'установлено' : 'ошибка';

    return Text(
      when.isEmpty ? outcome : '$when — $outcome',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: task.status == DownloadStatus.failed ? ItchColors.error : ItchColors.secondaryText,
        fontSize: 13,
      ),
    );
  }
}

class _DownloadProgressSection extends StatelessWidget {
  const _DownloadProgressSection({this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: ItchColors.zambezi.withValues(alpha: 0.35),
          color: ItchColors.accent,
        ),
      ),
    );
  }
}

class _InstallActionSection extends StatelessWidget {
  const _InstallActionSection({
    required this.task,
    required this.isInstalling,
    required this.onInstall,
  });

  final DownloadTask task;
  final bool isInstalling;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: FilledButton(
          onPressed: isInstalling ? null : onInstall,
          style: FilledButton.styleFrom(
            backgroundColor: ItchColors.accent,
            foregroundColor: ItchColors.ivory,
            disabledBackgroundColor: ItchColors.accent.withValues(alpha: 0.55),
            disabledForegroundColor: ItchColors.ivory.withValues(alpha: 0.85),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: isInstalling
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ItchColors.ivory,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text('Установка…'),
                  ],
                )
              : const Text('Установить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _PlayActionSection extends StatelessWidget {
  const _PlayActionSection({required this.onLaunch});

  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: FilledButton(
          onPressed: onLaunch,
          style: FilledButton.styleFrom(
            backgroundColor: ItchColors.accent,
            foregroundColor: ItchColors.ivory,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Играть', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _DismissButton extends ConsumerWidget {
  const _DismissButton({
    required this.task,
    required this.isDownloading,
    required this.isInstallPhase,
    this.onDismiss,
  });

  final DownloadTask task;
  final bool isDownloading;
  final bool isInstallPhase;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.close, size: 20),
      color: ItchColors.zambezi,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      tooltip: isDownloading
          ? 'Отменить'
          : isInstallPhase
              ? 'Отказаться от установки'
              : 'Скрыть',
      onPressed: onDismiss ??
          (isDownloading || isInstallPhase
              ? () => unawaited(
                    ref.read(downloadsControllerProvider.notifier).cancelActive(task.id),
                  )
              : null),
    );
  }
}

class _BottomProgress extends StatelessWidget {
  const _BottomProgress({this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: LinearProgressIndicator(
        value: value,
        minHeight: 3,
        backgroundColor: ItchColors.zambezi.withValues(alpha: 0.25),
        color: ItchColors.ivory.withValues(alpha: 0.35),
      ),
    );
  }
}
