import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/use_cases/providers.dart';
import '../../features/auth/presentation/api_keys_setup_page.dart';
import '../../features/auth/presentation/oauth_callback_page.dart';
import '../../features/auth/presentation/oauth_web_login_page.dart';
import '../../features/downloads/presentation/downloads_page.dart';
import '../../features/gate/presentation/gate_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/tabs/presentation/hub_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/gate',
    routes: [
      GoRoute(path: '/gate', builder: (_, _) => const GatePage()),
      GoRoute(path: '/oauth-login', builder: (_, _) => const OAuthWebLoginPage()),
      GoRoute(path: '/api-keys-setup', builder: (_, _) => const ApiKeysSetupPage()),
      GoRoute(
        path: '/callback',
        builder: (_, state) => OAuthCallbackPage(callbackUri: state.uri),
      ),
      GoRoute(
        path: '/oauth/callback',
        builder: (_, state) => OAuthCallbackPage(callbackUri: state.uri),
      ),
      GoRoute(path: '/tabs', builder: (_, _) => const HubPage()),
      GoRoute(
        path: '/library',
        redirect: (_, _) => '/tabs',
      ),
      GoRoute(
        path: '/downloads',
        builder: (_, _) => const DownloadsPage(standalone: true),
      ),
      GoRoute(
        path: '/downloads/new/:gameId',
        redirect: (_, state) {
          final gameId = int.tryParse(state.pathParameters['gameId'] ?? '');
          final title = state.uri.queryParameters['title'] ?? 'Unknown';
          if (gameId != null) {
            ref.read(enqueueDownloadUseCaseProvider).call(gameId: gameId, gameTitle: title);
          }
          return '/downloads';
        },
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
    ],
  );
});
