import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/providers/store_provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/image_helper.dart';

final adminProductsProvider = StateNotifierProvider<AdminProductsNotifier, AsyncValue<List<Map>>>((ref) {
  final dio = ref.watch(dioClientProvider).dio;
  final storeQp = ref.watch(storeQueryProvider).valueOrNull ?? <String, dynamic>{};
  return AdminProductsNotifier(dio, storeQp);
});

final adminCategoryListProvider = FutureProvider<List<Map>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final tenantQp = ref.watch(tenantQueryProvider).valueOrNull ?? <String, dynamic>{};
  try {
    final res = await dio.get('/superadmin/product-categories', queryParameters: tenantQp);
    final data = res.data;
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e)).toList();
    if (data is Map && data.containsKey('data')) return (data['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  } catch (_) {
    return [];
  }
});

final adminUnitListProvider = FutureProvider<List<Map>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final tenantQp = ref.watch(tenantQueryProvider).valueOrNull ?? <String, dynamic>{};
  try {
    final res = await dio.get('/units', queryParameters: tenantQp);
    final data = res.data;
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e)).toList();
    if (data is Map && data.containsKey('data')) return (data['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  } catch (_) {
    return [];
  }
});

class AdminProductsNotifier extends StateNotifier<AsyncValue<List<Map>>> {
  final Dio _dio;
  final Map<String, dynamic> _tenantQp;
  int _page = 1;
  bool _hasMore = true;

  bool get hasMore => _hasMore;

  AdminProductsNotifier(this._dio, this._tenantQp) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({String? search}) async {
    _page = 1;
    _hasMore = true;
    state = const AsyncValue.loading();
    try {
      final params = <String, dynamic>{..._tenantQp, 'page': 1, 'per_page': 20};
      if (search != null) params['search'] = search;
      final res = await _dio.get('/superadmin/products', queryParameters: params);
      final data = res.data;
      List list;
      if (data is Map && data.containsKey('data')) {
        list = data['data'];
      } else if (data is List) {
        list = data;
      } else {
        list = [];
      }
      _hasMore = list.length >= 20;
      state = AsyncValue.data(list.map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    _page++;
    try {
      final params = <String, dynamic>{..._tenantQp, 'page': _page, 'per_page': 20};
      final res = await _dio.get('/superadmin/products', queryParameters: params);
      final data = res.data;
      List list;
      if (data is Map && data.containsKey('data')) {
        list = data['data'];
      } else {
        list = [];
      }
      _hasMore = list.length >= 20;
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([...current, ...list.map((e) => Map<String, dynamic>.from(e))]);
    } catch (_) {}
  }

  Future<bool> delete(int id) async {
    try {
      await _dio.delete('/superadmin/products/$id', queryParameters: _tenantQp);
      await load();
      return true;
    } catch (e) {
      return false;
    }
  }
}

// ==================== LIST PAGE ====================

class AdminProductListPage extends ConsumerStatefulWidget {
  const AdminProductListPage({super.key});

  @override
  ConsumerState<AdminProductListPage> createState() => _AdminProductListPageState();
}

class _AdminProductListPageState extends ConsumerState<AdminProductListPage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification &&
        notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
      ref.read(adminProductsProvider.notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(adminProductsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Produk'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari produk...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); ref.read(adminProductsProvider.notifier).load(); })
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (v) => ref.read(adminProductsProvider.notifier).load(search: v.trim()),
            ),
          ),
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Gagal memuat', style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: () => ref.read(adminProductsProvider.notifier).load(), child: const Text('Coba Lagi')),
                ]),
              ),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('Belum ada produk'))
                  : NotificationListener<ScrollNotification>(
                      onNotification: _onScrollNotification,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: items.length + (ref.read(adminProductsProvider.notifier).hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == items.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final p = items[index];
                          return _ProductCard(product: p);
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/product/add'),
        backgroundColor: theme.colorScheme.primary,
        child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Map product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnail = ImageHelper.resolve(product['thumbnail']?.toString());
    final price = product['price']?.toString() ?? '0';
    final name = product['name'] ?? '-';
    final sku = product['sku'] ?? '-';
    final category = product['category'];
    final categoryName = category is Map ? category['name']?.toString() : '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: thumbnail != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(imageUrl: thumbnail, fit: BoxFit.cover),
                )
              : Icon(Icons.cookie, size: 28, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('SKU: $sku | $categoryName', style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(CurrencyFormatter.idr(num.tryParse(price) ?? 0), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            PopupMenuButton(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: Colors.red))),
              ],
              onSelected: (v) async {
                if (v == 'edit') {
                  context.push('/admin/product/edit/${product['id']}');
                } else if (v == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Hapus Produk'),
                      content: Text('Hapus "$name"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    final success = await ref.read(adminProductsProvider.notifier).delete(product['id']);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(success ? 'Berhasil dihapus' : 'Gagal menghapus'), backgroundColor: success ? Colors.green : Colors.red),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ADD / EDIT PAGE ====================

class AdminProductFormPage extends ConsumerStatefulWidget {
  final String? productId;
  const AdminProductFormPage({super.key, this.productId});

  @override
  ConsumerState<AdminProductFormPage> createState() => _AdminProductFormPageState();
}

class _AdminProductFormPageState extends ConsumerState<AdminProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _yieldCtrl = TextEditingController();
  final _manualCostCtrl = TextEditingController();
  final _imagePicker = ImagePicker();

  String _type = 'produced';
  int? _selectedCategoryId;
  List<int> _selectedCategoryIds = [];
  int? _selectedUnitId;
  bool _isLoading = false;

  final List<File> _newImages = [];
  List<Map<String, dynamic>> _existingMedia = [];

  bool get isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final dio = ref.read(dioClientProvider).dio;
      final tenantQp = ref.read(tenantQueryProvider).valueOrNull ?? {};
      final res = await dio.get('/superadmin/products/${widget.productId}', queryParameters: tenantQp);
      final p = res.data;
      if (p is Map) {
        setState(() {
          _nameCtrl.text = p['name']?.toString() ?? '';
          _skuCtrl.text = p['sku']?.toString() ?? '';
          _priceCtrl.text = p['price']?.toString() ?? '';
          _type = p['type']?.toString() ?? 'produced';
          _selectedCategoryId = p['category_id'] != null ? int.tryParse(p['category_id'].toString()) : null;
          _selectedUnitId = p['unit_id'] != null ? int.tryParse(p['unit_id'].toString()) : null;
          final cats = p['categories'];
          if (cats is List) {
            _selectedCategoryIds = cats.map((e) {
              if (e is Map) return e['id'] as int?;
              return int.tryParse(e.toString());
            }).whereType<int>().toList();
          } else if (_selectedCategoryId != null) {
            _selectedCategoryIds = [_selectedCategoryId!];
          }
          _yieldCtrl.text = p['production_yield']?.toString() ?? '';
          _manualCostCtrl.text = p['manual_cost']?.toString() ?? '';
          final mediaList = p['media'];
          if (mediaList is List) {
            _existingMedia = mediaList
                .where((m) => m is Map && m['id'] != null && m['path'] != null)
                .map((m) => Map<String, dynamic>.from(m))
                .toList();
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _priceCtrl.dispose();
    _yieldCtrl.dispose();
    _manualCostCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() {
        _newImages.addAll(picked.map((x) => File(x.path)));
      });
    }
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  Future<void> _deleteExistingMedia(Map<String, dynamic> media) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Gambar'),
        content: const Text('Hapus gambar ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final dio = ref.read(dioClientProvider).dio;
      final tenantQp = ref.read(tenantQueryProvider).valueOrNull ?? {};
      final mediaId = media['id'];
      await dio.delete(
        '/superadmin/products/${widget.productId}/media/$mediaId',
        queryParameters: tenantQp,
      );
      setState(() => _existingMedia.remove(media));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gambar dihapus'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadImages(String productId) async {
    if (_newImages.isEmpty) return;
    final dio = ref.read(dioClientProvider).dio;
    final tenantQp = ref.read(tenantQueryProvider).valueOrNull ?? {};
    final files = <MultipartFile>[];
    for (final image in _newImages) {
      final fileName = image.path.split('/').last;
      files.add(await MultipartFile.fromFile(image.path, filename: fileName));
    }
    final formData = FormData.fromMap({
      'images': files,
    });
    final res = await dio.post(
      '/superadmin/products/$productId/media',
      data: formData,
      queryParameters: tenantQp,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );
    debugPrint('Upload response: ${res.statusCode} ${res.data}');
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioClientProvider).dio;
      final tenantQp = ref.read(tenantQueryProvider).valueOrNull ?? {};
      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'sku': _skuCtrl.text.trim(),
        'type': _type,
        'price': double.tryParse(_priceCtrl.text) ?? 0,
        'category_ids': _selectedCategoryIds,
        if (_selectedUnitId != null) 'unit_id': _selectedUnitId,
      };

      if (_type == 'produced' && _yieldCtrl.text.isNotEmpty) {
        data['production_yield'] = double.tryParse(_yieldCtrl.text);
      }
      if (_type == 'purchased' && _manualCostCtrl.text.isNotEmpty) {
        data['manual_cost'] = double.tryParse(_manualCostCtrl.text);
      }

      String productId;
      if (isEdit) {
        productId = widget.productId!;
        await dio.put('/superadmin/products/$productId', data: data, queryParameters: tenantQp);
      } else {
        final res = await dio.post('/superadmin/products', data: data, queryParameters: tenantQp);
        final responseData = res.data;
        if (responseData is Map && responseData['id'] != null) {
          productId = responseData['id'].toString();
        } else if (responseData is Map && responseData['data'] is Map && responseData['data']['id'] != null) {
          productId = responseData['data']['id'].toString();
        } else {
          throw Exception('Tidak dapat membaca ID produk');
        }
      }

      await _uploadImages(productId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? 'Produk diperbarui' : 'Produk ditambahkan'), backgroundColor: Colors.green),
        );
        ref.read(adminProductsProvider.notifier).load();
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(adminCategoryListProvider);
    final units = ref.watch(adminUnitListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Produk' : 'Tambah Produk'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: _inputDecoration('Nama Produk'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _skuCtrl,
              decoration: _inputDecoration('SKU'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtrl,
              decoration: _inputDecoration('Harga'),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: _inputDecoration('Tipe Produk'),
              items: const [
                DropdownMenuItem(value: 'produced', child: Text('Diproduksi')),
                DropdownMenuItem(value: 'purchased', child: Text('Dibeli')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'produced'),
            ),
            const SizedBox(height: 12),
            categories.when(
              data: (cats) {
                if (cats.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kategori', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: cats.map((c) {
                        final catId = c['id'] as int?;
                        final isSelected = _selectedCategoryIds.contains(catId);
                        return FilterChip(
                          label: Text(c['name'] ?? '-'),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                if (catId != null) _selectedCategoryIds.add(catId);
                              } else {
                                _selectedCategoryIds.remove(catId);
                              }
                            });
                          },
                          selectedColor: theme.colorScheme.primaryContainer,
                          checkmarkColor: theme.colorScheme.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _selectedUnitId,
              decoration: _inputDecoration('Satuan'),
              items: units.when(
                data: (u) => u.map<DropdownMenuItem<int>>((e) => DropdownMenuItem(
                  value: e['id'] as int?,
                  child: Text('${e['name']} (${e['symbol'] ?? ''})'),
                )).toList(),
                loading: () => const [],
                error: (_, __) => const [],
              ),
              onChanged: (v) => setState(() => _selectedUnitId = v),
            ),
            const SizedBox(height: 12),
            if (_type == 'produced') ...[
              TextFormField(
                controller: _yieldCtrl,
                decoration: _inputDecoration('Production Yield'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
            ],
            if (_type == 'purchased') ...[
              TextFormField(
                controller: _manualCostCtrl,
                decoration: _inputDecoration('Biaya Manual (COGS)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            Text('Gambar Produk', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._existingMedia.asMap().entries.map((entry) {
                    final media = entry.value;
                    final path = ImageHelper.resolve(media['path']?.toString());
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: path,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 120,
                                height: 120,
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 120,
                                height: 120,
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: Icon(Icons.broken_image, color: theme.colorScheme.outline),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _deleteExistingMedia(media),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.close, size: 16, color: theme.colorScheme.onError),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  ..._newImages.asMap().entries.map((entry) {
                    final index = entry.key;
                    final file = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(file, width: 120, height: 120, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeNewImage(index),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.close, size: 16, color: theme.colorScheme.onError),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 28, color: theme.colorScheme.outline),
                          const SizedBox(height: 4),
                          Text('Tambah', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                    : Text(isEdit ? 'Simpan Perubahan' : 'Tambah Produk', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
