import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/cart_local_data_source.dart';
import '../../domain/entities/cart_entity.dart';

final cartDataSourceProvider = Provider<CartLocalDataSource>(
  (ref) => CartLocalDataSource(),
);

class CartNotifier extends StateNotifier<CartEntity> {
  final CartLocalDataSource _dataSource;

  CartNotifier(this._dataSource) : super(const CartEntity()) {
    _load();
  }

  Future<void> _load() async {
    final items = await _dataSource.loadCart();
    state = CartEntity(
      items: items.map((e) => CartItemEntity.fromJson(e)).toList(),
    );
  }

  Future<void> _save() async {
    final items = state.items.map((e) => e.toJson()).toList();
    await _dataSource.saveCart(items);
  }

  Future<void> addItem({
    required String productId,
    required String name,
    required double price,
    double? discountPrice,
    String? imageUrl,
    int quantity = 1,
    String? variant,
    int maxStock = 99,
  }) async {
    final existing = state.items.where((i) => i.productId == productId && i.variant == variant).toList();
    if (existing.isNotEmpty) {
      final item = existing.first;
      final newQty = (item.quantity + quantity).clamp(1, maxStock);
      state = CartEntity(
        items: state.items.map((i) {
          if (i.productId == productId && i.variant == variant) {
            return i.copyWith(quantity: newQty);
          }
          return i;
        }).toList(),
      );
    } else {
      state = CartEntity(
        items: [
          ...state.items,
          CartItemEntity(
            productId: productId,
            name: name,
            price: price,
            discountPrice: discountPrice,
            imageUrl: imageUrl,
            quantity: quantity,
            variant: variant,
            maxStock: maxStock,
          ),
        ],
      );
    }
    await _save();
  }

  Future<void> updateQuantity(String productId, int quantity, {String? variant}) async {
    if (quantity <= 0) {
      removeItem(productId, variant: variant);
      return;
    }
    state = CartEntity(
      items: state.items.map((i) {
        if (i.productId == productId && i.variant == variant) {
          return i.copyWith(quantity: quantity.clamp(1, i.maxStock));
        }
        return i;
      }).toList(),
    );
    await _save();
  }

  Future<void> removeItem(String productId, {String? variant}) async {
    state = CartEntity(
      items: state.items.where((i) => !(i.productId == productId && i.variant == variant)).toList(),
    );
    await _save();
  }

  Future<void> clear() async {
    state = const CartEntity();
    await _dataSource.clearCart();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartEntity>((ref) {
  return CartNotifier(ref.watch(cartDataSourceProvider));
});

final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).totalItems;
});

final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).subtotal;
});
