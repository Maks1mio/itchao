import 'package:flutter/material.dart';

import 'game_page_models.dart';
import 'game_page_theme.dart';
import 'game_web_url.dart';
import 'itch_image_urls.dart';
import 'models.dart';

/// Парсинг HTML страницы игры itch.io (эталоны в `Sites/*.html`).
class ItchGamePageParser {
  const ItchGamePageParser();

  static final _metaTag = RegExp(
    r'<meta\s+(?:[^>]*?\s)?(?:property|name)\s*=\s*["\x27]([^"\x27]+)["\x27](?:[^>]*?\s)?content\s*=\s*["\x27]([^"\x27]*)["\x27]|'
    r'<meta\s+(?:[^>]*?\s)?content\s*=\s*["\x27]([^"\x27]*)["\x27](?:[^>]*?\s)?(?:property|name)\s*=\s*["\x27]([^"\x27]+)["\x27]',
    caseSensitive: false,
  );
  static final _formattedDescriptionStart = RegExp(
    r'class="formatted_description[^"]*"[^>]*>',
    caseSensitive: false,
  );
  static final _moreInformationBlock = RegExp(
    r'<div class="more_information(?:_toggle)?',
    caseSensitive: false,
  );
  static final _dataGameJson = RegExp(r'data-game="(\{[^"]+\})"');
  static final _titleTag = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false);
  static final _h1GameTitle = RegExp(
    r'<h1[^>]*class="[^"]*game_title[^"]*"[^>]*>([\s\S]*?)</h1>',
    caseSensitive: false,
  );
  static final _relIcon = RegExp(
    r'<link[^>]+rel=["\x27]icon["\x27][^>]*(?:href|content)=["\x27]([^"\x27]+)["\x27]|'
    r'<link[^>]+(?:href|content)=["\x27]([^"\x27]+)["\x27][^>]+rel=["\x27]icon["\x27]',
    caseSensitive: false,
  );
  static final _screenshotSrcset = RegExp(
    r'class="screenshot"[^>]*srcset="([^"]+)"',
    caseSensitive: false,
  );
  static final _lightboxImg = RegExp(
    r'data-image_lightbox[^>]*(?:src|data-src)=["\x27]([^"\x27]+)["\x27]',
    caseSensitive: false,
  );
  static final _infoPanel = RegExp(
    r'game_info_panel_widget[\s\S]{0,8000}?<table><tbody>([\s\S]*?)</tbody>',
    caseSensitive: false,
  );
  static final _infoRow = RegExp(
    r'<tr><td>([^<]+)</td><td>([\s\S]*?)</td></tr>',
    caseSensitive: false,
  );
  static final _ratingValue = RegExp(
    r'itemprop="ratingValue"[^>]*content="([0-9.]+)"',
    caseSensitive: false,
  );
  static final _ratingTooltip = RegExp(
    r'data-tooltip="([0-9.]+)\s+average rating from\s+([0-9,]+)\s+total ratings"',
    caseSensitive: false,
  );
  static final _tagLink = RegExp(
    r'href="https://itch\.io/games/(?:tag-|genre-)([^"/?]+)',
    caseSensitive: false,
  );
  static final _themeBlock = RegExp(
    r'id="game_theme"[^>]*>([\s\S]*?)</style>',
    caseSensitive: false,
  );
  static final _headerCoverImg = RegExp(
    r'id="header"[^>]*>\s*<img[^>]*src="([^"]+)"',
    caseSensitive: false,
  );
  static final _headerCoverAlt = RegExp(
    r'<img[^>]*src="([^"]+)"[^>]*alt="([^"]+)"',
    caseSensitive: false,
  );
  static final _canonicalLink = RegExp(
    r'<link[^>]+rel=["\x27]canonical["\x27][^>]*href=["\x27]([^"\x27]+)["\x27]|'
    r'<link[^>]+href=["\x27]([^"\x27]+)["\x27][^>]+rel=["\x27]canonical["\x27]',
    caseSensitive: false,
  );

  GameDetail parse(
    String html, {
    required String webUrl,
    LibraryGame? seed,
  }) {
    final meta = _parseMeta(html);
    final resolvedWebUrl = _parseCanonicalUrl(html, webUrl);
    final id = _parseId(html, meta, seed);
    final title = _parseTitle(html, meta, seed);
    final shortText = _parseShortText(meta, seed);
    final desc = _parseDescription(html);
    final coverRaw = _firstNonEmpty([
      _metaValue(meta, 'og:image'),
      _metaValue(meta, 'twitter:image'),
      seed?.coverUrl,
    ]);
    final coverUrl = ItchImageUrls.toOriginal(coverRaw);
    final iconUrl = _parseIcon(html, coverUrl);
    final screenshots = _parseScreenshots(html);
    final headerCoverUrl = _parseHeaderCover(html, title, coverUrl);
    final theme = _parseTheme(html);
    final developer = _parseDeveloper(html, meta, title, resolvedWebUrl);
    final rating = _parseRating(html);
    final infoRows = _parseInfoPanel(html);
    final platforms = _parsePlatforms(html, infoRows, seed);
    final tags = _parseTags(html, infoRows);
    final statusLabel = infoRows['Состояние'] ?? infoRows['Status'];
    final updatedLabel = infoRows['Обновлено'] ?? infoRows['Updated'];
    final publishedLabel = infoRows['Опубликовано'] ?? infoRows['Published'];

    final parsed = GameDetail(
      id: id,
      title: title,
      webUrl: resolvedWebUrl,
      iconUrl: iconUrl,
      coverUrl: coverUrl,
      headerCoverUrl: headerCoverUrl,
      heroImageUrl: headerCoverUrl,
      theme: theme,
      shortText: shortText,
      description: desc.plain,
      descriptionHtml: desc.html,
      classification: seed?.classification ?? 'game',
      platforms: platforms,
      screenshots: screenshots,
      developerName: developer.$1,
      developerUrl: developer.$2,
      ratingAverage: rating.$1,
      ratingCount: rating.$2,
      infoRows: infoRows,
      tags: tags,
      statusLabel: statusLabel,
      publishedLabel: publishedLabel,
      updatedLabel: updatedLabel,
      isFree: true,
    );
    return _mergeWithSeed(parsed, seed, resolvedWebUrl);
  }

  String _parseCanonicalUrl(String html, String fallback) {
    final match = _canonicalLink.firstMatch(html);
    final href = match?.group(1) ?? match?.group(2);
    return GameWebUrl.pick(href, fallback) ?? fallback;
  }

  Map<String, String> _parseMeta(String html) {
    final meta = <String, String>{};
    for (final match in _metaTag.allMatches(html)) {
      final g1 = match.group(1) ?? '';
      final g2 = match.group(2) ?? '';
      final g3 = match.group(3);
      final g4 = match.group(4);
      if (g3 != null && g4 != null) {
        meta[g4.toLowerCase()] = _decodeHtml(g3);
      } else {
        meta[g1.toLowerCase()] = _decodeHtml(g2);
      }
    }
    return meta;
  }

  int _parseId(String html, Map<String, String> meta, LibraryGame? seed) {
    var id = seed?.id ?? 0;
    final itchPath = meta['itch:path'] ?? '';
    final pathMatch = RegExp(r'games/(\d+)').firstMatch(itchPath);
    if (pathMatch != null) {
      id = int.tryParse(pathMatch.group(1) ?? '') ?? id;
    }
    final dataGameMatch = _dataGameJson.firstMatch(html);
    if (dataGameMatch != null) {
      final raw = _decodeHtml(dataGameMatch.group(1) ?? '');
      final idMatch = RegExp(r'"id"\s*:\s*(\d+)').firstMatch(raw);
      if (idMatch != null) {
        id = int.tryParse(idMatch.group(1) ?? '') ?? id;
      }
    }
    return id;
  }

  String _parseTitle(String html, Map<String, String> meta, LibraryGame? seed) {
    final raw = _firstNonEmpty([
      _metaValue(meta, 'og:title'),
      _metaValue(meta, 'twitter:title'),
      _stripHtml(_titleTag.firstMatch(html)?.group(1) ?? ''),
      _stripHtml(_h1GameTitle.firstMatch(html)?.group(1) ?? ''),
      seed?.title,
    ]);
    if (raw == null) {
      return 'Игра';
    }
    final byIdx = raw.toLowerCase().lastIndexOf(' by ');
    if (byIdx > 0) {
      return raw.substring(0, byIdx).trim();
    }
    return raw;
  }

  String _parseShortText(Map<String, String> meta, LibraryGame? seed) {
    return _firstNonEmpty([
      _metaValue(meta, 'og:description'),
      _metaValue(meta, 'description'),
      _metaValue(meta, 'twitter:description'),
      seed?.shortText,
    ]) ?? '';
  }

  ({String html, String plain}) _parseDescription(String pageHtml) {
    final inner = _extractFormattedDescription(pageHtml);
    if (inner == null || inner.isEmpty) {
      return (html: '', plain: '');
    }
    final normalized = _normalizeDescriptionHtml(inner, pageHtml);
    return (html: normalized, plain: _stripHtml(normalized));
  }

  String? _extractFormattedDescription(String pageHtml) {
    final start = _formattedDescriptionStart.firstMatch(pageHtml);
    if (start == null) {
      return null;
    }
    final contentStart = start.end;
    final end = _moreInformationBlock.firstMatch(pageHtml.substring(contentStart));
    final endIndex = end != null ? contentStart + end.start : -1;
    if (endIndex < 0) {
      return null;
    }
    var chunk = pageHtml.substring(contentStart, endIndex).trim();
    chunk = chunk.replaceFirst(RegExp(r'</div>\s*$', caseSensitive: false), '').trim();
    return chunk;
  }

  String _normalizeDescriptionHtml(String html, String pageHtml) {
    var result = html;
    // Подставляем https-URL из остальной страницы (в т.ч. из meta/скриншотов).
    result = result.replaceAllMapped(
      RegExp(r'src="(https://img\.itch\.zone/[^"]+)"', caseSensitive: false),
      (m) => 'src="${ItchImageUrls.toOriginal(m.group(1)) ?? m.group(1)}"',
    );
    result = result.replaceAll('&amp;', '&');
    result = result.replaceAllMapped(
      RegExp(r'src="\./?[^"]*_files/([^"?]+)"', caseSensitive: false),
      (m) {
        final file = m.group(1)!;
        final resolved = _resolveItchImageFile(pageHtml, file);
        if (resolved != null) {
          return 'src="$resolved"';
        }
        return m.group(0)!;
      },
    );
    result = result.replaceAllMapped(
      RegExp(
        r'<iframe([^>]*)src="\./?[^"]*_files/(\d+)\.html"([^>]*)>',
        caseSensitive: false,
      ),
      (m) {
        final id = m.group(2)!;
        final embed =
            'https://itch.io/embed/$id?border_width=4&bg_color=0d0a13&fg_color=fcfcf7&link_color=fea339&border_color=7c3255';
        return '<iframe${m.group(1) ?? ''}src="$embed"${m.group(3) ?? ''}>';
      },
    );
    result = _stripDescriptionImageDimensions(result);
    result = _collapseDescriptionWhitespace(result);
    return result;
  }

  /// Убирает itch-embed в описании (на мобилке даёт пустой блок).
  String _collapseDescriptionWhitespace(String html) {
    return html.replaceAll(
      RegExp(
        r'<iframe[^>]*src="[^"]*itch\.io/embed/[^"]*"[^>]*>\s*</iframe>',
        caseSensitive: false,
      ),
      '',
    );
  }

  /// Убираем фиксированные размеры с `<img>` — на мобилке иначе не тянутся на 100%.
  String _stripDescriptionImageDimensions(String html) {
    return html.replaceAllMapped(
      RegExp(r'<img\b([^>]*)/?>', caseSensitive: false),
      (match) {
        var attrs = match.group(1) ?? '';
        attrs = attrs.replaceAll(
          RegExp(
            r'''\s(?:width|height)\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)''',
            caseSensitive: false,
          ),
          '',
        );
        attrs = attrs.replaceAllMapped(
          RegExp(r'''\sstyle\s*=\s*("([^"]*)"|'([^']*)')''', caseSensitive: false),
          (styleMatch) {
            var style = styleMatch.group(2) ?? styleMatch.group(3) ?? '';
            style = style.replaceAll(
              RegExp(r'(?:max-)?width\s*:\s*[^;]+;?', caseSensitive: false),
              '',
            );
            style = style.replaceAll(
              RegExp(r'height\s*:\s*[^;]+;?', caseSensitive: false),
              '',
            );
            style = style.trim();
            if (style.isEmpty) {
              return '';
            }
            return ' style="$style"';
          },
        );
        return '<img$attrs>';
      },
    );
  }

  String? _resolveItchImageFile(String pageHtml, String filename) {
    if (pageHtml.contains('https://img.itch.zone') && pageHtml.contains(filename)) {
      final direct = RegExp(
        'https://img\\.itch\\.zone/[^"\\s)>]*${RegExp.escape(filename)}',
        caseSensitive: false,
      ).firstMatch(pageHtml);
      if (direct != null) {
        return ItchImageUrls.toOriginal(direct.group(0));
      }
    }
    final stem = filename.replaceAll(RegExp(r'\.(png|gif|jpg|jpeg|webp)$', caseSensitive: false), '');
    final encodedStem = Uri.encodeComponent(stem);
    final matches = RegExp(
      r'https://img\.itch\.zone/[^"\s)>]+',
      caseSensitive: false,
    ).allMatches(pageHtml);
    for (final m in matches) {
      final url = m.group(0)!;
      if (url.contains(stem) ||
          url.contains(encodedStem) ||
          url.contains(filename) ||
          url.endsWith('/$stem.png') ||
          url.endsWith('/$stem.gif')) {
        return ItchImageUrls.toOriginal(url);
      }
    }
    return null;
  }

  String? _parseHeaderCover(String html, String title, String? coverUrl) {
    var foundHeaderTag = false;

    final header = _headerCoverImg.firstMatch(html);
    if (header != null) {
      foundHeaderTag = true;
      final resolved = _resolveImgSrc(html, header.group(1)!);
      if (resolved != null) {
        return resolved;
      }
    }
    for (final match in _headerCoverAlt.allMatches(html)) {
      final alt = match.group(2) ?? '';
      if (title.isNotEmpty &&
          alt.toLowerCase().contains(title.toLowerCase().substring(0, title.length.clamp(0, 8)))) {
        foundHeaderTag = true;
        final resolved = _resolveImgSrc(html, match.group(1)!);
        if (resolved != null) {
          return resolved;
        }
      }
    }

    // Не подменяем баннер og:image, если на странице есть `#header img`.
    if (foundHeaderTag) {
      return null;
    }
    return coverUrl;
  }

  String? _resolveImgSrc(String pageHtml, String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('http')) {
      return ItchImageUrls.toOriginal(trimmed);
    }
    final file = RegExp(r'([^/]+)$').firstMatch(trimmed)?.group(1);
    if (file != null) {
      return _resolveItchImageFile(pageHtml, file);
    }
    return null;
  }

  GamePageTheme? _parseTheme(String html) {
    final block = _themeBlock.firstMatch(html)?.group(1);
    if (block == null || block.isEmpty) {
      return null;
    }

    String? css(String name) {
      final m = RegExp(
        '$name\\s*:\\s*([^;}+]+)',
        caseSensitive: false,
      ).firstMatch(block);
      return m?.group(1)?.trim();
    }

    String? cssVar(String name) {
      final m = RegExp(
        RegExp.escape(name) + r'\s*:\s*([^;}+]+)',
        caseSensitive: false,
      ).firstMatch(block);
      return m?.group(1)?.trim();
    }

    final bgImage = RegExp(
      r'\.wrapper\s*\{[^}]*background-image:\s*url\((https://img\.itch\.zone/[^)]+)\)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(block)?.group(1) ??
        RegExp(
          r'background-image:\s*url\((https://img\.itch\.zone/[^)]+)\)',
          caseSensitive: false,
        ).firstMatch(block)?.group(1);

    return GamePageTheme(
      fontFamily: _cleanQuotes(cssVar('--itchio_font_family') ?? css('font-family')),
      backgroundColor: _parseCssColor(
        cssVar('--itchio_bg_color') ?? css('background-color'),
      ),
      backgroundImageUrl: ItchImageUrls.toOriginal(bgImage),
      innerColumnColor: _parseCssColor(cssVar('--itchio_bg2_color')),
      textColor: _parseCssColor(cssVar('--itchio_text_color')),
      linkColor: _parseCssColor(cssVar('--itchio_link_color')),
      buttonColor: _parseCssColor(cssVar('--itchio_button_color')),
      buttonForegroundColor: _parseCssColor(cssVar('--itchio_button_fg_color')),
      borderColor: _parseCssColor(cssVar('--itchio_border_color')),
    );
  }

  String? _cleanQuotes(String? value) {
    if (value == null) {
      return null;
    }
    return value.replaceAll("'", '').replaceAll('"', '').trim();
  }

  Color? _parseCssColor(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final value = raw.trim();
    if (value.startsWith('#')) {
      var hex = value.substring(1);
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) {
        return Color(parsed);
      }
    }
    final rgba = RegExp(r'rgba?\(([^)]+)\)', caseSensitive: false).firstMatch(value);
    if (rgba != null) {
      final parts = rgba.group(1)!.split(',').map((p) => p.trim()).toList();
      if (parts.length >= 3) {
        final r = double.parse(parts[0]);
        final g = double.parse(parts[1]);
        final b = double.parse(parts[2]);
        final a = parts.length > 3 ? double.parse(parts[3]) : 1.0;
        return Color.fromRGBO(
          r.round().clamp(0, 255),
          g.round().clamp(0, 255),
          b.round().clamp(0, 255),
          a.clamp(0.0, 1.0),
        );
      }
    }
    return null;
  }

  String? _parseIcon(String html, String? coverUrl) {
    return ItchImageUrls.toOriginal(coverUrl) ??
        ItchImageUrls.toOriginal(
          _firstNonEmpty([
            for (final match in _relIcon.allMatches(html))
              _firstNonEmpty([match.group(1), match.group(2)]),
          ]),
        );
  }

  List<GameMediaItem> _parseScreenshots(String html) {
    final urls = <String>[];
    final seen = <String>{};

    void addUrl(String? raw) {
      if (raw == null || raw.isEmpty) {
        return;
      }
      final url = raw.startsWith('http') ? raw : null;
      if (url == null || !url.contains('img.itch.zone')) {
        return;
      }
      final normalized = _normalizeItchAssetUrl(url);
      if (seen.add(normalized)) {
        urls.add(normalized);
      }
    }

    for (final match in _screenshotSrcset.allMatches(html)) {
      addUrl(_bestUrlFromSrcset(match.group(1) ?? ''));
    }
    for (final match in _lightboxImg.allMatches(html)) {
      addUrl(match.group(1));
    }

    return [
      for (final url in urls)
        GameMediaItem(url: url, isAnimated: url.toLowerCase().endsWith('.gif')),
    ];
  }

  (String?, String?) _parseDeveloper(
    String html,
    Map<String, String> meta,
    String title,
    String webUrl,
  ) {
    final authorLink = RegExp(
      r'class="[^"]*(?:game_author|user_name)[^"]*"[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a>',
      caseSensitive: false,
    ).firstMatch(html);
    if (authorLink != null) {
      final name = _stripHtml(authorLink.group(2) ?? '');
      if (name.isNotEmpty) {
        return (name, authorLink.group(1));
      }
    }

    final twitterTitle = _metaValue(meta, 'twitter:title') ?? '';
    final byMatch = RegExp(r' by (.+)$', caseSensitive: false).firstMatch(twitterTitle);
    if (byMatch != null) {
      final dev = byMatch.group(1)!.trim();
      final uri = Uri.tryParse(webUrl);
      if (uri != null && uri.host.endsWith('.itch.io')) {
        return (dev, 'https://${uri.host}');
      }
      final rss = RegExp(
        r'href="(https://[^/]+\.itch\.io/[^/]+)/devlog',
        caseSensitive: false,
      ).firstMatch(html);
      if (rss != null) {
        return (dev, rss.group(1));
      }
      return (dev, null);
    }
    return (null, null);
  }

  (double?, int?) _parseRating(String html) {
    final tooltip = _ratingTooltip.firstMatch(html);
    if (tooltip != null) {
      final avg = double.tryParse(tooltip.group(1) ?? '');
      final count = int.tryParse((tooltip.group(2) ?? '').replaceAll(',', ''));
      return (avg, count);
    }
    final value = _ratingValue.firstMatch(html);
    if (value != null) {
      return (double.tryParse(value.group(1) ?? ''), null);
    }
    return (null, null);
  }

  Map<String, String> _parseInfoPanel(String html) {
    final panel = _infoPanel.firstMatch(html);
    if (panel == null) {
      return {};
    }
    final rows = <String, String>{};
    for (final row in _infoRow.allMatches(panel.group(1)!)) {
      final key = _stripHtml(row.group(1) ?? '');
      final value = _stripHtml(row.group(2) ?? '');
      if (key.isNotEmpty && value.isNotEmpty) {
        rows[key] = value;
      }
    }
    return rows;
  }

  List<String> _parsePlatforms(
    String html,
    Map<String, String> infoRows,
    LibraryGame? seed,
  ) {
    final platforms = <String>{...?seed?.platforms};
    final panelPlatforms = infoRows['Платформы'] ?? infoRows['Platforms'] ?? '';
    final lower = panelPlatforms.toLowerCase();
    if (lower.contains('windows')) {
      platforms.add('windows');
    }
    if (lower.contains('mac') || lower.contains('osx')) {
      platforms.add('osx');
    }
    if (lower.contains('linux')) {
      platforms.add('linux');
    }
    if (lower.contains('android')) {
      platforms.add('android');
    }
    if (lower.contains('html5')) {
      platforms.add('html5');
    }
    if (html.contains('icon-windows')) {
      platforms.add('windows');
    }
    if (html.contains('icon-apple')) {
      platforms.add('osx');
    }
    if (html.contains('icon-tux')) {
      platforms.add('linux');
    }
    if (html.contains('icon-android')) {
      platforms.add('android');
    }
    return platforms.toList();
  }

  List<String> _parseTags(String html, Map<String, String> infoRows) {
    final tags = <String>{};
    final genres = infoRows['Жанр'] ?? infoRows['Жанры'] ?? infoRows['Genres'] ?? '';
    if (genres.isNotEmpty) {
      for (final part in genres.split(RegExp(r'[,;]'))) {
        final t = part.trim();
        if (t.isNotEmpty) {
          tags.add(t);
        }
      }
    }
    for (final m in _tagLink.allMatches(html)) {
      final slug = m.group(1)?.replaceAll('-', ' ').trim();
      if (slug != null && slug.isNotEmpty) {
        tags.add(slug);
      }
    }
    return tags.take(12).toList();
  }

  GameDetail _mergeWithSeed(GameDetail parsed, LibraryGame? seed, String webUrl) {
    if (seed == null) {
      return parsed;
    }
    return GameDetail(
      id: parsed.id > 0 ? parsed.id : seed.id,
      title: _firstNonEmpty([parsed.title, seed.title]) ?? seed.title,
      webUrl: webUrl,
      shortText: _firstNonEmpty([parsed.shortText, seed.shortText]) ?? '',
      description: parsed.description,
      descriptionHtml: parsed.descriptionHtml,
      iconUrl: ItchImageUrls.toOriginal(_firstNonEmpty([parsed.iconUrl, seed.coverUrl])),
      coverUrl: ItchImageUrls.toOriginal(_firstNonEmpty([parsed.coverUrl, seed.coverUrl])),
      headerCoverUrl: _firstNonEmpty([
        parsed.headerCoverUrl,
        parsed.coverUrl,
        ItchImageUrls.toOriginal(seed.coverUrl),
      ]),
      heroImageUrl: _firstNonEmpty([
        parsed.headerCoverUrl,
        parsed.coverUrl,
        ItchImageUrls.toOriginal(seed.coverUrl),
      ]),
      theme: parsed.theme,
      classification: seed.classification,
      platforms: parsed.platforms.isNotEmpty ? parsed.platforms : seed.platforms,
      screenshots: parsed.screenshots,
      developerName: parsed.developerName,
      developerUrl: parsed.developerUrl,
      ratingAverage: parsed.ratingAverage,
      ratingCount: parsed.ratingCount,
      infoRows: parsed.infoRows,
      tags: parsed.tags,
      statusLabel: parsed.statusLabel,
      updatedLabel: parsed.updatedLabel,
      publishedLabel: parsed.publishedLabel,
      minPriceCents: parsed.minPriceCents,
      isFree: parsed.isFree,
      priceLabel: parsed.priceLabel,
    );
  }

  String? _bestUrlFromSrcset(String srcset) {
    String? largest;
    var largestWidth = 0;
    for (final part in srcset.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final pieces = trimmed.split(RegExp(r'\s+'));
      final url = pieces.first;
      if (url.contains('/original/')) {
        return _normalizeItchAssetUrl(url);
      }
      final widthMatch = RegExp(r'(\d+)w').firstMatch(trimmed);
      final width = widthMatch != null ? int.tryParse(widthMatch.group(1)!) ?? 0 : 0;
      if (width >= largestWidth) {
        largestWidth = width;
        largest = url;
      }
      largest ??= url;
    }
    return largest != null ? _normalizeItchAssetUrl(largest) : null;
  }

  String _normalizeItchAssetUrl(String url) {
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    return url;
  }

  String? _metaValue(Map<String, String> meta, String key) {
    return _firstNonEmpty([meta[key.toLowerCase()]]);
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  String _stripHtml(String html) {
    return _decodeHtml(
      html
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
    );
  }

  String _decodeHtml(String text) {
    if (text.isEmpty) {
      return text;
    }
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
  }
}
