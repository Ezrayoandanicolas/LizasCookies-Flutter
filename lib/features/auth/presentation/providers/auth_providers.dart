import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/auth_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/datasources/auth_local_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/errors/failures.dart';

// Data sources
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AuthRemoteDataSource(dioClient.dio);
});

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return AuthLocalDataSource(secureStorage);
});

// Repository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remote = ref.watch(authRemoteDataSourceProvider);
  final local = ref.watch(authLocalDataSourceProvider);
  return AuthRepositoryImpl(remote, local);
});

// Auth State Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  AuthNotifier(this._ref) : super(const AuthLoading()) {
    _init();
  }

  Future<void> _init() async {
    final local = _ref.read(authLocalDataSourceProvider);
    final token = await local.getAccessToken();
    final user = await local.getUserProfile();
    if (token != null && token.isNotEmpty && user != null) {
      state = Authenticated(
        user: user,
        tokens: AuthTokens(accessToken: token, refreshToken: '', expiresIn: 3600),
      );
    } else {
      state = const Unauthenticated();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();
    final repo = _ref.read(authRepositoryProvider);
    final result = await repo.login(email: email, password: password);
    result.fold(
      (failure) => state = AuthError(message: failure.userMessage),
      (tokens) async {
        final profileResult = await repo.getProfile();
        profileResult.fold(
          (failure) {
            // Login succeeded, just profile failed - still authenticated
            final local = _ref.read(authLocalDataSourceProvider);
            local.getUserProfile().then((cachedUser) {
              if (cachedUser != null) {
                state = Authenticated(
                  user: cachedUser,
                  tokens: tokens,
                );
              } else {
                state = AuthError(message: 'Gagal memuat profil');
              }
            });
          },
          (user) => state = Authenticated(user: user, tokens: tokens),
        );
      },
    );
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
  }) async {
    state = const AuthLoading();
    final repo = _ref.read(authRepositoryProvider);
    final result = await repo.register(
      name: name, email: email, password: password,
      passwordConfirmation: passwordConfirmation, phone: phone,
    );
    result.fold(
      (failure) => state = AuthError(message: failure.userMessage),
      (tokens) async {
        final profileResult = await repo.getProfile();
        profileResult.fold(
          (failure) {
            final local = _ref.read(authLocalDataSourceProvider);
            local.getUserProfile().then((cachedUser) {
              if (cachedUser != null) {
                state = Authenticated(user: cachedUser, tokens: tokens);
              } else {
                state = AuthError(message: 'Gagal memuat profil');
              }
            });
          },
          (user) => state = Authenticated(user: user, tokens: tokens),
        );
      },
    );
  }

  Future<void> logout() async {
    state = const AuthLoading();
    final repo = _ref.read(authRepositoryProvider);
    await repo.logout();
    state = const Unauthenticated();
  }

  void clearError() {
    if (state is AuthError) {
      state = const Unauthenticated();
    }
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
