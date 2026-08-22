import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_models.dart';
import '../../domain/entities/auth_entity.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  AuthRepositoryImpl(this._remoteDataSource, this._localDataSource);

  @override
  Future<Either<Failure, AuthTokens>> login({
    required String email,
    required String password,
    String? deviceName,
  }) async {
    try {
      final request = LoginRequest(email: email, password: password);
      final authResponse = await _remoteDataSource.login(request);
      final tokens = authResponse.toTokens();
      final user = authResponse.toUserEntity();
      await _localDataSource.saveTokens(tokens);
      await _localDataSource.saveUserProfile(user);
      return Right(tokens);
    } on DioException catch (e) {
      final message = e.message ?? 'Login gagal';
      return Left(ServerFailure(message: message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthTokens>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
    String? deviceName,
  }) async {
    try {
      final request = RegisterRequest(
        name: name, email: email, password: password,
        passwordConfirmation: passwordConfirmation, phone: phone,
      );
      final authResponse = await _remoteDataSource.register(request);
      final tokens = authResponse.toTokens();
      final user = authResponse.toUserEntity();
      await _localDataSource.saveTokens(tokens);
      await _localDataSource.saveUserProfile(user);
      return Right(tokens);
    } on DioException catch (e) {
      final message = e.message ?? 'Registrasi gagal';
      return Left(ServerFailure(message: message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _remoteDataSource.logout();
    } catch (_) {}
    await _localDataSource.clearTokens();
    await _localDataSource.clearUserProfile();
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserEntity>> getProfile() async {
    try {
      final userData = await _remoteDataSource.getProfile();
      final user = userData.toEntity();
      await _localDataSource.saveUserProfile(user);
      return Right(user);
    } on DioException catch (e) {
      final cached = await _localDataSource.getUserProfile();
      if (cached != null) return Right(cached);
      return Left(ServerFailure(message: e.message ?? 'Gagal memuat profil'));
    } catch (e) {
      final cached = await _localDataSource.getUserProfile();
      if (cached != null) return Right(cached);
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthTokens>> refreshToken(String refreshToken) async {
    return Left(AuthFailure(message: 'Token refresh tidak didukung', isTokenExpired: true));
  }

  @override
  Future<Either<Failure, void>> forgotPassword(String email) async {
    return Left(ServerFailure(message: 'Fitur lupa password belum tersedia'));
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String email,
    required String password,
    required String passwordConfirmation,
    required String token,
  }) async {
    return Left(ServerFailure(message: 'Fitur reset password belum tersedia'));
  }

  @override
  Future<Either<Failure, void>> verifyEmail(int id, String hash) async {
    return Left(ServerFailure(message: 'Fitur verifikasi email belum tersedia'));
  }

  @override
  Future<Either<Failure, void>> resendVerificationEmail() async {
    return Left(ServerFailure(message: 'Fitur verifikasi email belum tersedia'));
  }
}
