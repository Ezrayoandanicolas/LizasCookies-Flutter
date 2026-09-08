import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../../cart/data/cart_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/entities/auth_entity.dart';

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
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 130,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: const Text('LizasCookies', style: TextStyle(fontWeight: FontWeight.w600)),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, Color(0xFFB06A3B)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(Responsive.padding(context), 52, Responsive.padding(context), 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Hai, $userName! 👋',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAdmin ? 'Kelola bisnis Anda hari ini' : 'Mau cookies yang mana hari ini?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(Responsive.padding(context), 16, Responsive.padding(context), 80),
            sliver: isAdmin
                ? SliverToBoxAdapter(child: _buildAdminSection(context))
                : SliverToBoxAdapter(
                    child: _buildCustomerSection(context),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: cartState.itemCount > 0
          ? _buildCartBar(context, cartState)
          : null,
    );
  }

  Widget _buildAdminSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Akses Cepat', 'Semua fitur dalam satu tempat'),
        const SizedBox(height: 12),
        _buildMenuGrid(context),
      ],
    );
  }

  Widget _buildCustomerSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Selamat Datang', 'Temukan cookies favorit Anda'),
        const SizedBox(height: 16),
        _buildCustomerActionCard(
          context,
          icon: Icons.storefront,
          title: 'Mulai Belanja',
          subtitle: 'Lihat katalog produk dan pesan sekarang',
          route: '/pos',
          color: AppColors.primary,
        ),
        const SizedBox(height: 12),
        _buildCustomerActionCard(
          context,
          icon: Icons.receipt_long,
          title: 'Pesanan Saya',
          subtitle: 'Lacak status pesanan Anda',
          route: '/orders',
          color: const Color(0xFF6B7B3A),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    final menus = [
      _MenuData(
        Icons.point_of_sale_rounded,
        'POS',
        '/pos',
        const Color(0xFFD4883A),
        const Color(0xFFF5DEB3),
      ),
      _MenuData(
        Icons.category_rounded,
        'Kategori',
        '/admin/categories',
        const Color(0xFF6B7B3A),
        const Color(0xFFD4E8C0),
      ),
      _MenuData(
        Icons.inventory_2_rounded,
        'Produk',
        '/admin/products',
        const Color(0xFF3A7BD4),
        const Color(0xFFB3D4F5),
      ),
      _MenuData(
        Icons.warehouse_rounded,
        'Stok',
        '/admin/stock',
        const Color(0xFF8B5CF6),
        const Color(0xFFDDD6FE),
      ),
      _MenuData(
        Icons.receipt_long_rounded,
        'Pesanan',
        '/orders',
        const Color(0xFF0EA5E9),
        const Color(0xFFCFFAFE),
      ),
      _MenuData(
        Icons.analytics_rounded,
        'Laporan',
        '/admin/analytics',
        const Color(0xFF10B981),
        const Color(0xFFD1FAE5),
      ),
      _MenuData(
        Icons.payments_rounded,
        'Pengeluaran',
        '/admin/expenses',
        const Color(0xFFEF4444),
        const Color(0xFFFEE2E2),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.gridColumns(context, mobile: 3, tablet: 4, desktop: 4),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final menu = menus[index];
        return _MenuCard(
          icon: menu.icon,
          label: menu.label,
          iconColor: menu.iconColor,
          bgColor: menu.bgColor,
          onTap: () => context.push(menu.route),
        );
      },
    );
  }

  Widget _buildCustomerActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.outlineVariant, size: 22),
            ],
          ),
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
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_cart, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${cart.itemCount}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
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
                backgroundColor: AppColors.primary,
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
  final Color iconColor;
  final Color bgColor;
  _MenuData(this.icon, this.label, this.route, this.iconColor, this.bgColor);
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: iconColor),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: iconColor.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
