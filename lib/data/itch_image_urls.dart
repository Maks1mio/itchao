/// Нормализация URL картинок itch.io (original = максимальное качество).
abstract final class ItchImageUrls {
  static final _itchImg = RegExp(
    r'(https://img\.itch\.zone/[^/]+)/(?:original|32x32[^/]*|347x500|794x1000|[^\s/]+)/([^/?\s]+)',
  );

  static String? toOriginal(String? url) {
    if (url == null || url.trim().isEmpty) {
      return null;
    }
    var normalized = url.trim();
    if (normalized.startsWith('//')) {
      normalized = 'https:$normalized';
    }
    if (!normalized.contains('img.itch.zone')) {
      return normalized;
    }
    final match = _itchImg.firstMatch(normalized);
    if (match != null) {
      return '${match.group(1)}/original/${match.group(2)}';
    }
    return normalized;
  }
}
