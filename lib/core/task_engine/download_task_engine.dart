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
    required void Function() onAwaitingInstall,
    required void Function() onCompleted,
  }) async {
    try {
      final result = await ref.read(gameInstallServiceProvider).downloadApkForGame(
        gameId: task.gameId,
        title: task.gameTitle,
        coverUrl: task.coverUrl,
        isCancelled: isCancelled,
        onProgress: onProgress,
      );
      if (isCancelled()) {
        return;
      }
      if (result.alreadyInstalled) {
        onCompleted();
        return;
      }
      onAwaitingInstall();
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
