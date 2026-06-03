import '../../data/game_web_url.dart';
import '../../data/models.dart';

/// Вкладка приложения: нативная страница игры.
String itchGamePageUrl(LibraryGame game) {
  final label = Uri.encodeQueryComponent(game.title);
  return 'itch://games/${game.id}?label=$label';
}

/// Если в URL есть числовой id игры — вкладка `itch://games/:id`.
String? itchGameTabUrlFromHistory(String url) {
  final parsed = Uri.tryParse(url.trim());
  if (parsed == null) {
    return null;
  }
  if (parsed.scheme == 'itch' && parsed.host == 'games' && parsed.pathSegments.isNotEmpty) {
    final id = int.tryParse(parsed.pathSegments.first);
    if (id != null && id > 0) {
      return 'itch://games/$id';
    }
  }
  final pathMatch = RegExp(r'/game/(\d+)(?:/|$)').firstMatch(parsed.path);
  if (pathMatch != null) {
    return 'itch://games/${pathMatch.group(1)}';
  }
  return null;
}

/// Публичный URL на itch.io (WebView, «Открыть на сайте»). Без `url` — null.
String? itchGameWebUrl(LibraryGame game) => GameWebUrl.pick(game.url, null);
