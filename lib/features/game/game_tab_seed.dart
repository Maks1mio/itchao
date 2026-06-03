import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_web_url.dart';
import '../../data/models.dart';
import '../tabs/tabs_controller.dart';
import 'game_catalog.dart';

/// Минимальные данные игры из активной вкладки `itch://games/:id?url=…` (как передаёт карточка).
LibraryGame? seedFromActiveGameTab(Ref ref, int gameId) {
  if (gameId <= 0) {
    return null;
  }
  final tabUrl = ref.watch(
    tabsControllerProvider.select((async) => async.asData?.value.activeTab?.url),
  );
  if (tabUrl == null || tabUrl.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(tabUrl);
  if (uri == null || uri.scheme != 'itch' || uri.host != 'games') {
    return null;
  }
  final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
  if (int.tryParse(segment ?? '') != gameId) {
    return null;
  }

  final storeUrl = uri.queryParameters['url'];
  if (!GameWebUrl.isValid(storeUrl)) {
    return null;
  }

  final label = uri.queryParameters['label'];
  final cover = uri.queryParameters['cover'];
  return LibraryGame(
    id: gameId,
    title: label != null && label.isNotEmpty ? Uri.decodeComponent(label) : 'Игра',
    url: storeUrl!.trim(),
    coverUrl: cover != null && cover.isNotEmpty ? Uri.decodeComponent(cover) : null,
    installed: false,
  );
}

/// Игра из кэша API, вкладки или библиотеки/коллекций.
LibraryGame? resolveGameSeed(Ref ref, int gameId) {
  return findLibraryGameById(ref, gameId) ?? seedFromActiveGameTab(ref, gameId);
}
