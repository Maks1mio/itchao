import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/game_url_resolver.dart';
import '../../data/game_web_url.dart';
import '../../data/itch_api_client.dart';
import '../../data/repositories/game_url_overrides_repository.dart';
import '../auth/auth_controller.dart';
import '../install/installed_games_controller.dart';
import '../library/library_controller.dart';
import 'game_catalog.dart';

final gameUrlFixServiceProvider = Provider<GameUrlFixService>((ref) {
  return GameUrlFixService(
    ref: ref,
    overrides: ref.read(gameUrlOverridesRepositoryProvider),
    api: ref.read(itchApiClientProvider),
    resolver: ref.read(gameUrlResolverProvider),
    readToken: () => ref.read(authControllerProvider.notifier).readApiKey(),
  );
});

class GameUrlFixResult {
  const GameUrlFixResult({required this.url, this.viaAuto = false});

  final String url;
  final bool viaAuto;
}

class GameUrlFixService {
  GameUrlFixService({
    required Ref ref,
    required GameUrlOverridesRepository overrides,
    required ItchApiClient api,
    required GameUrlResolver resolver,
    required Future<String?> Function() readToken,
  })  : _ref = ref,
        _overrides = overrides,
        _api = api,
        _resolver = resolver,
        _readToken = readToken,
        _client = http.Client();

  final Ref _ref;
  final GameUrlOverridesRepository _overrides;
  final ItchApiClient _api;
  final GameUrlResolver _resolver;
  final Future<String?> Function() _readToken;
  final http.Client _client;

  Future<GameUrlFixResult?> tryAutoFix(int gameId) async {
    final saved = await _overrides.get(gameId);
    if (GameWebUrl.isValid(saved)) {
      _resolver.remember(gameId, saved!);
      return GameUrlFixResult(url: saved, viaAuto: true);
    }

    final installed = _ref.read(installedGamesProvider)[gameId];
    if (GameWebUrl.isValid(installed?.storeUrl)) {
      final url = installed!.storeUrl!.trim();
      await _persistFix(gameId, url);
      return GameUrlFixResult(url: url, viaAuto: true);
    }

    await _ref.read(libraryControllerProvider.notifier).refresh();
    try {
      final url = await _resolver.resolve(gameId: gameId);
      await _persistFix(gameId, url);
      return GameUrlFixResult(url: url, viaAuto: true);
    } on GameUrlResolutionException {
      // continue with search
    }

    final title = _titleHint(gameId);
    if (title != null) {
      final fromSearch = await _lookupByAutocomplete(
        title: title,
        expectedGameId: gameId,
      );
      if (fromSearch != null) {
        await _persistFix(gameId, fromSearch);
        return GameUrlFixResult(url: fromSearch, viaAuto: true);
      }
    }

    return null;
  }

  Future<GameUrlFixResult> applyManualUrl(int gameId, String rawUrl) async {
    final normalized = _normalizeUserUrl(rawUrl);
    if (!GameWebUrl.isValid(normalized)) {
      throw FormatException('Некорректная ссылка itch.io');
    }
    final verified = await _verifyUrlMatchesGame(normalized, gameId);
    if (!verified) {
      throw FormatException(
        'Ссылка не совпадает с игрой (id: $gameId). Проверьте адрес.',
      );
    }
    await _persistFix(gameId, normalized);
    return GameUrlFixResult(url: normalized);
  }

  String? titleHintFor(int gameId) => _titleHint(gameId);

  String searchUrlForTitle(String title) {
    final q = Uri.encodeQueryComponent(title.trim());
    return 'https://itch.io/search?q=$q&type=games';
  }

  Future<void> _persistFix(int gameId, String url) async {
    await _overrides.set(gameId, url);
    _resolver.remember(gameId, url);

    final installed = _ref.read(installedGamesProvider)[gameId];
    if (installed != null) {
      await _ref.read(installedGamesProvider.notifier).upsert(
        installed.copyWith(storeUrl: url),
      );
    }
  }

  String? _titleHint(int gameId) {
    final installed = _ref.read(installedGamesProvider)[gameId];
    if (installed != null && installed.title.trim().isNotEmpty) {
      return installed.title.trim();
    }
    final seed = findLibraryGameById(_ref, gameId);
    return seed?.title.trim();
  }

  String _normalizeUserUrl(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    if (!trimmed.startsWith('http')) {
      trimmed = 'https://$trimmed';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return trimmed;
    }
    return uri.replace(query: '', fragment: '').toString().replaceAll(RegExp(r'/+$'), '');
  }

  Future<bool> _verifyUrlMatchesGame(String url, int gameId) async {
    if (gameId <= 0) {
      return true;
    }
    try {
      final dataUri = Uri.parse(url.endsWith('/') ? '${url}data.json' : '$url/data.json');
      final response = await _client.get(
        dataUri,
        headers: {'User-Agent': 'itchao/1.0'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return true;
      }
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final id = (body['id'] as num?)?.toInt();
        return id == null || id == gameId;
      }
    } catch (_) {
      return true;
    }
    return true;
  }

  Future<String?> _lookupByAutocomplete({
    required String title,
    required int expectedGameId,
  }) async {
    final queries = <String>{
      if (title.length <= 40) title,
      ..._titleQueryVariants(title),
    };

    final token = await _readToken();
    for (final query in queries) {
      if (query.length < 2 || query.length > 40) {
        continue;
      }
      final hits = await _fetchAutocomplete(query);
      for (final hit in hits) {
        final id = (hit['id'] as num?)?.toInt();
        final url = hit['url'] as String?;
        if (id == expectedGameId && GameWebUrl.isValid(url)) {
          return url!.trim();
        }
      }
      for (final hit in hits) {
        final id = (hit['id'] as num?)?.toInt();
        final url = hit['url'] as String?;
        final name = (hit['name'] as String? ?? '').trim();
        if (id == null || !GameWebUrl.isValid(url)) {
          continue;
        }
        if (_titlesMatch(title, name)) {
          if (token != null && token.isNotEmpty) {
            final owned = await _api.findOwnedGameUrl(token: token, gameId: id);
            if (GameWebUrl.isValid(owned)) {
              return owned;
            }
          }
          if (id == expectedGameId) {
            return url!.trim();
          }
        }
      }
    }

    if (token != null && token.isNotEmpty) {
      final fromOwned = await _api.findOwnedGameUrl(token: token, gameId: expectedGameId);
      if (GameWebUrl.isValid(fromOwned)) {
        return fromOwned;
      }
      final fromApi = await _api.fetchGameStoreUrl(token: token, gameId: expectedGameId);
      if (GameWebUrl.isValid(fromApi)) {
        return fromApi;
      }
    }

    return null;
  }

  Iterable<String> _titleQueryVariants(String title) {
    final base = title
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final words = base.split(' ').where((w) => w.length > 2).toList();
    return <String>{
      if (words.length >= 2) words.take(3).join(' '),
      if (words.isNotEmpty) words.first,
    };
  }

  bool _titlesMatch(String a, String b) {
    String norm(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
    final na = norm(a);
    final nb = norm(b);
    return na.isNotEmpty && (na == nb || na.contains(nb) || nb.contains(na));
  }

  Future<List<Map<String, dynamic>>> _fetchAutocomplete(String query) async {
    try {
      final uri = Uri.parse('https://itch.io/autocomplete').replace(
        queryParameters: {'query': query},
      );
      final response = await _client.get(
        uri,
        headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android) itchao/1.0'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        return const [];
      }
      final games = body['games'];
      if (games is! List) {
        return const [];
      }
      return games.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }
}
