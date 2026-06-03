class BrowsingHistoryEntry {
  const BrowsingHistoryEntry({
    required this.url,
    required this.label,
    required this.visitedAt,
  });

  final String url;
  final String label;
  final DateTime visitedAt;

  Map<String, dynamic> toJson() => {
    'url': url,
    'label': label,
    'visitedAt': visitedAt.toIso8601String(),
  };

  factory BrowsingHistoryEntry.fromJson(Map<String, dynamic> json) {
    return BrowsingHistoryEntry(
      url: json['url'] as String? ?? '',
      label: json['label'] as String? ?? '',
      visitedAt: DateTime.tryParse(json['visitedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
