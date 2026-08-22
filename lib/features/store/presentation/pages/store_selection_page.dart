import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/entities/auth_entity.dart';

class StoreSelectionPage extends ConsumerWidget {
  const StoreSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    if (authState is! Authenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = authState.user;
    final stores = user.accessibleStores;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Pilih Toko'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          if (user.isStaff)
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Lewati', style: TextStyle(color: Colors.grey)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFE85D3A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.store, size: 44, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'Halo, ${user.name}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              user.role?.toUpperCase() ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.grey, letterSpacing: 1),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Pilih toko yang ingin dikelola:', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: stores.isEmpty
                  ? const Center(child: Text('Tidak ada toko tersedia'))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: stores.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final store = stores[index];
                        return _StoreCard(
                          store: store,
                          isDefault: store.id == user.defaultStore?.id,
                          onTap: () => _selectStore(context, ref, store),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectStore(BuildContext context, WidgetRef ref, StoreEntity store) async {
    ref.read(selectedStoreProvider.notifier).state = store;
    final secureStorage = ref.read(secureStorageProvider);
    await secureStorage.saveSelectedStoreId(store.id);
    context.go('/');
  }
}

final selectedStoreProvider = StateProvider<StoreEntity?>((ref) => null);

class _StoreCard extends StatelessWidget {
  final StoreEntity store;
  final bool isDefault;
  final VoidCallback onTap;

  const _StoreCard({required this.store, required this.isDefault, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.store, color: Color(0xFFE85D3A), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          store.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE85D3A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('DEFAULT', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Kode: ${store.code}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  if (store.address != null) ...[
                    const SizedBox(height: 2),
                    Text(store.address!, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
