/// Проверка и выбор канонического URL страницы игры на itch.io.
abstract final class GameWebUrl {
  static final _brokenNumericPath = RegExp(
    r'^https?://(?:www\.)?itch\.io/game/\d+/?$',
    caseSensitive: false,
  );

  static bool isValid(String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return false;
    }
    if (_brokenNumericPath.hasMatch(trimmed)) {
      return false;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      return false;
    }
    return uri.host.endsWith('.itch.io') || uri.host == 'itch.io';
  }

  static String? pick(String? primary, String? secondary) {
    if (isValid(primary)) {
      return primary!.trim();
    }
    if (isValid(secondary)) {
      return secondary!.trim();
    }
    return null;
  }
}
