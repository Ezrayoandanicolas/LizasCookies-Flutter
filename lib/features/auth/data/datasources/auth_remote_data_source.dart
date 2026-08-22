import 'package:dio/dio.dart';
import '../models/auth_models.dart';

class AuthRemoteDataSource {
  final Dio _dio;
  AuthRemoteDataSource(this._dio);

  Future<AuthResponse> login(LoginRequest request) async {
    final response = await _dio.post('/login', data: request.toJson());
    if (response.statusCode == 200) {
      return AuthResponse.fromJson(response.data as Map<String, dynamic>);
    }
    final errors = response.data;
    String message = 'Login gagal';
    if (errors is Map && errors.containsKey('errors')) {
      final errs = errors['errors'] as Map;
      if (errs.isNotEmpty) {
        final firstKey = errs.keys.first;
        final val = errs[firstKey];
        message = (val is List && val.isNotEmpty) ? val[0].toString() : val.toString();
      }
    } else if (errors is Map && errors.containsKey('message')) {
      message = errors['message'].toString();
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      message: message,
    );
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    final response = await _dio.post('/v1/register', data: request.toJson());
    if (response.statusCode == 200) {
      return AuthResponse.fromJson(response.data as Map<String, dynamic>);
    }
    final errors = response.data;
    String message = 'Registrasi gagal';
    if (errors is Map && errors.containsKey('errors')) {
      final errs = errors['errors'] as Map;
      if (errs.isNotEmpty) {
        final firstKey = errs.keys.first;
        final val = errs[firstKey];
        message = (val is List && val.isNotEmpty) ? val[0].toString() : val.toString();
      }
    } else if (errors is Map && errors.containsKey('message')) {
      message = errors['message'].toString();
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      message: message,
    );
  }

  Future<void> logout() async {
    await _dio.post('/logout');
  }

  Future<UserData> getProfile() async {
    final response = await _dio.get('/me');
    if (response.statusCode == 200) {
      final data = response.data;
      final userData = data is Map && data.containsKey('user')
          ? data['user'] as Map<String, dynamic>
          : data as Map<String, dynamic>;
      return UserData.fromJson(userData);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      message: 'Gagal memuat profil',
    );
  }
}
