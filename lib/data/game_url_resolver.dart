import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import '../features/collections/collections_controller.dart';
import '../features/game/game_catalog.dart';
import '../features/install/installed_games_controller.dart';
import '../features/library/library_controller.dart';
import 'game_web_url.dart';
import 'itch_api_client.dart';
import 'models.dart';
import 'repositories/game_url_overrides_repository.dart';

final gameUrlOverridesRepositoryProvider = Provider<GameUrlOverridesRepository>((ref) {
  return GameUrlOverridesRepository();
});

final gameUrlResolverProvider = Provider<GameUrlResolver>((ref) {
  return GameUrlResolver(
    api: ref.read(itchApiClientProvider),
    overrides: ref.read(gameUrlOverridesRepositoryProvider),
    findSeed: (gameId) {
      ref.watch(libraryControllerProvider);
      ref.watch(collectionsControllerProvider);
      ref.watch(installedGamesProvider);
      return findLibraryGameById(ref, gameId);
    },
    findInstalledStoreUrl: (gameId) {
      ref.watch(installedGamesProvider);
      return ref.read(installedGamesProvider)[gameId]?.storeUrl;
    },
    readToken: () async {
      final auth = ref.read(authControllerProvider.notifier);
      final full = await auth.readFullApiKey();
      if (full != null && full.isNotEmpty) {
        return full;
      }
      return auth.readApiKey();
    },
  );
});

/// Разрешает публичный URL игры (поддомен автора), не `itch.io/game/:id` (404).
class GameUrlResolver {
  GameUrlResolver({
    required ItchApiClient api,
    required GameUrlOverridesRepository overrides,
    required LibraryGame? Function(int gameId) findSeed,
    required String? Function(int gameId) findInstalledStoreUrl,
    required Future<String?> Function() readToken,
  })  : _api = api,
        _overrides = overrides,
        _findSeed = findSeed,
        _findInstalledStoreUrl = findInstalledStoreUrl,
        _readToken = readToken;

  final ItchApiClient _api;
  final GameUrlOverridesRepository _overrides;
  final LibraryGame? Function(int gameId) _findSeed;
  final String? Function(int gameId) _findInstalledStoreUrl;
  final Future<String?> Function() _readToken;
  final Map<int, String> _cache = {};

  Future<String> resolve({required int gameId, LibraryGame? seed}) async {
    if (gameId <= 0) {
      return 'https://itch.io';
    }

    final cached = _cache[gameId];
    if (GameWebUrl.isValid(cached)) {
      return cached!;
    }

    final override = await _overrides.get(gameId);
    if (GameWebUrl.isValid(override)) {
      _cache[gameId] = override!;
      return override;
    }

    final fromInstalled = _findInstalledStoreUrl(gameId);
    if (GameWebUrl.isValid(fromInstalled)) {
      _cache[gameId] = fromInstalled!.trim();
      return fromInstalled;
    }

    final fromSeed = GameWebUrl.pick(seed?.url, _findSeed(gameId)?.url);
    if (fromSeed != null) {
      _cache[gameId] = fromSeed;
      return fromSeed;
    }

    final token = await _readToken();
    if (token != null && token.isNotEmpty) {
      final fromOwned = await _api.findOwnedGameUrl(token: token, gameId: gameId);
      if (GameWebUrl.isValid(fromOwned)) {
        _cache[gameId] = fromOwned!.trim();
        return fromOwned;
      }
      final fromApi = await _api.fetchGameStoreUrl(token: token, gameId: gameId);
      if (GameWebUrl.isValid(fromApi)) {
        _cache[gameId] = fromApi!.trim();
        return fromApi;
      }
    }

    throw GameUrlResolutionException(gameId);
  }

  void remember(int gameId, String url) {
    if (GameWebUrl.isValid(url)) {
      _cache[gameId] = url.trim();
    }
  }
}

class GameUrlResolutionException implements Exception {
  GameUrlResolutionException(this.gameId);

  final int gameId;

  @override
  String toString() =>
      'Не удалось определить ссылку на игру (id: $gameId). Откройте её на itch.io в браузере.';
}
