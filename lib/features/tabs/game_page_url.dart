import '../../data/models.dart';

/// URL страницы игры на itch.io для открытия во вкладке.
String itchGamePageUrl(LibraryGame game) {
  final url = game.url?.trim();
  if (url != null && url.isNotEmpty) {
    return url;
  }
  return 'https://itch.io/game/${game.id}';
}
