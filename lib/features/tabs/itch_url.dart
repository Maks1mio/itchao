class ItchUrl {
  const ItchUrl({
    required this.page,
    this.segment,
    this.externalUrl,
  });

  final String page;
  final String? segment;
  final String? externalUrl;

  bool get isExternal => externalUrl != null;

  factory ItchUrl.parse(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return ItchUrl(page: 'browser', externalUrl: url);
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return ItchUrl(page: 'browser', externalUrl: url);
    }
    if (uri.scheme != 'itch') {
      return ItchUrl(page: 'browser', externalUrl: url);
    }
    final page = uri.host.isNotEmpty ? uri.host : (uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'new-tab');
    final segment = uri.pathSegments.isNotEmpty && uri.host.isNotEmpty ? uri.pathSegments.first : null;
    return ItchUrl(page: page, segment: segment);
  }

  static String labelFor(String url) {
    final parsed = ItchUrl.parse(url);
    if (parsed.isExternal) {
      return 'Браузер';
    }
    switch (parsed.page) {
      case 'new-tab':
        return 'Новая вкладка';
      case 'featured':
        return 'Обзор';
      case 'library':
        return parsed.segment == 'installed' ? 'Установленные' : 'Игротека';
      case 'collections':
        return parsed.segment != null ? 'Коллекция' : 'Коллекции';
      case 'dashboard':
        return 'Мои творения';
      case 'upload':
        return 'Публикация';
      case 'downloads':
        return 'Скачивания';
      case 'preferences':
        return 'Настройки';
      case 'history':
        return 'История';
      default:
        return parsed.page;
    }
  }
}
