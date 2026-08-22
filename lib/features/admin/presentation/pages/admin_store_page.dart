import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/providers/tenant_provider.dart';

final adminStoresProvider =
    StateNotifierProvider<AdminStoresNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final dio = ref.watch(dioClientProvider).dio;
  final tenantQp = ref.watch(tenantQueryProvider).valueOrNull ?? <String, dynamic>{};
  return AdminStoresNotifier(dio, tenantQp);
});

class AdminStoresNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Dio _dio;
  final Map<String, dynamic> _tenantQp;

  AdminStoresNotifier(this._dio, this._tenantQp) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final res = await _dio.get('/superadmin/stores', queryParameters: _tenantQp);
      final data = res.data;
      List list;
      if (data is List) {
        list = data;
      } else if (data is Map && data.containsKey('data')) {
        list = data['data'];
      } else {
        list = [];
      }
      state = AsyncValue.data(list.map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> add(Map<String, dynamic> payload) async {
    try {
      await _dio.post('/superadmin/stores', data: payload, queryParameters: _tenantQp);
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> update(int id, Map<String, dynamic> payload) async {
    try {
      await _dio.put('/superadmin/stores/$id', data: payload, queryParameters: _tenantQp);
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _dio.delete('/superadmin/stores/$id', queryParameters: _tenantQp);
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class AdminStorePage extends ConsumerWidget {
  const AdminStorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(adminStoresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Toko'),
        backgroundColor: const Color(0xFFE85D3A),
        foregroundColor: Colors.white,
      ),
      body: stores.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Gagal memuat: $e'),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: () => ref.read(adminStoresProvider.notifier).load(),
                child: const Text('Coba Lagi')),
          ]),
        ),
        data: (list) => list.isEmpty
            ? const Center(child: Text('Belum ada toko'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final store = list[index];
                  final isActive = store['is_active'] == true || store['is_active'] == 1;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFFE8E0),
                      child: Text(
                        (store['name'] ?? '?').toString().substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                            color: Color(0xFFE85D3A), fontWeight: FontWeight.w600),
                      ),
                    ),
                    title: Text(store['name'] ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (store['code'] != null && store['code'].toString().isNotEmpty)
                          Text('Kode: ${store['code']}', maxLines: 1),
                        if (store['address'] != null && store['address'].toString().isNotEmpty)
                          Text(store['address'], maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                            value: 'delete',
                            child: Text('Hapus', style: TextStyle(color: Colors.red))),
                      ],
                      onSelected: (v) async {
                        if (v == 'edit') {
                          _showForm(context, ref, store: store);
                        } else if (v == 'delete') {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hapus Toko'),
                              content: Text('Hapus "${store['name']}"?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Batal')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Hapus',
                                        style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            final success = await ref
                                .read(adminStoresProvider.notifier)
                                .delete(store['id']);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(success ? 'Berhasil dihapus' : 'Gagal menghapus'),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ));
                            }
                          }
                        }
                      },
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context, ref),
        backgroundColor: const Color(0xFFE85D3A),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, {Map<String, dynamic>? store}) {
    final nameCtrl = TextEditingController(text: store?['name'] ?? '');
    final codeCtrl = TextEditingController(text: store?['code'] ?? '');
    final addressCtrl = TextEditingController(text: store?['address'] ?? '');
    final phoneCtrl = TextEditingController(text: store?['phone'] ?? '');
    final isEdit = store != null;
    bool isActive = store?['is_active'] == true || store?['is_active'] == 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(isEdit ? 'Edit Toko' : 'Tambah Toko',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Toko',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE85D3A))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                decoration: InputDecoration(
                  labelText: 'Kode',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE85D3A))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Alamat',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE85D3A))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Telepon',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE85D3A))),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Aktif'),
                value: isActive,
                onChanged: (v) => setSheetState(() => isActive = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    final payload = {
                      'name': nameCtrl.text.trim(),
                      'code': codeCtrl.text.trim(),
                      'address': addressCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'is_active': isActive,
                    };
                    bool success;
                    if (isEdit) {
                      success = await ref
                          .read(adminStoresProvider.notifier)
                          .update(store!['id'], payload);
                    } else {
                      success = await ref
                          .read(adminStoresProvider.notifier)
                          .add(payload);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(success ? 'Berhasil!' : 'Gagal'),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE85D3A),
                      foregroundColor: Colors.white),
                  child: Text(isEdit ? 'Simpan' : 'Tambah'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
