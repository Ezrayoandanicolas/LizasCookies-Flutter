import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/providers/store_provider.dart';
import '../../../admin/presentation/pages/admin_product_page.dart';

class StockPage extends ConsumerStatefulWidget {
  const StockPage({super.key});

  @override
  ConsumerState<StockPage> createState() => _StockPageState();
}

class _StockPageState extends ConsumerState<StockPage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(adminProductsProvider);
    final selectedStore = ref.watch(selectedAdminStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Stok'),
        backgroundColor: const Color(0xFFE85D3A),
        foregroundColor: Colors.white,
        actions: [
          // Store selector
          PopupMenuButton<StoreData?>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.store, size: 18),
                const SizedBox(width: 4),
                Text(selectedStore?.name ?? 'Pilih Toko',
                    style: const TextStyle(fontSize: 12)),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
            onSelected: (store) {
              ref.read(selectedAdminStoreProvider.notifier).state = store;
            },
            itemBuilder: (ctx) {
              final stores = ref.watch(storeListProvider).valueOrNull ?? [];
              return [
                const PopupMenuItem(value: null, child: Text('Semua Toko')),
                ...stores.map((s) => PopupMenuItem(
                  value: s,
                  child: Text('${s.name} (${s.code})'),
                )),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari produk...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(adminProductsProvider.notifier).load();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (v) =>
                  ref.read(adminProductsProvider.notifier).load(search: v.trim()),
            ),
          ),
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Gagal memuat',
                        style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          ref.read(adminProductsProvider.notifier).load(),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
              data: (items) {
                var filtered = items;
                final search = _searchCtrl.text.trim().toLowerCase();
                if (search.isNotEmpty) {
                  filtered = items
                      .where((p) =>
                          (p['name'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(search))
                      .toList();
                }
                if (filtered.isEmpty) {
                  return const Center(child: Text('Tidak ada produk'));
                }
                return ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    return _StockProductCard(product: p);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StockProductCard extends ConsumerWidget {
  final Map product;
  const _StockProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnail = product['thumbnail']?.toString();
    final name = product['name'] ?? '-';
    final sku = product['sku'] ?? '-';
    final selectedStore = ref.watch(selectedAdminStoreProvider);

    // Get stock - API returns store_stock as decimal string like "80.00"
    int stockQty = 0;
    if (product['store_stock'] != null) {
      stockQty = double.tryParse(product['store_stock'].toString())?.round() ?? 0;
    } else if (product['stores'] is List && selectedStore != null) {
      for (final s in product['stores']) {
        if (s is Map && s['id'] == selectedStore.id) {
          final pivot = s['pivot'];
          if (pivot is Map) {
            stockQty = int.tryParse(pivot['stock_quantity'].toString()) ?? 0;
          }
          break;
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: thumbnail != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: thumbnail,
                    fit: BoxFit.cover,
                  ),
                )
              : const Icon(Icons.cookie, size: 26, color: Color(0xFFE85D3A)),
        ),
        title: Text(name,
            style:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text('SKU: $sku', style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: stockQty > 0
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Stok: $stockQty',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: stockQty > 0
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton(
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'add',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text('Tambah Stok'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle,
                          color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text('Kurangi Stok'),
                    ],
                  ),
                ),
              ],
              onSelected: (v) => _showStockDialog(context, ref, v.toString()),
            ),
          ],
        ),
      ),
    );
  }

  void _showStockDialog(BuildContext context, WidgetRef ref, String action) {
    final qtyCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final productId = product['id'];
    final selectedStore = ref.read(selectedAdminStoreProvider);

    if (selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih toko terlebih dahulu!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String title;
    String buttonText;
    Color buttonColor;
    IconData icon;

    switch (action) {
      case 'add':
        title = 'Tambah Stok';
        buttonText = 'Tambah';
        buttonColor = Colors.green;
        icon = Icons.add_circle;
        break;
      default:
        title = 'Kurangi Stok';
        buttonText = 'Kurangi';
        buttonColor = Colors.orange;
        icon = Icons.remove_circle;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: buttonColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${product['name']} - ${selectedStore.name}',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 20),
            TextField(
              controller: qtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Jumlah',
                hintText: 'Masukkan jumlah stok',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE85D3A)),
                ),
              ),
            ),
            if (action == 'add') ...[
              const SizedBox(height: 12),
              TextField(
                controller: costCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Biaya per unit (opsional)',
                  hintText: 'Masukkan biaya',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFE85D3A)),
                  ),
                ),
              ),
            ],
            if (action == 'remove') ...[
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(
                  labelText: 'Alasan (opsional)',
                  hintText: 'Contoh: Rusak, Kadaluarsa',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFE85D3A)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final qty = double.tryParse(qtyCtrl.text);
                  if (qty == null || qty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Masukkan jumlah yang valid'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(ctx);

                  final dio = ref.read(dioClientProvider).dio;
                  final tenantQp =
                      ref.read(tenantQueryProvider).valueOrNull ??
                          <String, dynamic>{};

                  try {
                    final data = <String, dynamic>{
                      'quantity': qty,
                      'store_id': selectedStore.id,
                      ...tenantQp,
                    };

                    if (action == 'add') {
                      final cost = double.tryParse(costCtrl.text);
                      if (cost != null && cost > 0) data['cost'] = cost;
                      await dio.post(
                        '/superadmin/products/$productId/add-stock',
                        data: data,
                      );
                    } else {
                      if (reasonCtrl.text.isNotEmpty) {
                        data['reason'] = reasonCtrl.text;
                      }
                      await dio.post(
                        '/superadmin/products/$productId/remove-stock',
                        data: data,
                      );
                    }

                    ref.read(adminProductsProvider.notifier).load();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$title berhasil!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    String msg = 'Gagal';
                    if (e is DioException && e.response?.data != null) {
                      final resp = e.response!.data;
                      msg = resp['message'] ?? resp['error'] ?? msg;
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
