import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../catalog/data/products_provider.dart';
import '../../../cart/data/cart_provider.dart';
import '../../../orders/presentation/pages/orders_page.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/providers/store_provider.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/network/dio_client.dart';
import 'checkout_sheet.dart';

const _bg = Color(0xFF090D16);
const _surface = Color(0xFF131B2E);
const _surfaceLight = Color(0xFF1A2540);
const _gold = Color(0xFFD4AF37);
const _goldDark = Color(0xFFB8962E);
const _textPrimary = Color(0xFFF0F0F0);
const _textSecondary = Color(0xFF8892A6);
const _border = Color(0xFF1E2A45);
const _divider = Color(0xFF1A2238);
const _success = Color(0xFF22C55E);
const _error = Color(0xFFEF4444);
const _warning = Color(0xFFF59E0B);
const _info = Color(0xFF3B82F6);

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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: _bg,
      body: isLandscape
          ? _buildLandscapeLayout(productsAsync, cart)
          : _buildPortraitLayout(productsAsync, cart),
    );
  }

  Widget _buildLandscapeLayout(AsyncValue<List<ProductItem>> productsAsync, CartState cart) {
    return Row(
      children: [
        Expanded(flex: 7, child: _buildProductPanel(productsAsync)),
        Container(width: 1, color: _border),
        SizedBox(width: 360, child: _buildCartSidebar(cart)),
      ],
    );
  }

  Widget _buildPortraitLayout(AsyncValue<List<ProductItem>> productsAsync, CartState cart) {
    return Column(
      children: [
        _buildTopBar(cart),
        Expanded(child: _buildProductPanel(productsAsync)),
        if (cart.itemCount > 0)
          _buildMobileCartPreview(cart),
      ],
    );
  }

  Widget _buildTopBar(CartState cart) {
    return Container(
      padding: EdgeInsets.fromLTRB(Responsive.padding(context), 8, Responsive.padding(context), 8),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _textPrimary, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            const Text(
              'Point of Sale',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary, letterSpacing: -0.3),
            ),
            const Spacer(),
            _TopBarIconButton(
              icon: Icons.receipt_long_outlined,
              badge: null,
              onTap: () => _showOrdersSheet(context),
            ),
            const SizedBox(width: 6),
            _TopBarIconButton(
              icon: Icons.shopping_cart_outlined,
              badge: cart.itemCount > 0 ? '${cart.itemCount}' : null,
              onTap: () => _showMobileCartSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductPanel(AsyncValue<List<ProductItem>> productsAsync) {
    return Column(
      children: [
        _buildSearchBar(),
        _buildCategoryChips(productsAsync),
        Expanded(
          child: productsAsync.when(
            loading: () => Center(child: CircularProgressIndicator(color: _gold, strokeWidth: 2)),
            error: (e, _) => _buildErrorState(e),
            data: (products) {
              var filtered = products;
              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                filtered = filtered.where((p) => p.name.toLowerCase().contains(q)).toList();
              }
              if (_selectedCategory != null) {
                filtered = filtered.where((p) => p.categories.contains(_selectedCategory)).toList();
              }
              if (filtered.isEmpty) return _buildEmptyState();
              return _buildProductGrid(filtered);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(Responsive.padding(context), 10, Responsive.padding(context), 8),
      color: _bg,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearch,
        style: const TextStyle(color: _textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Cari produk...',
          hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: _gold, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: _textSecondary, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                )
              : null,
          filled: true,
          fillColor: _surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _gold, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(AsyncValue<List<ProductItem>> productsAsync) {
    return productsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        final categories = products.expand((p) => p.categories).toSet().toList();
        if (categories.isEmpty) return const SizedBox.shrink();
        return Container(
          height: 44,
          color: _bg,
          padding: EdgeInsets.only(left: Responsive.padding(context)),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: categories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = _selectedCategory == null;
                return _CategoryChip(
                  label: 'Semua',
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedCategory = null),
                );
              }
              final cat = categories[index - 1];
              final isSelected = _selectedCategory == cat;
              return _CategoryChip(
                label: cat,
                isSelected: isSelected,
                onTap: () => setState(() => _selectedCategory = isSelected ? null : cat),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProductGrid(List<ProductItem> products) {
    return GridView.builder(
      padding: EdgeInsets.all(Responsive.padding(context, mobile: 8, tablet: 10, desktop: 12)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.gridColumns(context, mobile: 2, tablet: 3, desktop: 4),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: Responsive.cardAspectRatio(context, mobile: 0.62, tablet: 0.68, desktop: 0.72),
      ),
      itemCount: products.length,
      itemBuilder: (context, index) => _ProductCard(product: products[index]),
    );
  }

  Widget _buildCartSidebar(CartState cart) {
    return Container(
      color: _surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: _surface,
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: _gold, size: 18),
                const SizedBox(width: 8),
                const Text('Pesanan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary)),
                const Spacer(),
                if (cart.itemCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${cart.itemCount}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _gold),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: cart.items.isEmpty
                ? _buildCartEmpty()
                : _buildCartList(cart),
          ),
          if (cart.itemCount > 0) _buildCartFooter(cart),
        ],
      ),
    );
  }

  Widget _buildCartEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 44, color: _textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('Keranjang kosong', style: TextStyle(fontSize: 13, color: _textSecondary)),
          const SizedBox(height: 4),
          const Text('Tap produk untuk menambahkan', style: TextStyle(fontSize: 11, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCartList(CartState cart) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: cart.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: _divider, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final item = cart.items[index];
        return _CartItemTile(item: item);
      },
    );
  }

  Widget _buildCartFooter(CartState cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${cart.itemCount} item', style: const TextStyle(fontSize: 13, color: _textSecondary)),
                Text(
                  CurrencyFormatter.idr(cart.total),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _gold, letterSpacing: -0.5),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _openCheckout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _bg,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'Bayar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCartPreview(CartState cart) {
    return GestureDetector(
      onTap: () => _showMobileCartSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: _border)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_cart_rounded, size: 16, color: _gold),
                    const SizedBox(width: 6),
                    Text('${cart.itemCount}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _gold)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  CurrencyFormatter.idr(cart.total),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _textSecondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object e) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 44, color: _error),
          const SizedBox(height: 12),
          const Text('Gagal memuat produk', style: TextStyle(color: _textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => ref.read(productsProvider.notifier).load(),
            style: ElevatedButton.styleFrom(backgroundColor: _surface, foregroundColor: _textPrimary),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 52, color: _textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('Produk tidak ditemukan', style: TextStyle(fontSize: 15, color: _textSecondary)),
        ],
      ),
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

  void _showMobileCartSheet(BuildContext context) {
    final cart = ref.read(cartProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _MobileCartSheet(
          scrollController: scrollController,
          onCheckout: () {
            Navigator.pop(ctx);
            _openCheckout(context);
          },
        ),
      ),
    );
  }
}

// ─── Top Bar Icon Button ──────────────────────────────────────────────
class _TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;

  const _TopBarIconButton({required this.icon, this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: _textPrimary),
          ),
          if (badge != null)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
                child: Text(
                  badge!,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _bg),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Category Chip ───────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _gold.withValues(alpha: 0.15) : _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _gold : _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? _gold : _textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Product Card ────────────────────────────────────────────────────
class _ProductCard extends ConsumerWidget {
  final ProductItem product;
  const _ProductCard({required this.product});

  Color get _stockColor {
    if (product.stock <= 0) return _error;
    if (product.stock <= 5) return _warning;
    return _success;
  }

  String get _stockLabel {
    if (product.stock <= 0) return 'Habis';
    if (product.stock <= 5) return 'Sisa ${product.stock}';
    return 'Stok ${product.stock}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final inCart = cart.items.where((i) => i.productId == product.id).toList();
    final qtyInCart = inCart.isNotEmpty ? inCart.first.quantity : 0;
    final stock = product.stock;

    return GestureDetector(
      onTap: stock > 0 ? () => _showAddQtyDialog(context, ref) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: qtyInCart > 0 ? _gold.withValues(alpha: 0.4) : _border,
            width: qtyInCart > 0 ? 1.5 : 1,
          ),
          boxShadow: qtyInCart > 0
              ? [BoxShadow(color: _gold.withValues(alpha: 0.08), blurRadius: 12, spreadRadius: 0)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: _surfaceLight,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                    ),
                    child: product.image != null && product.image!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                            child: CachedNetworkImage(
                              imageUrl: product.image!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _gold)),
                              errorWidget: (_, __, ___) => const Icon(Icons.cookie_rounded, size: 32, color: _gold),
                            ),
                          )
                        : const Center(child: Icon(Icons.cookie_rounded, size: 36, color: _gold)),
                  ),
                  if (qtyInCart > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _gold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$qtyInCart',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _bg),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _bg.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _stockLabel,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _stockColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
              child: Text(
                product.name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Text(
                CurrencyFormatter.idr(product.price),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _gold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddQtyDialog(BuildContext context, WidgetRef ref) {
    final qtyCtrl = TextEditingController(text: '1');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 36, height: 4, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: _textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(CurrencyFormatter.idr(product.price), style: const TextStyle(fontSize: 14, color: _gold)),
            const SizedBox(height: 20),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: false,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _textPrimary),
              decoration: InputDecoration(
                labelText: 'Jumlah',
                labelStyle: const TextStyle(color: _textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _gold, width: 1.5)),
                filled: true,
                fillColor: _surfaceLight,
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
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
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
                  backgroundColor: _gold,
                  foregroundColor: _bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Tambah ke Keranjang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Qty Button ────────────────────────────────────────────────
class _QuickQtyBtn extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  const _QuickQtyBtn({required this.label, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 40,
        child: OutlinedButton(
          onPressed: () => ctrl.text = label,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            side: const BorderSide(color: _border),
            foregroundColor: _gold,
          ),
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ─── Cart Item Tile ──────────────────────────────────────────────────
class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('cart_${item.productId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: _error.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline_rounded, color: _error, size: 22),
      ),
      onDismissed: (_) => ref.read(cartProvider.notifier).removeItem(item.productId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.quantity} x ${CurrencyFormatter.idr(item.price)}',
                    style: const TextStyle(fontSize: 11, color: _textSecondary),
                  ),
                  Text(
                    CurrencyFormatter.idr(item.price * item.quantity),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _gold),
                  ),
                ],
              ),
            ),
            _QtyControls(productId: item.productId, qty: item.quantity),
          ],
        ),
      ),
    );
  }
}

// ─── Quantity Controls ───────────────────────────────────────────────
class _QtyControls extends ConsumerWidget {
  final int productId;
  final int qty;
  const _QtyControls({required this.productId, required this.qty});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyBtn(
            icon: Icons.remove_rounded,
            onTap: () => ref.read(cartProvider.notifier).updateQuantity(productId, qty - 1),
          ),
          Container(width: 1, color: _border),
          SizedBox(
            width: 36,
            child: Center(
              child: Text(
                '$qty',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textPrimary),
              ),
            ),
          ),
          Container(width: 1, color: _border),
          _QtyBtn(
            icon: Icons.add_rounded,
            onTap: () => ref.read(cartProvider.notifier).updateQuantity(productId, qty + 1),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Icon(icon, size: 16, color: _gold),
      ),
    );
  }
}

// ─── Mobile Cart Sheet ───────────────────────────────────────────────
class _MobileCartSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final VoidCallback onCheckout;

  const _MobileCartSheet({required this.scrollController, required this.onCheckout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: _surface,
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart_rounded, color: _gold, size: 18),
              const SizedBox(width: 8),
              const Text('Pesanan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary)),
              const Spacer(),
              if (cart.itemCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text('${cart.itemCount}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _gold)),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded, color: _textSecondary, size: 22),
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
                      Icon(Icons.shopping_cart_outlined, size: 44, color: _textSecondary.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      const Text('Keranjang kosong', style: TextStyle(color: _textSecondary)),
                    ],
                  ),
                )
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: _divider, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return _CartItemTile(item: item);
                  },
                ),
        ),
        if (cart.itemCount > 0)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: _surface,
              border: Border(top: BorderSide(color: _border)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${cart.itemCount} item', style: const TextStyle(fontSize: 13, color: _textSecondary)),
                      Text(
                        CurrencyFormatter.idr(cart.total),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _gold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: onCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _bg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Bayar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

// ─── Orders Sheet ────────────────────────────────────────────────────
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
      case 'pending': return _warning;
      case 'paid': return _warning;
      case 'pending_sync': return _warning;
      case 'processing': return _info;
      case 'completed': return _success;
      case 'cancelled': return _error;
      default: return _textSecondary;
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
          SnackBar(content: Text('Pesanan ${_statusLabel(status)}'), backgroundColor: _surface),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: _error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _surface,
            foregroundColor: _textPrimary,
            surfaceTintColor: Colors.transparent,
            title: const Text('Pesanan Terbaru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            automaticallyImplyLeading: false,
            actions: [
              if (!isOnline)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.cloud_off_rounded, size: 18, color: _warning),
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ],
            bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: SizedBox(height: 1, child: ColoredBox(color: _border))),
          ),
          body: ordersAsync.when(
            loading: () => Center(child: CircularProgressIndicator(color: _gold, strokeWidth: 2)),
            error: (e, _) => Center(child: Text('Gagal memuat: $e', style: const TextStyle(color: _textSecondary))),
            data: (orders) {
              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 48, color: _textSecondary.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      const Text('Belum ada pesanan', style: TextStyle(color: _textSecondary)),
                    ],
                  ),
                );
              }
              return ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: _divider, indent: 16, endIndent: 16),
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
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _textPrimary),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_fmtWIB(order.createdAt)}  •  ${CurrencyFormatter.idr(order.finalTotal)}',
                          style: const TextStyle(fontSize: 12, color: _textSecondary),
                        ),
                        if (order.isOffline)
                          const Text(
                            'Offline — akan disync saat online',
                            style: TextStyle(fontSize: 11, color: _warning),
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
    if (order.status == 'pending' || order.status == 'paid') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SmallBtn(
            label: 'Tolak',
            color: _error,
            enabled: isOnline,
            onTap: () => _updateStatus(order, 'cancelled'),
          ),
          const SizedBox(width: 6),
          _SmallBtn(
            label: 'Proses',
            color: _gold,
            enabled: isOnline,
            onTap: () => _updateStatus(order, 'processing'),
          ),
        ],
      );
    }

    if (order.status == 'processing') {
      return _SmallBtn(
        label: 'Selesai',
        color: _success,
        enabled: isOnline,
        onTap: () => _updateStatus(order, 'completed'),
      );
    }

    final color = _statusColor(order.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(_statusLabel(order.status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _SmallBtn({required this.label, required this.color, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.15) : _surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: enabled ? color : _textSecondary,
          ),
        ),
      ),
    );
  }
}
