import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/providers/tenant_provider.dart';

const _green = Color(0xFF2E7D32);
const _red = Color(0xFFC62828);
const _blue = Color(0xFF1565C0);
const _orange = Color(0xFFEF6C00);

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final tenantQp = ref.watch(tenantQueryProvider).valueOrNull ?? <String, dynamic>{};
  final res = await dio.get('/superadmin/dashboard/stats', queryParameters: tenantQp);
  return res.data as Map<String, dynamic>;
});

final dailyPnlProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, dateRange) async {
  final dio = ref.watch(dioClientProvider).dio;
  final tenantQp = ref.watch(tenantQueryProvider).valueOrNull ?? <String, dynamic>{};
  final parts = dateRange.split('|');
  final res = await dio.get('/superadmin/dashboard/daily-profit-loss', queryParameters: {
    ...tenantQp,
    'start_date': parts[0],
    'end_date': parts[1],
  });
  return res.data as Map<String, dynamic>;
});

String _formatCurrency(num value) => CurrencyFormatter.idr(value);

String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String _daysAgo(int days) {
  final d = DateTime.now().subtract(Duration(days: days));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String _monthsAgo(int months) {
  final d = DateTime.now();
  int year = d.year;
  int month = d.month - months;
  while (month < 1) {
    month += 12;
    year--;
  }
  return '$year-${month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  int _selectedRange = 1;
  String _dateRange = '${_monthsAgo(1)}|${_today()}';

  static const _ranges = [
    ('7 Hari', 0),
    ('30 Hari', 1),
    ('3 Bulan', 2),
    ('1 Tahun', 3),
  ];

  void _applyRange(int idx) {
    String start;
    final end = _today();
    switch (idx) {
      case 0:
        start = _daysAgo(7);
        break;
      case 1:
        start = _monthsAgo(1);
        break;
      case 2:
        start = _monthsAgo(3);
        break;
      case 3:
        start = _monthsAgo(12);
        break;
      default:
        start = _monthsAgo(1);
    }
    setState(() {
      _selectedRange = idx;
      _dateRange = '$start|$end';
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final pnlAsync = ref.watch(dailyPnlProvider(_dateRange));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      appBar: AppBar(
        title: const Text('Laporan & Analitik', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(dailyPnlProvider);
        },
        color: Theme.of(context).colorScheme.primary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildDateSelector(),
            const SizedBox(height: 16),
            statsAsync.when(
              loading: () => SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))),
              error: (e, _) => _errorBox('Gagal memuat statistik', () => ref.invalidate(dashboardStatsProvider)),
              data: (data) => _buildStatsSection(data),
            ),
            const SizedBox(height: 20),
            statsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (data) => _buildRevenueChart(data),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Profit & Loss Harian'),
            const SizedBox(height: 8),
            pnlAsync.when(
              loading: () => SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))),
              error: (e, _) => _errorBox('Gagal memuat data P&L', () => ref.invalidate(dailyPnlProvider)),
              data: (data) => _buildPnlSection(data),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rentang Waktu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 10),
          Row(
            children: List.generate(_ranges.length, (i) {
              final (label, _) = _ranges[i];
              final selected = _selectedRange == i;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < _ranges.length - 1 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => _applyRange(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 38,
                      decoration: BoxDecoration(
                        color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(Map<String, dynamic> data) {
    final stats = data['stats'] as Map<String, dynamic>? ?? {};
    final revenue = (stats['total_revenue'] ?? 0).toDouble();
    final expenses = (stats['total_expenses'] ?? 0).toDouble();
    final netProfit = (stats['net_profit'] ?? 0).toDouble();
    final orderCount = stats['new_orders'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _statCard('Total Pendapatan', _formatCurrency(revenue), _green, Icons.trending_up_rounded),
        _statCard('Total Pengeluaran', _formatCurrency(expenses), _red, Icons.money_off_rounded),
        _statCard('Laba Bersih', _formatCurrency(netProfit), _blue, Icons.account_balance_wallet_rounded),
        _statCard('Total Pesanan', '$orderCount', _orange, Icons.shopping_bag_rounded),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(Map<String, dynamic> data) {
    final monthlyRevenue = (data['monthly_revenue'] as List<dynamic>?) ?? [];
    if (monthlyRevenue.isEmpty) return const SizedBox.shrink();

    final maxRevenue = monthlyRevenue
        .map((e) => (e['revenue'] ?? 0).toDouble())
        .fold<double>(0, (a, b) => b > a ? b : a);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pendapatan Bulanan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87)),
          const SizedBox(height: 16),
          ...monthlyRevenue.map((item) {
            final month = (item['month'] ?? '').toString();
            final revenue = (item['revenue'] ?? 0).toDouble();
            final ratio = maxRevenue > 0 ? revenue / maxRevenue : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(month, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                      Text(_formatCurrency(revenue), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(
                            height: 22,
                            width: constraints.maxWidth,
                            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(6)),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                            height: 22,
                            width: constraints.maxWidth * ratio.clamp(0.0, 1.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Color(0xFFFF8A65)]),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87));
  }

  Widget _buildPnlSection(Map<String, dynamic> data) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final daily = (data['daily_breakdown'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ringkasan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
              const SizedBox(height: 10),
              _summaryRow('Pendapatan Kotor', (summary['gross_revenue'] ?? 0).toDouble(), _green),
              _summaryRow('Total Diskon', -((summary['total_discounts'] ?? 0).toDouble()), _red),
              _summaryRow('COGS', -((summary['total_cogs'] ?? 0).toDouble()), _red),
              _summaryRow('Total Pengeluaran', -((summary['total_expenses'] ?? 0).toDouble()), _red),
              const Divider(height: 20),
              _summaryRow('Laba Bersih', (summary['net_profit'] ?? 0).toDouble(), _blue, bold: true),
              const SizedBox(height: 6),
              Row(
                children: [
                  _badge('${summary['order_count'] ?? 0} pesanan', _orange),
                  const SizedBox(width: 8),
                  _badge('${summary['expense_count'] ?? 0} pengeluaran', Colors.grey),
                ],
              ),
            ],
          ),
        ),
        if (daily.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Detail Harian', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
          const SizedBox(height: 8),
          ...daily.map((item) => _dailyCard(item as Map<String, dynamic>)),
        ],
      ],
    );
  }

  Widget _summaryRow(String label, double amount, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          Text(_formatCurrency(amount), style: TextStyle(fontSize: 13, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _dailyCard(Map<String, dynamic> item) {
    final date = (item['date'] ?? '').toString();
    final revenue = (item['revenue'] ?? 0).toDouble();
    final cogs = (item['cogs'] ?? 0).toDouble();
    final expenses = (item['expenses'] ?? 0).toDouble();
    final profit = (item['profit'] ?? 0).toDouble();
    final orderCount = item['order_count'] ?? 0;
    final isPositive = profit >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
              _badge('$orderCount pesanan', _orange),
            ],
          ),
          const Divider(height: 16),
          _detailRow('Pendapatan', _formatCurrency(revenue), Colors.grey.shade700),
          const SizedBox(height: 4),
          _detailRow('COGS', '-${_formatCurrency(cogs)}', _red),
          const SizedBox(height: 4),
          _detailRow('Pengeluaran', '-${_formatCurrency(expenses)}', _red),
          const Divider(height: 14),
          _detailRow('Profit', _formatCurrency(profit), isPositive ? _green : _red, bold: true),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, Color valueColor, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        Text(
          value,
          style: TextStyle(fontSize: 12, color: valueColor, fontWeight: bold ? FontWeight.w700 : FontWeight.w600),
        ),
      ],
    );
  }

  Widget _errorBox(String message, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 36),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh, size: 18, color: Theme.of(context).colorScheme.primary),
            label: Text('Coba Lagi', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
  }
}
