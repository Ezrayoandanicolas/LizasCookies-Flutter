import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CartLocalDataSource {
  final FlutterSecureStorage _storage;
  static const _cartKey = 'cart_items';

  CartLocalDataSource([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<List<Map<String, dynamic>>> loadCart() async {
    final json = await _storage.read(key: _cartKey);
    if (json == null) return [];
    final List<dynamic> decoded = jsonDecode(json);
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> saveCart(List<Map<String, dynamic>> items) async {
    await _storage.write(key: _cartKey, value: jsonEncode(items));
  }

  Future<void> clearCart() async {
    await _storage.delete(key: _cartKey);
  }
}
