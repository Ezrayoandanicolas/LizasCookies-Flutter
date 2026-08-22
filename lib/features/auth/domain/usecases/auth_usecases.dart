import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/auth_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;
  LoginUseCase(this._repository);

  Future<Either<Failure, AuthTokens>> call({
    required String email,
    required String password,
    String? deviceName,
  }) => _repository.login(email: email, password: password, deviceName: deviceName);
}

class RegisterUseCase {
  final AuthRepository _repository;
  RegisterUseCase(this._repository);

  Future<Either<Failure, AuthTokens>> call({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
    String? deviceName,
  }) => _repository.register(
    name: name, email: email, password: password,
    passwordConfirmation: passwordConfirmation, phone: phone, deviceName: deviceName,
  );
}

class LogoutUseCase {
  final AuthRepository _repository;
  LogoutUseCase(this._repository);
  Future<Either<Failure, void>> call() => _repository.logout();
}

class GetProfileUseCase {
  final AuthRepository _repository;
  GetProfileUseCase(this._repository);
  Future<Either<Failure, UserEntity>> call() => _repository.getProfile();
}

class RefreshTokenUseCase {
  final AuthRepository _repository;
  RefreshTokenUseCase(this._repository);
  Future<Either<Failure, AuthTokens>> call(String refreshToken) => _repository.refreshToken(refreshToken);
}

class ForgotPasswordUseCase {
  final AuthRepository _repository;
  ForgotPasswordUseCase(this._repository);
  Future<Either<Failure, void>> call(String email) => _repository.forgotPassword(email);
}

class ResetPasswordUseCase {
  final AuthRepository _repository;
  ResetPasswordUseCase(this._repository);

  Future<Either<Failure, void>> call({
    required String email,
    required String password,
    required String passwordConfirmation,
    required String token,
  }) => _repository.resetPassword(
    email: email, password: password,
    passwordConfirmation: passwordConfirmation, token: token,
  );
}

class VerifyEmailUseCase {
  final AuthRepository _repository;
  VerifyEmailUseCase(this._repository);
  Future<Either<Failure, void>> call(int id, String hash) => _repository.verifyEmail(id, hash);
}

class ResendVerificationEmailUseCase {
  final AuthRepository _repository;
  ResendVerificationEmailUseCase(this._repository);
  Future<Either<Failure, void>> call() => _repository.resendVerificationEmail();
}
