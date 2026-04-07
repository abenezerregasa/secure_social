import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static final FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _kAccessToken = 'access_token';

  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _kAccessToken, value: token);
  }

  static Future<String?> getAccessToken() async {
    return _storage.read(key: _kAccessToken);
  }

  static Future<void> deleteAccessToken() async {
    await _storage.delete(key: _kAccessToken);
  }
}