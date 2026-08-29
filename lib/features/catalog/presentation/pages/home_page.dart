import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/products_provider.dart';
import '../../../cart/data/cart_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/entities/auth_entity.dart';

const Color _themeColor = AppColors.primary;
const Color _lightBg = AppColors.primaryContainer;

final _selectedCategoryProvider = StateProvider<String?>((ref) => null);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final cartState = ref.watch(cartProvider);
    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);

    String userName = 'Teman';
    bool isAdmin = false;
    if (authState is Authenticated) {
      userName = authState.user.name.split(' ').first;
      isAdmin = authState.user.isAdmin || authState.user.isStaff;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('LizasCookies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (productsAsync is AsyncLoading)
            const LinearProgressIndicator(minHeight: 3),
          if (productsAsync is AsyncLoading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.primaryContainer,
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Mengunduh produk...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          if (productsAsync is AsyncError)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 14, color: theme.colorScheme.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Gagal memuat produk',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.read(productsProvider.notifier).load(),
                    child: const Text('Coba Lagi', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(productsProvider.notifier).load();
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 80),
                children: [
                  _buildWelcomeBanner(userName),
                  if (isAdmin) ...[
                    _buildSectionTitle('Menu'),
                    _buildAdminMenu(context),
                  ],
                  _buildCategoryFilter(ref, context),
                  _buildSectionTitle('Semua Produk'),
                  _buildProductBody(ref),
                ],
              ),
            ),
          ),
          if (cartState.itemCount > 0) _buildCartBar(context, cartState),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner(String name) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _lightBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hai, $name!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _themeColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Mau cookies yang mana hari ini?',
                  style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Icon(Icons.cookie, size: 48, color: _themeColor),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
      ),
    );
  }

  Widget _buildAdminMenu(BuildContext context) {
    final menus = [
      _MenuData(Icons.point_of_sale, 'POS', '/pos'),
      _MenuData(Icons.category, 'Kategori', '/admin/categories'),
      _MenuData(Icons.inventory_2, 'Produk', '/admin/products'),
      _MenuData(Icons.inventory, 'Stok', '/admin/stock'),
      _MenuData(Icons.receipt_long, 'Pesanan', '/orders'),
      _MenuData(Icons.bar_chart, 'Laporan', '/admin/analytics'),
      _MenuData(Icons.money_off, 'Pengeluaran', '/admin/expenses'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: menus.length,
        itemBuilder: (context, index) {
          final menu = menus[index];
          return _MenuTile(
            icon: menu.icon,
            label: menu.label,
            onTap: () => context.push(menu.route),
          );
        },
      ),
    );
  }

  Widget _buildCategoryFilter(WidgetRef ref, BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final theme = Theme.of(context);
    final selectedCat = ref.watch(_selectedCategoryProvider);

    return productsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        final categories = products
            .expand((p) => p.categories)
            .toSet()
            .toList();
        if (categories.isEmpty) return const SizedBox.shrink();
        return Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: categories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = selectedCat == null;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: FilterChip(
                    label: const Text('Semua'),
                    selected: isSelected,
                    onSelected: (_) =>
                        ref.read(_selectedCategoryProvider.notifier).state = null,
                    selectedColor: theme.colorScheme.primaryContainer,
                    checkmarkColor: theme.colorScheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                    elevation: isSelected ? 1 : 0,
                    shadowColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                );
              }
              final cat = categories[index - 1];
              final isSelected = selectedCat == cat;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) =>
                      ref.read(_selectedCategoryProvider.notifier).state =
                          isSelected ? null : cat,
                  selectedColor: theme.colorScheme.primaryContainer,
                  checkmarkColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
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

  Widget _buildProductBody(WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    return productsAsync.when(
      loading: () => _buildProductShimmer(),
      error: (e, _) => SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('Gagal memuat produk'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.read(productsProvider.notifier).load(),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
      data: (items) {
        final selectedCat = ref.read(_selectedCategoryProvider);
        var filtered = items;
        if (selectedCat != null) {
          filtered = items.where((p) => p.categories.contains(selectedCat)).toList();
        }
        if (filtered.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cookie_outlined, size: 48, color: AppColors.outlineVariant),
                  const SizedBox(height: 12),
                  const Text(
                    'Belum ada produk',
                    style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        }
        return _buildProductGrid(ref, filtered);
      },
    );
  }

  Widget _buildProductGrid(WidgetRef ref, List<ProductItem> products) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) => _buildProductCard(context, ref, products[index]),
    );
  }

  Widget _buildProductCard(BuildContext context, WidgetRef ref, ProductItem product) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: product.image != null && product.image!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: product.image!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.cookie, size: 48, color: _themeColor),
                    )
                  : const Icon(Icons.cookie, size: 48, color: _themeColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.idr(product.price),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _themeColor,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(cartProvider.notifier).addItem(
                            product.id,
                            product.name,
                            product.price,
                            image: product.image,
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${product.name} ditambahkan ke keranjang'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Tambah ke Keranjang'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductShimmer() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 100, color: AppColors.surfaceContainer),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 60, color: AppColors.surfaceContainer),
                  const SizedBox(height: 10),
                  Container(
                    height: 32,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartBar(BuildContext context, CartState cart) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _lightBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_cart, size: 18, color: _themeColor),
                  const SizedBox(width: 6),
                  Text(
                    '${cart.itemCount}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _themeColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                CurrencyFormatter.idr(cart.total),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => context.push('/pos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _themeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Lihat Keranjang'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuData {
  final IconData icon;
  final String label;
  final String route;
  _MenuData(this.icon, this.label, this.route);
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _lightBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 26, color: _themeColor),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
