import '../data/rust/wispie_core.dart';

class AuthService {
  AuthService();

  Future<String> updateUsername(String newUsername) async {
    final reply = WispieCore.helper({
      'action': 'auth_username',
      'name': newUsername,
    });
    if (reply['ok'] != true) {
      throw Exception('Display name cannot be empty');
    }
    return reply['value'] as String;
  }
}
