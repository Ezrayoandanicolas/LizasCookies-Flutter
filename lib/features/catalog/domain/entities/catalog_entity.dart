class ProductEntity {
  final String id;
  final String name;
  final String slug;
  final double price;
  final double? discountPrice;
  final String description;
  final List<String> images;
  final String categoryId;
  final String? categoryName;
  final int stock;
  final double rating;
  final int reviewCount;
  final bool isFeatured;
  final bool isNewArrival;
  final bool isBestSeller;
  final Map<String, String>? variants;
  final DateTime? createdAt;

  const ProductEntity({
    required this.id,
    required this.name,
    required this.slug,
    required this.price,
    this.discountPrice,
    required this.description,
    required this.images,
    required this.categoryId,
    this.categoryName,
    this.stock = 0,
    this.rating = 0,
    this.reviewCount = 0,
    this.isFeatured = false,
    this.isNewArrival = false,
    this.isBestSeller = false,
    this.variants,
    this.createdAt,
  });
}

class CategoryEntity {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final int productCount;

  const CategoryEntity({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.imageUrl,
    this.productCount = 0,
  });
}

class BannerEntity {
  final String id;
  final String imageUrl;
  final String? title;
  final String? link;
  final int sortOrder;

  const BannerEntity({
    required this.id,
    required this.imageUrl,
    this.title,
    this.link,
    this.sortOrder = 0,
  });
}
