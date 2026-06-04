import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../core/utils/http_response_body.dart';
import 'game_page_models.dart';
import 'game_page_parser.dart';
import 'game_web_url.dart';
import 'itch_image_urls.dart';
import 'models.dart';

export 'game_page_models.dart';

class GamePageFetcher {
  GamePageFetcher({http.Client? client, ItchGamePageParser? parser})
    : _client = client ?? http.Client(),
      _parser = parser ?? const ItchGamePageParser();

  final http.Client _client;
  final ItchGamePageParser _parser;
  String? _cachedCookieHeader;
  DateTime? _cookieCachedAt;

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

  Future<GameDetail> fetch({
    required String webUrl,
    LibraryGame? seed,
  }) async {
    final resolvedUrl = _normalizeGameUrl(webUrl, seed);
    final html = await _fetchHtml(resolvedUrl);
    if (html == null) {
      return _fromSeed(seed, resolvedUrl);
    }
    return _parser.parse(html, webUrl: resolvedUrl, seed: seed);
  }

  String _normalizeGameUrl(String webUrl, LibraryGame? seed) {
    final resolved = GameWebUrl.pick(webUrl, seed?.url);
    if (resolved != null) {
      return resolved;
    }
    return webUrl.trim().isNotEmpty ? webUrl.trim() : 'https://itch.io';
  }

  Future<String?> _fetchHtml(String url) async {
    final cookie = await _cookieHeader();
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 itchao/1.0',
      'Accept-Language': 'ru,en;q=0.9',
      if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
    };
    final response = await _client.get(Uri.parse(url), headers: headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodeHttpResponseBody(response);
    }
    return null;
  }

  GameDetail _fromSeed(LibraryGame? seed, String webUrl) {
    if (seed == null) {
      return GameDetail(
        id: 0,
        title: 'Игра',
        webUrl: webUrl,
      );
    }
    return GameDetail(
      id: seed.id,
      title: seed.title,
      webUrl: webUrl,
      iconUrl: ItchImageUrls.toOriginal(seed.coverUrl),
      coverUrl: ItchImageUrls.toOriginal(seed.coverUrl),
      heroImageUrl: ItchImageUrls.toOriginal(seed.coverUrl),
      shortText: seed.shortText ?? '',
      classification: seed.classification,
      platforms: seed.platforms,
      isFree: true,
    );
  }

  void dispose() {
    _client.close();
  }
}
