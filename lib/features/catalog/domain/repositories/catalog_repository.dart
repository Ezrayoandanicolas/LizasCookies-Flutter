import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/catalog_entity.dart';

abstract class CatalogRepository {
  Future<Either<Failure, List<ProductEntity>>> getProducts({
    int page = 1,
    int limit = 20,
    String? categoryId,
    String? search,
    String? sort,
  });

  Future<Either<Failure, ProductEntity>> getProductDetail(String id);

  Future<Either<Failure, List<CategoryEntity>>> getCategories();

  Future<Either<Failure, List<ProductEntity>>> getFeaturedProducts();

  Future<Either<Failure, List<ProductEntity>>> getNewArrivals();

  Future<Either<Failure, List<ProductEntity>>> getBestSellers();

  Future<Either<Failure, List<BannerEntity>>> getBanners();

  Future<Either<Failure, List<ProductEntity>>> searchProducts(String query);
}
