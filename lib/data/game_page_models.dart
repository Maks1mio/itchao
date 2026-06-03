import 'game_page_theme.dart';

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
