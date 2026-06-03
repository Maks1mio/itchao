import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../features/install/game_install_service.dart';
import '../../features/downloads/downloads_controller.dart';

final butlerAdapterProvider = Provider<ButlerAdapter>((ref) => AndroidButlerAdapter(ref));

abstract interface class ButlerAdapter {
  Future<void> queueInstall({
    required int gameId,
    required String gameTitle,
    DownloadReason reason,
    String? coverUrl,
  });

  Future<void> launchGame({
    required int gameId,
    required String gameTitle,
    String? coverUrl,
  });
}

class AndroidButlerAdapter implements ButlerAdapter {
  AndroidButlerAdapter(this._ref);

  final Ref _ref;

  @override
  Future<void> queueInstall({
    required int gameId,
    required String gameTitle,
    DownloadReason reason = DownloadReason.install,
    String? coverUrl,
  }) async {
    await _ref.read(downloadsControllerProvider.notifier).enqueue(
      gameId,
      gameTitle,
      reason: reason,
      coverUrl: coverUrl,
    );
  }

  @override
  Future<void> launchGame({
    required int gameId,
    required String gameTitle,
    String? coverUrl,
  }) async {
    await _ref.read(gameInstallServiceProvider).launchInstalled(
      gameId: gameId,
      title: gameTitle,
      coverUrl: coverUrl,
    );
  }
}
