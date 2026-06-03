import '../../data/models.dart';

/// Завершённая загрузка/установка (как «Последняя активность» на itch desktop).
class DownloadHistoryEntry {
  const DownloadHistoryEntry({
    required this.id,
    required this.gameId,
    required this.gameTitle,
    required this.status,
    required this.completedAt,
    this.reason = DownloadReason.install,
    this.coverUrl,
    this.filename,
    this.errorMessage,
  });

  final String id;
  final int gameId;
  final String gameTitle;
  final DownloadStatus status;
  final DateTime completedAt;
  final DownloadReason reason;
  final String? coverUrl;
  final String? filename;
  final String? errorMessage;

  bool get isSuccess => status == DownloadStatus.completed;

  DownloadTask toDisplayTask() {
    return DownloadTask(
      id: id,
      gameId: gameId,
      gameTitle: gameTitle,
      progress: isSuccess ? 1 : 0,
      status: status,
      reason: reason,
      coverUrl: coverUrl,
      filename: filename,
      errorMessage: errorMessage,
      startedAt: completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'game_id': gameId,
    'game_title': gameTitle,
    'status': status.name,
    'completed_at': completedAt.toIso8601String(),
    'reason': reason.name,
    'cover_url': coverUrl,
    'filename': filename,
    'error_message': errorMessage,
  };

  factory DownloadHistoryEntry.fromJson(Map<String, dynamic> json) {
    return DownloadHistoryEntry(
      id: json['id'] as String? ?? '',
      gameId: (json['game_id'] as num?)?.toInt() ?? 0,
      gameTitle: json['game_title'] as String? ?? 'Game',
      status: _statusFromString(json['status'] as String?),
      completedAt: DateTime.tryParse(json['completed_at'] as String? ?? '') ??
          DateTime.now(),
      reason: _reasonFromString(json['reason'] as String?),
      coverUrl: json['cover_url'] as String?,
      filename: json['filename'] as String?,
      errorMessage: json['error_message'] as String?,
    );
  }

  static DownloadStatus _statusFromString(String? raw) {
    return switch (raw) {
      'failed' => DownloadStatus.failed,
      'running' => DownloadStatus.running,
      'queued' => DownloadStatus.queued,
      _ => DownloadStatus.completed,
    };
  }

  static DownloadReason _reasonFromString(String? raw) {
    return switch (raw) {
      'update' => DownloadReason.update,
      'reinstall' => DownloadReason.reinstall,
      _ => DownloadReason.install,
    };
  }

  factory DownloadHistoryEntry.fromTask(DownloadTask task, {required DownloadStatus status}) {
    return DownloadHistoryEntry(
      id: task.id,
      gameId: task.gameId,
      gameTitle: task.gameTitle,
      status: status,
      completedAt: DateTime.now(),
      reason: task.reason,
      coverUrl: task.coverUrl,
      filename: task.filename,
      errorMessage: task.errorMessage,
    );
  }
}
