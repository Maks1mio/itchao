import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/web/itch_webview.dart';
import '../../data/itch_api_client.dart';
import '../../data/models.dart';
import '../../data/repositories/auth_repository.dart';

final itchApiClientProvider = Provider<ItchApiClient>((ref) {
  final client = ItchApiClient();
  ref.onDispose(client.dispose);
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(itchApiClientProvider));
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, UserProfile?>(AuthController.new);

class AuthController extends AsyncNotifier<UserProfile?> {
  static const _apiKeyStore = 'itch.apiKey';
  static const _fullApiKeyStore = 'itch.fullApiKey';

  @override
  Future<UserProfile?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(_apiKeyStore);
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }
    try {
      return await ref.read(authRepositoryProvider).fetchMe(apiKey: apiKey);
    } catch (_) {
      final username = prefs.getString('itch.username') ?? 'itch-user';
      return UserProfile(id: 0, username: username, displayName: username);
    }
  }

  Future<UserProfile?> loginWithPassword(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await ref
          .read(authRepositoryProvider)
          .loginWithPassword(username: username, password: password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('itch.username', profile.username);
      return profile;
    });
    return state.value;
  }

  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyStore, apiKey);
  }

  Future<UserProfile?> completeOAuthCallback(Uri callbackUri) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final fragmentParams = Uri.splitQueryString(callbackUri.fragment);
      final token = fragmentParams['access_token'] ?? callbackUri.queryParameters['access_token'];
      if (token == null || token.isEmpty) {
        throw const FormatException('OAuth callback has no access token');
      }
      await saveApiKey(token);
      final profile = await ref.read(authRepositoryProvider).fetchMe(apiKey: token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('itch.username', profile.username);
      return profile;
    });
    return state.value;
  }

  Future<void> refreshProfile() async {
    final token = await readApiKey();
    if (token == null || token.isEmpty) {
      return;
    }
    state = await AsyncValue.guard(() async {
      return ref.read(authRepositoryProvider).fetchMe(apiKey: token);
    });
  }

  Future<String?> readApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyStore);
  }

  Future<String?> readFullApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fullApiKeyStore);
  }

  Future<void> saveFullApiKey(String? apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (apiKey == null || apiKey.isEmpty) {
      await prefs.remove(_fullApiKeyStore);
      return;
    }
    await prefs.setString(_fullApiKeyStore, apiKey.trim());
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('itch.username');
    await prefs.remove(_apiKeyStore);
    await prefs.remove(_fullApiKeyStore);
    await ItchWebView.clearSession();
    state = const AsyncData(null);
  }
}
