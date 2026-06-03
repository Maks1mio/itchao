import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'itch_url.dart';
import 'models/browsing_history_entry.dart';

final browsingHistoryProvider =
    AsyncNotifierProvider<BrowsingHistoryController, List<BrowsingHistoryEntry>>(
      BrowsingHistoryController.new,
    );

class BrowsingHistoryController extends AsyncNotifier<List<BrowsingHistoryEntry>> {
  static const _storageKey = 'itchao.browsingHistory.v1';
  static const _maxEntries = 250;

  @override
  Future<List<BrowsingHistoryEntry>> build() async {
    return _loadFromPrefs();
  }

  Future<List<BrowsingHistoryEntry>> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(BrowsingHistoryEntry.fromJson)
          .where((e) => e.url.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist(List<BrowsingHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode([for (final e in entries) e.toJson()]);
    await prefs.setString(_storageKey, raw);
  }

  void record(String url, {String? label}) {
    Future.microtask(() => _applyRecord(url, label: label));
  }

  void _applyRecord(String url, {String? label}) {
    final trimmed = url.trim();
    if (trimmed.isEmpty || _shouldSkip(trimmed)) {
      return;
    }
    final resolvedLabel = label ?? _labelForUrl(trimmed);
    final now = DateTime.now();
    final current = state.valueOrNull ?? const <BrowsingHistoryEntry>[];
    final next = <BrowsingHistoryEntry>[];

    if (current.isNotEmpty && current.first.url == trimmed) {
      next.add(BrowsingHistoryEntry(url: trimmed, label: resolvedLabel, visitedAt: now));
      next.addAll(current.skip(1));
    } else {
      next.add(BrowsingHistoryEntry(url: trimmed, label: resolvedLabel, visitedAt: now));
      for (final entry in current) {
        if (entry.url != trimmed) {
          next.add(entry);
        }
      }
    }

    final limited = next.take(_maxEntries).toList();
    state = AsyncData(limited);
    _persist(limited);
  }

  Future<void> clear() async {
    state = const AsyncData([]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  bool _shouldSkip(String url) {
    if (url.startsWith('itch://new-tab') || url.startsWith('itch://history')) {
      return true;
    }
    final uri = Uri.tryParse(url);
    return uri?.scheme == 'itch' && uri?.host == 'oauth';
  }

  String _labelForUrl(String url) {
    final parsed = ItchUrl.parse(url);
    if (!parsed.isExternal) {
      return ItchUrl.labelFor(url);
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return url;
    }
    if (uri.host.endsWith('itch.io') && uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last;
      if (last.isNotEmpty && last != 'games') {
        return last.replaceAll('-', ' ');
      }
    }
    return uri.host;
  }
}
