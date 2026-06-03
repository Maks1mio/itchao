import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

/// Bearer для `collection-games` — как butler на ПК: полный API key, иначе OAuth.
Future<String?> readCollectionsApiToken(Ref ref) async {
  final full = await ref.read(authControllerProvider.notifier).readFullApiKey();
  if (full != null && full.isNotEmpty) {
    return full;
  }
  return ref.read(authControllerProvider.notifier).readApiKey();
}
