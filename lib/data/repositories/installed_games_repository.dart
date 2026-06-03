import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../install_models.dart';

class InstalledGamesRepository {
  static const _storeKey = 'itchao.installedGames';

  Future<Map<int, InstalledGameRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final map = <int, InstalledGameRecord>{};
      for (final item in list) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final record = InstalledGameRecord.fromJson(item);
        if (record.gameId > 0) {
          map[record.gameId] = record;
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveAll(Map<int, InstalledGameRecord> games) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(games.values.map((g) => g.toJson()).toList());
    await prefs.setString(_storeKey, encoded);
  }

  Future<void> upsert(InstalledGameRecord record) async {
    final all = await loadAll();
    all[record.gameId] = record;
    await saveAll(all);
  }

  Future<void> remove(int gameId) async {
    final all = await loadAll();
    all.remove(gameId);
    await saveAll(all);
  }
}
