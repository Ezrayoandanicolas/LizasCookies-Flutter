import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../../cart/data/cart_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/entities/auth_entity.dart';

const Color _themeColor = AppColors.primary;
const Color _lightBg = AppColors.primaryContainer;

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final authState = ref.watch(authNotifierProvider);

    String userName = 'Teman';
    bool isAdmin = false;
    if (authState is Authenticated) {
      userName = authState.user.name.split(' ').first;
      isAdmin = authState.user.isAdmin || authState.user.isStaff;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('LizasCookies'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          _buildWelcomeBanner(context, userName),
          if (isAdmin) ...[
            _buildSectionTitle(context, 'Menu'),
            _buildAdminMenu(context),
          ],
        ],
      ),
      bottomNavigationBar: cartState.itemCount > 0
          ? _buildCartBar(context, cartState)
          : null,
    );
  }

  Widget _buildWelcomeBanner(BuildContext context, String name) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(Responsive.padding(context), 8, Responsive.padding(context), 4),
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(Responsive.padding(context), 20, Responsive.padding(context), 8),
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

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: Responsive.padding(context)),
        itemCount: menus.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
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
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _lightBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: _themeColor),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
