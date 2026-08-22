import 'dart:convert';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/auth_entity.dart';

class AuthLocalDataSource {
  final SecureStorage _secureStorage;
  AuthLocalDataSource(this._secureStorage);

  Future<void> saveTokens(AuthTokens tokens) =>
      _secureStorage.saveTokens(tokens.accessToken, tokens.refreshToken);

  Future<String?> getAccessToken() => _secureStorage.getAccessToken();
  Future<String?> getRefreshToken() => _secureStorage.getRefreshToken();
  Future<void> clearTokens() => _secureStorage.clearTokens();

  Future<void> saveUserProfile(UserEntity user) async {
    final json = jsonEncode({
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'avatar': user.avatar,
      'role': user.role,
      'email_verified': user.emailVerified,
      'created_at': user.createdAt?.toIso8601String(),
      'updated_at': user.updatedAt?.toIso8601String(),
      'tenant': user.tenant != null ? {
        'id': user.tenant!.id,
        'name': user.tenant!.name,
        'slug': user.tenant!.slug,
        'logo_url': user.tenant!.logoUrl,
        'loading_message': user.tenant!.loadingMessage,
        'primary_color': user.tenant!.primaryColor,
      } : null,
      'default_store': user.defaultStore != null ? {
        'id': user.defaultStore!.id,
        'name': user.defaultStore!.name,
        'code': user.defaultStore!.code,
        'address': user.defaultStore!.address,
      } : null,
      'accessible_stores': user.accessibleStores.map((s) => {
        'id': s.id,
        'name': s.name,
        'code': s.code,
        'address': s.address,
      }).toList(),
    });
    await _secureStorage.saveUserProfile(json);
  }

  Future<UserEntity?> getUserProfile() async {
    final jsonStr = await _secureStorage.getUserProfile();
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UserEntity.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUserProfile() => _secureStorage.clearUserProfile();
  Future<void> setOnboardingComplete(bool value) => _secureStorage.setOnboardingComplete(value);
  Future<bool> isOnboardingComplete() => _secureStorage.isOnboardingComplete();
}
