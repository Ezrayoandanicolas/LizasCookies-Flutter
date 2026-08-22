import 'package:dio/dio.dart';
import '../models/catalog_models.dart';

class CatalogRemoteDataSource {
  final Dio _dio;

  CatalogRemoteDataSource(this._dio);

  Future<PaginatedResponse<ProductResponse>> getProducts({
    int page = 1,
    int limit = 20,
    String? categoryId,
    String? search,
    String? sort,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'per_page': limit,
    };
    if (categoryId != null) queryParams['category_id'] = categoryId;
    if (search != null) queryParams['search'] = search;
    if (sort != null) queryParams['sort'] = sort;

    final response = await _dio.get('/member/products', queryParameters: queryParams);
    return PaginatedResponse.fromJson(
      response.data,
      (json) => ProductResponse.fromJson(json),
    );
  }

  Future<ProductResponse> getProductDetail(String id) async {
    final response = await _dio.get('/member/products/$id');
    return ProductResponse.fromJson(response.data);
  }

  Future<List<CategoryResponse>> getCategories() async {
    final response = await _dio.get('/member/categories');
    final data = response.data;
    if (data is List) {
      return data.map((e) => CategoryResponse.fromJson(e)).toList();
    }
    if (data is Map && data.containsKey('data')) {
      return (data['data'] as List).map((e) => CategoryResponse.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<BannerResponse>> getBanners() async {
    final response = await _dio.get('/public/tenant-config');
    final data = response.data;
    if (data is Map && data.containsKey('banners')) {
      final banners = data['banners'] as List? ?? [];
      return banners.map((e) => BannerResponse.fromJson(e)).toList();
    }
    return [];
  }
}
