import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../catalog/data/products_provider.dart';
import '../../../cart/data/cart_provider.dart';
import '../../../orders/presentation/pages/orders_page.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/providers/store_provider.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/network/dio_client.dart';
import 'checkout_sheet.dart';

class POSPage extends ConsumerStatefulWidget {
  const POSPage({super.key});

  @override
  ConsumerState<POSPage> createState() => _POSPageState();
}

class _POSPageState extends ConsumerState<POSPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    setState(() => _searchQuery = value);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Point of Sale'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => _showOrdersSheet(context),
          ),
          if (!isLandscape)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () => _openCheckout(context),
                ),
                if (cart.itemCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cart.itemCount}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: isLandscape
          ? Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _POSProductPanel(
                    productsAsync: productsAsync,
                    searchController: _searchController,
                    searchQuery: _searchQuery,
                    selectedCategory: _selectedCategory,
                    onSearch: _onSearch,
                    onCategorySelected: (c) => setState(() => _selectedCategory = c),
                  ),
                ),
                Container(width: 1, color: theme.dividerColor),
                Expanded(
                  flex: 1,
                  child: _POSInlineCart(onCheckout: () => _openCheckout(context)),
                ),
              ],
            )
          : Column(
              children: [
                Container(
                  color: theme.colorScheme.surface,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearch,
                    decoration: InputDecoration(
                      hintText: 'Cari produk...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearch('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                _CategoryChips(
                  productsAsync: productsAsync,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: (c) => setState(() => _selectedCategory = c),
                ),
                Expanded(
                  child: productsAsync.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(color: theme.colorScheme.primary),
                    ),
                    error: (e, _) => Center(child: Text('Gagal memuat: $e')),
                    data: (products) {
                      var filtered = products;
                      if (_searchQuery.isNotEmpty) {
                        final q = _searchQuery.toLowerCase();
                        filtered = filtered
                            .where((p) => p.name.toLowerCase().contains(q))
                            .toList();
                      }
                      if (_selectedCategory != null) {
                        filtered = filtered
                            .where((p) => p.categories.contains(_selectedCategory))
                            .toList();
                      }
                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 56, color: theme.colorScheme.outline),
                              const SizedBox(height: 12),
                              Text('Produk tidak ditemukan',
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 15)),
                            ],
                          ),
                        );
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.55,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            _ProductCard(product: filtered[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: (!isLandscape && cart.itemCount > 0)
          ? _BottomBar(
              itemCount: cart.itemCount,
              total: cart.total,
              onBayar: () => _openCheckout(context),
            )
          : null,
    );
  }

  void _openCheckout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const CheckoutSheet(),
    );
  }

  void _showOrdersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _POSOrdersSheet(),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final AsyncValue<List<ProductItem>> productsAsync;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;

  const _CategoryChips({
    required this.productsAsync,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return productsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        final categories = products.expand((p) => p.categories).toSet().toList();
        if (categories.isEmpty) return const SizedBox.shrink();
        return Container(
          height: 48,
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.only(left: 16),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: categories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = selectedCategory == null;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: FilterChip(
                    label: const Text('Semua'),
                    selected: isSelected,
                    onSelected: (_) => onCategorySelected(null),
                    selectedColor: theme.colorScheme.primaryContainer,
                    checkmarkColor: theme.colorScheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
                    ),
                    elevation: isSelected ? 1 : 0,
                    shadowColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                );
              }
              final cat = categories[index - 1];
              final isSelected = selectedCategory == cat;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => onCategorySelected(cat),
                  selectedColor: theme.colorScheme.primaryContainer,
                  checkmarkColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
                  ),
                  elevation: isSelected ? 1 : 0,
                  shadowColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _POSProductPanel extends ConsumerStatefulWidget {
  final AsyncValue<List<ProductItem>> productsAsync;
  final TextEditingController searchController;
  final String searchQuery;
  final String? selectedCategory;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onCategorySelected;

  const _POSProductPanel({
    required this.productsAsync,
    required this.searchController,
    required this.searchQuery,
    required this.selectedCategory,
    required this.onSearch,
    required this.onCategorySelected,
  });

  @override
  ConsumerState<_POSProductPanel> createState() => _POSProductPanelState();
}

class _POSProductPanelState extends ConsumerState<_POSProductPanel> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: widget.searchController,
            onChanged: widget.onSearch,
            decoration: InputDecoration(
              hintText: 'Cari produk...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              suffixIcon: widget.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        widget.searchController.clear();
                        widget.onSearch('');
                      },
                    )
                  : null,
            ),
          ),
        ),
        _CategoryChips(
          productsAsync: widget.productsAsync,
          selectedCategory: widget.selectedCategory,
          onCategorySelected: widget.onCategorySelected,
        ),
        Expanded(
          child: widget.productsAsync.when(
            loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
            error: (e, _) => Center(child: Text('Gagal memuat: $e')),
            data: (products) {
              var filtered = products;
              if (widget.searchQuery.isNotEmpty) {
                final q = widget.searchQuery.toLowerCase();
                filtered = filtered.where((p) => p.name.toLowerCase().contains(q)).toList();
              }
              if (widget.selectedCategory != null) {
                filtered = filtered.where((p) => p.categories.contains(widget.selectedCategory)).toList();
              }
              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: theme.colorScheme.outline),
                      const SizedBox(height: 12),
                      Text('Produk tidak ditemukan', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.55,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) => _ProductCard(product: filtered[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _POSInlineCart extends ConsumerWidget {
  final VoidCallback onCheckout;
  const _POSInlineCart({required this.onCheckout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Icon(Icons.shopping_cart, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Keranjang', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
              const Spacer(),
              if (cart.itemCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                  child: Text('${cart.itemCount}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onPrimary)),
                ),
            ],
          ),
        ),
        Expanded(
          child: cart.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.remove_shopping_cart_outlined, size: 40, color: theme.colorScheme.outline),
                      const SizedBox(height: 8),
                      Text('Kosong', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      title: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(CurrencyFormatter.idr(item.price), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                      trailing: _InlineQtyBtn(productId: item.productId, qty: item.quantity),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -2))],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${cart.itemCount} item', style: theme.textTheme.bodySmall),
                    Text(CurrencyFormatter.idr(cart.total),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: cart.itemCount > 0 ? onCheckout : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Bayar', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineQtyBtn extends ConsumerWidget {
  final int productId;
  final int qty;
  const _InlineQtyBtn({required this.productId, required this.qty});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final container = theme.colorScheme.primaryContainer;
    return Container(
      height: 28,
      decoration: BoxDecoration(color: container, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
            onTap: () => ref.read(cartProvider.notifier).updateQuantity(productId, qty - 1),
            child: SizedBox(width: 28, child: Icon(Icons.remove, size: 14, color: primary)),
          ),
          SizedBox(width: 28, child: Center(child: Text('$qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary)))),
          InkWell(
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
            onTap: () => ref.read(cartProvider.notifier).updateQuantity(productId, qty + 1),
            child: SizedBox(width: 28, child: Icon(Icons.add, size: 14, color: primary)),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final ProductItem product;
  const _ProductCard({required this.product});

  Color _stockColor(ThemeData theme, int stock) {
    if (stock <= 0) return theme.colorScheme.error;
    if (stock <= 5) return Colors.orange.shade700;
    return theme.colorScheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);
    final inCart = cart.items.where((i) => i.productId == product.id).toList();
    final qtyInCart = inCart.isNotEmpty ? inCart.first.quantity : 0;
    final stock = product.stock;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: product.image != null && product.image!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: product.image!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                      ),
                      errorWidget: (_, __, ___) => Icon(Icons.cookie, size: 32, color: theme.colorScheme.primary),
                    )
                  : Icon(Icons.cookie, size: 32, color: theme.colorScheme.primary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
            child: Text(product.name, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500), maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
            child: Text(CurrencyFormatter.idr(product.price), style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary, fontSize: 10)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: _stockColor(theme, stock).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Stok: $stock',
                style: theme.textTheme.labelSmall?.copyWith(color: _stockColor(theme, stock), fontWeight: FontWeight.w600, fontSize: 9),
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (qtyInCart > 0)
                  _QtyControls(productId: product.id, qty: qtyInCart)
                else if (stock > 0)
                  SizedBox(
                    width: double.infinity,
                    height: 24,
                    child: FilledButton.tonal(
                      onPressed: () => _showAddQtyDialog(context, ref),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: const Text('Tambah', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                  ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  height: 24,
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddStockDialog(context, ref),
                    icon: const Icon(Icons.add_circle_outline, size: 12),
                    label: const Text('Stok', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      side: BorderSide(color: Colors.orange.shade700),
                      foregroundColor: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddQtyDialog(BuildContext context, WidgetRef ref) {
    final qtyCtrl = TextEditingController(text: '1');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(CurrencyFormatter.idr(product.price), style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Jumlah',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _QuickQtyBtn(label: '5', ctrl: qtyCtrl),
                const SizedBox(width: 6),
                _QuickQtyBtn(label: '10', ctrl: qtyCtrl),
                const SizedBox(width: 6),
                _QuickQtyBtn(label: '25', ctrl: qtyCtrl),
                const SizedBox(width: 6),
                _QuickQtyBtn(label: '50', ctrl: qtyCtrl),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final qty = int.tryParse(qtyCtrl.text) ?? 1;
                  if (qty <= 0) return;
                  ref.read(cartProvider.notifier).addItem(
                        product.id,
                        product.name,
                        product.price,
                        quantity: qty,
                        image: product.image,
                      );
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Tambah ke Keranjang'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStockDialog(BuildContext context, WidgetRef ref) {
    final qtyCtrl = TextEditingController(text: '1');
    final store = ref.read(selectedAdminStoreProvider);
    if (store == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih toko terlebih dahulu'), backgroundColor: Colors.orange));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.add_circle_outline, color: Colors.orange.shade700, size: 22),
                const SizedBox(width: 8),
                const Expanded(child: Text('Tambah Stok', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              ],
            ),
            const SizedBox(height: 4),
            Text('${product.name} — Stok: ${product.stock}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              decoration: InputDecoration(labelText: 'Jumlah', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _QuickQtyBtn(label: '5', ctrl: qtyCtrl),
                const SizedBox(width: 6),
                _QuickQtyBtn(label: '10', ctrl: qtyCtrl),
                const SizedBox(width: 6),
                _QuickQtyBtn(label: '25', ctrl: qtyCtrl),
                const SizedBox(width: 6),
                _QuickQtyBtn(label: '50', ctrl: qtyCtrl),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final qty = int.tryParse(qtyCtrl.text);
                  if (qty == null || qty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan jumlah valid'), backgroundColor: Colors.red));
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    final dio = ref.read(dioClientProvider).dio;
                    final tenantQp = ref.read(tenantQueryProvider).valueOrNull ?? <String, dynamic>{};
                    final res = await dio.post(
                      '/superadmin/products/${product.id}/stores/${store.id}/adjust-stock',
                      data: {'delta': qty, ...tenantQp},
                    );
                    final newStock = res.data['new_stock'] ?? (product.stock + qty);
                    ref.read(productsProvider.notifier).reloadAfterStockAdjust(product.id, newStock as int);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stok ditambah $qty → $newStock'), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    String msg = 'Gagal tambah stok';
                    if (e is DioException && e.response?.data != null) {
                      final resp = e.response!.data;
                      msg = resp['message'] ?? resp['error'] ?? msg;
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Tambah Stok'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickQtyBtn extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  const _QuickQtyBtn({required this.label, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: SizedBox(
        height: 36,
        child: OutlinedButton(
          onPressed: () => ctrl.text = label,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
        ),
      ),
    );
  }
}

class _QtyControls extends ConsumerWidget {
  final int productId;
  final int qty;
  const _QtyControls({required this.productId, required this.qty});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final primaryContainer = theme.colorScheme.primaryContainer;

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
              onTap: () => ref.read(cartProvider.notifier).updateQuantity(productId, qty - 1),
              child: Center(child: Icon(Icons.remove, size: 14, color: primary)),
            ),
          ),
          Container(width: 1, color: primary.withValues(alpha: 0.2)),
          SizedBox(
            width: 28,
            child: Center(
              child: Text(
                '$qty',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primary),
              ),
            ),
          ),
          Container(width: 1, color: primary.withValues(alpha: 0.2)),
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
              onTap: () => ref.read(cartProvider.notifier).updateQuantity(productId, qty + 1),
              child: Center(child: Icon(Icons.add, size: 14, color: primary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int itemCount;
  final double total;
  final VoidCallback onBayar;

  const _BottomBar({
    required this.itemCount,
    required this.total,
    required this.onBayar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$itemCount item',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    CurrencyFormatter.idr(total),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: onBayar,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Bayar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

const _wib = Duration(hours: 7);
String _fmtWIB(DateTime? d) {
  if (d == null) return '-';
  final wib = d.toUtc().add(_wib);
  return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(wib);
}

class _POSOrdersSheet extends ConsumerStatefulWidget {
  const _POSOrdersSheet();

  @override
  ConsumerState<_POSOrdersSheet> createState() => _POSOrdersSheetState();
}

class _POSOrdersSheetState extends ConsumerState<_POSOrdersSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ordersProvider.notifier).load();
    });
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending': return Colors.orange;
      case 'paid': return Colors.orange;
      case 'pending_sync': return Colors.orange;
      case 'processing': return Colors.blue;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending': return 'Menunggu';
      case 'paid': return 'Dibayar';
      case 'pending_sync': return 'Offline';
      case 'processing': return 'Diproses';
      case 'completed': return 'Selesai';
      case 'cancelled': return 'Dibatalkan';
      default: return s.toUpperCase();
    }
  }

  Future<void> _updateStatus(OrderData order, String status) async {
    if (order.id == null) return;
    try {
      await ref.read(ordersProvider.notifier).updateOrderStatus(order.id!, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pesanan ${_statusLabel(status)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(ordersProvider);
    final connectivity = ref.watch(connectivityProvider);
    final isOnline = connectivity == ConnectivityStatus.online;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Pesanan Terbaru'),
            automaticallyImplyLeading: false,
            actions: [
              if (!isOnline)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.cloud_off, size: 18, color: Colors.orange.shade600),
                ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          body: ordersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Gagal memuat: $e')),
            data: (orders) {
              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Belum ada pesanan', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                );
              }
              return ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final color = _statusColor(order.status);
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          order.id != null ? '${order.id}' : '!',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                        ),
                      ),
                    ),
                    title: Text(
                      order.itemsSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_fmtWIB(order.createdAt)}  •  ${CurrencyFormatter.idr(order.finalTotal)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (order.isOffline)
                          Text(
                            'Offline — akan disync saat online',
                            style: TextStyle(fontSize: 11, color: Colors.orange.shade600),
                          ),
                      ],
                    ),
                    trailing: _buildActionButton(order, isOnline),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget? _buildActionButton(OrderData order, bool isOnline) {
    final theme = Theme.of(context);

    if (order.status == 'pending' || order.status == 'paid') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.tonal(
            onPressed: isOnline ? () => _updateStatus(order, 'cancelled') : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Tolak', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: isOnline ? () => _updateStatus(order, 'processing') : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Proses', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      );
    }

    if (order.status == 'processing') {
      return FilledButton(
        onPressed: isOnline ? () => _updateStatus(order, 'completed') : null,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        child: const Text('Selesai', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      );
    }

    final color = _statusColor(order.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _statusLabel(order.status),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
