import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    'quantity': quantity,
    if (unit != null) 'unit': unit,
  };
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
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState());

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
  }

  void removeItem(int productId, {String? variant}) {
    state = state.copyWith(
      items: state.items.where((i) => !(i.productId == productId && i.variant == variant)).toList(),
    );
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
    }
  }

  void setStore(int storeId) {
    state = state.copyWith(storeId: storeId);
  }

  void clear() {
    state = CartState();
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
