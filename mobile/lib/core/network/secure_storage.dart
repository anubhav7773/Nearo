import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const String _keyAccessToken = 'jwt_access_token';
  static const String _keyRefreshToken = 'jwt_refresh_token';
  static const String _keyUserId = 'user_id';
  static const String _keyAliasName = 'user_alias_name';
  static const String _keyUserTier = 'user_tier';

  // Access Token
  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  // Refresh Token
  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  // User Profile Metadata
  static Future<void> saveUserSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String aliasName,
    required String tier,
  }) async {
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
      _storage.write(key: _keyUserId, value: userId),
      _storage.write(key: _keyAliasName, value: aliasName),
      _storage.write(key: _keyUserTier, value: tier),
    ]);
  }

  static Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  static Future<String?> getAliasName() async {
    return await _storage.read(key: _keyAliasName);
  }

  static Future<String?> getUserTier() async {
    return await _storage.read(key: _keyUserTier);
  }

  static Future<void> updateUserTier(String tier) async {
    await _storage.write(key: _keyUserTier, value: tier);
  }

  // Clear Session upon Logout or DPDP Account Purge
  static Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}
