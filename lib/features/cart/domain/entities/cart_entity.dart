class CartItemEntity {
  final String productId;
  final String name;
  final double price;
  final double? discountPrice;
  final String? imageUrl;
  final int quantity;
  final String? variant;
  final int maxStock;

  const CartItemEntity({
    required this.productId,
    required this.name,
    required this.price,
    this.discountPrice,
    this.imageUrl,
    this.quantity = 1,
    this.variant,
    this.maxStock = 99,
  });

  CartItemEntity copyWith({
    String? productId,
    String? name,
    double? price,
    double? discountPrice,
    String? imageUrl,
    int? quantity,
    String? variant,
    int? maxStock,
  }) {
    return CartItemEntity(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      discountPrice: discountPrice ?? this.discountPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
      variant: variant ?? this.variant,
      maxStock: maxStock ?? this.maxStock,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'name': name,
        'price': price,
        'discount_price': discountPrice,
        'image_url': imageUrl,
        'quantity': quantity,
        'variant': variant,
        'max_stock': maxStock,
      };

  factory CartItemEntity.fromJson(Map<String, dynamic> json) {
    return CartItemEntity(
      productId: (json['product_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: (json['price'] ?? 0).toDouble(),
      discountPrice: json['discount_price']?.toDouble(),
      imageUrl: json['image_url']?.toString(),
      quantity: (json['quantity'] ?? 1).toInt(),
      variant: json['variant']?.toString(),
      maxStock: (json['max_stock'] ?? 99).toInt(),
    );
  }
}

class CartEntity {
  final List<CartItemEntity> items;

  const CartEntity({this.items = const []});

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => items.fold(0, (sum, item) {
        final price = item.discountPrice ?? item.price;
        return sum + (price * item.quantity);
      });

  bool get isEmpty => items.isEmpty;
}
