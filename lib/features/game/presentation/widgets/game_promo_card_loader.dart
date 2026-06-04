import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/itch_external_link.dart';
import '../../../../data/game_page_models.dart';
import '../../itch_embed_provider.dart';
import '../../../tabs/game_page_url.dart';
import '../../../tabs/tabs_controller.dart';
import 'game_promo_card_tile.dart';

/// Промо-карточка с подгрузкой метаданных из itch embed widget.
class GamePromoCardLoader extends ConsumerWidget {
  const GamePromoCardLoader({
    required this.game,
    required this.textColor,
    required this.linkColor,
    required this.buttonBg,
    required this.buttonFg,
    required this.borderColor,
    this.cardBackground,
    this.embedBorderColor,
    this.embedBorderWidth = 1,
    super.key,
  });

  final GamePromoCard game;
  final Color textColor;
  final Color linkColor;
  final Color buttonBg;
  final Color buttonFg;
  final Color borderColor;
  final Color? cardBackground;
  final Color? embedBorderColor;
  final double embedBorderWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var card = game;
    final embedId = game.embedId;
    if (embedId != null) {
      final fetched = ref.watch(itchEmbedCardProvider(embedId));
      card = fetched.valueOrNull ?? game;
    }

    return GamePromoCardTile(
      game: card,
      textColor: textColor,
      linkColor: linkColor,
      buttonBg: buttonBg,
      buttonFg: buttonFg,
      borderColor: borderColor,
      cardBackground: cardBackground,
      embedBorderColor: embedBorderColor,
      embedBorderWidth: embedBorderWidth,
      onTap: () => _openGame(ref, card.webUrl),
    );
  }

  void _openGame(WidgetRef ref, String webUrl) {
    final tabUrl = itchGameTabUrlFromWebUrl(webUrl);
    if (tabUrl != null) {
      ref.read(tabsControllerProvider.notifier).navigateActiveTab(tabUrl);
      return;
    }
    final uri = Uri.tryParse(webUrl);
    if (uri != null) {
      launchItchExternalLink(uri);
    }
  }
}
