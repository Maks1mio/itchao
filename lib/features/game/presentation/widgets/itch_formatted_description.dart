import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/itch_external_link.dart';
import '../../../../core/utils/itch_cached_network_image.dart';
import '../../../../data/game_page_theme.dart';
import '../../../../data/itch_embed_parser.dart';
import 'game_promo_card_loader.dart';

/// Горизонтальный padding текстовых блоков описания (картинки — на всю ширину панели).
const _descriptionHorizontalPadding = 16.0;

sealed class _DescriptionSegment {
  const _DescriptionSegment();
}

final class _HtmlSegment extends _DescriptionSegment {
  const _HtmlSegment(this.html);

  final String html;
}

final class _ImageSegment extends _DescriptionSegment {
  const _ImageSegment({required this.url, required this.centered});

  final String url;
  final bool centered;
}

final class _EmbedSegment extends _DescriptionSegment {
  const _EmbedSegment(this.embed);

  final ParsedItchEmbed embed;
}

/// Рендер `formatted_description` как на itch.io (один HTML-поток, без потери текста).
class ItchFormattedDescription extends StatelessWidget {
  const ItchFormattedDescription({
    required this.html,
    this.theme,
    super.key,
  });

  final String html;
  final GamePageTheme? theme;

  static String preprocessHtml(String raw) {
    var result = raw;
    final moreInfoMarker = RegExp(
      r'<div[^>]*class\s*=\s*["\x27][^"\x27]*more_information(?:_toggle)?[^"\x27]*["\x27][^>]*>',
      caseSensitive: false,
    );
    final markerMatch = moreInfoMarker.firstMatch(result);
    if (markerMatch != null) {
      result = result.substring(0, markerMatch.start);
    }

    result = result.replaceAll(
      RegExp(
        r'<(?:div|section|figure)[^>]*class\s*=\s*["\x27][^"\x27]*(?:embed|video|iframe|responsive)[^"\x27]*["\x27][^>]*>[\s\S]*?</(?:div|section|figure)>',
        caseSensitive: false,
      ),
      '',
    );
    result = result.replaceAll(
      RegExp(
        r'<(?:div|section|figure)[^>]*style\s*=\s*["\x27][^"\x27]*(?:min-height|padding-bottom|height)\s*:[^"\x27]*["\x27][^>]*>\s*((?:&nbsp;|\s|<br\s*/?>)*)</(?:div|section|figure)>',
        caseSensitive: false,
      ),
      '',
    );

    result = _stripBreaksAroundImages(result);
    result = _unwrapImagesFromInlineWrappers(result);
    result = _extractImageOnlyListItems(result);
    for (final tag in _imageContainerTags) {
      result = _unwrapImagesFromContainer(result, tag);
    }
    result = _collapseImageOnlyBlocks(result);
    result = _stripTrailingBreaksInParagraphs(result);

    result = result.replaceAll(
      RegExp(
        r'<(?:p|div)[^>]*>\s*(?:&nbsp;|\s|<br\s*/?>)*</(?:p|div)>',
        caseSensitive: false,
      ),
      '',
    );
    result = result.replaceAll(
      RegExp(r'(?:\s*<br\s*/?>\s*){3,}', caseSensitive: false),
      '<br><br>',
    );
    return result;
  }

  static const _imageContainerTags = [
    'p',
    'li',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'td',
    'th',
  ];

  static List<_DescriptionSegment> _parseSegments(String raw) {
    final html = preprocessHtml(raw);
    final pattern = RegExp(
      r'(<iframe\b[^>]*src="[^"]*itch\.io/embed/[^"]*"[^>]*>[\s\S]*?</iframe>|<img\b[^>]*/?>)',
      caseSensitive: false,
    );
    final segments = <_DescriptionSegment>[];
    var cursor = 0;

    for (final match in pattern.allMatches(html)) {
      if (match.start > cursor) {
        final chunk = html.substring(cursor, match.start);
        if (_hasVisibleContent(chunk)) {
          segments.add(_HtmlSegment(chunk));
        }
      }

      final tag = match.group(0)!;
      if (tag.toLowerCase().startsWith('<iframe')) {
        final parsed = ItchEmbedParser.parseIframeBlock(tag);
        if (parsed != null) {
          segments.add(_EmbedSegment(parsed));
        }
      } else {
        final src = _imgSrcFromTag(tag);
        if (src != null && src.isNotEmpty) {
          segments.add(
            _ImageSegment(
              url: src,
              centered: _imgTagIsCentered(tag),
            ),
          );
        }
      }
      cursor = match.end;
    }

    if (cursor < html.length) {
      final tail = html.substring(cursor);
      if (_hasVisibleContent(tail)) {
        segments.add(_HtmlSegment(tail));
      }
    }

    return segments;
  }

  static bool _hasVisibleContent(String html) {
    final stripped = html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
    return stripped.isNotEmpty;
  }

  static String? _imgSrcFromTag(String tag) {
    final match = RegExp(
      r'''src\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))''',
      caseSensitive: false,
    ).firstMatch(tag);
    return match?.group(1) ?? match?.group(2) ?? match?.group(3);
  }

  static bool _imgTagIsCentered(String tag) {
    return RegExp(r'text-center', caseSensitive: false).hasMatch(tag);
  }

  /// Убирает `<br>` до/после `<img>`.
  static String _stripBreaksAroundImages(String html) {
    var result = html;
    result = result.replaceAllMapped(
      RegExp(r'(<img\b[^>]*>)\s*(?:<br\s*/?>\s*)+', caseSensitive: false),
      (match) => match.group(1)!,
    );
    result = result.replaceAllMapped(
      RegExp(r'(?:<br\s*/?>\s*)+(<img\b[^>]*>)', caseSensitive: false),
      (match) => match.group(1)!,
    );
    return result;
  }

  static String _unwrapImagesFromInlineWrappers(String html) {
    var result = html;
    for (var pass = 0; pass < 6; pass++) {
      final next = result
          .replaceAllMapped(
            RegExp(
              r'<(?:strong|em|b|i|span)(\s[^>]*)?>\s*(<img\b[^>]*/?>)\s*</(?:strong|em|b|i|span)>',
              caseSensitive: false,
            ),
            (match) => match.group(2)!,
          )
          .replaceAllMapped(
            RegExp(
              r'<a(\s[^>]*)?>\s*(<img\b[^>]*/?>)\s*</a>',
              caseSensitive: false,
            ),
            (match) => match.group(2)!,
          );
      if (next == result) {
        break;
      }
      result = next;
    }
    return result;
  }

  /// `<li><img></li>` → `<img>` (вне списка, иначе inline внутри `<li>`).
  static String _extractImageOnlyListItems(String html) {
    return html.replaceAllMapped(
      RegExp(r'<li(\s[^>]*)?>\s*(<img\b[^>]*/?>)\s*</li>', caseSensitive: false),
      (match) => match.group(2)!,
    );
  }

  static String _unwrapImagesFromContainer(String html, String tag) {
    return html.replaceAllMapped(
      RegExp('<$tag(\\s[^>]*)?>([\\s\\S]*?)</$tag>', caseSensitive: false),
      (match) {
        final inner = match.group(2) ?? '';
        if (!RegExp(r'<img\b', caseSensitive: false).hasMatch(inner)) {
          return match.group(0)!;
        }

        final attrs = match.group(1) ?? '';
        final imgRe = RegExp(r'<img\b[^>]*/?>', caseSensitive: false);
        final parts = <String>[];
        var cursor = 0;

        for (final imgMatch in imgRe.allMatches(inner)) {
          final before = inner.substring(cursor, imgMatch.start);
          final textBit = _cleanInlineFragment(before);
          if (textBit.isNotEmpty) {
            parts.add('<$tag$attrs>$textBit</$tag>');
          }
          parts.add(imgMatch.group(0)!);
          cursor = imgMatch.end;
        }

        final tail = _cleanInlineFragment(inner.substring(cursor));
        if (tail.isNotEmpty) {
          parts.add('<$tag$attrs>$tail</$tag>');
        }
        return parts.join('');
      },
    );
  }

  static String _collapseImageOnlyBlocks(String html) {
    return html.replaceAllMapped(
      RegExp(
        r'<(?:div|p|figure|center)(\s[^>]*)?>\s*(<img\b[^>]*/?>)\s*</(?:div|p|figure|center)>',
        caseSensitive: false,
      ),
      (match) {
        final attrs = match.group(1) ?? '';
        var img = match.group(2)!;
        if (RegExp(r'text-center', caseSensitive: false).hasMatch(attrs)) {
          img = _addClassToImg(img, 'text-center');
        }
        return img;
      },
    );
  }

  static String _addClassToImg(String img, String className) {
    if (RegExp(r'\bclass\s*=', caseSensitive: false).hasMatch(img)) {
      return img.replaceFirstMapped(
        RegExp(r'''class\s*=\s*(["'])([^"']*)\1''', caseSensitive: false),
        (m) {
          final quote = m.group(1)!;
          final existing = m.group(2)!;
          if (existing.split(RegExp(r'\s+')).contains(className)) {
            return m.group(0)!;
          }
          return 'class=$quote$className $existing$quote';
        },
      );
    }
    return img.replaceFirst('<img', '<img class="$className"');
  }

  static String _stripTrailingBreaksInParagraphs(String html) {
    return html.replaceAllMapped(
      RegExp(
        r'(<p(\s[^>]*)?>[\s\S]*?)(?:<br\s*/?>\s*)+(</p>)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}${match.group(3)}',
    );
  }

  static String _cleanInlineFragment(String raw) {
    return raw
        .replaceAll(RegExp(r'(?:\s*<br\s*/?>\s*)+', caseSensitive: false), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final segments = _parseSegments(html);
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = theme?.textColor ?? const Color(0xFFD4CECE);
    final linkColor = theme?.linkColor ?? const Color(0xFFFA5C5C);
    final buttonBg = theme?.buttonColor ?? linkColor;
    final buttonFg = theme?.buttonForegroundColor ?? Colors.white;
    final borderColor = theme?.borderColor ?? const Color(0xFF262626);
    final cardBackground = theme?.innerColumnColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;
        final imageWidth =
            contentWidth - _descriptionHorizontalPadding * 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final segment in segments)
              switch (segment) {
                _HtmlSegment(:final html) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _descriptionHorizontalPadding,
                    ),
                    child: _DescriptionHtmlBlock(
                      html: html,
                      textColor: textColor,
                      linkColor: linkColor,
                    ),
                  ),
                _ImageSegment(:final url, :final centered) => Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _descriptionHorizontalPadding,
                      0,
                      _descriptionHorizontalPadding,
                      6,
                    ),
                    child: ItchCachedNetworkImage(
                      url: url,
                      width: imageWidth,
                      fit: BoxFit.fitWidth,
                      alignment:
                          centered ? Alignment.center : Alignment.centerLeft,
                      filterQuality: FilterQuality.medium,
                      errorWidget: const SizedBox.shrink(),
                    ),
                  ),
                _EmbedSegment(:final embed) => Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _descriptionHorizontalPadding,
                      0,
                      _descriptionHorizontalPadding,
                      10,
                    ),
                    child: _InlineEmbedCard(
                      embed: embed,
                      textColor: textColor,
                      linkColor: linkColor,
                      buttonBg: buttonBg,
                      buttonFg: buttonFg,
                      borderColor: borderColor,
                      cardBackground: cardBackground,
                    ),
                  ),
              },
          ],
        );
      },
    );
  }
}

class _DescriptionHtmlBlock extends StatelessWidget {
  const _DescriptionHtmlBlock({
    required this.html,
    required this.textColor,
    required this.linkColor,
  });

  final String html;
  final Color textColor;
  final Color linkColor;

  @override
  Widget build(BuildContext context) {
    return Html(
      data: html,
      shrinkWrap: true,
      onLinkTap: (url, attributes, _) {
        if (url == null) {
          return;
        }
        final uri = Uri.tryParse(url);
        if (uri == null) {
          return;
        }
        launchItchExternalLink(uri, linkAttributes: attributes);
      },
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          color: textColor,
          fontSize: FontSize(14),
          lineHeight: const LineHeight(1.5),
        ),
        'h3': Style(
          color: textColor,
          fontSize: FontSize(18),
          fontWeight: FontWeight.w900,
          textAlign: TextAlign.center,
          margin: Margins.only(top: 4, bottom: 10),
        ),
        'h4': Style(
          color: textColor,
          fontSize: FontSize(15),
          fontWeight: FontWeight.w700,
          textAlign: TextAlign.center,
          margin: Margins.only(top: 8, bottom: 8),
        ),
        'p': Style(
          margin: Margins.only(bottom: 8),
          lineHeight: const LineHeight(1.5),
        ),
        'div': Style(
          margin: Margins.only(bottom: 8),
          display: Display.block,
        ),
        'br': Style(height: Height(1)),
        'a': Style(
          color: linkColor,
          textDecoration: TextDecoration.underline,
          textDecorationColor: linkColor,
        ),
        'strong': Style(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
        'em': Style(
          color: textColor,
          fontStyle: FontStyle.italic,
        ),
        '.text-center': Style(textAlign: TextAlign.center),
        'ul': Style(
          margin: Margins.only(left: 16, bottom: 8),
        ),
        'ol': Style(
          margin: Margins.only(left: 16, bottom: 8),
        ),
        'li': Style(margin: Margins.only(bottom: 4)),
      },
    );
  }
}

class _InlineEmbedCard extends ConsumerWidget {
  const _InlineEmbedCard({
    required this.embed,
    required this.textColor,
    required this.linkColor,
    required this.buttonBg,
    required this.buttonFg,
    required this.borderColor,
    this.cardBackground,
  });

  final ParsedItchEmbed embed;
  final Color textColor;
  final Color linkColor;
  final Color buttonBg;
  final Color buttonFg;
  final Color borderColor;
  final Color? cardBackground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GamePromoCardLoader(
      game: embed.card,
      textColor: textColor,
      linkColor: linkColor,
      buttonBg: buttonBg,
      buttonFg: buttonFg,
      borderColor: borderColor,
      cardBackground: cardBackground,
      embedBorderColor: embed.borderColor,
      embedBorderWidth: embed.borderWidth,
    );
  }
}
