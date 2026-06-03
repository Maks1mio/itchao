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
}

final gameInstallUiStateProvider = Provider.family<GameInstallUiState, int>((ref, gameId) {
  final installed = ref.watch(installedGamesProvider)[gameId];
  final tasks = ref.watch(downloadsControllerProvider);
  DownloadTask? active;
  for (final t in tasks) {
    if (t.gameId == gameId &&
        (t.status == DownloadStatus.queued || t.status == DownloadStatus.running)) {
      active = t;
      break;
    }
  }
  if (active != null) {
    return GameInstallUiState(
      action: GamePrimaryAction.downloading,
      downloadProgress: active.progress,
    );
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
