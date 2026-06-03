import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';

/// Кэш метаданных игр из API (библиотека, коллекции) для открытия `itch://games/:id`.
final gameCatalogCacheProvider =
    NotifierProvider<GameCatalogCache, Map<int, LibraryGame>>(GameCatalogCache.new);

class GameCatalogCache extends Notifier<Map<int, LibraryGame>> {
  @override
  Map<int, LibraryGame> build() => const {};

  void putAll(Iterable<LibraryGame> games) {
    if (games.isEmpty) {
      return;
    }
    final next = Map<int, LibraryGame>.from(state);
    var changed = false;
    for (final game in games) {
      if (game.id <= 0) {
        continue;
      }
      final existing = next[game.id];
      if (existing == null || _shouldReplace(existing, game)) {
        next[game.id] = game;
        changed = true;
      }
    }
    if (changed) {
      state = next;
    }
  }

  bool _shouldReplace(LibraryGame existing, LibraryGame incoming) {
    if (incoming.url != null && incoming.url!.isNotEmpty && (existing.url == null || existing.url!.isEmpty)) {
      return true;
    }
    return false;
  }
}
