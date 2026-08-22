import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/providers/tenant_provider.dart';

final adminExpenseCategoriesProvider =
    StateNotifierProvider<AdminExpenseCategoriesNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final dio = ref.watch(dioClientProvider).dio;
  final tenantQp = ref.watch(tenantQueryProvider).valueOrNull ?? <String, dynamic>{};
  return AdminExpenseCategoriesNotifier(dio, tenantQp);
});

class AdminExpenseCategoriesNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Dio _dio;
  final Map<String, dynamic> _tenantQp;

  AdminExpenseCategoriesNotifier(this._dio, this._tenantQp) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final res = await _dio.get('/superadmin/expense-categories', queryParameters: _tenantQp);
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

  Future<bool> add(String name, String? description) async {
    try {
      await _dio.post('/superadmin/expense-categories', data: {
        'name': name,
        if (description != null && description.isNotEmpty) 'description': description,
      }, queryParameters: _tenantQp);
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> update(int id, String name, String? description) async {
    try {
      await _dio.put('/superadmin/expense-categories/$id', data: {
        'name': name,
        if (description != null) 'description': description,
      }, queryParameters: _tenantQp);
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _dio.delete('/superadmin/expense-categories/$id', queryParameters: _tenantQp);
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class AdminExpenseCategoryPage extends ConsumerWidget {
  const AdminExpenseCategoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(adminExpenseCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategori Pengeluaran'),
        backgroundColor: const Color(0xFFE85D3A),
        foregroundColor: Colors.white,
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Gagal memuat: $e'),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: () => ref.read(adminExpenseCategoriesProvider.notifier).load(),
                child: const Text('Coba Lagi')),
          ]),
        ),
        data: (cats) => cats.isEmpty
            ? const Center(child: Text('Belum ada kategori'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: cats.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final cat = cats[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFFE8E0),
                      child: Text(
                        (cat['name'] ?? '?').toString().substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                            color: Color(0xFFE85D3A), fontWeight: FontWeight.w600),
                      ),
                    ),
                    title: Text(cat['name'] ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(cat['description'] ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: PopupMenuButton(
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                            value: 'delete',
                            child: Text('Hapus', style: TextStyle(color: Colors.red))),
                      ],
                      onSelected: (v) async {
                        if (v == 'edit') {
                          _showForm(context, ref, category: cat);
                        } else if (v == 'delete') {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hapus Kategori'),
                              content: Text('Hapus "${cat['name']}"?'),
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
                                .read(adminExpenseCategoriesProvider.notifier)
                                .delete(cat['id']);
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

  void _showForm(BuildContext context, WidgetRef ref, {Map<String, dynamic>? category}) {
    final nameCtrl = TextEditingController(text: category?['name'] ?? '');
    final descCtrl = TextEditingController(text: category?['description'] ?? '');
    final isEdit = category != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isEdit ? 'Edit Kategori' : 'Tambah Kategori',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Nama Kategori',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE85D3A))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Deskripsi (opsional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE85D3A))),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  bool success;
                  if (isEdit) {
                    success = await ref
                        .read(adminExpenseCategoriesProvider.notifier)
                        .update(category['id'], nameCtrl.text.trim(), descCtrl.text.trim());
                  } else {
                    success = await ref
                        .read(adminExpenseCategoriesProvider.notifier)
                        .add(nameCtrl.text.trim(), descCtrl.text.trim());
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(success ? 'Berhasil!' : 'Gagal'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ));
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE85D3A), foregroundColor: Colors.white),
                child: Text(isEdit ? 'Simpan' : 'Tambah'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
