import 'package:flutter/services.dart';

import '../../features/downloads/downloads_controller.dart';

/// Native PackageInstaller session callbacks (install success / failure).
class InstallEventChannel {
  static const _channel = MethodChannel('com.example.itchao/install');
  static bool _bound = false;

  static void bind(DownloadsController controller) {
    if (_bound) {
      return;
    }
    _bound = true;
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      if (args is! Map) {
        return;
      }
      final rawGameId = args['gameId'];
      final gameId = rawGameId is int ? rawGameId : -1;

      switch (call.method) {
        case 'installSuccess':
          await controller.onInstallSessionSuccess(
            gameId: gameId,
            packageName: args['package'] as String?,
          );
        case 'installFailed':
          await controller.onInstallSessionFailed(
            gameId: gameId,
            message: args['message'] as String?,
          );
      }
    });
  }
}
