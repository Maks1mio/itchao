import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../auth/auth_controller.dart';
import '../auth/oauth_config.dart';

/// Scopes, которые запрашивает приложение при входе (см. [OAuthConfig.oauthScopes]).
final kRecommendedScopes = OAuthConfig.oauthScopes;

final settingsAccountProvider = FutureProvider<AccountSettingsInfo?>((ref) async {
  final token = await ref.read(authControllerProvider.notifier).readApiKey();
  if (token == null || token.isEmpty) {
    return null;
  }
  final client = ref.read(itchApiClientProvider);
  final profile = await client.fetchMe(apiKey: token);
  final credentials = await client.fetchCredentialInfo(token: token);
  return AccountSettingsInfo(
    profile: profile,
    credentials: credentials,
    token: token,
  );
});

bool hasScope(List<String> scopes, String scope) {
  if (scopes.contains(scope)) {
    return true;
  }
  if (scope.startsWith('profile:') && scopes.contains('profile')) {
    return true;
  }
  return false;
}
