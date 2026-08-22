import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

sealed class Failure {
  const Failure();
}

class ServerFailure extends Failure {
  final int statusCode;
  final String message;
  final String? code;
  const ServerFailure({this.statusCode = 0, required this.message, this.code});
}

class NetworkFailure extends Failure {
  final String message;
  final String? code;
  const NetworkFailure({required this.message, this.code});
}

class CacheFailure extends Failure {
  final String message;
  const CacheFailure({required this.message});
}

class AuthFailure extends Failure {
  final String message;
  final bool isTokenExpired;
  const AuthFailure({required this.message, required this.isTokenExpired});
}

class ValidationFailure extends Failure {
  final Map<String, List<String>> errors;
  const ValidationFailure({required this.errors});
}

class UnknownFailure extends Failure {
  final String message;
  const UnknownFailure({required this.message});
}

class NotFoundFailure extends Failure {
  final String message;
  const NotFoundFailure({required this.message});
}

class ForbiddenFailure extends Failure {
  final String message;
  const ForbiddenFailure({required this.message});
}

extension FailureX on Failure {
  String get userMessage {
    return switch (this) {
      ServerFailure(:final message) => message,
      NetworkFailure() => 'Tidak ada koneksi internet. Periksa koneksi Anda.',
      CacheFailure() => 'Terjadi kesalahan penyimpanan lokal.',
      AuthFailure(:final message, :final isTokenExpired) => isTokenExpired
          ? 'Sesi Anda telah berakhir. Silakan login kembali.'
          : message,
      ValidationFailure(:final errors) => errors.values.first.first,
      UnknownFailure() => 'Terjadi kesalahan tidak diketahui. Coba lagi nanti.',
      NotFoundFailure() => 'Data tidak ditemukan.',
      ForbiddenFailure() => 'Anda tidak memiliki akses ke fitur ini.',
    };
  }

  bool get isAuthError => this is AuthFailure;
  bool get isNetworkError => this is NetworkFailure;
}

Failure handleDioError(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return const NetworkFailure(message: 'Koneksi timeout. Coba lagi.');
    case DioExceptionType.badResponse:
      final statusCode = error.response?.statusCode ?? 0;
      final data = error.response?.data;
      String message = 'Terjadi kesalahan server';
      String? code;
      if (data is Map) {
        message = data['message']?.toString() ?? message;
        code = data['code']?.toString();
      }
      if (statusCode == 401) {
        return const AuthFailure(
          message: 'Sesi berakhir. Silakan login kembali.',
          isTokenExpired: true,
        );
      }
      if (statusCode == 403) return ForbiddenFailure(message: message);
      if (statusCode == 404) return NotFoundFailure(message: message);
      if (statusCode == 422) {
        final errors = <String, List<String>>{};
        if (data is Map && data['errors'] is Map) {
          (data['errors'] as Map).forEach((key, value) {
            errors[key.toString()] = List<String>.from(value as Iterable);
          });
        }
        return ValidationFailure(errors: errors);
      }
      return ServerFailure(statusCode: statusCode, message: message, code: code);
    case DioExceptionType.cancel:
      return const NetworkFailure(message: 'Permintaan dibatalkan.');
    case DioExceptionType.unknown:
      return UnknownFailure(message: error.message ?? 'Kesalahan tidak diketahui');
    case DioExceptionType.badCertificate:
      return const NetworkFailure(message: 'Kesalahan keamanan sertifikat.');
    default:
      return const NetworkFailure(message: 'Kesalahan koneksi.');
  }
}
