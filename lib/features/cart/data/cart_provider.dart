import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartItem {
  final int productId;
  final String name;
  final double price;
  final String? image;
  int quantity;
  final String? unit;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.image,
    this.quantity = 1,
    this.unit,
  });

  double get total => price * quantity;

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
  double get total => items.fold(0.0, (sum, i) => sum + i.total);

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

  void addItem(int productId, String name, double price, {String? image, String? unit}) {
    final existing = state.items.indexWhere((i) => i.productId == productId);
    if (existing >= 0) {
      final updated = List<CartItem>.from(state.items);
      updated[existing].quantity += 1;
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(
        items: [...state.items, CartItem(
          productId: productId, name: name, price: price, image: image, unit: unit,
        )],
      );
    }
  }

  void removeItem(int productId) {
    state = state.copyWith(
      items: state.items.where((i) => i.productId != productId).toList(),
    );
  }

  void updateQuantity(int productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    final updated = List<CartItem>.from(state.items);
    final idx = updated.indexWhere((i) => i.productId == productId);
    if (idx >= 0) {
      updated[idx].quantity = quantity;
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
