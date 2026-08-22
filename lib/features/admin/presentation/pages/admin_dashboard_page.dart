import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/entities/auth_entity.dart';

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final tenantQp = ref.watch(tenantQueryProvider).valueOrNull ?? <String, dynamic>{};
  try {
    final res = await dio.get('/superadmin/dashboard/stats', queryParameters: tenantQp);
    final data = res.data;
    if (data is Map && data.containsKey('data')) {
      return Map<String, dynamic>.from(data['data']);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  } catch (_) {
    return {};
  }
});

String _formatNumber(dynamic value) {
  final n = value is num ? value : num.tryParse(value?.toString() ?? '0') ?? 0;
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}jt';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}rb';
  return n.toInt().toString();
}

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState is Authenticated ? authState.user : null;
    final theme = Theme.of(context);
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            statsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (stats) => Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _StatCard(icon: Icons.shopping_bag, label: 'Pesanan', value: '${stats['total_orders'] ?? 0}', color: theme.colorScheme.primary)),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(icon: Icons.attach_money, label: 'Pendapatan', value: 'Rp ${_formatNumber(stats['revenue'] ?? 0)}', color: theme.colorScheme.tertiary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _StatCard(icon: Icons.inventory, label: 'Produk', value: '${stats['total_products'] ?? 0}', color: theme.colorScheme.secondary)),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(icon: Icons.money_off, label: 'Pengeluaran', value: 'Rp ${_formatNumber(stats['expenses'] ?? 0)}', color: theme.colorScheme.error)),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            Text('Menu', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            _MenuTile(icon: Icons.point_of_sale, title: 'POS (Point of Sale)', subtitle: 'Transaksi penjualan langsung', onTap: () => context.push('/pos')),
            _MenuTile(icon: Icons.inventory_2, title: 'Manajemen Produk', subtitle: 'Tambah, edit, hapus produk', onTap: () => context.push('/admin/products')),
            _MenuTile(icon: Icons.category, title: 'Kategori Produk', subtitle: 'Kelola kategori', onTap: () => context.push('/admin/categories')),
            _MenuTile(icon: Icons.inventory, title: 'Kelola Stok', subtitle: 'Tambah, kurangi, atur stok produk', onTap: () => context.push('/admin/stock')),
            _MenuTile(icon: Icons.receipt_long, title: 'Pesanan', subtitle: 'Lihat & kelola pesanan', onTap: () => context.push('/orders')),
            _MenuTile(icon: Icons.bar_chart, title: 'Laporan & Analitik', subtitle: 'Statistik penjualan, laba rugi', onTap: () => context.push('/admin/analytics')),
            _MenuTile(icon: Icons.money_off, title: 'Pengeluaran', subtitle: 'Catat & kelola pengeluaran', onTap: () => context.push('/admin/expenses')),
            if (user?.isAdmin == true) ...[
              _MenuTile(icon: Icons.people, title: 'Manajemen User', subtitle: 'Kelola staff & member', onTap: () => context.push('/admin/users')),
              _MenuTile(icon: Icons.store, title: 'Manajemen Toko', subtitle: 'Pengaturan toko', onTap: () => context.push('/admin/stores')),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
