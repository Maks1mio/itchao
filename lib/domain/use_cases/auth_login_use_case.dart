import '../../data/models.dart';
import '../../features/auth/auth_controller.dart';

class AuthLoginUseCase {
  const AuthLoginUseCase(this._authController);

  final AuthController _authController;

  Future<UserProfile?> call({
    required String username,
    required String password,
    required String apiKey,
  }) async {
    await _authController.saveApiKey(apiKey);
    return _authController.loginWithPassword(username, password);
  }
}
