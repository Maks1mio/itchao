import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_page_fetcher.dart';
import '../../data/game_url_resolver.dart';
import '../../data/models.dart';
import '../auth/auth_controller.dart';
import '../collections/collections_controller.dart';
import '../library/library_controller.dart';
import 'game_catalog.dart';

final gamePageFetcherProvider = Provider<GamePageFetcher>((ref) {
  final fetcher = GamePageFetcher();
  ref.onDispose(fetcher.dispose);
  return fetcher;
});

final gameSeedProvider = Provider.family<LibraryGame?, int>((ref, gameId) {
  ref.watch(libraryControllerProvider);
  ref.watch(collectionsControllerProvider);
  return findLibraryGameById(ref, gameId);
});

final gameDetailProvider = FutureProvider.family<GameDetail, int>((ref, gameId) async {
  ref.watch(libraryControllerProvider);
  ref.watch(collectionsControllerProvider);
  final seed = findLibraryGameById(ref, gameId);
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

final gameOwnedProvider = FutureProvider.family<bool, int>((ref, gameId) async {
  if (gameId <= 0) {
    return false;
  }
  final seed = findLibraryGameById(ref, gameId);
  if (seed != null) {
    return true;
  }
  final token = await ref.read(authControllerProvider.notifier).readApiKey();
  if (token == null || token.isEmpty) {
    return false;
  }
  return ref.read(itchApiClientProvider).checkGameOwnership(token: token, gameId: gameId);
});
