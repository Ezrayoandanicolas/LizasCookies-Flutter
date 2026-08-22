import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../network/dio_client.dart';
import '../storage/secure_storage.dart';
import 'tenant_provider.dart';

class StoreData {
  final int id;
  final String name;
  final String code;

  StoreData({required this.id, required this.name, required this.code});

  factory StoreData.fromJson(Map<String, dynamic> json) {
    return StoreData(
      id: (json['id'] ?? 0).toInt(),
      name: (json['name'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
    );
  }
}

/// List of stores from API (for admin/cashier dropdowns).
final storeListProvider = FutureProvider<List<StoreData>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final tenantQp = ref.watch(tenantQueryProvider).valueOrNull ?? <String, dynamic>{};
  try {
    final res = await dio.get('/superadmin/stores', queryParameters: tenantQp);
    final data = res.data;
    List list;
    if (data is List) {
      list = data;
    } else if (data is Map && data.containsKey('data')) {
      list = data['data'];
    } else {
      list = [];
    }
    return list.map((e) => StoreData.fromJson(e)).toList();
  } catch (_) {
    return [];
  }
});

/// Currently selected store for admin operations (stock, POS, etc.).
/// Auto-selects first store from API list.
final selectedAdminStoreProvider = StateProvider<StoreData?>((ref) {
  final storesAsync = ref.watch(storeListProvider);
  final store = storesAsync.whenOrNull(data: (stores) => stores.isNotEmpty ? stores.first : null);
  // Auto-persist to SecureStorage
  if (store != null) {
    final secureStorage = ref.read(secureStorageProvider);
    secureStorage.saveSelectedStoreId(store.id);
  }
  return store;
});

/// Query parameters with both tenant_id and store_id.
final storeQueryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final tenantQp = await ref.watch(tenantQueryProvider.future);
  final store = ref.watch(selectedAdminStoreProvider);
  final result = Map<String, dynamic>.from(tenantQp);
  if (store != null) {
    result['store_id'] = store.id;
  }
  return result;
});
