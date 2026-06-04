import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/android/apk_platform_channel.dart';
import '../../core/android/install_event_channel.dart';
import '../../core/task_engine/download_task_engine.dart';
import '../../core/utils/download_format.dart';
import '../../data/models.dart';
import '../install/game_install_service.dart';
import '../install/installed_games_controller.dart';
import 'download_history_controller.dart';
import 'download_progress_update.dart';

final downloadsControllerProvider =
    NotifierProvider<DownloadsController, List<DownloadTask>>(
      DownloadsController.new,
    );

final activeDownloadProvider = Provider<DownloadTask?>((ref) {
  final snapshot = ref.watch(
    downloadsControllerProvider.select((tasks) {
      for (final task in tasks) {
        if (task.isActive) {
          return (
            task.id,
            task.gameId,
            task.gameTitle,
            task.status,
            (task.progress * 1000).round(),
            task.coverUrl,
          );
        }
      }
      return null;
    }),
  );
  if (snapshot == null) {
    return null;
  }
  final tasks = ref.read(downloadsControllerProvider);
  for (final task in tasks) {
    if (task.id == snapshot.$1) {
      return task;
    }
  }
  return null;
});

class DownloadsController extends Notifier<List<DownloadTask>> {
  final Set<String> _cancelledTaskIds = {};
  final Map<String, DateTime> _lastProgressEmit = {};
  final Set<String> _installingTaskIds = {};
  final Map<String, DateTime> _installStartedAt = {};
  Timer? _reconcileTimer;

  @override
  List<DownloadTask> build() {
    ref.onDispose(() {
      _reconcileTimer?.cancel();
    });
    InstallEventChannel.bind(this);
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

    final pendingApk = await ref.read(gameInstallServiceProvider).findPendingApk(gameId);
    if (pendingApk != null) {
      final task = DownloadTask(
        id: '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}',
        gameId: gameId,
        gameTitle: title,
        progress: 1,
        status: DownloadStatus.awaitingInstall,
        reason: reason,
        coverUrl: coverUrl,
        filename: pendingApk.path.split(Platform.pathSeparator).last,
        startedAt: DateTime.now(),
      );
      state = [...state, task];
      unawaited(_triggerAutoInstall(task.id));
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

  Future<void> cancelActive(String taskId) async {
    final task = _taskById(taskId);
    _cancelledTaskIds.add(taskId);
    _lastProgressEmit.remove(taskId);
    _installingTaskIds.remove(taskId);
    _installStartedAt.remove(taskId);
    _commitStateNow((current) => current.where((t) => t.id != taskId).toList());
    if (task != null && task.status != DownloadStatus.queued) {
      await ref.read(gameInstallServiceProvider).deleteDownloadedApk(task.gameId);
    }
  }

  Future<void> cancelAllActive() async {
    for (final task in state.where((t) => t.isActive)) {
      _cancelledTaskIds.add(task.id);
      if (task.status != DownloadStatus.queued) {
        await ref.read(gameInstallServiceProvider).deleteDownloadedApk(task.gameId);
      }
    }
    _installingTaskIds.clear();
    _commitStateNow((current) => current.where((t) => !t.isActive).toList());
  }

  bool _isCancelled(String taskId) => _cancelledTaskIds.contains(taskId);

  void _commitStateNow(List<DownloadTask> Function(List<DownloadTask> current) apply) {
    state = apply(List<DownloadTask>.from(state));
  }

  DownloadTask? _taskById(String taskId) {
    for (final task in state) {
      if (task.id == taskId) {
        return task;
      }
    }
    return null;
  }

  Future<void> beginInstall(String taskId) async {
    if (_installingTaskIds.contains(taskId)) {
      return;
    }
    final task = _taskById(taskId);
    if (task == null ||
        (task.status != DownloadStatus.awaitingInstall &&
            task.status != DownloadStatus.installing)) {
      return;
    }

    _installingTaskIds.add(taskId);
    markInstalling(taskId);
    try {
      final installed = await ref.read(gameInstallServiceProvider).installDownloadedApk(
        gameId: task.gameId,
        title: task.gameTitle,
        coverUrl: task.coverUrl,
        packageName: task.packageName,
        isCancelled: () => _isCancelled(taskId),
        onProgress: (update) => markProgress(taskId, update),
        waitForCompletion: false,
      );
      if (_isCancelled(taskId)) {
        return;
      }
      if (installed) {
        await markCompleted(taskId);
      }
      _syncReconcileTimer();
    } catch (error) {
      if (_isCancelled(taskId)) {
        return;
      }
      markAwaitingInstallWithError(taskId, error.toString());
      rethrow;
    } finally {
      _installingTaskIds.remove(taskId);
    }
  }

  Future<void> _runTask(DownloadTask task) async {
    markRunning(task.id, 0);
    try {
      await DownloadTaskEngine.run(
        ref: ref,
        task: task,
        isCancelled: () => _isCancelled(task.id),
        onProgress: (update) => markProgress(task.id, update),
        onFailed: (msg) => markFailed(task.id, msg),
        onAwaitingInstall: () => markAwaitingInstall(task.id),
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
    _commitStateNow((current) => [
      for (final task in current)
        if (task.id == taskId)
          task.copyWith(
            progress: progress,
            status: DownloadStatus.running,
            startedAt: task.startedAt ?? DateTime.now(),
          )
        else
          task,
    ]);
  }

  void markInstalling(String taskId) {
    if (_isCancelled(taskId)) {
      return;
    }
    _lastProgressEmit.remove(taskId);
    _installStartedAt[taskId] = DateTime.now();
    _commitStateNow((current) => [
      for (final task in current)
        if (task.id == taskId)
          task.copyWith(
            progress: 1,
            status: DownloadStatus.installing,
            bytesPerSecond: null,
            etaSeconds: null,
            speedSamples: const [],
            errorMessage: null,
          )
        else
          task,
    ]);
    _syncReconcileTimer();
  }

  void markAwaitingInstallWithError(String taskId, String error) {
    if (_isCancelled(taskId)) {
      return;
    }
    _lastProgressEmit.remove(taskId);
    _commitStateNow((current) => [
      for (final task in current)
        if (task.id == taskId)
          task.copyWith(
            progress: 1,
            status: DownloadStatus.awaitingInstall,
            bytesPerSecond: null,
            etaSeconds: null,
            speedSamples: const [],
            errorMessage: error,
          )
        else
          task,
    ]);
    _syncReconcileTimer();
  }

  void markAwaitingInstall(String taskId) {
    if (_isCancelled(taskId)) {
      return;
    }
    _lastProgressEmit.remove(taskId);
    _commitStateNow((current) => [
      for (final task in current)
        if (task.id == taskId)
          task.copyWith(
            progress: 1,
            status: DownloadStatus.awaitingInstall,
            bytesPerSecond: null,
            etaSeconds: null,
            speedSamples: const [],
            errorMessage: null,
          )
        else
          task,
    ]);
    _syncReconcileTimer();
    unawaited(_triggerAutoInstall(taskId));
  }

  Future<void> _triggerAutoInstall(String taskId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (_isCancelled(taskId)) {
      return;
    }
    final task = _taskById(taskId);
    if (task == null || task.status != DownloadStatus.awaitingInstall) {
      return;
    }
    try {
      await beginInstall(taskId);
    } catch (error) {
      if (_isCancelled(taskId)) {
        return;
      }
      markAwaitingInstallWithError(taskId, error.toString());
    }
  }

  void markProgress(String taskId, DownloadProgressUpdate update) {
    if (_isCancelled(taskId)) {
      return;
    }
    final progress = update.progress.clamp(0.0, 1.0);
    final now = DateTime.now();
    final lastEmit = _lastProgressEmit[taskId];
    final significant = progress <= 0 || progress >= 0.99;
    if (!significant &&
        lastEmit != null &&
        now.difference(lastEmit) < const Duration(milliseconds: 250)) {
      return;
    }
    _lastProgressEmit[taskId] = now;

    _commitStateNow((current) => [
      for (final task in current)
        if (task.id == taskId)
          task.status == DownloadStatus.installing
              ? task.copyWith(
                  packageName: update.packageName ?? task.packageName,
                  filename: update.filename ?? task.filename,
                )
              : _applyProgress(task, update)
        else
          task,
    ]);
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
    return task.copyWith(
      progress: progress,
      status: DownloadStatus.running,
      bytesPerSecond: bps ?? task.bytesPerSecond,
      etaSeconds: update.etaSeconds ?? task.etaSeconds,
      filename: update.filename ?? task.filename,
      packageName: update.packageName ?? task.packageName,
      speedSamples: samples,
    );
  }

  Future<void> _finishTask(String taskId, DownloadStatus status, {String? error}) async {
    if (_isCancelled(taskId)) {
      return;
    }
    final task = _taskById(taskId);
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
    _commitStateNow((current) => current.where((t) => t.id != taskId).toList());
    _lastProgressEmit.remove(taskId);
    _installStartedAt.remove(taskId);
  }

  Future<void> onInstallSessionSuccess({
    required int gameId,
    String? packageName,
  }) async {
    final tasks = gameId > 0
        ? state.where((t) => t.isActive && t.gameId == gameId)
        : state.where((t) => t.isActive && t.status == DownloadStatus.installing);
    for (final task in List<DownloadTask>.from(tasks)) {
      await _completeInstallTask(task, packageName: packageName ?? task.packageName);
    }
    _syncReconcileTimer();
  }

  Future<void> _completeInstallTask(
    DownloadTask task, {
    String? packageName,
  }) async {
    _installStartedAt.remove(task.id);
    _installingTaskIds.remove(task.id);
    await markCompleted(task.id);
    try {
      await ref.read(gameInstallServiceProvider).tryFinalizeInstalledTask(
        gameId: task.gameId,
        title: task.gameTitle,
        coverUrl: task.coverUrl,
        packageName: packageName,
      );
    } catch (_) {
      // UI already updated; registry sync happens on next reconcile.
    }
  }

  Future<void> onInstallSessionFailed({
    required int gameId,
    String? message,
  }) async {
    final text = formatInstallFailureMessage(message);
    final tasks = gameId > 0
        ? state.where(
            (t) =>
                t.isActive &&
                t.gameId == gameId &&
                t.status == DownloadStatus.installing,
          )
        : state.where((t) => t.isActive && t.status == DownloadStatus.installing);
    for (final task in List<DownloadTask>.from(tasks)) {
      markAwaitingInstallWithError(task.id, text);
    }
    _syncReconcileTimer();
  }

  void _syncReconcileTimer() {
    final needsPoll = state.any((t) => t.status == DownloadStatus.installing);
    if (needsPoll) {
      _reconcileTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        unawaited(reconcileActiveTasks());
      });
      return;
    }
    _reconcileTimer?.cancel();
    _reconcileTimer = null;
  }

  Future<void> markCompleted(String taskId) => _finishTask(taskId, DownloadStatus.completed);

  Future<void> markFailed(String taskId, String message) =>
      _finishTask(taskId, DownloadStatus.failed, error: message);

  /// Closes stuck tasks when the game is already on the device (e.g. after system install dialog).
  Future<void> reconcileActiveTasks() async {
    await ref.read(installedGamesProvider.notifier).syncWithDevice();
    final installed = ref.read(installedGamesProvider);
    final install = ref.read(gameInstallServiceProvider);
    final apk = ref.read(apkPlatformChannelProvider);
    final now = DateTime.now();

    for (final task in List<DownloadTask>.from(state.where((t) => t.isActive))) {
      if (_isCancelled(task.id)) {
        continue;
      }

      final record = installed[task.gameId];
      if (record != null &&
          record.packageName.isNotEmpty &&
          await apk.isAppInstalled(record.packageName)) {
        await markCompleted(task.id);
        continue;
      }

      final pkg = _resolvedPackageHint(task.packageName, record?.packageName);
      if (pkg != null && await apk.isAppInstalled(pkg)) {
        await install.tryFinalizeInstalledTask(
          gameId: task.gameId,
          title: task.gameTitle,
          coverUrl: task.coverUrl,
          packageName: pkg,
        );
        await markCompleted(task.id);
        continue;
      }

      final finalized = await install.tryFinalizeInstalledTask(
        gameId: task.gameId,
        title: task.gameTitle,
        coverUrl: task.coverUrl,
        packageName: task.packageName ?? record?.packageName,
      );
      if (finalized) {
        await markCompleted(task.id);
        continue;
      }

      if (task.status == DownloadStatus.installing) {
        final started = _installStartedAt[task.id] ?? task.startedAt;
        if (started != null &&
            now.difference(started) > const Duration(seconds: 90)) {
          markAwaitingInstallWithError(
            task.id,
            'Установка не завершилась. Нажмите «Установить» ещё раз.',
          );
        }
      }
    }
    _syncReconcileTimer();
  }

  static String? _resolvedPackageHint(String? primary, String? fallback) {
    for (final candidate in [primary, fallback]) {
      if (candidate == null || candidate.isEmpty) {
        continue;
      }
      if (candidate.startsWith('game.')) {
        continue;
      }
      return candidate;
    }
    return null;
  }
}
