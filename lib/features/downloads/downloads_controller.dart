import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/butler/butler_adapter.dart';
import '../../core/task_engine/download_task_engine.dart';
import '../../data/models.dart';

final downloadsControllerProvider =
    NotifierProvider<DownloadsController, List<DownloadTask>>(
      DownloadsController.new,
    );

class DownloadsController extends Notifier<List<DownloadTask>> {
  late final ButlerAdapter _butlerAdapter;

  @override
  List<DownloadTask> build() {
    _butlerAdapter = AndroidButlerAdapter();
    return const [];
  }

  Future<void> enqueue(int gameId, String title) async {
    final task = DownloadTask(
      id: '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}',
      gameId: gameId,
      gameTitle: title,
      progress: 0,
      status: DownloadStatus.queued,
    );
    state = [...state, task];
    await _butlerAdapter.queueInstall(gameId: gameId, gameTitle: title);
    await DownloadTaskEngine.enqueue(task);
  }

  void markProgress(String taskId, double progress) {
    state = [
      for (final task in state)
        if (task.id == taskId)
          task.copyWith(
            progress: progress.clamp(0, 1),
            status: progress >= 1 ? DownloadStatus.completed : DownloadStatus.running,
          )
        else
          task,
    ];
  }
}
