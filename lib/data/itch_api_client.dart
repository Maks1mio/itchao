import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'install_models.dart';
import 'json_list_utils.dart';
import 'models.dart';

class ItchApiClient {
  ItchApiClient({http.Client? client, this.baseUrl = 'https://itch.io'})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  static const _apiBase = 'https://api.itch.io';

  Future<UserProfile> loginWithPassword({
    required String username,
    required String password,
  }) async {
    if (username.isEmpty || password.isEmpty) {
      throw const FormatException('Username and password are required');
    }
    return UserProfile(id: 0, username: username, displayName: username);
  }

  Future<CredentialInfo> fetchCredentialInfo({required String token}) async {
    final response = await _getBearer('$_apiBase/credentials/info', token);
    final body = _decodeMap(response);
    _throwIfErrors(body, response.statusCode);
    final scopes = body['scopes'];
    final scopeList = scopes is List ? scopes.map((s) => s.toString()).toList() : <String>[];
    final expiresRaw = body['expires_at'] as String?;
    return CredentialInfo(
      type: body['type'] as String? ?? 'unknown',
      scopes: scopeList,
      expiresAt: expiresRaw != null ? DateTime.tryParse(expiresRaw) : null,
    );
  }

  Future<List<LibraryGame>> fetchLibrary({required String apiKey}) async {
    final bearerGames = await _fetchOwnedKeysBearer(apiKey);
    if (bearerGames != null) {
      return bearerGames;
    }

    final legacyUri = Uri.parse('$baseUrl/api/1/key/my-games').replace(
      queryParameters: {'api_key': apiKey},
    );
    final legacyResponse = await _client.get(legacyUri);
    if (legacyResponse.statusCode >= 200 && legacyResponse.statusCode < 300) {
      final body = _decodeMap(legacyResponse);
      if (!_hasErrors(body)) {
        final parsed = _parseLibraryFromLegacyResponse(body);
        if (parsed.isNotEmpty) {
          return parsed;
        }
      }
    }

    throw Exception(
      'Не удалось загрузить библиотеку (${legacyResponse.statusCode}). '
      'Выйдите и войдите снова через OAuth.',
    );
  }

  Future<List<LibraryGame>?> _fetchOwnedKeysBearer(String token) async {
    final response = await _getBearer('$_apiBase/profile/owned-keys', token);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final body = _decodeMap(response);
    if (_hasErrors(body)) {
      return null;
    }
    return _parseOwnedKeysBody(body);
  }

  List<LibraryGame> _parseOwnedKeysBody(Map<String, dynamic> body) {
    final gameMaps = <Map<String, dynamic>>[];
    for (final raw in normalizeJsonObjectList(body['owned_keys'])) {
      final game = raw['game'];
      if (game is Map<String, dynamic>) {
        gameMaps.add(game);
      }
    }
    return _dedupeAndMapGames(gameMaps);
  }

  List<LibraryGame> _parseLibraryFromLegacyResponse(Map<String, dynamic> body) {
    final gameMaps = <Map<String, dynamic>>[];
    final directGames = body['games'] as List<dynamic>?;
    if (directGames != null) {
      for (final raw in directGames) {
        if (raw is Map<String, dynamic>) {
          gameMaps.add(raw);
        }
      }
    }
    for (final raw in normalizeJsonObjectList(body['owned_keys'])) {
      final game = raw['game'];
      if (game is Map<String, dynamic>) {
        gameMaps.add(game);
      }
    }
    return _dedupeAndMapGames(gameMaps);
  }

  List<LibraryGame> _dedupeAndMapGames(List<Map<String, dynamic>> gameMaps) {
    final seen = <int>{};
    return gameMaps.where((map) {
      final id = (map['id'] as num?)?.toInt() ?? 0;
      if (id == 0 || seen.contains(id)) {
        return false;
      }
      seen.add(id);
      return true;
    }).map(_libraryGameFromMap).toList();
  }

  LibraryGame _libraryGameFromMap(Map<String, dynamic> map) {
    final traits = stringListFromJson(map['traits']);
    return LibraryGame(
      id: (map['id'] as num?)?.toInt() ?? 0,
      title: map['title'] as String? ?? 'Untitled',
      coverUrl: map['cover_url'] as String?,
      installed: false,
      shortText: map['short_text'] as String?,
      url: map['url'] as String?,
      classification: map['classification'] as String? ?? 'game',
      platforms: _platformsFromTraits(traits),
    );
  }

  List<String> _platformsFromTraits(List<String> traits) {
    final platforms = <String>[];
    for (final t in traits) {
      if (t == 'p_windows') {
        platforms.add('windows');
      } else if (t == 'p_osx') {
        platforms.add('osx');
      } else if (t == 'p_linux') {
        platforms.add('linux');
      } else if (t == 'p_android') {
        platforms.add('android');
      }
    }
    return platforms;
  }

  Future<List<ItchCollection>> fetchCollections({required String token}) async {
    final response = await _getBearer('$_apiBase/profile/collections', token);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Collections request failed (${response.statusCode})');
    }
    final body = _decodeMap(response);
    _throwIfErrors(body, response.statusCode);
    final raw = body['collections'] as List<dynamic>? ?? const <dynamic>[];
    return raw.whereType<Map<String, dynamic>>().map(_collectionFromMap).toList();
  }

  Future<ItchCollection?> findCollectionById({
    required String token,
    required int collectionId,
  }) async {
    final collections = await fetchCollections(token: token);
    for (final collection in collections) {
      if (collection.id == collectionId) {
        return collection;
      }
    }
    return null;
  }

  /// `collection-games` требует unscoped API key (см. Serverside API) или scope `collection:view`.
  Future<bool> probeCollectionGamesAccess({
    required String token,
    required int collectionId,
  }) async {
    try {
      await _fetchCollectionGamesWithToken(
        token: token,
        collectionId: collectionId,
        page: 1,
        perPage: 1,
      );
      return true;
    } on ApiException catch (error) {
      if (error.isCollectionViewDenied) {
        return false;
      }
      rethrow;
    }
  }

  Future<List<LibraryGame>> fetchCollectionGames({
    required String token,
    required int collectionId,
    String? fullAccessToken,
    int page = 1,
    int perPage = 12,
  }) async {
    final tokens = <String>{
      if (fullAccessToken != null && fullAccessToken.isNotEmpty) fullAccessToken,
      token,
    };
    ApiException? lastError;
    for (final bearer in tokens) {
      try {
        return await _fetchCollectionGamesWithToken(
          token: bearer,
          collectionId: collectionId,
          page: page,
          perPage: perPage,
        );
      } on ApiException catch (error) {
        lastError = error;
        if (!error.isCollectionViewDenied) {
          rethrow;
        }
      }
    }
    throw lastError ?? ApiException('Collection games failed', statusCode: 403);
  }

  /// Все страницы `collection-games` (на itch ~30 игр на страницу в web, до 100 в API).
  Future<List<LibraryGame>> fetchAllCollectionGames({
    required String token,
    required int collectionId,
    String? fullAccessToken,
    int perPage = 100,
    int maxPages = 64,
  }) async {
    final merged = <LibraryGame>[];
    final seen = <int>{};
    for (var page = 1; page <= maxPages; page++) {
      final batch = await fetchCollectionGames(
        token: token,
        fullAccessToken: fullAccessToken,
        collectionId: collectionId,
        page: page,
        perPage: perPage,
      );
      if (batch.isEmpty) {
        break;
      }
      for (final game in batch) {
        if (seen.add(game.id)) {
          merged.add(game);
        }
      }
      if (batch.length < perPage) {
        break;
      }
    }
    return merged;
  }

  Future<List<LibraryGame>> _fetchCollectionGamesWithToken({
    required String token,
    required int collectionId,
    required int page,
    required int perPage,
  }) async {
    final uri = Uri.parse('$_apiBase/collections/$collectionId/collection-games').replace(
      queryParameters: {
        'page': '$page',
        'per_page': '$perPage',
      },
    );
    final response = await _getBearer(uri.toString(), token);
    final body = _decodeMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final missingScope = _extractMissingScope(body);
      throw ApiException(
        'Collection games failed (${response.statusCode})',
        statusCode: response.statusCode,
        missingScope: missingScope,
      );
    }
    _throwIfErrors(body, response.statusCode);
    final items = body['collection_games'] as List<dynamic>? ?? const <dynamic>[];
    final gameMaps = <Map<String, dynamic>>[];
    for (final raw in items) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final game = raw['game'];
      if (game is Map<String, dynamic>) {
        gameMaps.add(game);
      }
    }
    return _dedupeAndMapGames(gameMaps);
  }

  String? _extractMissingScope(Map<String, dynamic> body) {
    final errors = body['errors'];
    if (errors is! List || errors.isEmpty) {
      return null;
    }
    final first = errors.first.toString();
    final match = RegExp(r'`([^`]+)`').firstMatch(first);
    return match?.group(1);
  }

  ItchCollection _collectionFromMap(Map<String, dynamic> map) {
    return ItchCollection(
      id: (map['id'] as num?)?.toInt() ?? 0,
      title: map['title'] as String? ?? 'Без названия',
      gamesCount: (map['games_count'] as num?)?.toInt() ?? 0,
      updatedAt: _parseDate(map['updated_at'] as String?),
      createdAt: _parseDate(map['created_at'] as String?),
    );
  }

  DateTime _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<UserProfile> fetchMe({required String apiKey}) async {
    final bearerResponse = await _getBearer('$_apiBase/profile', apiKey);
    if (bearerResponse.statusCode >= 200 && bearerResponse.statusCode < 300) {
      final body = _decodeMap(bearerResponse);
      if (!_hasErrors(body)) {
        return _profileFromBody(body);
      }
    }

    final uri = Uri.parse('$baseUrl/api/1/key/me').replace(
      queryParameters: {'api_key': apiKey},
    );
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Profile request failed (${response.statusCode})');
    }
    return _profileFromBody(_decodeMap(response));
  }

  UserProfile _profileFromBody(Map<String, dynamic> body) {
    final user = body['user'] as Map<String, dynamic>? ?? const {};
    return UserProfile(
      id: (user['id'] as num?)?.toInt() ?? 0,
      username: user['username'] as String? ?? 'itch-user',
      displayName: user['display_name'] as String? ?? (user['username'] as String? ?? 'itch-user'),
      coverUrl: user['cover_url'] as String?,
    );
  }

  /// OAuth scope `game:view:ownership` — только для игр создателя OAuth-приложения.
  /// Numeric download key id from owned-keys (for paid/claimed games).
  Future<int?> findDownloadKeyId({
    required String token,
    required int gameId,
    int maxPages = 64,
  }) async {
    for (var page = 1; page <= maxPages; page++) {
      final uri = Uri.parse('$_apiBase/profile/owned-keys').replace(
        queryParameters: {'page': '$page'},
      );
      final response = await _getBearer(uri.toString(), token);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final body = _decodeMap(response);
      if (_hasErrors(body)) {
        return null;
      }
      for (final raw in normalizeJsonObjectList(body['owned_keys'])) {
        final keyGameId = (raw['game_id'] as num?)?.toInt();
        final nestedGame = raw['game'];
        final nestedId = nestedGame is Map<String, dynamic>
            ? (nestedGame['id'] as num?)?.toInt()
            : null;
        if (keyGameId == gameId || nestedId == gameId) {
          return (raw['id'] as num?)?.toInt();
        }
      }
      if (normalizeJsonObjectList(body['owned_keys']).isEmpty) {
        break;
      }
    }
    return null;
  }

  Future<List<GameUpload>> fetchGameUploads({
    required String token,
    required int gameId,
    int? downloadKeyId,
  }) async {
    final modern = await _fetchUploadsModern(
      token: token,
      gameId: gameId,
      downloadKeyId: downloadKeyId,
    );
    if (modern != null) {
      return modern;
    }
    return _fetchUploadsLegacy(
      token: token,
      gameId: gameId,
      downloadKeyId: downloadKeyId,
    );
  }

  Future<List<GameUpload>?> _fetchUploadsModern({
    required String token,
    required int gameId,
    int? downloadKeyId,
  }) async {
    final params = <String, String>{};
    if (downloadKeyId != null) {
      params['download_key_id'] = '$downloadKeyId';
    }
    final uri = Uri.parse('$_apiBase/games/$gameId/uploads').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final response = await _getBearer(uri.toString(), token);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    try {
      return _parseUploadsResponse(response);
    } catch (_) {
      return null;
    }
  }

  Future<List<GameUpload>> _fetchUploadsLegacy({
    required String token,
    required int gameId,
    int? downloadKeyId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/1/$token/game/$gameId/uploads').replace(
      queryParameters: downloadKeyId != null
          ? {'download_key_id': '$downloadKeyId'}
          : null,
    );
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Не удалось получить список файлов (${response.statusCode})');
    }
    return _parseUploadsResponse(response);
  }

  List<GameUpload> _parseUploadsResponse(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return _parseUploads(decoded);
    }
    if (decoded is Map<String, dynamic>) {
      if (_hasErrors(decoded)) {
        return const [];
      }
      return _parseUploads(decoded['uploads'] ?? decoded);
    }
    return const [];
  }

  List<GameUpload> _parseUploads(dynamic raw) {
    return normalizeJsonObjectList(raw)
        .map(GameUpload.fromMap)
        .where((u) => u.id > 0)
        .toList();
  }

  GameUpload? pickAndroidUpload(List<GameUpload> uploads) {
    final apks = uploads.where((u) => u.isAndroidApk).toList();
    if (apks.isEmpty) {
      return null;
    }
    apks.sort((a, b) {
      final aApk = a.filename.toLowerCase().endsWith('.apk');
      final bApk = b.filename.toLowerCase().endsWith('.apk');
      if (aApk != bApk) {
        return aApk ? -1 : 1;
      }
      return 0;
    });
    return apks.first;
  }

  Future<Uri> resolveUploadDownloadUrl({
    required String token,
    required int uploadId,
    int? downloadKeyId,
  }) async {
    final query = <String, String>{
      'api_key': token,
      if (downloadKeyId != null) 'download_key_id': '$downloadKeyId',
    };

    final legacyUri = Uri.parse('$baseUrl/api/1/$token/upload/$uploadId/download').replace(
      queryParameters: downloadKeyId != null
          ? {'download_key_id': '$downloadKeyId'}
          : null,
    );
    final legacyUrl = _extractRedirectOrUrl(await _client.get(legacyUri));
    if (legacyUrl != null) {
      return legacyUrl;
    }

    final modernUri = Uri.parse('$_apiBase/uploads/$uploadId/download').replace(
      queryParameters: query,
    );
    final modernUrl = _extractRedirectOrUrl(
      await _client.get(
        modernUri,
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (modernUrl != null) {
      return modernUrl;
    }

    throw Exception(
      'Не удалось получить ссылку на скачивание. '
      'Укажите полный API key с itch.io в настройках (OAuth не подходит для загрузок).',
    );
  }

  Uri? _extractRedirectOrUrl(http.Response response) {
    if (response.statusCode >= 300 && response.statusCode < 400) {
      final location = response.headers['location'];
      if (location != null && location.isNotEmpty) {
        return Uri.parse(location);
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final body = _decodeMap(response);
        if (_hasErrors(body)) {
          return null;
        }
        final url = body['url'] as String? ?? body['download_url'] as String?;
        if (url != null && url.isNotEmpty) {
          return Uri.parse(url);
        }
      } catch (_) {
        final finalUrl = response.request?.url;
        if (finalUrl != null) {
          return finalUrl;
        }
      }
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('json') && response.request?.url != null) {
        return response.request!.url;
      }
    }
    return null;
  }

  Future<String?> fetchWharfLatestVersion({
    required int gameId,
    required String channelName,
  }) async {
    final uri = Uri.parse('$_apiBase/wharf/latest').replace(
      queryParameters: {
        'game_id': '$gameId',
        'channel_name': channelName,
      },
    );
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final body = _decodeMap(response);
    if (_hasErrors(body)) {
      return null;
    }
    return body['latest'] as String?;
  }

  /// Канонический URL витрины (`https://author.itch.io/slug`).
  Future<String?> fetchGameStoreUrl({
    required String token,
    required int gameId,
  }) async {
    if (gameId <= 0) {
      return null;
    }
    final response = await _getBearer('$_apiBase/games/$gameId', token);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final body = _decodeMap(response);
    if (_hasErrors(body)) {
      return null;
    }
    final game = body['game'];
    if (game is Map<String, dynamic>) {
      return game['url'] as String?;
    }
    return null;
  }

  /// URL из купленных игр (owned-keys), если в кэше библиотеки нет `url`.
  Future<String?> findOwnedGameUrl({
    required String token,
    required int gameId,
    int maxPages = 64,
  }) async {
    if (gameId <= 0) {
      return null;
    }
    for (var page = 1; page <= maxPages; page++) {
      final uri = Uri.parse('$_apiBase/profile/owned-keys').replace(
        queryParameters: {'page': '$page'},
      );
      final response = await _getBearer(uri.toString(), token);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final body = _decodeMap(response);
      if (_hasErrors(body)) {
        return null;
      }
      final keys = normalizeJsonObjectList(body['owned_keys']);
      if (keys.isEmpty) {
        break;
      }
      for (final raw in keys) {
        final nested = raw['game'];
        final nestedId = nested is Map<String, dynamic>
            ? (nested['id'] as num?)?.toInt()
            : null;
        final keyGameId = (raw['game_id'] as num?)?.toInt();
        if (nestedId != gameId && keyGameId != gameId) {
          continue;
        }
        if (nested is Map<String, dynamic>) {
          final url = nested['url'] as String?;
          if (url != null && url.trim().isNotEmpty) {
            return url.trim();
          }
        }
      }
    }
    return null;
  }

  Future<bool> checkGameOwnership({required String token, required int gameId}) async {
    if (gameId <= 0) {
      return false;
    }
    try {
      final response = await _getBearer('$_apiBase/games/$gameId/ownership', token);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final body = _decodeMap(response);
      if (_hasErrors(body)) {
        return false;
      }
      return body['owned'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<http.Response> _getBearer(String url, String token) {
    return _client.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return const {};
  }

  bool _hasErrors(Map<String, dynamic> body) {
    final errors = body['errors'];
    return errors is List && errors.isNotEmpty;
  }

  void _throwIfErrors(Map<String, dynamic> body, int statusCode) {
    if (_hasErrors(body)) {
      final errors = (body['errors'] as List).map((e) => e.toString()).join(', ');
      throw ApiException(
        'API error ($statusCode): $errors',
        statusCode: statusCode,
        missingScope: _extractMissingScope(body),
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
