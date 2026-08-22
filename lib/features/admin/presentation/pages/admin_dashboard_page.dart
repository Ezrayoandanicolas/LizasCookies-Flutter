import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/entities/auth_entity.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState is Authenticated ? authState.user : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        backgroundColor: const Color(0xFFE85D3A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats cards
            Row(
              children: [
                Expanded(child: _StatCard(icon: Icons.shopping_bag, label: 'Pesanan', value: '0', color: Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(icon: Icons.attach_money, label: 'Pendapatan', value: 'Rp 0', color: Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatCard(icon: Icons.inventory, label: 'Produk', value: '0', color: Colors.orange)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(icon: Icons.people, label: 'Member', value: '0', color: Colors.purple)),
              ],
            ),
            const SizedBox(height: 24),

            const Text('Menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            _MenuTile(icon: Icons.point_of_sale, title: 'POS (Point of Sale)', subtitle: 'Transaksi penjualan langsung', onTap: () => context.push('/pos')),
            _MenuTile(icon: Icons.inventory_2, title: 'Manajemen Produk', subtitle: 'Tambah, edit, hapus produk', onTap: () => context.push('/admin/products')),
            _MenuTile(icon: Icons.category, title: 'Kategori Produk', subtitle: 'Kelola kategori', onTap: () => context.push('/admin/categories')),
            _MenuTile(icon: Icons.inventory, title: 'Kelola Stok', subtitle: 'Tambah, kurangi, atur stok produk', onTap: () => context.push('/admin/stock')),
            _MenuTile(icon: Icons.receipt_long, title: 'Pesanan', subtitle: 'Lihat & kelola pesanan', onTap: () => context.push('/orders')),
            _MenuTile(icon: Icons.bar_chart, title: 'Laporan & Analitik', subtitle: 'Statistik penjualan, laba rugi', onTap: () => context.push('/admin/analytics')),
            _MenuTile(icon: Icons.money_off, title: 'Pengeluaran', subtitle: 'Catat & kelola pengeluaran', onTap: () => context.push('/admin/expenses')),
            if (user?.isAdmin == true) ...[
              _MenuTile(icon: Icons.people, title: 'Manajemen User', subtitle: 'Kelola staff & member', onTap: () {}),
              _MenuTile(icon: Icons.store, title: 'Manajemen Toko', subtitle: 'Pengaturan toko', onTap: () {}),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE8E0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFE85D3A)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
