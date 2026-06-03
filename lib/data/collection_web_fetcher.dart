import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'models.dart';

class CollectionPageResult {
  const CollectionPageResult({
    required this.games,
    this.collectionPath,
    this.hasNextPage = false,
  });

  final List<LibraryGame> games;
  final String? collectionPath;
  final bool hasNextPage;
}

/// Обложки и список игр коллекции через HTML itch.io (сессия WebView).
class CollectionWebFetcher {
  CollectionWebFetcher({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _cachedCookieHeader;
  DateTime? _cookieCachedAt;

  static final _gameIdPattern = RegExp(r'data-game_id="(\d+)"');
  static final _canonicalPathPattern = RegExp(
    r'(?:rel="canonical"|property="og:url")[^>]+(?:href|content)="https://itch\.io(/c/\d+/[^"?#]+)"',
    caseSensitive: false,
  );
  static final _collectionPathPattern = RegExp(
    r'https://itch\.io(/c/\d+/[a-zA-Z0-9][a-zA-Z0-9_-]*)',
  );
  static final _nextPagePattern = RegExp(
    r'href="(\?page=\d+[^"]*)"',
    caseSensitive: false,
  );

  Future<String?> _cookieHeader() async {
    final cachedAt = _cookieCachedAt;
    if (_cachedCookieHeader != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(minutes: 15)) {
      return _cachedCookieHeader;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    final manager = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams.fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    final cookies = await manager.getCookies(Uri.parse('https://itch.io'));
    if (cookies.isEmpty) {
      return null;
    }
    _cachedCookieHeader = cookies.map((c) => '${c.name}=${c.value}').join('; ');
    _cookieCachedAt = DateTime.now();
    return _cachedCookieHeader;
  }

  List<Uri> _pageUris({
    required int collectionId,
    required int page,
    String? collectionPath,
  }) {
    final query = page > 1 ? {'page': '$page'} : null;
    final uris = <Uri>[];
    if (collectionPath != null && collectionPath.isNotEmpty) {
      uris.add(Uri.parse('https://itch.io$collectionPath').replace(queryParameters: query));
    }
    uris.add(
      Uri.parse('https://itch.io/c/$collectionId/hello').replace(queryParameters: query),
    );
    uris.add(Uri.parse('https://itch.io/c/$collectionId').replace(queryParameters: query));
    return uris;
  }

  Future<String?> _fetchHtml({
    required int collectionId,
    required int page,
    String? collectionPath,
  }) async {
    final cookie = await _cookieHeader();
    if (cookie == null || cookie.isEmpty) {
      return null;
    }
    for (final uri in _pageUris(collectionId: collectionId, page: page, collectionPath: collectionPath)) {
      final response = await _client.get(
        uri,
        headers: {
          'Cookie': cookie,
          'User-Agent': 'itchao/1.0 (Flutter; collection)',
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300 && response.body.contains('data-game_id')) {
        return response.body;
      }
    }
    return null;
  }

  String? _extractCollectionPath(String html) {
    final canonical = _canonicalPathPattern.firstMatch(html);
    if (canonical != null) {
      return canonical.group(1);
    }
    final match = _collectionPathPattern.firstMatch(html);
    return match?.group(1);
  }

  bool _hasNextPage(String html, int currentPage) {
    final next = currentPage + 1;
    final exactNext = RegExp(r'href="\?page=$next(?:&|")');
    if (exactNext.hasMatch(html)) {
      return true;
    }
    for (final link in _nextPagePattern.allMatches(html)) {
      final href = link.group(1) ?? '';
      final pageMatch = RegExp(r'page=(\d+)').firstMatch(href);
      if (int.tryParse(pageMatch?.group(1) ?? '') == next) {
        return true;
      }
    }
    return false;
  }

  Future<CollectionPageResult> fetchGamesPage({
    required int collectionId,
    int page = 1,
    String? collectionPath,
  }) async {
    final html = await _fetchHtml(
      collectionId: collectionId,
      page: page,
      collectionPath: collectionPath,
    );
    if (html == null) {
      return const CollectionPageResult(games: []);
    }
    final path = collectionPath ?? _extractCollectionPath(html);
    final games = _parseGamesFromHtml(html);
    return CollectionPageResult(
      games: games,
      collectionPath: path,
      hasNextPage: _hasNextPage(html, page),
    );
  }

  Future<List<LibraryGame>> fetchPreviewGames({
    required int collectionId,
    int limit = 12,
  }) async {
    final page = await fetchGamesPage(collectionId: collectionId, page: 1);
    if (limit > 0 && page.games.length > limit) {
      return page.games.take(limit).toList();
    }
    return page.games;
  }

  /// Все страницы коллекции (как infinite scroll на itch.io, ~30 игр на страницу).
  Future<List<LibraryGame>> fetchAllGames({
    required int collectionId,
    int maxPages = 64,
  }) async {
    final games = <LibraryGame>[];
    final seen = <int>{};
    String? path;
    var hasNext = true;

    for (var page = 1; page <= maxPages && hasNext; page++) {
      final result = await fetchGamesPage(
        collectionId: collectionId,
        page: page,
        collectionPath: path,
      );
      path = result.collectionPath ?? path;
      var added = 0;
      for (final game in result.games) {
        if (seen.add(game.id)) {
          games.add(game);
          added++;
        }
      }
      if (result.games.isEmpty || added == 0) {
        break;
      }
      hasNext = result.hasNextPage;
    }
    return games;
  }

  List<LibraryGame> _parseGamesFromHtml(String html, {int? limit}) {
    final games = <LibraryGame>[];
    final seen = <int>{};

    for (final idMatch in _gameIdPattern.allMatches(html)) {
      final id = int.tryParse(idMatch.group(1) ?? '') ?? 0;
      if (id == 0 || seen.contains(id)) {
        continue;
      }
      seen.add(id);
      final start = idMatch.start;
      final end = (start + 2500).clamp(0, html.length);
      final segment = html.substring(start, end);
      games.add(_parseGameCell(segment, id));
      if (limit != null && games.length >= limit) {
        break;
      }
    }
    return games;
  }

  LibraryGame _parseGameCell(String html, int id) {
    final coverMatch = RegExp(r'data-lazy_src="([^"]+)"').firstMatch(html) ??
        RegExp(r'<img[^>]+src="([^"]+)"').firstMatch(html);
    final titleMatch = RegExp(r'class="title game_link"[^>]*>([^<]*)<').firstMatch(html) ??
        RegExp(r'class="game_title"[^>]*>([^<]*)<').firstMatch(html);
    final textMatch = RegExp(r'class="game_text"[^>]*>([^<]*)<').firstMatch(html);
    final urlMatch = RegExp(r'class="thumb_link game_link"[^>]*href="([^"]+)"').firstMatch(html) ??
        RegExp(r'href="(https://[^"]+\.itch\.io/[^"]*)"').firstMatch(html);
    final genreMatch = RegExp(r'class="game_genre"[^>]*>([^<]*)<').firstMatch(html);

    final platforms = <String>[];
    if (html.contains('icon-windows')) {
      platforms.add('windows');
    }
    if (html.contains('icon-apple')) {
      platforms.add('osx');
    }
    if (html.contains('icon-tux')) {
      platforms.add('linux');
    }
    if (html.contains('icon-android')) {
      platforms.add('android');
    }

    return LibraryGame(
      id: id,
      title: _decodeHtmlEntities(titleMatch?.group(1)?.trim() ?? 'Untitled'),
      coverUrl: coverMatch?.group(1)?.trim(),
      installed: false,
      shortText: _decodeHtmlEntities(textMatch?.group(1)?.trim() ?? ''),
      url: urlMatch?.group(1)?.trim(),
      classification: _decodeHtmlEntities(genreMatch?.group(1)?.trim() ?? 'game'),
      platforms: platforms,
    );
  }

  String _decodeHtmlEntities(String text) {
    if (text.isEmpty) {
      return text;
    }
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  void dispose() {
    _client.close();
  }
}
