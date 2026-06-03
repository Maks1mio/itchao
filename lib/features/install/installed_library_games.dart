import '../../data/game_web_url.dart';
import '../../data/install_models.dart';
import '../../data/models.dart';

/// Builds library cards for the «Установленные» stripe from device records.
List<LibraryGame> buildInstalledLibraryGames({
  required Map<int, InstalledGameRecord> installed,
  required List<LibraryGame> library,
}) {
  final libraryById = {for (final g in library) g.id: g};
  final games = <LibraryGame>[];

  for (final record in installed.values) {
    if (record.gameId <= 0 || record.packageName.isEmpty) {
      continue;
    }
    final lib = libraryById[record.gameId];
    games.add(
      LibraryGame(
        id: record.gameId,
        title: lib?.title ?? record.title,
        coverUrl: lib?.coverUrl ?? record.coverUrl,
        installed: true,
        shortText: lib?.shortText,
        url: GameWebUrl.pick(lib?.url, record.storeUrl),
        classification: lib?.classification ?? 'game',
        platforms: lib?.platforms ?? const [],
      ),
    );
  }

  games.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return games;
}
