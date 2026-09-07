import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/providers/store_provider.dart';
import '../../../../core/utils/image_helper.dart';
import 'admin_product_page.dart';

class StockPage extends ConsumerStatefulWidget {
  const StockPage({super.key});

  @override
  ConsumerState<StockPage> createState() => _StockPageState();
}

class _StockPageState extends ConsumerState<StockPage> {
  final _searchCtrl = TextEditingController();
  int? _selectedCategoryId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(adminProductsProvider);
    final selectedStore = ref.watch(selectedAdminStoreProvider);
    final categories = ref.watch(adminCategoryListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Stok'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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
                          ref.read(adminProductsProvider.notifier).load(search: '');
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
              onChanged: (v) {
                setState(() {});
                ref.read(adminProductsProvider.notifier).load(search: v.trim());
              },
            ),
          ),
          categories.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (cats) {
              if (cats.isEmpty) return const SizedBox.shrink();
              return Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text('Semua', style: TextStyle(
                          fontSize: 12,
                          color: _selectedCategoryId == null ? Colors.white : Colors.grey.shade700,
                        )),
                        selected: _selectedCategoryId == null,
                        onSelected: (_) => setState(() {
                          _selectedCategoryId = null;
                          ref.read(adminProductsProvider.notifier).load(categoryId: null);
                        }),
                        selectedColor: theme.colorScheme.primary,
                        backgroundColor: Colors.grey.shade100,
                        checkmarkColor: Colors.white,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    ...cats.map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(cat['name'] ?? '-', style: TextStyle(
                          fontSize: 12,
                          color: _selectedCategoryId == cat['id'] ? Colors.white : Colors.grey.shade700,
                        )),
                        selected: _selectedCategoryId == cat['id'],
                        onSelected: (_) => setState(() {
                          _selectedCategoryId = cat['id'];
                          ref.read(adminProductsProvider.notifier).load(categoryId: cat['id']);
                        }),
                        selectedColor: theme.colorScheme.primary,
                        backgroundColor: Colors.grey.shade100,
                        checkmarkColor: Colors.white,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )),
                  ],
                ),
              );
            },
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
                return GridView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    return _StockProductGridCard(product: p);
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

class _StockProductGridCard extends ConsumerWidget {
  final Map product;
  const _StockProductGridCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnail = ImageHelper.resolve(product['thumbnail']?.toString());
    final name = product['name'] ?? '-';
    final selectedStore = ref.watch(selectedAdminStoreProvider);
    final theme = Theme.of(context);

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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showStockDialog(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.grey.shade100,
                child: thumbnail != null
                    ? CachedNetworkImage(
                        imageUrl: thumbnail,
                        fit: BoxFit.cover,
                      )
                    : Icon(Icons.cookie, size: 40, color: theme.colorScheme.primary),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: stockQty > 0
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Stok: $stockQty',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: stockQty > 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStockDialog(BuildContext context, WidgetRef ref) {
    final name = product['name'] ?? '-';
    final sku = product['sku'] ?? '-';
    final selectedStore = ref.watch(selectedAdminStoreProvider);

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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (ctx, scrollCtrl) => _StockEditSheet(
          product: product,
          currentStock: stockQty,
          storeName: selectedStore?.name ?? '-',
        ),
      ),
    );
  }
}

class _StockEditSheet extends ConsumerStatefulWidget {
  final Map product;
  final int currentStock;
  final String storeName;

  const _StockEditSheet({
    required this.product,
    required this.currentStock,
    required this.storeName,
  });

  @override
  ConsumerState<_StockEditSheet> createState() => _StockEditSheetState();
}

class _StockEditSheetState extends ConsumerState<_StockEditSheet> {
  late TextEditingController _qtyCtrl;
  String _action = 'add';

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.product['name'] ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text('SKU: ${widget.product['sku'] ?? '-'} | Toko: ${widget.storeName}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.currentStock > 0
                  ? Colors.green.withValues(alpha: 0.08)
                  : Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2, size: 20),
                const SizedBox(width: 8),
                Text('Stok saat ini: ${widget.currentStock}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'add', label: Text('Tambah'), icon: Icon(Icons.add, size: 16)),
              ButtonSegment(value: 'remove', label: Text('Kurangi'), icon: Icon(Icons.remove, size: 16)),
              ButtonSegment(value: 'set', label: Text('Atur'), icon: Icon(Icons.edit, size: 16)),
            ],
            selected: {_action},
            onSelectionChanged: (v) => setState(() => _action = v.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Jumlah',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _save(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0) return;

    final productId = widget.product['id'];
    final selectedStore = ref.read(selectedAdminStoreProvider);
    if (selectedStore == null) return;

    try {
      final dio = ref.read(dioClientProvider).dio;
      final storeStocks = widget.product['store_stock'];
      int currentPivotStock = 0;
      final stores = widget.product['stores'];
      if (stores is List) {
        for (final s in stores) {
          if (s is Map && s['id'] == selectedStore.id) {
            currentPivotStock = int.tryParse((s['pivot']?['stock_quantity'] ?? '0').toString()) ?? 0;
            break;
          }
        }
      }

      int newStock;
      switch (_action) {
        case 'add':
          newStock = currentPivotStock + qty;
          break;
        case 'remove':
          newStock = (currentPivotStock - qty).clamp(0, 999999);
          break;
        case 'set':
          newStock = qty;
          break;
        default:
          newStock = currentPivotStock;
      }

      final connectivity = ref.read(connectivityProvider);
      if (connectivity == ConnectivityStatus.online) {
        await dio.post('/superadmin/products/$productId/sync-stock', data: {
          'store_id': selectedStore.id,
          'stock_quantity': newStock,
        });
      } else {
        final box = Hive.box('offline_stock');
        await box.put('stock_$productId', {
          'product_id': productId,
          'store_id': selectedStore.id,
          'stock_quantity': newStock,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Update local product data
      if (mounted) {
        widget.product['store_stock'] = newStock;
        ref.read(adminProductsProvider.notifier).load();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_action == 'add'
                ? 'Stok ditambah $qty'
                : _action == 'remove'
                    ? 'Stok dikurangi $qty'
                    : 'Stok diatur ke $qty'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

