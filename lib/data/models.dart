enum AppRouteTab { library, downloads, settings }

enum DownloadStatus { queued, running, completed, failed }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.coverUrl,
  });

  final int id;
  final String username;
  final String displayName;
  final String? coverUrl;
}

class CredentialInfo {
  const CredentialInfo({
    required this.type,
    required this.scopes,
    this.expiresAt,
  });

  final String type;
  final List<String> scopes;
  final DateTime? expiresAt;
}

class AccountSettingsInfo {
  const AccountSettingsInfo({
    required this.profile,
    required this.credentials,
    required this.token,
  });

  final UserProfile profile;
  final CredentialInfo credentials;
  final String token;
}

class ItchCollection {
  const ItchCollection({
    required this.id,
    required this.title,
    required this.gamesCount,
    required this.updatedAt,
    required this.createdAt,
  });

  final int id;
  final String title;
  final int gamesCount;
  final DateTime updatedAt;
  final DateTime createdAt;
}

class CollectionWithPreview {
  const CollectionWithPreview({
    required this.collection,
    required this.previewGames,
    this.previewLoading = false,
  });

  final ItchCollection collection;
  final List<LibraryGame> previewGames;
  final bool previewLoading;
}

class LibraryGame {
  const LibraryGame({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.installed,
    this.shortText,
    this.url,
    this.classification = 'game',
    this.platforms = const [],
  });

  final int id;
  final String title;
  final String? coverUrl;
  final bool installed;
  final String? shortText;
  final String? url;
  final String classification;
  final List<String> platforms;
}

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.gameId,
    required this.gameTitle,
    required this.progress,
    required this.status,
  });

  final String id;
  final int gameId;
  final String gameTitle;
  final double progress;
  final DownloadStatus status;

  DownloadTask copyWith({
    String? id,
    int? gameId,
    String? gameTitle,
    double? progress,
    DownloadStatus? status,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      gameTitle: gameTitle ?? this.gameTitle,
      progress: progress ?? this.progress,
      status: status ?? this.status,
    );
  }
}
