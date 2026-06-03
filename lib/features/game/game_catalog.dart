import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_web_url.dart';
import '../../data/models.dart';
import '../collections/collections_controller.dart';
import '../library/library_controller.dart';

/// Ищет игру по id в кэше библиотеки и коллекций (данные API).
LibraryGame? findLibraryGameById(Ref ref, int gameId) {
  if (gameId <= 0) {
    return null;
  }
  final library = ref.read(libraryControllerProvider).valueOrNull;
  if (library != null) {
    for (final game in library) {
      if (game.id == gameId) {
        return game;
      }
    }
  }
  final collections = ref.read(collectionsControllerProvider).valueOrNull;
  if (collections != null) {
    final notifier = ref.read(collectionsControllerProvider.notifier);
    for (final entry in collections.items) {
      final cached = notifier.cachedGamesFor(entry.collection.id);
      if (cached == null) {
        continue;
      }
      for (final game in cached) {
        if (game.id == gameId) {
          return game;
        }
      }
    }
  }
  return null;
}

String? gameWebUrl(LibraryGame game) {
  return GameWebUrl.pick(game.url, null);
}
