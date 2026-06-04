import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/itch_embed_fetcher.dart';
import '../../data/game_page_models.dart';

final itchEmbedFetcherProvider = Provider<ItchEmbedFetcher>((ref) {
  final fetcher = ItchEmbedFetcher();
  ref.onDispose(fetcher.dispose);
  return fetcher;
});

final itchEmbedCardProvider =
    FutureProvider.autoDispose.family<GamePromoCard?, int>((ref, embedId) {
  return ref.read(itchEmbedFetcherProvider).fetch(embedId);
});
