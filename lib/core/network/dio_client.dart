// Dio HTTP client setup with interceptors

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../config/app_config.dart';
import '../errors/failures.dart';
import '../storage/secure_storage.dart';

class DioClient {
  final Dio _dio;
  final Ref _ref;

  DioClient(this._ref) : _dio = Dio() {
    _configureDio();
    _addInterceptors();
  }

  Dio get dio => _dio;

  void _configureDio() {
    final config = AppConfig.instance;
    _dio.options
      ..baseUrl = config.apiBaseUrl
      ..connectTimeout = AppConstants.connectTimeout
      ..receiveTimeout = AppConstants.apiTimeout
      ..sendTimeout = AppConstants.apiTimeout
      ..headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
      }
      ..validateStatus = (status) => status != null && status < 500;
  }

  void _addInterceptors() {
    final config = AppConfig.instance;

    // Auth interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final secureStorage = _ref.read(secureStorageProvider);
        final token = await secureStorage.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // Set X-Store-Id from saved store selection
        final storeId = await secureStorage.getSelectedStoreId();
        if (storeId != null) {
          options.headers['X-Store-Id'] = storeId.toString();
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final secureStorage = _ref.read(secureStorageProvider);
          await secureStorage.clearTokens();
        }
        handler.next(error);
      },
    ));

    // Logging interceptor (dev/staging only)
    if (config.enableLogging) {
      _dio.interceptors.add(PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
        compact: false,
        maxWidth: 120,
      ));
    }
  }

}

final dioClientProvider = Provider<DioClient>((ref) => DioClient(ref));

// Retrofit API interfaces will be generated here
// Example:
/*
@RestApi()
abstract class ApiService {
  factory ApiService(Dio dio) = _ApiService;

  @POST('/v1/login')
  Future<ApiResponse<AuthResponse>> login(@Body() LoginRequest request);

  @POST('/v1/register')
  Future<ApiResponse<AuthResponse>> register(@Body() RegisterRequest request);

  @GET('/v1/user')
  Future<ApiResponse<User>> getProfile();

  @GET('/member/products')
  Future<ApiResponse<PaginatedResponse<Product>>> getProducts({
    @Query('page') int page = 1,
    @Query('per_page') int perPage = 20,
    @Query('category') String? category,
    @Query('search') String? search,
  });
}
*/