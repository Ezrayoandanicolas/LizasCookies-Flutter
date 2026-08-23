import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/connectivity_provider.dart' show connectivityProvider, ConnectivityStatus;
import '../../../core/providers/tenant_provider.dart';
import '../../../core/providers/store_provider.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/utils/image_helper.dart';

class ProductItem {
  final int id;
  final String name;
  final String? sku;
  final double price;
  final String? image;
  final String? categoryName;
  final String? type;
  final int stock;

  ProductItem({
    required this.id,
    required this.name,
    this.sku,
    required this.price,
    this.image,
    this.categoryName,
    this.type,
    this.stock = 0,
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    String? img;
    if (json['thumbnail'] != null && json['thumbnail'].toString().isNotEmpty) {
      img = ImageHelper.resolve(json['thumbnail'].toString());
    } else if (json['media'] != null && (json['media'] as List).isNotEmpty) {
      img = ImageHelper.resolve(json['media'][0]['path']?.toString());
    }

    double price = 0;
    if (json['price'] != null) {
      price = double.tryParse(json['price'].toString()) ?? 0;
    }

    String? catName;
    if (json['category'] is Map) {
      catName = json['category']['name']?.toString();
    }

    int stock = 0;
    if (json['store_stock'] != null) {
      stock = double.tryParse(json['store_stock'].toString())?.round() ?? 0;
    } else if (json['stock'] != null) {
      stock = double.tryParse(json['stock'].toString())?.round() ?? 0;
    }

    return ProductItem(
      id: (json['id'] ?? 0).toInt(),
      name: (json['name'] ?? '-').toString(),
      sku: json['sku']?.toString(),
      price: price,
      image: img,
      categoryName: catName,
      type: json['type']?.toString(),
      stock: stock,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sku': sku,
    'price': price,
    'thumbnail': image,
    'category': categoryName != null ? {'name': categoryName} : null,
    'type': type,
    'stock': stock,
  };
}

class ProductsNotifier extends StateNotifier<AsyncValue<List<ProductItem>>> {
  final Dio _dio;
  final Map<String, dynamic> _tenantQp;
  final Map<String, dynamic> _storeQp;
  final Ref _ref;

  ProductsNotifier(this._dio, this._tenantQp, this._storeQp, this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  String get _cacheKey {
    final storeId = _storeQp['store_id'] ?? 'all';
    return 'products_$storeId';
  }

  Future<void> load({String? search}) async {
    state = const AsyncValue.loading();

    final cached = LocalStorage.getCachedProducts(_cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final list = jsonDecode(cached) as List;
        state = AsyncValue.data(list.map((e) => ProductItem.fromJson(e as Map<String, dynamic>)).toList());
      } catch (_) {}
    }

    final connectivity = _ref.read(connectivityProvider);
    if (connectivity == ConnectivityStatus.offline) {
      if (state is! AsyncData) {
        state = const AsyncValue.data([]);
      }
      return;
    }

    try {
      final params = <String, dynamic>{..._tenantQp, ..._storeQp, 'per_page': 100};
      if (search != null && search.isNotEmpty) params['search'] = search;

      String endpoint = '/member/products';
      if (_storeQp.containsKey('store_id')) {
        endpoint = '/cashier/pos/products';
      }

      final res = await _dio.get(endpoint, queryParameters: params);
      final data = res.data;
      List list;
      if (data is Map && data.containsKey('data')) {
        list = data['data'];
      } else if (data is List) {
        list = data;
      } else {
        list = [];
      }

      final products = list.map((e) => ProductItem.fromJson(e)).toList();
      state = AsyncValue.data(products);

      final encoded = jsonEncode(list);
      LocalStorage.cacheProducts(_cacheKey, encoded);
    } catch (e, st) {
      if (state is AsyncData) return;
      state = AsyncValue.error(e, st);
    }
  }
}

final productsProvider = StateNotifierProvider<ProductsNotifier, AsyncValue<List<ProductItem>>>((ref) {
  final dio = ref.watch(dioClientProvider).dio;
  final tenantQp = ref.watch(tenantQueryProvider).valueOrNull ?? <String, dynamic>{};
  final storeQp = ref.watch(storeQueryProvider).valueOrNull ?? <String, dynamic>{};
  return ProductsNotifier(dio, tenantQp, storeQp, ref);
});

final productsCacheProvider = Provider<List<ProductItem>>((ref) {
  final asyncProducts = ref.watch(productsProvider);
  return asyncProducts.valueOrNull ?? [];
});
