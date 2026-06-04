import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/android/apk_platform_channel.dart';
import '../../data/install_models.dart';
import '../../data/models.dart';
import '../auth/auth_controller.dart';
import '../game/game_catalog.dart';
import '../downloads/download_cancelled.dart';
import '../downloads/download_progress_update.dart';
import 'installed_games_controller.dart';

final gameInstallServiceProvider = Provider<GameInstallService>((ref) {
  return GameInstallService(ref);
});

class GameInstallService {
  GameInstallService(this._ref);

  final Ref _ref;

  Future<File?> findPendingApk(int gameId) => _findApkFile(gameId);

  Future<void> deleteDownloadedApk(int gameId) async {
    final dir = await _gameInstallDir(gameId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<String> _requireDownloadApiKey() async {
    final full = await _ref.read(authControllerProvider.notifier).readFullApiKey();
    if (full != null && full.isNotEmpty) {
      return full;
    }
    throw Exception(
      'Для скачивания нужен полный API key с itch.io (Настройки → API keys). '
      'OAuth-токен не даёт доступ к файлам игр.',
    );
  }

  Future<void> installOrUpdate({
    required int gameId,
    required String title,
    String? coverUrl,
    DownloadReason reason = DownloadReason.install,
    DownloadCancelledCheck? isCancelled,
    void Function(DownloadProgressUpdate update)? onProgress,
  }) async {
    final result = await downloadApkForGame(
      gameId: gameId,
      title: title,
      coverUrl: coverUrl,
      isCancelled: isCancelled,
      onProgress: onProgress,
    );
    if (result.alreadyInstalled) {
      return;
    }
    final installed = await installDownloadedApk(
      gameId: gameId,
      title: title,
      coverUrl: coverUrl,
      packageName: result.packageName,
      uploadId: result.uploadId,
      channelName: result.channelName,
      userVersion: result.userVersion,
      isCancelled: isCancelled,
      onProgress: onProgress,
    );
    if (!installed) {
      throw Exception(
        'Подтвердите установку в диалоге Android или нажмите «Установить» снова.',
      );
    }
  }

  /// Downloads and validates the APK. Does not launch the system installer.
  Future<ApkDownloadResult> downloadApkForGame({
    required int gameId,
    required String title,
    String? coverUrl,
    DownloadCancelledCheck? isCancelled,
    void Function(DownloadProgressUpdate update)? onProgress,
  }) async {
    void ensureNotCancelled() {
      if (isCancelled?.call() == true) {
        throw const DownloadCancelledException();
      }
    }

    ensureNotCancelled();
    final token = await _requireDownloadApiKey();

    final client = _ref.read(itchApiClientProvider);
    final downloadKeyId = await client.findDownloadKeyId(token: token, gameId: gameId);
    ensureNotCancelled();

    final uploads = await client.fetchGameUploads(
      token: token,
      gameId: gameId,
      downloadKeyId: downloadKeyId,
    );
    ensureNotCancelled();
    if (uploads.isEmpty) {
      throw Exception(
        'Нет доступных файлов для скачивания. '
        'Добавьте полный API key в настройках (OAuth не даёт доступ к загрузкам).',
      );
    }

    final upload = client.pickAndroidUpload(uploads) ??
        (uploads.length == 1 ? uploads.first : null);
    if (upload == null) {
      final names = uploads.map((u) => u.filename).take(5).join(', ');
      throw Exception(
        uploads.isEmpty
            ? 'Нет файлов для скачивания.'
            : 'Нет Android APK для этой игры (доступно: $names). '
                'На телефоне можно установить только .apk.',
      );
    }

    String? knownPackage;

    void report(double progress, {double? bps, int? eta, String? file}) {
      onProgress?.call(
        DownloadProgressUpdate(
          progress: progress,
          bytesPerSecond: bps,
          etaSeconds: eta,
          filename: file,
          packageName: knownPackage,
        ),
      );
    }

    ensureNotCancelled();
    report(0.02, file: upload.filename);
    final downloadUri = await client.resolveUploadDownloadUrl(
      token: token,
      uploadId: upload.id,
      downloadKeyId: downloadKeyId,
    );
    ensureNotCancelled();

    final dir = await _gameInstallDir(gameId);
    final safeName = _safeFilename(upload.filename);
    final apkFile = File('${dir.path}/$safeName');

    await _downloadFile(
      downloadUri,
      apkFile,
      isCancelled: isCancelled,
      onProgress: (p, stats) => report(
        p,
        bps: stats.bytesPerSecond,
        eta: stats.etaSeconds,
        file: upload.filename,
      ),
    );

    await _validateApkFile(apkFile);

    final apk = _ref.read(apkPlatformChannelProvider);
    var packageName = await apk.getPackageNameFromApk(apkFile.path);
    packageName ??= 'game.$gameId';
    knownPackage = packageName;

    ensureNotCancelled();
    if (await apk.isAppInstalled(packageName)) {
      await _saveInstalledRecord(
        gameId: gameId,
        title: title,
        apkPath: apkFile.path,
        packageName: packageName,
        uploadId: upload.id,
        channelName: upload.channelName,
        userVersion: upload.userVersion,
        coverUrl: coverUrl,
      );
      report(1, file: upload.filename);
      return ApkDownloadResult(
        alreadyInstalled: true,
        packageName: packageName,
        uploadId: upload.id,
        channelName: upload.channelName,
        userVersion: upload.userVersion,
        filename: upload.filename,
      );
    }

    report(1, file: upload.filename);
    return ApkDownloadResult(
      packageName: packageName,
      uploadId: upload.id,
      channelName: upload.channelName,
      userVersion: upload.userVersion,
      filename: upload.filename,
    );
  }

  /// Opens the system installer for a downloaded APK.
  ///
  /// Returns `true` when the app is already on device and the local record is saved.
  /// When [waitForCompletion] is `false`, returns `false` after launching the system
  /// installer (user must confirm in Android).
  Future<bool> installDownloadedApk({
    required int gameId,
    required String title,
    String? coverUrl,
    String? packageName,
    int? uploadId,
    String? channelName,
    String? userVersion,
    DownloadCancelledCheck? isCancelled,
    void Function(DownloadProgressUpdate update)? onProgress,
    bool waitForCompletion = true,
  }) async {
    void ensureNotCancelled() {
      if (isCancelled?.call() == true) {
        throw const DownloadCancelledException();
      }
    }

    void report(double progress, {String? file, String? pkg}) {
      onProgress?.call(
        DownloadProgressUpdate(
          progress: progress,
          filename: file,
          packageName: pkg,
        ),
      );
    }

    ensureNotCancelled();
    final apkFile = await _findApkFile(gameId);
    if (apkFile == null) {
      throw Exception('Файл установки не найден. Скачайте игру снова.');
    }

    await _validateApkFile(apkFile);

    final apk = _ref.read(apkPlatformChannelProvider);
    final apkPackage = await apk.getPackageNameFromApk(apkFile.path);
    var resolvedPackage = apkPackage ?? packageName;
    if (_isPlaceholderPackage(resolvedPackage)) {
      resolvedPackage = apkPackage;
    }

    ensureNotCancelled();
    if (!await apk.canInstallPackages()) {
      await apk.requestInstallPermission();
      throw InstallPermissionRequiredException(
        'Разрешите itchao устанавливать приложения в настройках Android, '
        'затем повторите установку.',
      );
    }

    if (resolvedPackage != null &&
        resolvedPackage.isNotEmpty &&
        await apk.isAppInstalled(resolvedPackage)) {
      await _saveInstalledRecord(
        gameId: gameId,
        title: title,
        apkPath: apkFile.path,
        packageName: resolvedPackage,
        uploadId: uploadId ?? 0,
        channelName: channelName,
        userVersion: userVersion,
        coverUrl: coverUrl,
      );
      report(1, file: apkFile.path.split(Platform.pathSeparator).last, pkg: resolvedPackage);
      return true;
    }

    report(0.98, file: apkFile.path.split(Platform.pathSeparator).last, pkg: resolvedPackage);
    await apk.installApk(
      apkFile.path,
      gameId: gameId,
      packageName: resolvedPackage,
    );

    if (!waitForCompletion) {
      return false;
    }

    if (resolvedPackage == null || resolvedPackage.isEmpty) {
      return false;
    }

    final installed = await _waitForPackageInstalled(
      packageName: resolvedPackage,
      isCancelled: isCancelled,
    );
    if (!installed) {
      return false;
    }

    await _saveInstalledRecord(
      gameId: gameId,
      title: title,
      apkPath: apkFile.path,
      packageName: resolvedPackage,
      uploadId: uploadId ?? 0,
      channelName: channelName,
      userVersion: userVersion,
      coverUrl: coverUrl,
    );
    report(1, file: apkFile.path.split(Platform.pathSeparator).last, pkg: resolvedPackage);
    return true;
  }

  /// Returns true when the game is on device and local install record is saved.
  Future<bool> tryFinalizeInstalledTask({
    required int gameId,
    required String title,
    String? coverUrl,
    String? packageName,
  }) async {
    final apk = _ref.read(apkPlatformChannelProvider);
    final existing = _ref.read(installedGamesProvider)[gameId];

    var resolvedPackage = packageName ?? existing?.packageName;
    if (_isPlaceholderPackage(resolvedPackage)) {
      resolvedPackage = null;
    }

    if (resolvedPackage == null || resolvedPackage.isEmpty) {
      final apkFile = await _findApkFile(gameId);
      if (apkFile != null) {
        resolvedPackage = await apk.getPackageNameFromApk(apkFile.path);
      }
    }

    if (resolvedPackage != null &&
        resolvedPackage.isNotEmpty &&
        await apk.isAppInstalled(resolvedPackage)) {
      final apkFile = await _findApkFile(gameId);
      await _saveInstalledRecord(
        gameId: gameId,
        title: title,
        apkPath: apkFile?.path ?? existing?.apkPath ?? '',
        packageName: resolvedPackage,
        uploadId: existing?.uploadId ?? 0,
        channelName: existing?.channelName,
        userVersion: existing?.userVersion,
        coverUrl: coverUrl ?? existing?.coverUrl,
        keepInstalledAt: existing?.installedAt,
      );
      return true;
    }

    return false;
  }

  static bool _isPlaceholderPackage(String? packageName) {
    if (packageName == null || packageName.isEmpty) {
      return false;
    }
    return packageName.startsWith('game.');
  }

  Future<void> _saveInstalledRecord({
    required int gameId,
    required String title,
    required String apkPath,
    required String packageName,
    required int uploadId,
    String? channelName,
    String? userVersion,
    String? coverUrl,
    DateTime? keepInstalledAt,
  }) async {
    final lib = findLibraryGameById(_ref, gameId);
    final storeUrl = lib != null ? gameWebUrl(lib) : null;

    final record = InstalledGameRecord(
      gameId: gameId,
      title: title,
      apkPath: apkPath,
      packageName: packageName,
      uploadId: uploadId,
      coverUrl: coverUrl,
      channelName: channelName,
      userVersion: userVersion,
      installedAt: keepInstalledAt ?? DateTime.now(),
      storeUrl: storeUrl,
    );
    await _ref.read(installedGamesProvider.notifier).upsert(record);
  }

  Future<bool> _waitForPackageInstalled({
    required String packageName,
    DownloadCancelledCheck? isCancelled,
  }) async {
    final apk = _ref.read(apkPlatformChannelProvider);
    const timeout = Duration(minutes: 3);
    const interval = Duration(milliseconds: 800);
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      if (isCancelled?.call() == true) {
        throw const DownloadCancelledException();
      }
      if (await apk.isAppInstalled(packageName)) {
        return true;
      }
      await Future<void>.delayed(interval);
    }

    return apk.isAppInstalled(packageName);
  }

  Future<void> _validateApkFile(File file) async {
    if (!await file.exists()) {
      throw Exception('Файл загрузки не найден');
    }
    final size = await file.length();
    if (size < 1024) {
      await file.delete();
      throw Exception('Скачанный APK повреждён (файл слишком маленький)');
    }
    final raf = await file.open();
    try {
      final header = await raf.read(4);
      if (header.length < 2 || header[0] != 0x50 || header[1] != 0x4B) {
        await file.delete();
        throw Exception('Скачанный файл не является корректным APK');
      }
    } finally {
      await raf.close();
    }
  }

  Future<File?> _findApkFile(int gameId) async {
    final dir = await _gameInstallDir(gameId);
    if (!await dir.exists()) {
      return null;
    }
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.apk')) {
        return entity;
      }
    }
    return null;
  }

  Future<void> launchInstalled({
    required int gameId,
    required String title,
    String? coverUrl,
  }) async {
    final record = _ref.read(installedGamesProvider)[gameId];
    if (record == null) {
      throw Exception('Игра не установлена');
    }
    final apk = _ref.read(apkPlatformChannelProvider);
    if (!await apk.isAppInstalled(record.packageName)) {
      await _ref.read(installedGamesProvider.notifier).remove(gameId);
      throw Exception('Игра удалена с устройства. Нажмите «Установить», чтобы скачать снова.');
    }
    await apk.launchApp(record.packageName);
    await _ref.read(installedGamesProvider.notifier).upsert(
      record.copyWith(
        title: title,
        coverUrl: coverUrl ?? record.coverUrl,
        lastPlayedAt: DateTime.now(),
      ),
    );
  }

  Future<Directory> _gameInstallDir(int gameId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/itchao/games/$gameId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _downloadFile(
    Uri url,
    File destination, {
    DownloadCancelledCheck? isCancelled,
    required void Function(double progress, _DownloadStats stats) onProgress,
  }) async {
    final client = HttpClient();
    IOSink? sink;
    try {
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Ошибка загрузки HTTP ${response.statusCode}');
      }
      final total = response.contentLength;
      sink = destination.openWrite();
      var received = 0;
      var lastTick = DateTime.now();
      var lastReceived = 0;
      await for (final chunk in response) {
        if (isCancelled?.call() == true) {
          throw const DownloadCancelledException();
        }
        received += chunk.length;
        sink.add(chunk);
        final now = DateTime.now();
        final elapsed = now.difference(lastTick).inMilliseconds;
        double? bps;
        int? eta;
        if (elapsed >= 400) {
          bps = (received - lastReceived) * 1000 / elapsed;
          lastTick = now;
          lastReceived = received;
          if (total > 0 && bps > 0) {
            eta = ((total - received) / bps).round();
          }
        }
        if (total > 0) {
          onProgress(
            received / total,
            _DownloadStats(bytesPerSecond: bps, etaSeconds: eta),
          );
        }
      }
      await sink.close();
      if (total <= 0) {
        onProgress(1, const _DownloadStats());
      }
    } on DownloadCancelledException {
      await sink?.close();
      if (await destination.exists()) {
        await destination.delete();
      }
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  String _safeFilename(String name) {
    final trimmed = name.trim().isEmpty ? 'game.apk' : name.trim();
    return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}

class _DownloadStats {
  const _DownloadStats({this.bytesPerSecond, this.etaSeconds});

  final double? bytesPerSecond;
  final int? etaSeconds;
}

class ApkDownloadResult {
  const ApkDownloadResult({
    required this.packageName,
    required this.uploadId,
    this.channelName,
    this.userVersion,
    this.filename,
    this.alreadyInstalled = false,
  });

  final String packageName;
  final int uploadId;
  final String? channelName;
  final String? userVersion;
  final String? filename;
  final bool alreadyInstalled;
}
