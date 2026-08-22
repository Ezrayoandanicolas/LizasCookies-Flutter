import '../../domain/entities/auth_entity.dart';

class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class RegisterRequest {
  final String name;
  final String email;
  final String password;
  final String passwordConfirmation;
  final String? phone;

  const RegisterRequest({
    required this.name,
    required this.email,
    required this.password,
    required this.passwordConfirmation,
    this.phone,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        if (phone != null) 'phone': phone,
      };
}

class AuthResponse {
  final UserData user;
  final String accessToken;
  final String tokenType;
  final TenantData? tenant;
  final StoreData? defaultStore;
  final List<StoreData> accessibleStores;

  const AuthResponse({
    required this.user,
    required this.accessToken,
    this.tokenType = 'Bearer',
    this.tenant,
    this.defaultStore,
    this.accessibleStores = const [],
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: UserData.fromJson(json['user'] ?? {}),
      accessToken: (json['access_token'] ?? json['token'] ?? '').toString(),
      tokenType: (json['token_type'] ?? 'Bearer').toString(),
      tenant: json['tenant'] != null ? TenantData.fromJson(json['tenant']) : null,
      defaultStore: json['default_store'] != null ? StoreData.fromJson(json['default_store']) : null,
      accessibleStores: json['accessible_stores'] != null
          ? (json['accessible_stores'] as List).map((e) => StoreData.fromJson(e)).toList()
          : [],
    );
  }

  AuthTokens toTokens() => AuthTokens(
        accessToken: accessToken,
        refreshToken: '',
        expiresIn: 3600,
        tokenType: tokenType,
      );

  UserEntity toUserEntity() => UserEntity(
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        avatar: user.avatar,
        role: user.role,
        tenant: tenant?.toEntity(),
        defaultStore: defaultStore?.toEntity(),
        accessibleStores: accessibleStores.map((e) => e.toEntity()).toList(),
      );
}

class UserData {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final String? role;
  final String? roleLabel;

  const UserData({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
    this.role,
    this.roleLabel,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: (json['id'] ?? 0).toInt(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: json['phone']?.toString(),
      avatar: json['avatar']?.toString(),
      role: json['role']?.toString(),
      roleLabel: json['role_label']?.toString(),
    );
  }

  UserEntity toEntity() => UserEntity(
        id: id,
        name: name,
        email: email,
        phone: phone,
        avatar: avatar,
        role: role,
      );
}

class TenantData {
  final int id;
  final String name;
  final String slug;
  final String? logoUrl;
  final String? loadingMessage;
  final String? primaryColor;

  const TenantData({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.loadingMessage,
    this.primaryColor,
  });

  factory TenantData.fromJson(Map<String, dynamic> json) {
    return TenantData(
      id: (json['id'] ?? 0).toInt(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      logoUrl: json['logo_url']?.toString(),
      loadingMessage: json['loading_message']?.toString(),
      primaryColor: json['primary_color']?.toString(),
    );
  }

  TenantEntity toEntity() => TenantEntity(
        id: id, name: name, slug: slug,
        logoUrl: logoUrl, loadingMessage: loadingMessage, primaryColor: primaryColor,
      );
}

class StoreData {
  final int id;
  final String name;
  final String code;
  final String? address;

  const StoreData({
    required this.id,
    required this.name,
    required this.code,
    this.address,
  });

  factory StoreData.fromJson(Map<String, dynamic> json) {
    return StoreData(
      id: (json['id'] ?? 0).toInt(),
      name: (json['name'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      address: json['address']?.toString(),
    );
  }

  StoreEntity toEntity() => StoreEntity(
        id: id, name: name, code: code, address: address,
      );
}

class ForgotPasswordRequest {
  final String email;
  const ForgotPasswordRequest({required this.email});
  Map<String, dynamic> toJson() => {'email': email};
}

class ResetPasswordRequest {
  final String email;
  final String password;
  final String passwordConfirmation;
  final String token;
  const ResetPasswordRequest({
    required this.email,
    required this.password,
    required this.passwordConfirmation,
    required this.token,
  });
  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'token': token,
      };
}
