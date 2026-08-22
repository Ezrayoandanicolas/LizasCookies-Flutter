import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/catalog_entity.dart';
import '../repositories/catalog_repository.dart';

class GetProductsUseCase {
  final CatalogRepository _repo;
  GetProductsUseCase(this._repo);

  Future<Either<Failure, List<ProductEntity>>> call({
    int page = 1,
    int limit = 20,
    String? categoryId,
    String? search,
    String? sort,
  }) {
    return _repo.getProducts(
      page: page,
      limit: limit,
      categoryId: categoryId,
      search: search,
      sort: sort,
    );
  }
}

class GetProductDetailUseCase {
  final CatalogRepository _repo;
  GetProductDetailUseCase(this._repo);

  Future<Either<Failure, ProductEntity>> call(String id) {
    return _repo.getProductDetail(id);
  }
}

class GetCategoriesUseCase {
  final CatalogRepository _repo;
  GetCategoriesUseCase(this._repo);

  Future<Either<Failure, List<CategoryEntity>>> call() {
    return _repo.getCategories();
  }
}

class GetFeaturedProductsUseCase {
  final CatalogRepository _repo;
  GetFeaturedProductsUseCase(this._repo);

  Future<Either<Failure, List<ProductEntity>>> call() {
    return _repo.getFeaturedProducts();
  }
}

class SearchProductsUseCase {
  final CatalogRepository _repo;
  SearchProductsUseCase(this._repo);

  Future<Either<Failure, List<ProductEntity>>> call(String query) {
    return _repo.searchProducts(query);
  }
}
