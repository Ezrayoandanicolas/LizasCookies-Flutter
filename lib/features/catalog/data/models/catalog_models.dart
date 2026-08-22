import '../../domain/entities/catalog_entity.dart';
import '../../../../core/utils/image_helper.dart';

class ProductResponse {
  final int id;
  final String name;
  final double price;
  final String description;
  final String? thumbnail;
  final List<String> images;
  final int categoryId;
  final String? categoryName;
  final String? sku;
  final String? unitName;
  final String? createdAt;

  const ProductResponse({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    this.thumbnail,
    this.images = const [],
    required this.categoryId,
    this.categoryName,
    this.sku,
    this.unitName,
    this.createdAt,
  });

  factory ProductResponse.fromJson(Map<String, dynamic> json) {
    final mediaList = json['media'] as List<dynamic>?;
    final images = <String>[];
    if (json['thumbnail'] != null) {
      final resolved = ImageHelper.resolve(json['thumbnail'].toString());
      if (resolved.isNotEmpty) images.add(resolved);
    }
    if (mediaList != null) {
      for (final m in mediaList) {
        if (m is Map && m['path'] != null) {
          final resolved = ImageHelper.resolve(m['path'].toString());
          if (resolved.isNotEmpty && !images.contains(resolved)) images.add(resolved);
        }
      }
    }

    final category = json['category'];
    final categoryName = category is Map ? category['name']?.toString() : null;

    final unit = json['unit'];
    final unitName = unit is Map ? unit['name']?.toString() : null;

    return ProductResponse(
      id: (json['id'] ?? 0).toInt(),
      name: (json['name'] ?? '').toString(),
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      description: (json['description'] ?? '').toString(),
      thumbnail: ImageHelper.resolve(json['thumbnail']?.toString()),
      images: images,
      categoryId: (json['category_id'] ?? 0).toInt(),
      categoryName: categoryName,
      sku: json['sku']?.toString(),
      unitName: unitName,
      createdAt: json['created_at']?.toString(),
    );
  }

  ProductEntity toEntity() => ProductEntity(
        id: id.toString(),
        name: name,
        slug: name.toLowerCase().replaceAll(' ', '-'),
        price: price,
        description: description,
        images: images,
        categoryId: categoryId.toString(),
        categoryName: categoryName,
        stock: 0,
        createdAt: createdAt != null ? DateTime.tryParse(createdAt!) : null,
      );
}

class CategoryResponse {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final int productCount;

  const CategoryResponse({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.imageUrl,
    this.productCount = 0,
  });

  factory CategoryResponse.fromJson(Map<String, dynamic> json) {
    return CategoryResponse(
      id: (json['id'] ?? 0).toInt(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      description: json['description']?.toString(),
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString(),
      productCount: (json['product_count'] ?? 0).toInt(),
    );
  }

  CategoryEntity toEntity() => CategoryEntity(
        id: id.toString(),
        name: name,
        slug: slug,
        description: description,
        imageUrl: imageUrl,
        productCount: productCount,
      );
}

class BannerResponse {
  final String id;
  final String imageUrl;
  final String? title;
  final String? link;
  final int sortOrder;

  const BannerResponse({
    required this.id,
    required this.imageUrl,
    this.title,
    this.link,
    this.sortOrder = 0,
  });

  factory BannerResponse.fromJson(Map<String, dynamic> json) {
    return BannerResponse(
      id: (json['id'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? json['image'] ?? '').toString(),
      title: json['title']?.toString(),
      link: json['link']?.toString(),
      sortOrder: (json['sort_order'] ?? 0).toInt(),
    );
  }

  BannerEntity toEntity() => BannerEntity(
        id: id,
        imageUrl: imageUrl,
        title: title,
        link: link,
        sortOrder: sortOrder,
      );
}

class PaginatedResponse<T> {
  final List<T> data;
  final int total;
  final int page;
  final int lastPage;

  const PaginatedResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.lastPage,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PaginatedResponse(
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => fromJsonT(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: (json['total'] ?? 0).toInt(),
      page: (json['current_page'] ?? 1).toInt(),
      lastPage: (json['last_page'] ?? 1).toInt(),
    );
  }
}
