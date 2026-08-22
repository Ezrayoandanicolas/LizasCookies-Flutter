import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';

class CartItem {
  final int productId;
  final String name;
  final double price;
  final double? discountPrice;
  final String? image;
  int quantity;
  final String? unit;
  final String? variant;
  final int maxStock;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.discountPrice,
    this.image,
    this.quantity = 1,
    this.unit,
    this.variant,
    this.maxStock = 99,
  });

  double get total => (discountPrice ?? price) * quantity;

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'name': name,
    'price': price,
    'discount_price': discountPrice,
    'image': image,
    'quantity': quantity,
    'unit': unit,
    'variant': variant,
    'max_stock': maxStock,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    productId: json['product_id'] as int,
    name: json['name'] as String,
    price: (json['price'] as num).toDouble(),
    discountPrice: json['discount_price'] != null
        ? (json['discount_price'] as num).toDouble()
        : null,
    image: json['image'] as String?,
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    unit: json['unit'] as String?,
    variant: json['variant'] as String?,
    maxStock: (json['max_stock'] as num?)?.toInt() ?? 99,
  );
}

class CartState {
  final List<CartItem> items;
  final int? storeId;
  final int? tenantId;

  CartState({this.items = const [], this.storeId, this.tenantId});

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
  int get totalItems => itemCount;
  double get total => items.fold(0.0, (sum, i) => sum + i.total);
  double get subtotal => total;
  bool get isEmpty => items.isEmpty;

  CartState copyWith({List<CartItem>? items, int? storeId, int? tenantId}) {
    return CartState(
      items: items ?? this.items,
      storeId: storeId ?? this.storeId,
      tenantId: tenantId ?? this.tenantId,
    );
  }

  String toJson() => jsonEncode(items.map((i) => i.toJson()).toList());

  factory CartState.fromJson(String jsonString) {
    final list = jsonDecode(jsonString) as List;
    return CartState(
      items: list.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState()) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final json = LocalStorage.getCart();
    if (json != null && json.isNotEmpty) {
      try {
        state = CartState.fromJson(json);
      } catch (_) {}
    }
  }

  void _saveToStorage() {
    LocalStorage.saveCart(state.toJson());
  }

  void addItem(int productId, String name, double price, {String? image, String? unit, String? variant, double? discountPrice, int maxStock = 99}) {
    final existing = state.items.where((i) => i.productId == productId && i.variant == variant).toList();
    if (existing.isNotEmpty) {
      final updated = List<CartItem>.from(state.items);
      final idx = updated.indexWhere((i) => i.productId == productId && i.variant == variant);
      updated[idx].quantity += 1;
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(
        items: [...state.items, CartItem(
          productId: productId, name: name, price: price, image: image, unit: unit, variant: variant, discountPrice: discountPrice, maxStock: maxStock,
        )],
      );
    }
    _saveToStorage();
  }

  void removeItem(int productId, {String? variant}) {
    state = state.copyWith(
      items: state.items.where((i) => !(i.productId == productId && i.variant == variant)).toList(),
    );
    _saveToStorage();
  }

  void updateQuantity(int productId, int quantity, {String? variant}) {
    if (quantity <= 0) {
      removeItem(productId, variant: variant);
      return;
    }
    final updated = List<CartItem>.from(state.items);
    final idx = updated.indexWhere((i) => i.productId == productId && i.variant == variant);
    if (idx >= 0) {
      updated[idx].quantity = quantity.clamp(1, updated[idx].maxStock);
      state = state.copyWith(items: updated);
      _saveToStorage();
    }
  }

  void setStore(int storeId) {
    state = state.copyWith(storeId: storeId);
  }

  void clear() {
    state = CartState();
    LocalStorage.clearCart();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).totalItems;
});

final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).subtotal;
});
