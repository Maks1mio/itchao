import 'json_list_utils.dart';

class GameUpload {
  const GameUpload({
    required this.id,
    required this.filename,
    this.displayName,
    this.type,
    this.platforms = const [],
    this.traits = const {},
    this.channelName,
    this.userVersion,
    this.size,
  });

  final int id;
  final String filename;
  final String? displayName;
  final String? type;
  final List<String> platforms;
  final Map<String, dynamic> traits;
  final String? channelName;
  final String? userVersion;
  final int? size;

  factory GameUpload.fromMap(Map<String, dynamic> map) {
    final traitsRaw = map['traits'];
    final traits = traitsRaw is Map<String, dynamic>
        ? traitsRaw
        : traitsRaw is Map
            ? Map<String, dynamic>.from(traitsRaw)
            : const <String, dynamic>{};
    final build = map['build'] as Map<String, dynamic>?;
    return GameUpload(
      id: (map['id'] as num?)?.toInt() ?? 0,
      filename: map['filename'] as String? ?? '',
      displayName: map['display_name'] as String?,
      type: map['type'] as String?,
      platforms: stringListFromJson(map['platforms']),
      traits: traits,
      channelName: map['channel_name'] as String? ?? build?['channel_name'] as String?,
      userVersion: map['user_version'] as String? ?? build?['user_version'] as String?,
      size: (map['size'] as num?)?.toInt(),
    );
  }

  bool get isAndroidApk {
    final name = filename.toLowerCase();
    if (name.endsWith('.apk')) {
      return true;
    }
    final display = displayName?.toLowerCase() ?? '';
    if (display.contains('android') || display.contains('apk')) {
      return true;
    }
    if (type?.toLowerCase() == 'android') {
      return true;
    }
    if (jsonMapHasTruthyKey(traits, 'p_android')) {
      return true;
    }
    return platforms.any((p) => p.toLowerCase().contains('android'));
  }
}

class InstalledGameRecord {
  const InstalledGameRecord({
    required this.gameId,
    required this.title,
    required this.apkPath,
    required this.packageName,
    required this.uploadId,
    this.coverUrl,
    this.channelName,
    this.userVersion,
    this.installedAt,
    this.lastPlayedAt,
    this.storeUrl,
  });

  final int gameId;
  final String title;
  final String apkPath;
  final String packageName;
  final int uploadId;
  final String? coverUrl;
  final String? channelName;
  final String? userVersion;
  final DateTime? installedAt;
  final DateTime? lastPlayedAt;
  /// Канонический URL витрины (если API/библиотека не дали `url`).
  final String? storeUrl;

  InstalledGameRecord copyWith({
    String? title,
    String? apkPath,
    String? packageName,
    int? uploadId,
    String? coverUrl,
    String? channelName,
    String? userVersion,
    DateTime? installedAt,
    DateTime? lastPlayedAt,
    String? storeUrl,
  }) {
    return InstalledGameRecord(
      gameId: gameId,
      title: title ?? this.title,
      apkPath: apkPath ?? this.apkPath,
      packageName: packageName ?? this.packageName,
      uploadId: uploadId ?? this.uploadId,
      coverUrl: coverUrl ?? this.coverUrl,
      channelName: channelName ?? this.channelName,
      userVersion: userVersion ?? this.userVersion,
      installedAt: installedAt ?? this.installedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      storeUrl: storeUrl ?? this.storeUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'game_id': gameId,
    'title': title,
    'apk_path': apkPath,
    'package_name': packageName,
    'upload_id': uploadId,
    'cover_url': coverUrl,
    'channel_name': channelName,
    'user_version': userVersion,
    'installed_at': installedAt?.toIso8601String(),
    'last_played_at': lastPlayedAt?.toIso8601String(),
    if (storeUrl != null) 'store_url': storeUrl,
  };

  factory InstalledGameRecord.fromJson(Map<String, dynamic> json) {
    return InstalledGameRecord(
      gameId: (json['game_id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Game',
      apkPath: json['apk_path'] as String? ?? '',
      packageName: json['package_name'] as String? ?? '',
      uploadId: (json['upload_id'] as num?)?.toInt() ?? 0,
      coverUrl: json['cover_url'] as String?,
      channelName: json['channel_name'] as String?,
      userVersion: json['user_version'] as String?,
      installedAt: DateTime.tryParse(json['installed_at'] as String? ?? ''),
      lastPlayedAt: DateTime.tryParse(json['last_played_at'] as String? ?? ''),
      storeUrl: json['store_url'] as String?,
    );
  }
}
