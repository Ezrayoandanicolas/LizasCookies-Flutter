class TenantEntity {
  final int id;
  final String name;
  final String slug;
  final String? logoUrl;
  final String? loadingMessage;
  final String? primaryColor;

  const TenantEntity({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.loadingMessage,
    this.primaryColor,
  });

  factory TenantEntity.fromJson(Map<String, dynamic> json) {
    return TenantEntity(
      id: (json['id'] ?? 0).toInt(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      logoUrl: json['logo_url']?.toString(),
      loadingMessage: json['loading_message']?.toString(),
      primaryColor: json['primary_color']?.toString(),
    );
  }
}

class StoreEntity {
  final int id;
  final String name;
  final String code;
  final String? address;

  const StoreEntity({
    required this.id,
    required this.name,
    required this.code,
    this.address,
  });

  factory StoreEntity.fromJson(Map<String, dynamic> json) {
    return StoreEntity(
      id: (json['id'] ?? 0).toInt(),
      name: (json['name'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      address: json['address']?.toString(),
    );
  }
}

class UserEntity {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final String? role;
  final bool emailVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final TenantEntity? tenant;
  final StoreEntity? defaultStore;
  final List<StoreEntity> accessibleStores;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
    this.role,
    this.emailVerified = false,
    this.createdAt,
    this.updatedAt,
    this.tenant,
    this.defaultStore,
    this.accessibleStores = const [],
  });

  bool get isSuperAdmin => role == 'superadmin' || role == 'super_admin';
  bool get isMember => role == 'member';
  bool get isStaff => ['staff', 'cashier', 'store_manager', 'tenant_owner', 'super_admin', 'superadmin', 'admin'].contains(role);
  bool get isAdmin => ['super_admin', 'superadmin', 'admin', 'tenant_owner'].contains(role);
  bool get canPOS => ['cashier', 'staff', 'store_manager', 'tenant_owner', 'super_admin', 'superadmin'].contains(role);
  bool get needsTenantSelection => isSuperAdmin && tenant == null;
  bool get needsStoreSelection => isStaff && !isSuperAdmin && accessibleStores.length > 1;

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: (json['id'] ?? 0).toInt(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: json['phone']?.toString(),
      avatar: json['avatar']?.toString(),
      role: json['role']?.toString(),
      emailVerified: json['email_verified'] == true || json['email_verified_at'] != null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      tenant: json['tenant'] != null ? TenantEntity.fromJson(json['tenant']) : null,
      defaultStore: json['default_store'] != null ? StoreEntity.fromJson(json['default_store']) : null,
      accessibleStores: json['accessible_stores'] != null
          ? (json['accessible_stores'] as List).map((e) => StoreEntity.fromJson(e)).toList()
          : [],
    );
  }
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String? tokenType;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.tokenType,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: (json['access_token'] ?? '').toString(),
      refreshToken: (json['refresh_token'] ?? '').toString(),
      expiresIn: (json['expires_in'] ?? 3600).toInt(),
      tokenType: json['token_type']?.toString(),
    );
  }
}

sealed class AuthState {
  const AuthState();
}

class Authenticated extends AuthState {
  final UserEntity user;
  final AuthTokens tokens;
  const Authenticated({required this.user, required this.tokens});
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthError extends AuthState {
  final String message;
  const AuthError({required this.message});
}
