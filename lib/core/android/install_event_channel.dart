import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/downloads/downloads_controller.dart';

/// Native PackageInstaller session callbacks (install success).
class InstallEventChannel {
  static const _channel = MethodChannel('com.example.itchao/install');
  static bool _bound = false;

  static void bind(WidgetRef ref) {
    if (_bound) {
      return;
    }
    _bound = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'installSuccess') {
        return;
      }
      final args = call.arguments;
      if (args is! Map) {
        return;
      }
      final gameId = args['gameId'];
      final package = args['package'] as String?;
      if (gameId is int && gameId > 0) {
        await ref.read(downloadsControllerProvider.notifier).onInstallSessionSuccess(
          gameId: gameId,
          packageName: package,
        );
      }
    });
  }
}
