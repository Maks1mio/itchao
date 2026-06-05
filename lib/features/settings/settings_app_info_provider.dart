import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const _githubLatestReleaseUrl =
    'https://api.github.com/repos/Maks1mio/itchao/releases/latest';

final settingsAppInfoProvider = FutureProvider<SettingsAppInfo>((ref) async {
  final package = await PackageInfo.fromPlatform();
  final device = await _loadDeviceInfo();
  return SettingsAppInfo(
    appName: package.appName,
    version: package.version,
    buildNumber: package.buildNumber,
    device: device,
  );
});

final settingsAppUpdateProvider =
    AsyncNotifierProvider<SettingsAppUpdateNotifier, AppUpdateStatus>(
      SettingsAppUpdateNotifier.new,
    );

class SettingsAppInfo {
  const SettingsAppInfo({
    required this.appName,
    required this.version,
    required this.buildNumber,
    required this.device,
  });

  final String appName;
  final String version;
  final String buildNumber;
  final DeviceSummary device;

  String get versionLabel => '$version+$buildNumber';
}

class DeviceSummary {
  const DeviceSummary({
    required this.platform,
    required this.description,
  });

  final String platform;
  final String description;
}

enum AppUpdateCheckState { idle, checking, upToDate, outdated, unavailable, failed }

class AppUpdateStatus {
  const AppUpdateStatus({
    required this.state,
    this.latestVersion,
    this.releaseUrl,
    this.message,
  });

  final AppUpdateCheckState state;
  final String? latestVersion;
  final String? releaseUrl;
  final String? message;

  static const initial = AppUpdateStatus(state: AppUpdateCheckState.idle);
}

class SettingsAppUpdateNotifier extends AsyncNotifier<AppUpdateStatus> {
  @override
  Future<AppUpdateStatus> build() async {
    return AppUpdateStatus.initial;
  }

  Future<void> checkNow() async {
    state = const AsyncData(
      AppUpdateStatus(state: AppUpdateCheckState.checking),
    );
    try {
      final package = await PackageInfo.fromPlatform();
      final response = await http.get(
        Uri.parse(_githubLatestReleaseUrl),
        headers: const {'Accept': 'application/vnd.github+json'},
      );
      if (response.statusCode != 200) {
        state = AsyncData(
          AppUpdateStatus(
            state: AppUpdateCheckState.failed,
            message: 'Не удалось проверить (HTTP ${response.statusCode})',
          ),
        );
        return;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String? ?? '').replaceFirst(RegExp('^v'), '');
      final htmlUrl = json['html_url'] as String?;
      if (tag.isEmpty) {
        state = const AsyncData(
          AppUpdateStatus(
            state: AppUpdateCheckState.unavailable,
            message: 'Релизы на GitHub не найдены',
          ),
        );
        return;
      }
      final outdated = _isVersionNewer(tag, package.version);
      state = AsyncData(
        AppUpdateStatus(
          state: outdated ? AppUpdateCheckState.outdated : AppUpdateCheckState.upToDate,
          latestVersion: tag,
          releaseUrl: htmlUrl,
          message: outdated
              ? 'Доступна версия $tag'
              : 'Установлена актуальная версия',
        ),
      );
    } catch (error) {
      state = AsyncData(
        AppUpdateStatus(
          state: AppUpdateCheckState.failed,
          message: 'Ошибка проверки: $error',
        ),
      );
    }
  }
}

Future<DeviceSummary> _loadDeviceInfo() async {
  if (kIsWeb) {
    return const DeviceSummary(
      platform: 'Web',
      description: 'Web',
    );
  }
  if (Platform.isAndroid) {
    final info = await DeviceInfoPlugin().androidInfo;
    final model = info.model.trim();
    final manufacturer = info.manufacturer.trim();
    final device = info.device.trim();
    final name = [
      if (manufacturer.isNotEmpty && manufacturer.toLowerCase() != model.toLowerCase())
        manufacturer,
      if (model.isNotEmpty) model else device,
    ].join(' ');
    return DeviceSummary(
      platform: 'Android ${info.version.release}',
      description: name.isNotEmpty ? name : 'Android',
    );
  }
  if (Platform.isIOS) {
    final info = await DeviceInfoPlugin().iosInfo;
    return DeviceSummary(
      platform: 'iOS ${info.systemVersion}',
      description: info.utsname.machine,
    );
  }
  return DeviceSummary(
    platform: Platform.operatingSystem,
    description: Platform.operatingSystemVersion,
  );
}

bool _isVersionNewer(String remote, String local) {
  final remoteParts = _parseVersionParts(remote);
  final localParts = _parseVersionParts(local);
  for (var i = 0; i < 3; i++) {
    final r = i < remoteParts.length ? remoteParts[i] : 0;
    final l = i < localParts.length ? localParts[i] : 0;
    if (r > l) {
      return true;
    }
    if (r < l) {
      return false;
    }
  }
  return false;
}

List<int> _parseVersionParts(String raw) {
  return raw
      .split(RegExp(r'[^0-9]+'))
      .where((part) => part.isNotEmpty)
      .map(int.parse)
      .toList();
}
