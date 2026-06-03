import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tab_entry.dart';

class PersistedTabFrame {
  const PersistedTabFrame({required this.url, required this.label});

  final String url;
  final String label;

  Map<String, dynamic> toJson() => {'url': url, 'label': label};

  factory PersistedTabFrame.fromJson(Map<String, dynamic> json) {
    return PersistedTabFrame(
      url: json['url'] as String? ?? 'itch://new-tab',
      label: json['label'] as String? ?? 'Вкладка',
    );
  }
}

class PersistedTabsSnapshot {
  const PersistedTabsSnapshot({
    required this.state,
    required this.histories,
  });

  final TabsState state;
  final Map<String, List<PersistedTabFrame>> histories;
}

class TabsPersistence {
  TabsPersistence._();

  static const _storageKey = 'itchao.tabs.v1';
  static const _activeTabKey = 'itchao.tabs.active_id';

  static String _encodePayload(Map<String, dynamic> payload) => jsonEncode(payload);

  static Map<String, dynamic> _decodePayload(String raw) =>
      jsonDecode(raw) as Map<String, dynamic>;

  static Future<PersistedTabsSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final json = await compute(_decodePayload, raw);
      final tabsJson = json['openTabs'] as List<dynamic>? ?? const [];
      final openTabs = tabsJson
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => TabEntry(
              id: e['id'] as String? ?? '',
              url: e['url'] as String? ?? 'itch://new-tab',
              label: e['label'] as String? ?? 'Вкладка',
            ),
          )
          .where((t) => t.id.isNotEmpty)
          .toList();

      if (openTabs.isEmpty) {
        return null;
      }

      var activeTabId = json['activeTabId'] as String? ?? openTabs.first.id;
      final quickActive = prefs.getString(_activeTabKey);
      if (quickActive != null && openTabs.any((t) => t.id == quickActive)) {
        activeTabId = quickActive;
      } else if (!openTabs.any((t) => t.id == activeTabId)) {
        activeTabId = openTabs.first.id;
      }

      final historiesRaw = json['histories'] as Map<String, dynamic>? ?? const {};
      final histories = <String, List<PersistedTabFrame>>{};
      for (final entry in historiesRaw.entries) {
        final frames = (entry.value as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PersistedTabFrame.fromJson)
            .toList();
        if (frames.isNotEmpty) {
          histories[entry.key] = frames;
        }
      }

      for (final tab in openTabs) {
        histories.putIfAbsent(
          tab.id,
          () => [PersistedTabFrame(url: tab.url, label: tab.label)],
        );
      }

      return PersistedTabsSnapshot(
        state: TabsState(openTabs: openTabs, activeTabId: activeTabId),
        histories: histories,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save({
    required TabsState state,
    required Map<String, List<PersistedTabFrame>> histories,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'activeTabId': state.activeTabId,
      'openTabs': [
        for (final tab in state.openTabs)
          {'id': tab.id, 'url': tab.url, 'label': tab.label},
      ],
      'histories': {
        for (final entry in histories.entries)
          entry.key: [for (final frame in entry.value) frame.toJson()],
      },
    };
    final raw = await compute(_encodePayload, payload);
    await prefs.setString(_storageKey, raw);
    await prefs.setString(_activeTabKey, state.activeTabId);
  }

  /// Быстрое сохранение только активной вкладки (переключение в drawer).
  static Future<void> saveActiveTabId(String activeTabId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeTabKey, activeTabId);
  }
}
