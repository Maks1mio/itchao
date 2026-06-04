import 'package:flutter/material.dart';

import 'game_page_models.dart';
import 'itch_image_urls.dart';

/// Результат разбора itch.io `<iframe src="…/embed/…">`.
class ParsedItchEmbed {
  const ParsedItchEmbed({
    required this.card,
    this.embedId,
    this.borderColor,
    this.borderWidth = 1,
  });

  final GamePromoCard card;
  final int? embedId;
  final Color? borderColor;
  final double borderWidth;
}

/// Парсит fallback-содержимое itch embed iframe в [GamePromoCard].
class ItchEmbedParser {
  ItchEmbedParser._();

  static final _embedIframe = RegExp(
    r'<iframe\b[^>]*src="[^"]*itch\.io/embed/[^"]*"[^>]*>[\s\S]*?</iframe>',
    caseSensitive: false,
  );

  static final _iframeInner = RegExp(
    r'<iframe\b[^>]*>([\s\S]*?)</iframe>',
    caseSensitive: false,
  );

  static final _iframeSrc = RegExp(
    r'''src\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  );

  static final _itchGameHref = RegExp(
    r'href="(https://[^"]+\.itch\.io/[^"?#/][^"]*)"',
    caseSensitive: false,
  );

  static final _itchGameUrl = RegExp(
    r'https://[a-z0-9-]+\.itch\.io/[a-z0-9-]+(?:/[a-z0-9-]+)?',
    caseSensitive: false,
  );

  static final _embedIdInSrc = RegExp(
    r'itch\.io/embed/(\d+)',
    caseSensitive: false,
  );

  /// Все itch embed iframe в HTML-фрагменте.
  static Iterable<RegExpMatch> embedMatches(String html) =>
      _embedIframe.allMatches(html);

  static int? extractEmbedId(String block) {
    final src = _iframeSrc.firstMatch(block)?.group(1);
    if (src == null) {
      return null;
    }
    final match = _embedIdInSrc.firstMatch(src);
    return int.tryParse(match?.group(1) ?? '');
  }

  static ParsedItchEmbed? parseIframeBlock(String block) {
    if (!block.toLowerCase().contains('itch.io/embed')) {
      return null;
    }

    final inner = _iframeInner.firstMatch(block)?.group(1) ?? block;
    final decoded = _fullyDecode(inner);
    final webUrl = _extractWebUrl(decoded);
    if (webUrl == null || webUrl.isEmpty) {
      return null;
    }

    final split = _extractTitleAuthor(decoded, webUrl);
    final style = _parseEmbedStyle(block);
    final embedId = extractEmbedId(block);

    return ParsedItchEmbed(
      embedId: embedId,
      card: GamePromoCard(
        title: split.$1,
        webUrl: webUrl,
        author: split.$2.isNotEmpty ? split.$2 : null,
        embedId: embedId,
      ),
      borderColor: style.borderColor,
      borderWidth: style.borderWidth,
    );
  }

  /// HTML страницы `https://itch.io/embed/{id}` → карточка с обложкой.
  static GamePromoCard? parseEmbedWidgetHtml(String pageHtml) {
    final summaryMatch = RegExp(
      r'<div class="game_summary">([\s\S]*?)</div>',
      caseSensitive: false,
    ).firstMatch(pageHtml);
    if (summaryMatch == null) {
      return null;
    }
    final summary = summaryMatch.group(1)!;

    final titleMatch = RegExp(
      r'class="game_title"[\s\S]*?<a[^>]+href="([^"]+)"[^>]*>([\s\S]*?)</a>',
      caseSensitive: false,
    ).firstMatch(summary);
    if (titleMatch == null) {
      return null;
    }

    final authorMatch = RegExp(
      r'class="author_row"[\s\S]*?<a[^>]+href="([^"]+)"[^>]*>([\s\S]*?)</a>',
      caseSensitive: false,
    ).firstMatch(summary);
    final summaryTextMatch = RegExp(
      r'<h3[^>]*title="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(summary);
    final summaryText = summaryTextMatch?.group(1)?.trim().isNotEmpty == true
        ? _decodeHtml(summaryTextMatch!.group(1)!.trim())
        : _stripHtml(
            RegExp(r'<h3[^>]*>([\s\S]*?)</h3>', caseSensitive: false)
                    .firstMatch(summary)
                    ?.group(1) ??
                '',
          );

    final coverUrl = _extractCoverUrl(pageHtml);

    return GamePromoCard(
      title: _stripHtml(titleMatch.group(2) ?? ''),
      webUrl: _normalizeUrl(titleMatch.group(1)!),
      author: authorMatch != null ? _stripHtml(authorMatch.group(2) ?? '') : null,
      authorUrl: authorMatch?.group(1),
      summary: summaryText.isEmpty ? null : summaryText,
      coverUrl: coverUrl,
      platforms: _parsePlatforms(pageHtml),
    );
  }

  static String? _extractCoverUrl(String pageHtml) {
    final imgTag = RegExp(
      r'<img\b[^>]*class="thumb"[^>]*/?>',
      caseSensitive: false,
    ).firstMatch(pageHtml)?.group(0);
    if (imgTag == null) {
      final wrapper = RegExp(
        r'class="thumb_wrapper"[\s\S]*?<img\b([^>]+)/>',
        caseSensitive: false,
      ).firstMatch(pageHtml)?.group(1);
      if (wrapper == null) {
        return null;
      }
      return _pickImageUrlFromAttrs(wrapper);
    }
    return _pickImageUrlFromAttrs(imgTag);
  }

  static String? _pickImageUrlFromAttrs(String attrs) {
    final srcset = RegExp(r'''srcset="([^"]+)''', caseSensitive: false)
        .firstMatch(attrs)
        ?.group(1);
    if (srcset != null) {
      final candidates = srcset.split(',');
      String? best;
      var bestWidth = 0;
      for (final candidate in candidates) {
        final parts = candidate.trim().split(RegExp(r'\s+'));
        if (parts.isEmpty) {
          continue;
        }
        final url = _decodeHtml(parts.first);
        var width = 0;
        if (parts.length >= 2 && parts[1].endsWith('x')) {
          width = int.tryParse(parts[1].substring(0, parts[1].length - 1)) ?? 0;
        }
        if (url.contains('img.itch.zone') && width >= bestWidth) {
          best = url;
          bestWidth = width;
        }
      }
      if (best != null) {
        return best;
      }
    }

    final src = RegExp(r'''src="([^"]+)''', caseSensitive: false)
        .firstMatch(attrs)
        ?.group(1);
    if (src == null) {
      return null;
    }
    final decoded = _decodeHtml(src);
    return ItchImageUrls.toOriginal(decoded) ?? decoded;
  }

  static String? _extractWebUrl(String decoded) {
    for (final match in _itchGameHref.allMatches(decoded)) {
      final url = _normalizeUrl(match.group(1)!);
      if (!url.contains('/embed/')) {
        return url;
      }
    }
    final bare = _itchGameUrl.firstMatch(decoded);
    if (bare != null) {
      return _normalizeUrl(bare.group(0)!);
    }
    return null;
  }

  static ({Color? borderColor, double borderWidth}) _parseEmbedStyle(String block) {
    final src = _iframeSrc.firstMatch(block)?.group(1);
    final uri = src != null ? Uri.tryParse(src) : null;
    if (uri == null) {
      return (borderColor: null, borderWidth: 1);
    }

    final width = double.tryParse(uri.queryParameters['border_width'] ?? '') ?? 1;
    final hex = uri.queryParameters['border_color'];
    Color? color;
    if (hex != null && RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
      color = Color(int.parse('FF$hex', radix: 16));
    }
    return (borderColor: color, borderWidth: width);
  }

  static (String, String) _extractTitleAuthor(String inner, String webUrl) {
    final text = _stripHtmlToText(inner);
    if (text.isEmpty || _looksLikeBrokenTitle(text)) {
      return (_titleFromUrl(webUrl), '');
    }

    final split = _splitTitleAuthor(text);
    var title = split.$1;
    if (title.isEmpty || _looksLikeBrokenTitle(title)) {
      title = _titleFromUrl(webUrl);
    } else {
      title = _dedupeLeadingWord(title);
    }
    final author = _looksLikeBrokenTitle(split.$2) ? '' : split.$2;
    return (title, author);
  }

  static bool _looksLikeBrokenTitle(String text) {
    final lower = text.toLowerCase();
    return lower.contains('class=') ||
        lower.contains('redactor') ||
        lower.contains('href=') ||
        text.contains('">');
  }

  static String _dedupeLeadingWord(String title) {
    final parts = title.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].toLowerCase() == parts[1].toLowerCase()) {
      return parts.sublist(1).join(' ');
    }
    return title;
  }

  static String _normalizeUrl(String url) {
    return url.split('?').first.split('#').first;
  }

  static (String, String) _splitTitleAuthor(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return ('', '');
    }
    final byIdx = text.toLowerCase().lastIndexOf(' by ');
    if (byIdx > 0) {
      return (
        text.substring(0, byIdx).trim(),
        text.substring(byIdx + 4).trim(),
      );
    }
    return (text, '');
  }

  static String _stripHtmlToText(String html) {
    var text = _fullyDecode(html);
    text = text.replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ');
    for (var pass = 0; pass < 24; pass++) {
      final next = text.replaceAll(RegExp(r'<[^>]{0,300}>'), ' ');
      if (next == text) {
        break;
      }
      text = next;
    }
    text = text.replaceAll(_itchGameUrl, ' ');
    text = text.replaceAll(
      RegExp(r'\b(?:class|href|redactor-linkify-object)\b\s*=?\s*"[^"]*"', caseSensitive: false),
      ' ',
    );
    text = text.replaceAll(RegExp(r'https?://\S+'), ' ');
    text = text.replaceAll(RegExp('["\'<>]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  static String _stripHtml(String html) {
    return _stripHtmlToText(html);
  }

  static List<String> _parsePlatforms(String block) {
    final platforms = <String>[];
    if (block.contains('icon-windows')) {
      platforms.add('windows');
    }
    if (block.contains('icon-apple')) {
      platforms.add('osx');
    }
    if (block.contains('icon-tux')) {
      platforms.add('linux');
    }
    if (block.contains('icon-android')) {
      platforms.add('android');
    }
    return platforms;
  }

  static String _titleFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return url;
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return url;
    }
    final slug = segments.last;
    return slug
        .split('-')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.length > 1 ? part.substring(1) : ''}',
        )
        .join(' ');
  }

  static String _fullyDecode(String text) {
    var result = text;
    for (var i = 0; i < 6; i++) {
      final next = _decodeHtml(result);
      if (next == result) {
        break;
      }
      result = next;
    }
    return result;
  }

  static String _decodeHtml(String text) {
    if (text.isEmpty) {
      return text;
    }
    var result = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');

    result = result.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
    );
    result = result.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!)),
    );
    return result;
  }
}
