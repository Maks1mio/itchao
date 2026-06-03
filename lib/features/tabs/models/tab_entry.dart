class TabEntry {
  const TabEntry({
    required this.id,
    required this.url,
    required this.label,
  });

  final String id;
  final String url;
  final String label;

  TabEntry copyWith({String? url, String? label}) {
    return TabEntry(
      id: id,
      url: url ?? this.url,
      label: label ?? this.label,
    );
  }
}

class TabsState {
  const TabsState({
    required this.openTabs,
    required this.activeTabId,
  });

  final List<TabEntry> openTabs;
  final String activeTabId;

  TabEntry? get activeTab {
    for (final tab in openTabs) {
      if (tab.id == activeTabId) {
        return tab;
      }
    }
    return openTabs.isNotEmpty ? openTabs.first : null;
  }

  TabsState copyWith({
    List<TabEntry>? openTabs,
    String? activeTabId,
  }) {
    return TabsState(
      openTabs: openTabs ?? this.openTabs,
      activeTabId: activeTabId ?? this.activeTabId,
    );
  }
}
