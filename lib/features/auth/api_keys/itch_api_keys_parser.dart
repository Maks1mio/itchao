import 'dart:convert';

class ItchApiKeyEntry {
  const ItchApiKeyEntry({required this.key, required this.source});

  final String key;
  final String source;
}

class ItchApiKeysPageData {
  const ItchApiKeysPageData({required this.keys, this.csrfToken});

  final List<ItchApiKeyEntry> keys;
  final String? csrfToken;

  /// desktop → web; остальные источники (hitchapp и т.д.) не используем.
  String? pickDownloadKey() {
    for (final source in const ['desktop', 'web']) {
      for (final entry in keys) {
        if (entry.source == source && entry.key.length > 20) {
          return entry.key;
        }
      }
    }
    return null;
  }
}

ItchApiKeysPageData? parseApiKeysJsonResult(Object? raw) {
  if (raw == null) {
    return null;
  }
  var text = raw.toString();
  if (text.startsWith('"') && text.endsWith('"')) {
    try {
      text = jsonDecode(text) as String;
    } catch (_) {}
  }
  try {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final keysRaw = decoded['keys'];
    final keys = <ItchApiKeyEntry>[];
    if (keysRaw is List) {
      for (final item in keysRaw) {
        if (item is! Map) {
          continue;
        }
        final key = item['key']?.toString() ?? '';
        final source = item['source']?.toString().toLowerCase() ?? '';
        if (key.isNotEmpty) {
          keys.add(ItchApiKeyEntry(key: key, source: source));
        }
      }
    }
    final csrf = decoded['csrf']?.toString();
    return ItchApiKeysPageData(
      keys: keys,
      csrfToken: csrf != null && csrf.isNotEmpty ? csrf : null,
    );
  } catch (_) {
    return null;
  }
}

bool parseSubmitCreateResult(Object? raw) {
  final text = raw?.toString().replaceAll('"', '') ?? '';
  return text == 'submitted';
}
