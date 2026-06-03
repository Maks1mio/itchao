import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/repositories/library_repository.dart';
import '../auth/auth_controller.dart';
import '../game/game_catalog_cache.dart';
import '../install/installed_games_controller.dart';

final libraryControllerProvider =
    AsyncNotifierProvider<LibraryController, List<LibraryGame>>(
      LibraryController.new,
    );

class LibraryController extends AsyncNotifier<List<LibraryGame>> {
  @override
  Future<List<LibraryGame>> build() async {
    ref.watch(installedGamesProvider);
    final apiKey = await ref.read(authControllerProvider.notifier).readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return const [];
    }
    final repository = LibraryRepository(ref.read(itchApiClientProvider));
    final games = await repository.fetchLibrary(apiKey);
    final installed = ref.read(installedGamesProvider);
    final merged = games
        .map(
          (g) => installed.containsKey(g.id)
              ? LibraryGame(
                  id: g.id,
                  title: g.title,
                  coverUrl: g.coverUrl,
                  installed: true,
                  shortText: g.shortText,
                  url: g.url,
                  classification: g.classification,
                  platforms: g.platforms,
                )
              : g,
        )
        .toList();
    ref.read(gameCatalogCacheProvider.notifier).putAll(merged);
    return merged;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  List<LibraryGame> currentValue() {
    return state.value ?? const [];
  }
}
