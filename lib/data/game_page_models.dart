import 'game_page_theme.dart';

/// Ссылка в блоке «Больше информации».
class GameInfoLink {
  const GameInfoLink({required this.text, required this.url});

  final String text;
  final String url;
}

/// Строка панели «Больше информации» (значение может быть ссылками).
class GameInfoEntry {
  const GameInfoEntry({
    required this.label,
    this.plainText = '',
    this.links = const [],
    this.ratingAverage,
    this.ratingCount,
  });

  final String label;
  final String plainText;
  final List<GameInfoLink> links;
  final double? ratingAverage;
  final int? ratingCount;

  bool get isRating => ratingAverage != null;
}

/// Промо-карточка из секции «Also check out».
class GamePromoCard {
  const GamePromoCard({
    required this.title,
    required this.webUrl,
    this.author,
    this.authorUrl,
    this.summary,
    this.coverUrl,
    this.platforms = const [],
    this.embedId,
  });

  final String title;
  final String webUrl;
  final String? author;
  final String? authorUrl;
  final String? summary;
  final String? coverUrl;
  final List<String> platforms;
  /// ID из `https://itch.io/embed/{id}` — для подгрузки обложки и метаданных.
  final int? embedId;
}

/// Медиа для карусели (скриншот / gif / обложка).
class GameMediaItem {
  const GameMediaItem({
    required this.url,
    this.isAnimated = false,
  });

  final String url;
  final bool isAnimated;
}

/// Полная карточка игры с itch.io (HTML + seed из API).
class GameDetail {
  const GameDetail({
    required this.id,
    required this.title,
    required this.webUrl,
    this.iconUrl,
    this.coverUrl,
    this.heroImageUrl,
    this.headerCoverUrl,
    this.theme,
    this.shortText = '',
    this.description = '',
    this.descriptionHtml = '',
    this.descriptionFooterHtml = '',
    this.relatedGames = const [],
    this.infoEntries = const [],
    this.classification = 'game',
    this.platforms = const [],
    this.screenshots = const [],
    this.developerName,
    this.developerUrl,
    this.ratingAverage,
    this.ratingCount,
    this.infoRows = const {},
    this.tags = const [],
    this.statusLabel,
    this.updatedLabel,
    this.publishedLabel,
    this.minPriceCents,
    this.isFree = true,
    this.priceLabel,
  });

  final int id;
  final String title;
  final String webUrl;
  /// Favicon / `rel=icon` со страницы (32×32+).
  final String? iconUrl;
  final String? coverUrl;
  /// Верхняя обложка (`#header img`), не фон `.wrapper`.
  final String? headerCoverUrl;
  /// То же, что [headerCoverUrl] (совместимость).
  final String? heroImageUrl;
  final GamePageTheme? theme;
  final String shortText;
  final String description;
  /// HTML из `formatted_description` (картинки, ссылки, embed itch).
  final String descriptionHtml;
  /// Текст после «Also check out» (кредиты, примечания).
  final String descriptionFooterHtml;
  /// Секция «Also check out».
  final List<GamePromoCard> relatedGames;
  /// Панель «Больше информации» со ссылками.
  final List<GameInfoEntry> infoEntries;
  final String classification;
  final List<String> platforms;
  final List<GameMediaItem> screenshots;
  final String? developerName;
  final String? developerUrl;
  final double? ratingAverage;
  final int? ratingCount;
  final Map<String, String> infoRows;
  final List<String> tags;
  final String? statusLabel;
  final String? updatedLabel;
  final String? publishedLabel;
  final int? minPriceCents;
  final bool isFree;
  final String? priceLabel;

  List<GameMediaItem> get carouselMedia {
    if (screenshots.isNotEmpty) {
      return screenshots;
    }
    final cover = coverUrl ?? heroImageUrl;
    if (cover != null && cover.isNotEmpty) {
      return [GameMediaItem(url: cover)];
    }
    return const [];
  }
}
