import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apkPlatformChannelProvider = Provider<ApkPlatformChannel>((ref) {
  return ApkPlatformChannel();
});

/// App on device that lists itchao as the installing package.
class ItchaoInstalledPackage {
  const ItchaoInstalledPackage({required this.packageName, required this.label});

  final String packageName;
  final String label;
}

class ApkPlatformChannel {
  static const _channel = MethodChannel('com.example.itchao/apk');

  Future<String?> getPackageNameFromApk(String apkPath) async {
    final name = await _channel.invokeMethod<String>('getApkPackageName', {
      'path': apkPath,
    });
    return name;
  }

  Future<bool> canInstallPackages() async {
    final allowed = await _channel.invokeMethod<bool>('canInstallPackages');
    return allowed ?? false;
  }

  Future<void> requestInstallPermission() async {
    await _channel.invokeMethod<void>('requestInstallPermission');
  }

  Future<void> installApk(
    String apkPath, {
    required int gameId,
    String? packageName,
  }) async {
    try {
      await _channel.invokeMethod<void>('installApk', {
        'path': apkPath,
        'gameId': gameId,
        'package': packageName,
      });
    } on PlatformException catch (e) {
      if (e.code == 'install_permission_required') {
        throw InstallPermissionRequiredException(
          e.message ?? 'Разрешите установку приложений для itchao',
        );
      }
      rethrow;
    }
  }

  Future<void> launchApp(String packageName) async {
    await _channel.invokeMethod<void>('launchApp', {'package': packageName});
  }

  Future<List<ItchaoInstalledPackage>> listInstalledByItchao() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('listInstalledByItchao');
    if (raw == null) {
      return const [];
    }
    return [
      for (final item in raw)
        if (item is Map)
          ItchaoInstalledPackage(
            packageName: '${item['package'] ?? ''}',
            label: '${item['label'] ?? item['package'] ?? ''}',
          ),
    ].where((p) => p.packageName.isNotEmpty).toList();
  }

  Future<bool> isAppInstalled(String packageName) async {
    if (packageName.isEmpty) {
      return false;
    }
    final installed = await _channel.invokeMethod<bool>('isAppInstalled', {
      'package': packageName,
    });
    return installed ?? false;
  }
}

class InstallPermissionRequiredException implements Exception {
  InstallPermissionRequiredException(this.message);

  final String message;

  @override
  String toString() => message;
}
