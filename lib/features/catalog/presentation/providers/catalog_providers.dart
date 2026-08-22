import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/catalog_remote_data_source.dart';
import '../../data/repositories/catalog_repository_impl.dart';
import '../../domain/entities/catalog_entity.dart';
import '../../domain/usecases/catalog_usecases.dart';
import '../../../../core/network/dio_client.dart';

// Data source
final catalogRemoteDataSourceProvider = Provider<CatalogRemoteDataSource>(
  (ref) => CatalogRemoteDataSource(ref.watch(dioClientProvider).dio),
);

// Repository
final catalogRepositoryProvider = Provider<CatalogRepositoryImpl>(
  (ref) => CatalogRepositoryImpl(ref.watch(catalogRemoteDataSourceProvider)),
);

// Use cases
final getProductsProvider = Provider<GetProductsUseCase>(
  (ref) => GetProductsUseCase(ref.watch(catalogRepositoryProvider)),
);

final getProductDetailProvider = Provider<GetProductDetailUseCase>(
  (ref) => GetProductDetailUseCase(ref.watch(catalogRepositoryProvider)),
);

final getCategoriesProvider = Provider<GetCategoriesUseCase>(
  (ref) => GetCategoriesUseCase(ref.watch(catalogRepositoryProvider)),
);

final getFeaturedProductsProvider = Provider<GetFeaturedProductsUseCase>(
  (ref) => GetFeaturedProductsUseCase(ref.watch(catalogRepositoryProvider)),
);

final searchProductsProvider = Provider<SearchProductsUseCase>(
  (ref) => SearchProductsUseCase(ref.watch(catalogRepositoryProvider)),
);

// Notifiers
class ProductsNotifier extends StateNotifier<AsyncValue<List<ProductEntity>>> {
  final GetProductsUseCase _getProducts;
  int _page = 1;
  bool _hasMore = true;

  ProductsNotifier(this._getProducts) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({String? categoryId, String? search}) async {
    _page = 1;
    _hasMore = true;
    state = const AsyncValue.loading();
    final result = await _getProducts(page: 1, categoryId: categoryId, search: search);
    result.fold(
      (failure) => state = AsyncValue.error(failure, StackTrace.current),
      (products) {
        _hasMore = products.length >= 20;
        state = AsyncValue.data(products);
      },
    );
  }

  Future<void> loadMore({String? categoryId, String? search}) async {
    if (!_hasMore) return;
    _page++;
    final result = await _getProducts(page: _page, categoryId: categoryId, search: search);
    result.fold(
      (failure) => null,
      (products) {
        _hasMore = products.length >= 20;
        final current = state.valueOrNull ?? [];
        state = AsyncValue.data([...current, ...products]);
      },
    );
  }
}

final productsProvider =
    StateNotifierProvider<ProductsNotifier, AsyncValue<List<ProductEntity>>>((ref) {
  return ProductsNotifier(ref.watch(getProductsProvider));
});

class ProductDetailNotifier extends StateNotifier<AsyncValue<ProductEntity?>> {
  final GetProductDetailUseCase _getDetail;

  ProductDetailNotifier(this._getDetail) : super(const AsyncValue.data(null));

  Future<void> load(String id) async {
    state = const AsyncValue.loading();
    final result = await _getDetail(id);
    result.fold(
      (failure) => state = AsyncValue.error(failure, StackTrace.current),
      (product) => state = AsyncValue.data(product),
    );
  }
}

final productDetailProvider =
    StateNotifierProvider<ProductDetailNotifier, AsyncValue<ProductEntity?>>((ref) {
  return ProductDetailNotifier(ref.watch(getProductDetailProvider));
});

class CategoriesNotifier extends StateNotifier<AsyncValue<List<CategoryEntity>>> {
  final GetCategoriesUseCase _getCategories;

  CategoriesNotifier(this._getCategories) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    final result = await _getCategories();
    result.fold(
      (failure) => state = AsyncValue.error(failure, StackTrace.current),
      (categories) => state = AsyncValue.data(categories),
    );
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, AsyncValue<List<CategoryEntity>>>((ref) {
  return CategoriesNotifier(ref.watch(getCategoriesProvider));
});

class SearchNotifier extends StateNotifier<AsyncValue<List<ProductEntity>>> {
  final SearchProductsUseCase _search;
  String _lastQuery = '';

  SearchNotifier(this._search) : super(const AsyncValue.data([]));

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    _lastQuery = query;
    state = const AsyncValue.loading();
    final result = await _search(query);
    result.fold(
      (failure) => state = AsyncValue.error(failure, StackTrace.current),
      (products) => state = AsyncValue.data(products),
    );
  }

  void clear() {
    _lastQuery = '';
    state = const AsyncValue.data([]);
  }
}

final searchNotifierProvider =
    StateNotifierProvider<SearchNotifier, AsyncValue<List<ProductEntity>>>((ref) {
  return SearchNotifier(ref.watch(searchProductsProvider));
});
