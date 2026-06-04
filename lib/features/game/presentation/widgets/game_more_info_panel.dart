import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/itch_external_link.dart';
import '../../../../data/game_page_models.dart';
import '../../../../data/game_page_theme.dart';
import '../../../tabs/game_page_url.dart';
import '../../../tabs/tabs_controller.dart';

/// Панель «Больше информации» как на itch.io (таблица + кликабельные ссылки).
class GameMoreInfoPanel extends StatefulWidget {
  const GameMoreInfoPanel({
    required this.entries,
    required this.textColor,
    this.theme,
    super.key,
  });

  final List<GameInfoEntry> entries;
  final Color textColor;
  final GamePageTheme? theme;

  @override
  State<GameMoreInfoPanel> createState() => _GameMoreInfoPanelState();
}

class _GameMoreInfoPanelState extends State<GameMoreInfoPanel> {
  var _expanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final linkColor = widget.theme?.linkColor ?? const Color(0xFFFA5C5C);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Больше информации',
                    style: TextStyle(
                      color: linkColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: linkColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: linkColor,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            for (final entry in widget.entries)
              _InfoRow(
                entry: entry,
                textColor: widget.textColor,
                linkColor: linkColor,
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends ConsumerWidget {
  const _InfoRow({
    required this.entry,
    required this.textColor,
    required this.linkColor,
  });

  final GameInfoEntry entry;
  final Color textColor;
  final Color linkColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              entry.label,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.65),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ValueCell(
              entry: entry,
              linkColor: linkColor,
              textColor: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueCell extends ConsumerWidget {
  const _ValueCell({
    required this.entry,
    required this.linkColor,
    required this.textColor,
  });

  final GameInfoEntry entry;
  final Color linkColor;
  final Color textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entry.isRating) {
      return _RatingValue(
        average: entry.ratingAverage ?? 0,
        count: entry.ratingCount,
        linkColor: linkColor,
        textColor: textColor,
      );
    }

    if (entry.links.isNotEmpty) {
      return Wrap(
        spacing: 0,
        runSpacing: 2,
        children: [
          for (var i = 0; i < entry.links.length; i++) ...[
            if (i > 0)
              Text(', ', style: TextStyle(color: textColor.withValues(alpha: 0.9), fontSize: 12)),
            _LinkLabel(
              link: entry.links[i],
              color: linkColor,
              onTap: () => _openUrl(ref, entry.links[i].url),
            ),
          ],
        ],
      );
    }

    return Text(
      entry.plainText,
      style: TextStyle(color: textColor.withValues(alpha: 0.9), fontSize: 12, height: 1.35),
    );
  }

  void _openUrl(WidgetRef ref, String url) {
    final tabUrl = itchGameTabUrlFromWebUrl(url);
    if (tabUrl != null && _isCreatorGameUrl(url)) {
      ref.read(tabsControllerProvider.notifier).navigateActiveTab(tabUrl);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null) {
      launchItchExternalLink(uri);
    }
  }

  bool _isCreatorGameUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }
    final host = uri.host.toLowerCase();
    return host.endsWith('.itch.io') &&
        host != 'itch.io' &&
        host != 'www.itch.io' &&
        uri.pathSegments.length == 1 &&
        uri.pathSegments.first.isNotEmpty;
  }
}

class _LinkLabel extends StatelessWidget {
  const _LinkLabel({
    required this.link,
    required this.color,
    required this.onTap,
  });

  final GameInfoLink link;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        link.text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          height: 1.35,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
      ),
    );
  }
}

class _RatingValue extends StatelessWidget {
  const _RatingValue({
    required this.average,
    required this.count,
    required this.linkColor,
    required this.textColor,
  });

  final double average;
  final int? count;
  final Color linkColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (index) {
          final filled = average >= index + 1
              ? 1.0
              : (average > index ? average - index : 0.0);
          return Icon(
            filled >= 1 ? Icons.star : Icons.star_border,
            size: 14,
            color: linkColor,
          );
        }),
        if (count != null) ...[
          const SizedBox(width: 4),
          Text(
            '($count)',
            style: TextStyle(color: textColor.withValues(alpha: 0.9), fontSize: 12),
          ),
        ],
      ],
    );
  }
}
