/// OAuth scopes for third-party apps — see `OAuth Applications.md` / itch.io docs.
final class OAuthConfig {
  static const clientId = 'b24496f50a8653cd060bd4723c7fec1c';
  static const redirectUri = 'hitchapp://oauth/callback';
  static const callbackScheme = 'hitchapp';

  /// Все scope из документации itch OAuth (`OAuth Applications.md`).
  /// `collection:view` в OAuth нет — только у полного API key с itch.io/settings.
  static const oauthScopes = <String>[
    'profile:me',
    'profile:games',
    'profile:collections',
    'profile:owned',
    'game:view:ownership',
    'game:view:rewards',
  ];

  static String get scope => oauthScopes.join(' ');

  static Uri loginUri() {
    return Uri.parse('https://itch.io/user/oauth').replace(
      queryParameters: {
        'client_id': clientId,
        'scope': scope,
        'response_type': 'token',
        'redirect_uri': redirectUri,
      },
    );
  }
}
