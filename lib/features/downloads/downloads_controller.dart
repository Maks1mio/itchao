import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/task_engine/download_task_engine.dart';
import '../../data/models.dart';
import '../install/game_install_service.dart';
import 'download_history_controller.dart';
import 'download_progress_update.dart';

final downloadsControllerProvider =
    NotifierProvider<DownloadsController, List<DownloadTask>>(
      DownloadsController.new,
    );

final activeDownloadProvider = Provider<DownloadTask?>((ref) {
  for (final task in ref.watch(downloadsControllerProvider)) {
    if (task.isActive) {
      return task;
    }
  }
  return null;
});

class DownloadsController extends Notifier<List<DownloadTask>> {
  final Set<String> _cancelledTaskIds = {};

  @override
  List<DownloadTask> build() {
    return const [];
  }

  Future<void> enqueue(
    int gameId,
    String title, {
    DownloadReason reason = DownloadReason.install,
    String? coverUrl,
  }) async {
    final existing = state.where(
      (t) => t.gameId == gameId && t.isActive,
    );
    if (existing.isNotEmpty) {
      return;
    }

    final task = DownloadTask(
      id: '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}',
      gameId: gameId,
      gameTitle: title,
      progress: 0,
      status: DownloadStatus.queued,
      reason: reason,
      coverUrl: coverUrl,
      startedAt: DateTime.now(),
    );
    state = [...state, task];
    _runTask(task);
  }

  void cancelActive(String taskId) {
    _cancelledTaskIds.add(taskId);
    state = state.where((t) => t.id != taskId).toList();
  }

  void cancelAllActive() {
    for (final task in state.where((t) => t.isActive)) {
      _cancelledTaskIds.add(task.id);
    }
    state = state.where((t) => !t.isActive).toList();
  }

  bool _isCancelled(String taskId) => _cancelledTaskIds.contains(taskId);

  Future<void> _runTask(DownloadTask task) async {
    markRunning(task.id, 0);
    try {
      await DownloadTaskEngine.run(
        ref: ref,
        task: task,
        isCancelled: () => _isCancelled(task.id),
        onProgress: (update) => markProgress(task.id, update),
        onFailed: (msg) => markFailed(task.id, msg),
        onCompleted: () => markCompleted(task.id),
      );
    } finally {
      _cancelledTaskIds.remove(task.id);
    }
  }

  void markRunning(String taskId, double progress) {
    if (_isCancelled(taskId)) {
      return;
    }
    state = [
      for (final task in state)
        if (task.id == taskId)
          task.copyWith(
            progress: progress,
            status: DownloadStatus.running,
            startedAt: task.startedAt ?? DateTime.now(),
          )
        else
          task,
    ];
  }

  void markProgress(String taskId, DownloadProgressUpdate update) {
    if (_isCancelled(taskId)) {
      return;
    }
    state = [
      for (final task in state)
        if (task.id == taskId) _applyProgress(task, update) else task,
    ];
  }

  DownloadTask _applyProgress(DownloadTask task, DownloadProgressUpdate update) {
    var samples = List<double>.from(task.speedSamples);
    final bps = update.bytesPerSecond;
    if (bps != null && bps > 0) {
      final normalized = (bps / (8 * 1024 * 1024)).clamp(0.0, 1.0);
      samples = [...samples, normalized];
      if (samples.length > 24) {
        samples = samples.sublist(samples.length - 24);
      }
    }
    final progress = update.progress.clamp(0.0, 1.0);
    final installing = progress >= 0.92;
    return task.copyWith(
      progress: progress,
      status: DownloadStatus.running,
      bytesPerSecond: installing ? null : (bps ?? task.bytesPerSecond),
      etaSeconds: installing ? null : (update.etaSeconds ?? task.etaSeconds),
      filename: update.filename ?? task.filename,
      packageName: update.packageName ?? task.packageName,
      speedSamples: installing ? const [] : samples,
    );
  }

  Future<void> _finishTask(String taskId, DownloadStatus status, {String? error}) async {
    if (_isCancelled(taskId)) {
      return;
    }
    final task = state.cast<DownloadTask?>().firstWhere(
      (t) => t?.id == taskId,
      orElse: () => null,
    );
    if (task == null) {
      return;
    }
    final finalTask = task.copyWith(
      status: status,
      errorMessage: error,
      progress: status == DownloadStatus.completed ? 1 : task.progress,
    );
    try {
      await ref.read(downloadHistoryProvider.notifier).recordFromTask(finalTask, status);
    } catch (_) {
      // History must not block removing an active task from the UI.
    }
    state = state.where((t) => t.id != taskId).toList();
  }

  /// Called from Android when PackageInstaller reports success.
  Future<void> onInstallSessionSuccess({
    required int gameId,
    String? packageName,
  }) async {
    final install = ref.read(gameInstallServiceProvider);
    for (final task in List<DownloadTask>.from(
      state.where((t) => t.isActive && t.gameId == gameId),
    )) {
      await install.tryFinalizeInstalledTask(
        gameId: gameId,
        title: task.gameTitle,
        coverUrl: task.coverUrl,
        packageName: packageName ?? task.packageName,
      );
      await markCompleted(task.id);
    }
  }

  Future<void> markCompleted(String taskId) => _finishTask(taskId, DownloadStatus.completed);

  Future<void> markFailed(String taskId, String message) =>
      _finishTask(taskId, DownloadStatus.failed, error: message);

  /// Closes stuck tasks when the game is already on the device (e.g. after system install dialog).
  Future<void> reconcileActiveTasks() async {
    final install = ref.read(gameInstallServiceProvider);
    for (final task in List<DownloadTask>.from(state.where((t) => t.isActive))) {
      if (_isCancelled(task.id)) {
        continue;
      }
      final installed = await install.tryFinalizeInstalledTask(
        gameId: task.gameId,
        title: task.gameTitle,
        coverUrl: task.coverUrl,
        packageName: task.packageName,
      );
      if (installed) {
        await markCompleted(task.id);
      }
    }
  }
}
