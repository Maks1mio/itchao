import 'package:http/http.dart' as http;

import '../core/utils/http_response_body.dart';
import 'game_page_models.dart';
import 'itch_embed_parser.dart';

/// Загружает метаданные itch embed widget (`/embed/{id}`).
class ItchEmbedFetcher {
  ItchEmbedFetcher({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final _cache = <int, GamePromoCard>{};

  static const _headers = <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 itchao/1.0',
    'Accept-Language': 'en,ru;q=0.9',
  };

  void dispose() {
    _client.close();
  }

  Future<GamePromoCard?> fetch(int embedId) async {
    final cached = _cache[embedId];
    if (cached != null) {
      return cached;
    }

    try {
      final response = await _client
          .get(
            Uri.parse('https://itch.io/embed/$embedId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final html = decodeHttpResponseBody(response);
      final card = ItchEmbedParser.parseEmbedWidgetHtml(html);
      if (card != null) {
        _cache[embedId] = card;
      }
      return card;
    } catch (_) {
      return null;
    }
  }
}
