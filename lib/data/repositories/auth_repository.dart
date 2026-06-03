import '../itch_api_client.dart';
import '../models.dart';

class AuthRepository {
  const AuthRepository(this._client);

  final ItchApiClient _client;

  Future<UserProfile> loginWithPassword({
    required String username,
    required String password,
  }) {
    return _client.loginWithPassword(username: username, password: password);
  }

  Future<UserProfile> fetchMe({required String apiKey}) {
    return _client.fetchMe(apiKey: apiKey);
  }
}
