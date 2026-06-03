import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/downloads/download_history_entry.dart';

class DownloadHistoryRepository {
  static const _storeKey = 'itchao.downloadHistory';
  static const _maxEntries = 128;

  Future<List<DownloadHistoryEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in list)
          if (item is Map<String, dynamic>)
            DownloadHistoryEntry.fromJson(item),
      ].where((e) => e.id.isNotEmpty && e.gameId > 0).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<DownloadHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = entries.take(_maxEntries).toList();
    await prefs.setString(
      _storeKey,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> upsert(DownloadHistoryEntry entry) async {
    final all = List<DownloadHistoryEntry>.from(await loadAll());
    all.removeWhere((e) => e.id == entry.id || e.gameId == entry.gameId);
    all.insert(0, entry);
    await saveAll(all);
  }

  Future<void> remove(String id) async {
    final all = List<DownloadHistoryEntry>.from(await loadAll());
    all.removeWhere((e) => e.id == id);
    await saveAll(all);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storeKey);
  }
}
