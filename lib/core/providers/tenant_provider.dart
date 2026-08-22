import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/domain/entities/auth_entity.dart';

/// Resolves the active tenant_id: from SecureStorage (selected tenant) or user's tenant.
final activeTenantIdProvider = FutureProvider<int?>((ref) async {
  final secureStorage = ref.read(secureStorageProvider);
  final savedTenantId = await secureStorage.getSelectedTenantId();
  if (savedTenantId != null) return savedTenantId;

  final authState = ref.read(authNotifierProvider);
  if (authState is Authenticated && authState.user.tenant != null) {
    return authState.user.tenant!.id;
  }
  return null;
});

/// Resolves the active store_id: from SecureStorage (selected store) or user's default store.
final activeStoreIdProvider = FutureProvider<int?>((ref) async {
  final secureStorage = ref.read(secureStorageProvider);
  final savedStoreId = await secureStorage.getSelectedStoreId();
  if (savedStoreId != null) return savedStoreId;

  final authState = ref.read(authNotifierProvider);
  if (authState is Authenticated && authState.user.defaultStore != null) {
    return authState.user.defaultStore!.id;
  }
  return null;
});

/// Query parameters with tenant_id (used by admin endpoints).
final tenantQueryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final tenantId = await ref.watch(activeTenantIdProvider.future);
  if (tenantId != null) return {'tenant_id': tenantId};
  return {};
});
