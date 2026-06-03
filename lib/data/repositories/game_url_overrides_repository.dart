import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game_web_url.dart';

/// Сохранённые пользователем или авто-исправленные URL страниц игр.
class GameUrlOverridesRepository {
  static const _storeKey = 'itchao.gameUrlOverrides';

  Future<Map<int, String>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return {};
      }
      final out = <int, String>{};
      for (final entry in decoded.entries) {
        final id = int.tryParse(entry.key.toString());
        final url = entry.value?.toString().trim();
        if (id != null && id > 0 && GameWebUrl.isValid(url)) {
          out[id] = url!;
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<String?> get(int gameId) async {
    return (await loadAll())[gameId];
  }

  Future<void> set(int gameId, String url) async {
    if (gameId <= 0 || !GameWebUrl.isValid(url)) {
      return;
    }
    final all = await loadAll();
    all[gameId] = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storeKey,
      jsonEncode(all.map((k, v) => MapEntry('$k', v))),
    );
  }

  Future<void> remove(int gameId) async {
    final all = await loadAll();
    if (!all.containsKey(gameId)) {
      return;
    }
    all.remove(gameId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storeKey,
      jsonEncode(all.map((k, v) => MapEntry('$k', v))),
    );
  }
}
