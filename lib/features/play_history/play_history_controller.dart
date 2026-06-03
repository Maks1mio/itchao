import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models.dart';
import '../tabs/game_page_url.dart';
import 'models/last_played_game.dart';

/// Учёт реальных запусков игр (аналог butler `lastTouchedAt`, не история просмотров).
final playHistoryProvider =
    AsyncNotifierProvider<PlayHistoryController, LastPlayedGame?>(PlayHistoryController.new);

class PlayHistoryController extends AsyncNotifier<LastPlayedGame?> {
  static const _storageKey = 'itchao.play_history.v1';

  @override
  Future<LastPlayedGame?> build() async {
    return _loadMostRecent();
  }

  /// Вызвать при запуске игры (butler launch / открытие установленной).
  Future<void> recordPlay({
    required int gameId,
    required String title,
    String? coverUrl,
    String? tabUrl,
  }) async {
    if (gameId <= 0) {
      return;
    }
    final game = LibraryGame(
      id: gameId,
      title: title,
      coverUrl: coverUrl,
      installed: true,
    );
    final entry = LastPlayedGame(
      gameId: gameId,
      title: title,
      coverUrl: coverUrl,
      tabUrl: tabUrl ?? itchGamePageUrl(game),
      lastPlayedAt: DateTime.now(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(entry.toJson()));
    state = AsyncData(entry);
  }

  Future<LastPlayedGame?> _loadMostRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final entry = LastPlayedGame.fromJson(json);
      if (entry.gameId <= 0) {
        return null;
      }
      return entry;
    } catch (_) {
      return null;
    }
  }
}
