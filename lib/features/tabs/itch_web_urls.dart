import 'itch_url.dart';

String itchUrlToWebUrl(String url) {
  final parsed = ItchUrl.parse(url);
  if (parsed.isExternal && parsed.externalUrl != null) {
    return parsed.externalUrl!;
  }
  switch (parsed.page) {
    case 'featured':
      return 'https://itch.io/games';
    case 'library':
      return 'https://itch.io/';
    case 'collections':
      return 'https://itch.io/my-collections';
    case 'dashboard':
      return 'https://itch.io/dashboard';
    case 'upload':
      return 'https://itch.io/dashboard';
    case 'new-tab':
      return 'https://itch.io/games';
    default:
      if (url.startsWith('http')) {
        return url;
      }
      return 'https://itch.io/games';
  }
}
