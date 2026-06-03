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

/// Строка загрузки в стиле itch desktop (`DownloadsPage/Row.tsx`).
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

  static const _coverFactor = 1.2;
  static const _coverWidth = 105.0 * _coverFactor;
  static const _coverHeight = 80.0 * _coverFactor;

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
    final isActive = task.isActive && !isFinished;
    final hasOperation = isActive && !isQueued;
    final progress = _safeProgress(
      task.status == DownloadStatus.completed ? 1.0 : task.progress,
    );
    final dimmed = isQueued;

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: hasOperation ? ItchColors.lightMineShaft : ItchColors.item,
          border: Border.all(
            color: hasOperation ? ItchColors.borderFocused : Colors.transparent,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (isFirst && isActive)
              Positioned.fill(
                child: DownloadSpeedChart(samples: task.speedSamples),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _Cover(url: task.coverUrl, dimmed: task.status == DownloadStatus.failed),
                      Expanded(child: _StatsBlock(task: task, isFirst: isFirst, isActive: isActive)),
                      _Controls(
                        task: task,
                        isActive: isActive,
                        isFinished: isFinished,
                        onDismiss: onDismiss,
                        onLaunch: () => _launchGame(context, ref),
                      ),
                    ],
                  ),
                ),
                if (isFirst && isActive)
                  _BottomProgress(value: progress),
              ],
            ),
          ],
        ),
      ),
    );
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
    return Container(
      width: DownloadRow._coverWidth,
      height: DownloadRow._coverHeight,
      margin: const EdgeInsets.only(left: 0, right: 16),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 0),
          ),
        ],
      ),
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
                  child: Icon(Icons.videogame_asset_outlined, color: ItchColors.zambezi, size: 32),
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
    required this.isActive,
  });

  final DownloadTask task;
  final bool isFirst;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.gameTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ItchColors.ivory,
              fontWeight: FontWeight.w600,
              fontSize: 17,
              height: 1.2,
            ),
          ),
          if (task.filename != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.sports_esports_outlined, size: 14, color: ItchColors.zambezi),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    task.filename!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ItchColors.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (task.status == DownloadStatus.failed)
            Text(
              task.errorMessage ?? 'Ошибка загрузки',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ItchColors.error, fontSize: 13, height: 1.35),
            )
          else if (isActive)
            _ActiveStatusLine(task: task, isFirst: isFirst)
          else
            _FinishedStatusLine(task: task),
        ],
      ),
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
    final speed = isFirst
        ? formatDownloadSpeedLine(
            bytesPerSecond: task.bytesPerSecond,
            etaSeconds: task.etaSeconds,
          )
        : '';

    return Row(
      children: [
        Flexible(
          child: Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ItchColors.secondaryText, fontSize: 13),
          ),
        ),
        if (speed.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            speed,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ItchColors.secondaryText, fontSize: 13),
          ),
        ],
      ],
    );
  }

  static String _statusText(DownloadTask task) {
    if (task.status == DownloadStatus.queued) {
      return 'В очереди';
    }
    if (task.progress >= 0.93) {
      return 'Подтвердите установку в Android';
    }
    final when = task.startedAt != null ? formatTimeAgoRu(task.startedAt!) : '';
    final reason = downloadReasonLabelRu(task.reason);
    if (when.isEmpty) {
      return 'Начато — $reason';
    }
    return 'Начато $when — $reason';
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
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: task.status == DownloadStatus.failed ? ItchColors.error : ItchColors.secondaryText,
        fontSize: 13,
      ),
    );
  }
}

class _BottomProgress extends StatelessWidget {
  const _BottomProgress({this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: LinearProgressIndicator(
        value: value,
        minHeight: 4,
        backgroundColor: ItchColors.zambezi.withValues(alpha: 0.47),
        color: ItchColors.ivory.withValues(alpha: 0.4),
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({
    required this.task,
    required this.isActive,
    required this.isFinished,
    this.onDismiss,
    this.onLaunch,
  });

  final DownloadTask task;
  final bool isActive;
  final bool isFinished;
  final VoidCallback? onDismiss;
  final VoidCallback? onLaunch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFinished && task.status == DownloadStatus.completed) ...[
            TextButton(
              onPressed: onLaunch,
              style: TextButton.styleFrom(
                foregroundColor: ItchColors.ivory,
                backgroundColor: ItchColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Играть', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(Icons.close, size: 22),
            color: ItchColors.zambezi,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: isActive ? 'Отменить' : 'Скрыть',
            onPressed: onDismiss ??
                (isActive
                    ? () => ref.read(downloadsControllerProvider.notifier).cancelActive(task.id)
                    : null),
          ),
        ],
      ),
    );
  }
}
