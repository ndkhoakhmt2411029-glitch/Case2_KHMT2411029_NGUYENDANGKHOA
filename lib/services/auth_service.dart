import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _api = ApiClient.instance;

  /// POST /auth/register
  Future<User> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final data = await _api.post('/auth/register',
        auth: false,
        body: {
          'fullName': fullName.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
        });
    final token = data['token']?.toString();
    if (token != null) await _api.saveToken(token);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// POST /auth/login
  Future<User> login({required String email, required String password}) async {
    final data = await _api.post('/auth/login',
        auth: false,
        body: {'email': email.trim().toLowerCase(), 'password': password});
    final token = data['token']?.toString();
    if (token == null) throw ApiException('Không nhận được token đăng nhập');
    await _api.saveToken(token);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// GET /auth/me
  Future<User> getMe() async {
    final data = await _api.get('/auth/me');
    return User.fromJson((data['user'] ?? data) as Map<String, dynamic>);
  }

  /// PUT /auth/me
  Future<User> updateProfile({required String fullName, String? avatarUrl}) async {
    final data = await _api.put('/auth/me', body: {
      'fullName': fullName.trim(),
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    return User.fromJson((data['user'] ?? data) as Map<String, dynamic>);
  }

  /// PUT /auth/change-password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.put('/auth/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<bool> hasToken() async => (await _api.getToken()) != null;

  /// Đăng xuất: xóa token phía client (JWT stateless).
  Future<void> logout() => _api.clearToken();
}
