import '../../data/game_web_url.dart';
import '../../data/models.dart';

/// Вкладка приложения: нативная страница игры (как `urlForGame` + evolve на ПК).
String itchGamePageUrl(LibraryGame game) {
  final params = <String, String>{
    'label': game.title,
  };
  final storeUrl = GameWebUrl.pick(game.url, null);
  if (storeUrl != null) {
    params['url'] = storeUrl;
  }
  if (game.coverUrl != null && game.coverUrl!.trim().isNotEmpty) {
    params['cover'] = game.coverUrl!.trim();
  }
  return Uri(
    scheme: 'itch',
    host: 'games',
    pathSegments: ['${game.id}'],
    queryParameters: params,
  ).toString();
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

/// Нативная вкладка игры из публичного itch.io URL.
///
/// `author.itch.io/game` не содержит id, поэтому открываем через `from-url`:
/// страница сама загрузит HTML, распарсит id и дальше будет работать как обычная игра.
String? itchGameTabUrlFromWebUrl(String url) {
  final parsed = Uri.tryParse(url.trim());
  if (parsed == null || (parsed.scheme != 'http' && parsed.scheme != 'https')) {
    return null;
  }

  final numeric = itchGameTabUrlFromHistory(url);
  if (numeric != null) {
    return numeric;
  }

  final host = parsed.host.toLowerCase();
  final isCreatorSubdomain = host.endsWith('.itch.io') &&
      host != 'itch.io' &&
      host != 'www.itch.io';
  if (!isCreatorSubdomain || parsed.pathSegments.length != 1) {
    return null;
  }

  final slug = parsed.pathSegments.first.trim();
  if (slug.isEmpty) {
    return null;
  }

  final normalizedWebUrl = parsed.replace(fragment: '').toString();
  return Uri(
    scheme: 'itch',
    host: 'games',
    pathSegments: const ['from-url'],
    queryParameters: {
      'url': normalizedWebUrl,
      'label': _titleFromSlug(slug),
    },
  ).toString();
}

String _titleFromSlug(String slug) {
  return slug
      .split(RegExp(r'[-_]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

/// Публичный URL на itch.io (WebView, «Открыть на сайте»). Без `url` — null.
String? itchGameWebUrl(LibraryGame game) => GameWebUrl.pick(game.url, null);

/// itch.io URL из вкладки `itch://games/...?url=...` (для браузерного режима).
String? itchGameWebUrlFromTab(String tabUrl) {
  final uri = Uri.tryParse(tabUrl);
  if (uri == null || uri.scheme != 'itch' || uri.host != 'games') {
    return null;
  }
  final webUrl = uri.queryParameters['url']?.trim();
  if (webUrl == null || webUrl.isEmpty) {
    return null;
  }
  return webUrl;
}
