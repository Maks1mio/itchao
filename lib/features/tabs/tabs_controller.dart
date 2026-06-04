import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browsing_history_controller.dart';
import 'data/tabs_persistence.dart';
import 'itch_url.dart';
import 'models/tab_entry.dart';

final tabsControllerProvider = AsyncNotifierProvider<TabsController, TabsState>(TabsController.new);

class _TabNavFrame {
  const _TabNavFrame({required this.url, required this.label});

  final String url;
  final String label;

  PersistedTabFrame toPersisted() => PersistedTabFrame(url: url, label: label);

  factory _TabNavFrame.fromPersisted(PersistedTabFrame frame) {
    return _TabNavFrame(url: frame.url, label: frame.label);
  }
}

class TabsController extends AsyncNotifier<TabsState> {
  static const _initialTabId = 'initial-tab';
  final Map<String, List<_TabNavFrame>> _tabHistories = {};
  var _persistenceReady = false;
  var _alive = true;
  Timer? _persistDebounce;
  TabsState? _lastFullPersistSnapshot;

  @override
  Future<TabsState> build() async {
    ref.onDispose(() => _alive = false);
    final stored = await TabsPersistence.load();
    if (stored != null) {
      _tabHistories.clear();
      for (final entry in stored.histories.entries) {
        _tabHistories[entry.key] = [
          for (final frame in entry.value) _TabNavFrame.fromPersisted(frame),
        ];
      }
      _persistenceReady = true;
      _lastFullPersistSnapshot = stored.state;
      return stored.state;
    }
    _bootstrapDefault();
    _persistenceReady = true;
    _lastFullPersistSnapshot = state.value!;
    return state.value!;
  }

  void _bootstrapDefault() {
    _tabHistories[_initialTabId] = [
      _TabNavFrame(url: 'itch://new-tab', label: ItchUrl.labelFor('itch://new-tab')),
    ];
    state = AsyncData(
      TabsState(
        openTabs: [
          TabEntry(
            id: _initialTabId,
            url: 'itch://new-tab',
            label: ItchUrl.labelFor('itch://new-tab'),
          ),
        ],
        activeTabId: _initialTabId,
      ),
    );
  }

  void _commit(TabsState next) {
    if (!_alive) {
      return;
    }
    state = AsyncData(next);
    if (!_persistenceReady) {
      return;
    }
    if (_onlyActiveTabChanged(next)) {
      _persistDebounce?.cancel();
      unawaited(TabsPersistence.saveActiveTabId(next.activeTabId));
      _lastFullPersistSnapshot = _lastFullPersistSnapshot?.copyWith(
        activeTabId: next.activeTabId,
      );
      return;
    }
    _lastFullPersistSnapshot = next;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 500), () {
      _persistFull(next);
    });
  }

  bool _onlyActiveTabChanged(TabsState next) {
    final prev = _lastFullPersistSnapshot;
    if (prev == null) {
      return false;
    }
    if (prev.openTabs.length != next.openTabs.length) {
      return false;
    }
    for (var i = 0; i < prev.openTabs.length; i++) {
      final a = prev.openTabs[i];
      final b = next.openTabs[i];
      if (a.id != b.id || a.url != b.url || a.label != b.label) {
        return false;
      }
    }
    return prev.activeTabId != next.activeTabId;
  }

  Future<void> _persistFull(TabsState next) async {
    final histories = {
      for (final entry in _tabHistories.entries)
        entry.key: [for (final frame in entry.value) frame.toPersisted()],
    };
    await TabsPersistence.save(state: next, histories: histories);
    _lastFullPersistSnapshot = next;
  }

  void _recordBrowsing(String url, {String? label}) {
    Future.microtask(() {
      ref.read(browsingHistoryProvider.notifier).record(url, label: label);
    });
  }

  void focusTab(String tabId) {
    final current = state.valueOrNull;
    if (current == null || !current.openTabs.any((t) => t.id == tabId)) {
      return;
    }
    _commit(current.copyWith(activeTabId: tabId));
  }

  bool canPopActiveTab() {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }
    final history = _tabHistories[current.activeTabId];
    return history != null && history.length > 1;
  }

  bool popActiveTab() {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }
    final activeId = current.activeTabId;
    final history = _tabHistories[activeId];
    if (history == null || history.length <= 1) {
      return false;
    }
    history.removeLast();
    final previous = history.last;
    final tabs = [
      for (final tab in current.openTabs)
        if (tab.id == activeId)
          tab.copyWith(url: previous.url, label: previous.label)
        else
          tab,
    ];
    _commit(current.copyWith(openTabs: tabs));
    return true;
  }

  void openTab(String url, {bool background = false, String? label}) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final tabId = 'tab-${DateTime.now().millisecondsSinceEpoch}';
    final resolvedLabel = label ?? ItchUrl.labelFor(url);
    final entry = TabEntry(
      id: tabId,
      url: url,
      label: resolvedLabel,
    );
    _tabHistories[tabId] = [_TabNavFrame(url: url, label: resolvedLabel)];
    if (!background) {
      _recordBrowsing(url, label: resolvedLabel);
    }
    final tabs = [...current.openTabs];
    final activeIndex = tabs.indexWhere((t) => t.id == current.activeTabId);
    if (activeIndex >= 0) {
      tabs.insert(activeIndex + 1, entry);
    } else {
      tabs.add(entry);
    }
    _commit(
      TabsState(
        openTabs: tabs,
        activeTabId: background ? current.activeTabId : tabId,
      ),
    );
  }

  /// Обновляет URL активной вкладки без новой записи в стеке «назад» (WebView).
  void replaceActiveTabLocation(String url, {String? label}) {
    final current = state.valueOrNull;
    final active = current?.activeTab;
    if (current == null || active == null) {
      return;
    }
    final resolvedLabel = label ?? ItchUrl.labelFor(url);
    final history = _tabHistories.putIfAbsent(
      active.id,
      () => [_TabNavFrame(url: active.url, label: active.label)],
    );
    if (history.isNotEmpty) {
      history[history.length - 1] = _TabNavFrame(url: url, label: resolvedLabel);
    } else {
      history.add(_TabNavFrame(url: url, label: resolvedLabel));
    }
    final tabs = [
      for (final tab in current.openTabs)
        if (tab.id == active.id)
          tab.copyWith(url: url, label: resolvedLabel)
        else
          tab,
    ];
    _commit(current.copyWith(openTabs: tabs));
  }

  void navigateActiveTab(String url, {String? label}) {
    final current = state.valueOrNull;
    final active = current?.activeTab;
    if (current == null || active == null) {
      return;
    }
    final resolvedLabel = label ?? ItchUrl.labelFor(url);
    final history = _tabHistories.putIfAbsent(
      active.id,
      () => [_TabNavFrame(url: active.url, label: active.label)],
    );
    if (history.last.url != url) {
      history.add(_TabNavFrame(url: url, label: resolvedLabel));
      _recordBrowsing(url, label: resolvedLabel);
    }
    final tabs = [
      for (final tab in current.openTabs)
        if (tab.id == active.id)
          tab.copyWith(url: url, label: resolvedLabel)
        else
          tab,
    ];
    _commit(current.copyWith(openTabs: tabs));
  }

  void closeTab(String tabId) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    if (current.openTabs.length <= 1) {
      _tabHistories[tabId] = [
        _TabNavFrame(url: 'itch://new-tab', label: ItchUrl.labelFor('itch://new-tab')),
      ];
      navigateActiveTab('itch://new-tab');
      return;
    }
    _tabHistories.remove(tabId);
    final tabs = current.openTabs.where((t) => t.id != tabId).toList();
    var nextActive = current.activeTabId;
    if (tabId == current.activeTabId) {
      final index = current.openTabs.indexWhere((t) => t.id == tabId);
      if (index + 1 < current.openTabs.length) {
        nextActive = current.openTabs[index + 1].id;
      } else if (index > 0) {
        nextActive = current.openTabs[index - 1].id;
      } else {
        nextActive = tabs.first.id;
      }
    }
    _commit(TabsState(openTabs: tabs, activeTabId: nextActive));
  }

  void newTab() {
    openTab('itch://new-tab');
  }

  /// Закрыть все вкладки и оставить одну «Новая вкладка».
  void closeAllTabs() {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final tabId = 'tab-${DateTime.now().millisecondsSinceEpoch}';
    const url = 'itch://new-tab';
    const label = 'Новая вкладка';
    _tabHistories
      ..clear()
      ..[tabId] = [_TabNavFrame(url: url, label: label)];
    _commit(
      TabsState(
        openTabs: [TabEntry(id: tabId, url: url, label: label)],
        activeTabId: tabId,
      ),
    );
  }
}
