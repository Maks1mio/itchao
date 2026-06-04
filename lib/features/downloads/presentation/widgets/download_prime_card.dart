import 'package:flutter/material.dart';

import '../../../../core/theme/itch_colors.dart';
import '../../../../core/utils/download_format.dart';
import '../../../../core/utils/itch_cached_network_image.dart';
import '../../../../data/models.dart';

/// Карточка активной загрузки в drawer (как PrimeDownload на itch desktop).
class DownloadPrimeCard extends StatelessWidget {
  const DownloadPrimeCard({
    required this.task,
    required this.onTap,
    super.key,
  });

  final DownloadTask task;
  final VoidCallback onTap;

  static double? _safeProgress(double value) {
    if (!value.isFinite || value <= 0) {
      return null;
    }
    return value.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final rawProgress = task.status == DownloadStatus.completed ||
            task.status == DownloadStatus.awaitingInstall ||
            task.status == DownloadStatus.installing
        ? 1.0
        : task.progress;
    final progress = _safeProgress(rawProgress);
    final speedLine = task.status == DownloadStatus.running
        ? formatDownloadSpeedLine(
            bytesPerSecond: task.bytesPerSecond,
            etaSeconds: task.etaSeconds,
          )
        : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Material(
        color: ItchColors.item,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 215 / 170,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (task.coverUrl != null && task.coverUrl!.isNotEmpty)
                  ItchCachedNetworkImage(
                    url: task.coverUrl!,
                    fit: BoxFit.cover,
                  )
                else
                  const ColoredBox(color: ItchColors.darkMineShaft),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.82),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    children: [
                      Text(
                        task.gameTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: ItchColors.ivory,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.2,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 2.5,
                          color: ItchColors.ivory,
                          backgroundColor: ItchColors.zambezi.withValues(alpha: 0.5),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        switch (task.status) {
                          DownloadStatus.queued => 'В очереди…',
                          DownloadStatus.awaitingInstall => 'Готово к установке',
                          DownloadStatus.installing => 'Установка…',
                          DownloadStatus.running when task.progress > 0 =>
                            '${(task.progress * 100).round()}%',
                          _ => speedLine.isNotEmpty ? speedLine : 'Загрузка…',
                        },
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: ItchColors.secondaryText,
                          fontSize: 11,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
