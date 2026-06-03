import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/dom.dart' as dom;

import '../../../../core/utils/itch_external_link.dart';
import '../../../../core/utils/itch_cached_network_image.dart';
import '../../../../data/game_page_theme.dart';

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
    result = result.replaceAll(
      RegExp(
        r'<iframe[^>]*src="[^"]*itch\.io/embed/[^"]*"[^>]*>\s*</iframe>',
        caseSensitive: false,
      ),
      '',
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cleaned = preprocessHtml(html).trim();
    if (cleaned.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = theme?.textColor ?? const Color(0xFFD4CECE);
    final linkColor = theme?.linkColor ?? const Color(0xFFFA5C5C);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Html(
          data: cleaned,
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
          extensions: [
            TagExtension(
              tagsToExtend: const {'img'},
              builder: (extensionContext) {
                final src = extensionContext.attributes['src'] ?? '';
                if (src.isEmpty) {
                  return const SizedBox.shrink();
                }
                final imgEl = extensionContext.element;
                final centered = imgEl is dom.Element && _imgIsCentered(imgEl);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ItchCachedNetworkImage(
                    url: src,
                    width: width,
                    fit: BoxFit.fitWidth,
                    alignment: centered ? Alignment.center : Alignment.centerLeft,
                    filterQuality: FilterQuality.medium,
                    errorWidget: const SizedBox.shrink(),
                  ),
                );
              },
            ),
          ],
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
            'br': Style(
              height: Height(6),
            ),
            'a': Style(
              color: linkColor,
              textDecoration: TextDecoration.none,
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
            'ul': Style(margin: Margins.only(left: 16, bottom: 8)),
            'ol': Style(margin: Margins.only(left: 16, bottom: 8)),
            'li': Style(margin: Margins.only(bottom: 4)),
          },
        );
      },
    );
  }

  static bool _imgIsCentered(dom.Element? img) {
    var cur = img?.parent;
    while (cur != null) {
      if (cur.classes.contains('text-center')) {
        return true;
      }
      cur = cur.parent;
    }
    return false;
  }
}
