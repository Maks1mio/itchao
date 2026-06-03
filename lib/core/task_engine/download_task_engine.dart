import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../features/downloads/download_cancelled.dart';
import '../../features/downloads/download_progress_update.dart';
import '../../features/install/game_install_service.dart';

class DownloadTaskEngine {
  static Future<void> run({
    required Ref ref,
    required DownloadTask task,
    required DownloadCancelledCheck isCancelled,
    required void Function(DownloadProgressUpdate update) onProgress,
    required void Function(String message) onFailed,
    required void Function() onCompleted,
  }) async {
    try {
      await ref.read(gameInstallServiceProvider).installOrUpdate(
        gameId: task.gameId,
        title: task.gameTitle,
        coverUrl: task.coverUrl,
        reason: task.reason,
        isCancelled: isCancelled,
        onProgress: (update) => onProgress(update),
      );
      if (isCancelled()) {
        return;
      }
      onCompleted();
    } on DownloadCancelledException {
      // Task removed from UI; do not record history or trigger install.
    } catch (error) {
      if (isCancelled()) {
        return;
      }
      onFailed(error.toString());
    }
  }
}
