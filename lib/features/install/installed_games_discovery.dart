import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/android/apk_platform_channel.dart';
import '../../data/install_models.dart';
import '../../data/models.dart';
import '../library/library_controller.dart';
import 'installed_games_controller.dart';

final installedGamesDiscoveryProvider = Provider<InstalledGamesDiscovery>((ref) {
  return InstalledGamesDiscovery(ref);
});

/// Links Android packages installed by itchao to library game IDs.
class InstalledGamesDiscovery {
  InstalledGamesDiscovery(this._ref);

  final Ref _ref;

  Future<void> syncFromDevice() async {
    final apk = _ref.read(apkPlatformChannelProvider);
    var onDevice = await apk.listInstalledByItchao();

    final library = await _waitForLibrary();
    final installed = _ref.read(installedGamesProvider);
    final gamesRoot = await _gamesRootDir();

    // Fallback: re-check saved records if MIUI omits installer in bulk scan.
    if (onDevice.isEmpty && installed.isNotEmpty) {
      onDevice = [
        for (final r in installed.values)
          if (r.packageName.isNotEmpty)
            ItchaoInstalledPackage(packageName: r.packageName, label: r.title),
      ];
    }

    if (onDevice.isEmpty) {
      return;
    }

    for (final app in onDevice) {
      if (!await apk.isAppInstalled(app.packageName)) {
        continue;
      }

      final gameId = await _resolveGameId(
        packageName: app.packageName,
        label: app.label,
        library: library,
        gamesRoot: gamesRoot,
        installed: installed,
        onDeviceCount: onDevice.length,
      );
      if (gameId == null) {
        continue;
      }

      InstalledGameRecord? existing = installed[gameId];
      for (final r in installed.values) {
        if (r.packageName == app.packageName) {
          existing = r;
          break;
        }
      }

      LibraryGame? libGame;
      for (final g in library) {
        if (g.id == gameId) {
          libGame = g;
          break;
        }
      }
      final apkPath = await _apkPathForGame(gamesRoot, gameId) ?? '';

      await _ref.read(installedGamesProvider.notifier).upsert(
        InstalledGameRecord(
          gameId: gameId,
          title: libGame?.title ?? existing?.title ?? app.label,
          apkPath: apkPath.isNotEmpty ? apkPath : (existing?.apkPath ?? ''),
          packageName: app.packageName,
          uploadId: existing?.uploadId ?? 0,
          coverUrl: libGame?.coverUrl ?? existing?.coverUrl,
          channelName: existing?.channelName,
          userVersion: existing?.userVersion,
          installedAt: existing?.installedAt ?? DateTime.now(),
        ),
      );
    }
  }

  Future<List<LibraryGame>> _waitForLibrary() async {
    final current = _ref.read(libraryControllerProvider);
    if (current.hasValue && current.value!.isNotEmpty) {
      return current.value!;
    }
    try {
      return await _ref.read(libraryControllerProvider.future);
    } catch (_) {
      return _ref.read(libraryControllerProvider).value ?? [];
    }
  }

  Future<Directory?> _gamesRootDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/itchao/games');
    if (!await dir.exists()) {
      return null;
    }
    return dir;
  }

  Future<int?> _resolveGameId({
    required String packageName,
    required String label,
    required List<LibraryGame> library,
    required Directory? gamesRoot,
    required Map<int, InstalledGameRecord> installed,
    required int onDeviceCount,
  }) async {
    for (final entry in installed.entries) {
      if (entry.value.packageName == packageName) {
        return entry.key;
      }
    }

    final apk = _ref.read(apkPlatformChannelProvider);
    if (gamesRoot != null) {
      await for (final entity in gamesRoot.list()) {
        if (entity is! Directory) {
          continue;
        }
        final gameId = int.tryParse(entity.uri.pathSegments.last);
        if (gameId == null) {
          continue;
        }
        final apkFile = await _firstApkInDir(entity);
        if (apkFile != null) {
          final fromApk = await apk.getPackageNameFromApk(apkFile.path);
          if (fromApk == packageName) {
            return gameId;
          }
        }
      }

      final folderId = _singleFolderGameId(gamesRoot, onDeviceCount);
      if (folderId != null) {
        return folderId;
      }
    }

    return _matchLibraryByTitle(label, library);
  }

  int? _singleFolderGameId(Directory gamesRoot, int onDeviceCount) {
    if (onDeviceCount != 1) {
      return null;
    }
    final ids = <int>[];
    for (final entity in gamesRoot.listSync()) {
      if (entity is Directory) {
        final id = int.tryParse(entity.uri.pathSegments.last);
        if (id != null) {
          ids.add(id);
        }
      }
    }
    if (ids.length == 1) {
      return ids.first;
    }
    return null;
  }

  int? _matchLibraryByTitle(String label, List<LibraryGame> library) {
    final norm = _normalizeTitle(label);
    if (norm.isEmpty) {
      return null;
    }
    for (final game in library) {
      final gameNorm = _normalizeTitle(game.title);
      if (gameNorm == norm ||
          gameNorm.startsWith(norm) ||
          norm.startsWith(gameNorm)) {
        return game.id;
      }
    }
    return null;
  }

  String _normalizeTitle(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<File?> _firstApkInDir(Directory dir) async {
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.apk')) {
        return entity;
      }
    }
    return null;
  }

  Future<String?> _apkPathForGame(Directory? gamesRoot, int gameId) async {
    if (gamesRoot == null) {
      return null;
    }
    final dir = Directory('${gamesRoot.path}/$gameId');
    if (!await dir.exists()) {
      return null;
    }
    final file = await _firstApkInDir(dir);
    return file?.path;
  }
}
