import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/entities/auth_entity.dart';

class OrderItem {
  final String name;
  final int quantity;
  final double price;

  const OrderItem({required this.name, required this.quantity, required this.price});
  double get total => price * quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    String name = '-';
    if (json['product'] is Map) {
      name = (json['product']['name'] ?? '-').toString();
    } else {
      name = (json['product_name'] ?? json['name'] ?? '-').toString();
    }
    return OrderItem(
      name: name,
      quantity: (json['quantity'] ?? 1).toInt(),
      price: double.tryParse((json['price'] ?? 0).toString()) ?? 0,
    );
  }
}

class OrderData {
  final int id;
  final String status;
  final double totalAmount;
  final double discountAmount;
  final String paymentMethod;
  final String orderSource;
  final DateTime? createdAt;
  final List<OrderItem> items;
  final String? notes;
  final String? storeName;

  const OrderData({
    required this.id,
    required this.status,
    required this.totalAmount,
    this.discountAmount = 0,
    this.paymentMethod = '-',
    this.orderSource = '-',
    this.createdAt,
    this.items = const [],
    this.notes,
    this.storeName,
  });

  String get orderNumber => '#$id';
  double get finalTotal => totalAmount - discountAmount;

  String get itemsSummary {
    if (items.isEmpty) return '-';
    final count = items.length;
    final firstItem = items.first.name;
    if (count == 1) return '$firstItem x${items.first.quantity}';
    return '$firstItem + ${count - 1} lainnya';
  }

  factory OrderData.fromJson(Map<String, dynamic> json) {
    final itemsList = <OrderItem>[];
    if (json['items'] is List) {
      itemsList.addAll(
        (json['items'] as List).map((e) => OrderItem.fromJson(e as Map<String, dynamic>)),
      );
    }

    return OrderData(
      id: (json['id'] ?? 0).toInt(),
      status: (json['status'] ?? 'pending').toString().toLowerCase(),
      totalAmount: double.tryParse((json['total_amount'] ?? json['total'] ?? 0).toString()) ?? 0,
      discountAmount: double.tryParse((json['discount_amount'] ?? 0).toString()) ?? 0,
      paymentMethod: (json['payment_method'] ?? '-').toString(),
      orderSource: (json['order_source'] ?? '-').toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      items: itemsList,
      notes: json['notes']?.toString(),
      storeName: json['store'] is Map ? json['store']['name']?.toString() : null,
    );
  }
}

class OrdersNotifier extends StateNotifier<AsyncValue<List<OrderData>>> {
  final Dio _dio;
  final Map<String, dynamic> _tenantQp;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  OrdersNotifier(this._dio, this._tenantQp) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    _page = 1;
    _hasMore = true;
    state = const AsyncValue.loading();
    try {
      final params = <String, dynamic>{..._tenantQp, 'page': 1, 'per_page': 20};
      final res = await _dio.get('/superadmin/orders', queryParameters: params);
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
      state = AsyncValue.data(
        list.map((e) => OrderData.fromJson(e as Map<String, dynamic>)).toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    _isLoadingMore = true;
    _page++;
    try {
      final params = <String, dynamic>{..._tenantQp, 'page': _page, 'per_page': 20};
      final res = await _dio.get('/superadmin/orders', queryParameters: params);
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
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([
        ...current,
        ...list.map((e) => OrderData.fromJson(e as Map<String, dynamic>)),
      ]);
    } catch (_) {}
    _isLoadingMore = false;
  }
}

final ordersProvider = StateNotifierProvider<OrdersNotifier, AsyncValue<List<OrderData>>>((ref) {
  final dio = ref.watch(dioClientProvider).dio;
  final tenantQp = ref.watch(tenantQueryProvider).valueOrNull ?? <String, dynamic>{};
  return OrdersNotifier(dio, tenantQp);
});

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});
  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification &&
        notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
      ref.read(ordersProvider.notifier).loadMore();
    }
    return false;
  }

  String _fmt(double amount) => CurrencyFormatter.idr(amount);
  String _fmtDate(DateTime? d) => d != null ? DateFormat('dd MMM yyyy, HH:mm').format(d) : '-';

  Color _statusColor(String s) {
    switch (s) {
      case 'pending': return Colors.orange;
      case 'paid': return Colors.orange;
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
      case 'processing': return 'Diproses';
      case 'completed': return 'Selesai';
      case 'cancelled': return 'Dibatalkan';
      default: return s.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan Saya'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Semua'),
            Tab(text: 'Diproses'),
            Tab(text: 'Selesai'),
            Tab(text: 'Dibatalkan'),
          ],
        ),
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Gagal memuat pesanan', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(ordersProvider.notifier).load(),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (orders) {
          final all = orders;
          final processed = orders.where((o) => o.status == 'pending' || o.status == 'paid' || o.status == 'processing').toList();
          final completed = orders.where((o) => o.status == 'completed').toList();
          final cancelled = orders.where((o) => o.status == 'cancelled').toList();

          final lists = [all, processed, completed, cancelled];

          return TabBarView(
            controller: _tabController,
            children: lists.map((list) {
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Belum ada pesanan', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.read(ordersProvider.notifier).load(),
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    itemCount: list.length + (ref.watch(ordersProvider).valueOrNull != null && ref.read(ordersProvider.notifier).hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == list.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _OrderCard(
                        order: list[index],
                        fmt: _fmt,
                        fmtDate: _fmtDate,
                        statusColor: _statusColor,
                        statusLabel: _statusLabel,
                      );
                    },
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final OrderData order;
  final String Function(double) fmt;
  final String Function(DateTime?) fmtDate;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;

  const _OrderCard({
    required this.order,
    required this.fmt,
    required this.fmtDate,
    required this.statusColor,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = statusColor(order.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(order.orderNumber,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(statusLabel(order.status),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(fmtDate(order.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (order.storeName != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.store, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(order.storeName!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(order.itemsSummary,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(fmt(order.finalTotal),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFE85D3A))),
                  const Spacer(),
                  Text(order.paymentMethod.toUpperCase(),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approveOrder(BuildContext context, WidgetRef ref) async {
    final dio = ref.read(dioClientProvider).dio;
    final tenantQp = ref.read(tenantQueryProvider).valueOrNull ?? <String, dynamic>{};
    try {
      await dio.put(
        '/superadmin/orders/${order.id}/status',
        queryParameters: tenantQp,
        data: {'status': 'processing'},
      );
      if (context.mounted) Navigator.pop(context);
      ref.read(ordersProvider.notifier).load();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesanan diproses')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _rejectOrder(BuildContext context, WidgetRef ref) async {
    final dio = ref.read(dioClientProvider).dio;
    final tenantQp = ref.read(tenantQueryProvider).valueOrNull ?? <String, dynamic>{};
    try {
      await dio.put(
        '/superadmin/orders/${order.id}/status',
        queryParameters: tenantQp,
        data: {'status': 'cancelled'},
      );
      if (context.mounted) Navigator.pop(context);
      ref.read(ordersProvider.notifier).load();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesanan dibatalkan')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _completeOrder(BuildContext context, WidgetRef ref) async {
    final dio = ref.read(dioClientProvider).dio;
    final tenantQp = ref.read(tenantQueryProvider).valueOrNull ?? <String, dynamic>{};
    try {
      await dio.put(
        '/superadmin/orders/${order.id}/status',
        queryParameters: tenantQp,
        data: {'status': 'completed'},
      );
      if (context.mounted) Navigator.pop(context);
      ref.read(ordersProvider.notifier).load();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesanan selesai')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pesanan ${order.orderNumber}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('Status', statusLabel(order.status)),
              _row('Tanggal', fmtDate(order.createdAt)),
              _row('Pembayaran', order.paymentMethod.toUpperCase()),
              _row('Sumber', order.orderSource),
              if (order.storeName != null) _row('Toko', order.storeName!),
              if (order.discountAmount > 0) _row('Diskon', fmt(order.discountAmount)),
              const Divider(height: 24),
              const Text('Item:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (order.items.isEmpty)
                const Text('Tidak ada item')
              else
                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text('${item.name} x${item.quantity}', style: const TextStyle(fontSize: 13))),
                          Text(fmt(item.total), style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    )),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(fmt(order.finalTotal),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFFE85D3A))),
                ],
              ),
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Catatan: ${order.notes}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ],
          ),
        ),
        actions: [
          if (order.status == 'pending') ...[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            FilledButton(
              onPressed: () => _rejectOrder(ctx, ref),
              style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
              child: const Text('Tolak'),
            ),
            FilledButton(
              onPressed: () => _approveOrder(ctx, ref),
              child: const Text('Proses'),
            ),
          ] else if (order.status == 'processing') ...[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            FilledButton(
              onPressed: () => _completeOrder(ctx, ref),
              child: const Text('Selesai'),
            ),
          ] else ...[
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
