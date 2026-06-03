/// Игра с реальным запуском (как `cave.stats.lastTouchedAt` в itch desktop).
class LastPlayedGame {
  const LastPlayedGame({
    required this.gameId,
    required this.title,
    required this.lastPlayedAt,
    this.coverUrl,
    this.tabUrl,
  });

  final int gameId;
  final String title;
  final DateTime lastPlayedAt;
  final String? coverUrl;
  final String? tabUrl;

  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'title': title,
    'lastPlayedAt': lastPlayedAt.toIso8601String(),
    if (coverUrl != null) 'coverUrl': coverUrl,
    if (tabUrl != null) 'tabUrl': tabUrl,
  };

  factory LastPlayedGame.fromJson(Map<String, dynamic> json) {
    final gameId = json['gameId'] as int? ?? 0;
    return LastPlayedGame(
      gameId: gameId,
      title: json['title'] as String? ?? 'Игра',
      lastPlayedAt:
          DateTime.tryParse(json['lastPlayedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      coverUrl: json['coverUrl'] as String?,
      tabUrl: json['tabUrl'] as String? ?? 'itch://games/$gameId',
    );
  }
}
