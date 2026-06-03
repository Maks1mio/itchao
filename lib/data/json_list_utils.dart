/// itch.io JSON often uses `{}` instead of `[]` for empty lists (see itchio/itch.io#1301).
List<Map<String, dynamic>> normalizeJsonObjectList(dynamic raw) {
  if (raw == null) {
    return const [];
  }
  if (raw is List) {
    return raw.whereType<Map<String, dynamic>>().toList();
  }
  if (raw is Map) {
    if (raw.isEmpty) {
      return const [];
    }
    final values = raw.values.toList();
    if (values.every((v) => v is Map<String, dynamic>)) {
      return values.cast<Map<String, dynamic>>();
    }
  }
  return const [];
}

List<String> stringListFromJson(dynamic raw) {
  if (raw == null) {
    return const [];
  }
  if (raw is List) {
    return raw.map((e) => e.toString()).toList();
  }
  if (raw is Map) {
    return raw.keys.map((e) => e.toString()).toList();
  }
  return const [];
}

bool jsonMapHasTruthyKey(dynamic raw, String key) {
  if (raw is! Map) {
    return false;
  }
  final value = raw[key];
  if (value == null) {
    return false;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  return true;
}
