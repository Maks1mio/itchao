import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_page_fetcher.dart';
import '../../data/game_url_resolver.dart';
import '../../data/models.dart';
import '../auth/auth_controller.dart';
import '../collections/collections_controller.dart';
import '../library/library_controller.dart';
import '../game/game_tab_seed.dart';

final gamePageFetcherProvider = Provider<GamePageFetcher>((ref) {
  final fetcher = GamePageFetcher();
  ref.onDispose(fetcher.dispose);
  return fetcher;
});

final gameSeedProvider = Provider.family<LibraryGame?, int>((ref, gameId) {
  ref.watch(libraryControllerProvider);
  ref.watch(collectionsControllerProvider);
  return resolveGameSeed(ref, gameId);
});

final gameDetailProvider = FutureProvider.family<GameDetail, int>((ref, gameId) async {
  // Read-only seed: do not refetch HTML when library/collections sync in background.
  final seed = resolveGameSeedForFetch(ref, gameId);
  final webUrl = await ref.read(gameUrlResolverProvider).resolve(
    gameId: gameId,
    seed: seed,
  );
  final detail = await ref.read(gamePageFetcherProvider).fetch(
    webUrl: webUrl,
    seed: seed,
  );
  ref.read(gameUrlResolverProvider).remember(gameId, detail.webUrl);
  return detail;
});

final gameDetailByUrlProvider = FutureProvider.family<GameDetail, String>((ref, webUrl) async {
  final detail = await ref.read(gamePageFetcherProvider).fetch(webUrl: webUrl);
  if (detail.id > 0) {
    ref.read(gameUrlResolverProvider).remember(detail.id, detail.webUrl);
  }
  return detail;
});

final gameOwnedProvider = FutureProvider.family<bool, int>((ref, gameId) async {
  if (gameId <= 0) {
    return false;
  }
  final seed = resolveGameSeed(ref, gameId);
  if (seed != null) {
    return true;
  }
  final token = await ref.read(authControllerProvider.notifier).readApiKey();
  if (token == null || token.isEmpty) {
    return false;
  }
  return ref.read(itchApiClientProvider).checkGameOwnership(token: token, gameId: gameId);
});
