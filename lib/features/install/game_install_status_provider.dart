import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/downloads/downloads_controller.dart';
import 'installed_games_controller.dart';

enum GamePrimaryAction { install, play, update, downloading }

class GameInstallUiState {
  const GameInstallUiState({
    required this.action,
    this.downloadProgress,
    this.installedVersion,
    this.latestVersion,
  });

  final GamePrimaryAction action;
  final double? downloadProgress;
  final String? installedVersion;
  final String? latestVersion;

  bool get updateAvailable =>
      installedVersion != null &&
      latestVersion != null &&
      installedVersion != latestVersion;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is GameInstallUiState &&
            other.action == action &&
            other.downloadProgress == downloadProgress &&
            other.installedVersion == installedVersion &&
            other.latestVersion == latestVersion;
  }

  @override
  int get hashCode => Object.hash(
        action,
        downloadProgress,
        installedVersion,
        latestVersion,
      );
}

typedef GameInstallUiSnapshot = (
  GamePrimaryAction,
  double?,
  String?,
  String?,
);

GameInstallUiState gameInstallUiStateFromSnapshot(GameInstallUiSnapshot snapshot) {
  return GameInstallUiState(
    action: snapshot.$1,
    downloadProgress: snapshot.$2,
    installedVersion: snapshot.$3,
    latestVersion: snapshot.$4,
  );
}

GameInstallUiSnapshot gameInstallUiSnapshot(GameInstallUiState state) {
  return (
    state.action,
    state.downloadProgress,
    state.installedVersion,
    state.latestVersion,
  );
}

final gameInstallUiStateProvider = Provider.family<GameInstallUiState, int>((ref, gameId) {
  if (gameId <= 0) {
    return const GameInstallUiState(action: GamePrimaryAction.install);
  }

  final installed = ref.watch(installedGamesProvider)[gameId];
  final activeDownload = ref.watch(
    downloadsControllerProvider.select((tasks) {
      for (final task in tasks) {
        if (task.gameId == gameId && task.isActive) {
          return (task.status, (task.progress * 100).round());
        }
      }
      return null;
    }),
  );
  if (activeDownload != null) {
    if (activeDownload.$1 == DownloadStatus.installing) {
      return const GameInstallUiState(
        action: GamePrimaryAction.downloading,
        downloadProgress: 1,
      );
    }
    if (activeDownload.$1 == DownloadStatus.awaitingInstall) {
      return const GameInstallUiState(action: GamePrimaryAction.install);
    }
    if (activeDownload.$1 == DownloadStatus.running ||
        activeDownload.$1 == DownloadStatus.queued) {
      return GameInstallUiState(
        action: GamePrimaryAction.downloading,
        downloadProgress: activeDownload.$2 / 100,
      );
    }
  }
  if (installed != null) {
    final latest = ref.watch(_gameLatestVersionProvider(gameId)).valueOrNull;
    final hasUpdate = latest != null &&
        installed.userVersion != null &&
        latest != installed.userVersion;
    return GameInstallUiState(
      action: hasUpdate ? GamePrimaryAction.update : GamePrimaryAction.play,
      installedVersion: installed.userVersion,
      latestVersion: latest,
    );
  }
  return const GameInstallUiState(action: GamePrimaryAction.install);
});

final _gameLatestVersionProvider = FutureProvider.family<String?, int>((ref, gameId) async {
  final installed = ref.watch(installedGamesProvider)[gameId];
  final channel = installed?.channelName;
  if (channel == null || channel.isEmpty) {
    return null;
  }
  return ref.read(itchApiClientProvider).fetchWharfLatestVersion(
    gameId: gameId,
    channelName: channel,
  );
});
