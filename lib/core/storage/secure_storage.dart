// Secure storage for tokens and sensitive data

import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class SecureStorage {
  static const _options = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: false,
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: _options,
    aOptions: _androidOptions,
  );

  // Token keys
  static const String _accessTokenKey = AppConstants.accessTokenKey;
  static const String _refreshTokenKey = AppConstants.refreshTokenKey;
  static const String _userProfileKey = AppConstants.userProfileKey;
  static const String _fcmTokenKey = AppConstants.fcmTokenKey;
  static const String _onboardingCompleteKey = AppConstants.onboardingCompleteKey;
  static const String _themeModeKey = AppConstants.themeModeKey;
  static const String _languageCodeKey = AppConstants.languageCodeKey;

  // Tokens
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() async => _storage.read(key: _accessTokenKey);

  Future<String?> getRefreshToken() async => _storage.read(key: _refreshTokenKey);

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _userProfileKey),
    ]);
  }

  // User Profile
  Future<void> saveUserProfile(String json) async =>
      _storage.write(key: _userProfileKey, value: json);

  Future<String?> getUserProfile() async => _storage.read(key: _userProfileKey);

  Future<void> clearUserProfile() async => _storage.delete(key: _userProfileKey);

  // FCM Token
  Future<void> saveFcmToken(String token) async =>
      _storage.write(key: _fcmTokenKey, value: token);

  Future<String?> getFcmToken() async => _storage.read(key: _fcmTokenKey);

  Future<void> clearFcmToken() async => _storage.delete(key: _fcmTokenKey);

  // Onboarding
  Future<void> setOnboardingComplete(bool value) async =>
      _storage.write(key: _onboardingCompleteKey, value: value.toString());

  Future<bool> isOnboardingComplete() async =>
      (await _storage.read(key: _onboardingCompleteKey)) == 'true';

  // Theme Mode
  Future<void> saveThemeMode(String mode) async =>
      _storage.write(key: _themeModeKey, value: mode);

  Future<String?> getThemeMode() async => _storage.read(key: _themeModeKey);

  // Language
  Future<void> saveLanguageCode(String code) async =>
      _storage.write(key: _languageCodeKey, value: code);

  Future<String?> getLanguageCode() async => _storage.read(key: _languageCodeKey);

  // Selected Tenant & Store
  static const String _selectedTenantIdKey = 'selected_tenant_id';
  static const String _selectedStoreIdKey = 'selected_store_id';

  Future<void> saveSelectedTenantId(int id) async =>
      _storage.write(key: _selectedTenantIdKey, value: id.toString());

  Future<int?> getSelectedTenantId() async {
    final val = await _storage.read(key: _selectedTenantIdKey);
    return val != null ? int.tryParse(val) : null;
  }

  Future<void> saveSelectedStoreId(int id) async =>
      _storage.write(key: _selectedStoreIdKey, value: id.toString());

  Future<int?> getSelectedStoreId() async {
    final val = await _storage.read(key: _selectedStoreIdKey);
    return val != null ? int.tryParse(val) : null;
  }

  Future<void> clearSelectedTenant() async => _storage.delete(key: _selectedTenantIdKey);
  Future<void> clearSelectedStore() async => _storage.delete(key: _selectedStoreIdKey);

  // Device ID (generated once, persists forever)
  static const String _deviceIdKey = 'device_id';

  Future<String> getOrCreateDeviceId() async {
    var id = await _storage.read(key: _deviceIdKey);
    if (id != null && id.isNotEmpty) return id;
    id = _generateUuid();
    await _storage.write(key: _deviceIdKey, value: id);
    return id;
  }

  String _generateUuid() {
    final rng = Random.secure();
    final values = List<int>.generate(16, (_) => rng.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40;
    values[8] = (values[8] & 0x3f) | 0x80;
    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
    final s = values.map(hex).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  // Clear all (logout)
  Future<void> clearAll() async => _storage.deleteAll();
}

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());