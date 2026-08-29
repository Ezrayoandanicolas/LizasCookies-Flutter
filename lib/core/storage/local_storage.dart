// Local storage using Hive for offline caching

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';

class LocalStorage {
  static late Box _cartBox;
  static late Box _productsCacheBox;
  static late Box _categoriesCacheBox;
  static late Box _addressesBox;
  static late Box _notificationsBox;
  static late Box _syncQueueBox;
  static late Box _offlineOrdersBox;
  static late Box _offlineStockBox;
  static late Box _syncHistoryBox;
  static late Box _localOrdersBox;

  static Future<void> init() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocDir.path);

    _cartBox = await Hive.openBox(AppConstants.cartBoxName);
    _productsCacheBox = await Hive.openBox(AppConstants.productsCacheBoxName);
    _categoriesCacheBox = await Hive.openBox(AppConstants.categoriesCacheBoxName);
    _addressesBox = await Hive.openBox(AppConstants.addressesBoxName);
    _notificationsBox = await Hive.openBox(AppConstants.notificationsBoxName);
    _syncQueueBox = await Hive.openBox(AppConstants.syncQueueBoxName);
    _offlineOrdersBox = await Hive.openBox(AppConstants.offlineOrdersBoxName);
    _offlineStockBox = await Hive.openBox(AppConstants.offlineStockBoxName);
    _syncHistoryBox = await Hive.openBox(AppConstants.syncHistoryBoxName);
    _localOrdersBox = await Hive.openBox(AppConstants.localOrdersBoxName);
  }

  // Cart
  static Box get cartBox => _cartBox;

  static Future<void> saveCart(String json) async =>
      _cartBox.put('cart', json);

  static String? getCart() => _cartBox.get('cart');

  static Future<void> clearCart() async => _cartBox.delete('cart');

  // Products Cache
  static Box get productsCacheBox => _productsCacheBox;

  static Future<void> cacheProducts(String key, String json) async =>
      _productsCacheBox.put(key, json);

  static String? getCachedProducts(String key) => _productsCacheBox.get(key);

  static Future<void> clearProductsCache() async => _productsCacheBox.clear();

  // Categories Cache
  static Box get categoriesCacheBox => _categoriesCacheBox;

  static Future<void> cacheCategories(String json) async =>
      _categoriesCacheBox.put('categories', json);

  static String? getCachedCategories() => _categoriesCacheBox.get('categories');

  static Future<void> clearCategoriesCache() async => _categoriesCacheBox.clear();

  // Addresses
  static Box get addressesBox => _addressesBox;

  static Future<void> saveAddresses(String json) async =>
      _addressesBox.put('addresses', json);

  static String? getAddresses() => _addressesBox.get('addresses');

  static Future<void> clearAddresses() async => _addressesBox.delete('addresses');

  // Notifications
  static Box get notificationsBox => _notificationsBox;

  static Future<void> saveNotifications(String json) async =>
      _notificationsBox.put('notifications', json);

  static String? getNotifications() => _notificationsBox.get('notifications');

  static Future<void> clearNotifications() async => _notificationsBox.delete('notifications');

  // Sync Queue
  static Box get syncQueueBox => _syncQueueBox;

  // Offline Orders
  static Box get offlineOrdersBox => _offlineOrdersBox;

  static Future<void> saveOfflineOrder(String key, Map<String, dynamic> order) async =>
      _offlineOrdersBox.put(key, order);

  static Map<String, dynamic>? getOfflineOrder(String key) =>
      _offlineOrdersBox.get(key);

  static List<Map<String, dynamic>> getAllPendingOrders() {
    return _offlineOrdersBox.values
        .where((e) => e is Map)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<void> removeOfflineOrder(String key) async =>
      _offlineOrdersBox.delete(key);

  // Offline Stock
  static Box get offlineStockBox => _offlineStockBox;

  // Sync History
  static Box get syncHistoryBox => _syncHistoryBox;

  static Future<void> addSyncHistory(Map<String, dynamic> item) async {
    await _syncHistoryBox.put(item['id'], item);
  }

  static List<Map<String, dynamic>> getAllSyncHistory() {
    final items = _syncHistoryBox.values
        .where((e) => e is Map)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    items.sort((a, b) {
      final ta = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2000);
      final tb = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2000);
      return tb.compareTo(ta);
    });
    return items;
  }

  static Future<void> clearSyncHistory() async => _syncHistoryBox.clear();

  // Local Orders (for full offline mode)
  static Box get localOrdersBox => _localOrdersBox;

  static Future<void> saveLocalOrder(String key, Map<String, dynamic> order) async =>
      _localOrdersBox.put(key, order);

  static Map<String, dynamic>? getLocalOrder(String key) =>
      _localOrdersBox.get(key);

  static List<Map<String, dynamic>> getAllLocalOrders() {
    return _localOrdersBox.values
        .where((e) => e is Map)
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort((a, b) {
        final ta = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
        final tb = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
        return tb.compareTo(ta);
      });
  }

  static Future<void> updateLocalOrder(String key, Map<String, dynamic> order) async =>
      _localOrdersBox.put(key, order);

  static Future<void> removeLocalOrder(String key) async =>
      _localOrdersBox.delete(key);

  static Future<void> clearLocalOrders() async => _localOrdersBox.clear();

  // Generic
  static Future<void> put(String boxName, String key, dynamic value) async {
    final box = Hive.box(boxName);
    await box.put(key, value);
  }

  static T? get<T>(String boxName, String key) {
    final box = Hive.box(boxName);
    return box.get(key);
  }

  static Future<void> delete(String boxName, String key) async {
    final box = Hive.box(boxName);
    await box.delete(key);
  }

  static Future<void> clearBox(String boxName) async {
    final box = Hive.box(boxName);
    await box.clear();
  }
}

final localStorageProvider = Provider<LocalStorage>((ref) => LocalStorage());