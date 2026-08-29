import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/entities/auth_entity.dart';

const _wib = Duration(hours: 7);
String _fmtWIB(DateTime? d) {
  if (d == null) return '-';
  final wib = d.toUtc().add(_wib);
  return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(wib);
}

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

  Map<String, dynamic> toJson() => {
    'product_name': name,
    'quantity': quantity,
    'price': price,
  };
}

class OrderData {
  final int? id;
  final String? localId;
  final String status;
  final double totalAmount;
  final double discountAmount;
  final String paymentMethod;
  final String orderSource;
  final DateTime? createdAt;
  final List<OrderItem> items;
  final String? notes;
  final String? storeName;
  final bool isOffline;

  const OrderData({
    this.id,
    this.localId,
    required this.status,
    required this.totalAmount,
    this.discountAmount = 0,
    this.paymentMethod = '-',
    this.orderSource = '-',
    this.createdAt,
    this.items = const [],
    this.notes,
    this.storeName,
    this.isOffline = false,
  });

  String get orderNumber => id != null ? '#$id' : '#OFFLINE-${(localId ?? '').substring(0, 8)}';
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
      id: json['id'] != null ? (json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString())) : null,
      localId: json['local_id']?.toString(),
      status: (json['status'] ?? 'pending').toString().toLowerCase(),
      totalAmount: double.tryParse((json['total_amount'] ?? json['total'] ?? 0).toString()) ?? 0,
      discountAmount: double.tryParse((json['discount_amount'] ?? 0).toString()) ?? 0,
      paymentMethod: (json['payment_method'] ?? '-').toString(),
      orderSource: (json['order_source'] ?? '-').toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      items: itemsList,
      notes: json['notes']?.toString(),
      storeName: json['store'] is Map ? json['store']['name']?.toString() : null,
      isOffline: json['is_offline'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'local_id': localId,
    'status': status,
    'total_amount': totalAmount,
    'discount_amount': discountAmount,
    'payment_method': paymentMethod,
    'order_source': orderSource,
    'created_at': createdAt?.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
    'notes': notes,
    'store_name': storeName,
    'is_offline': isOffline,
  };
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

  List<OrderData> _getOfflineOrders() {
    final raw = LocalStorage.getAllPendingOrders();
    return raw.where((o) => o['body'] is Map).map((o) {
      final body = Map<String, dynamic>.from(o['body'] as Map);
      final itemsList = <OrderItem>[];
      if (body['items'] is List) {
        itemsList.addAll(
          (body['items'] as List).map((e) => OrderItem.fromJson(e as Map<String, dynamic>)),
        );
      }
      return OrderData(
        localId: o['id']?.toString(),
        status: 'pending_sync',
        totalAmount: double.tryParse((body['total'] ?? body['grand_total'] ?? 0).toString()) ?? 0,
        paymentMethod: (body['payment_method'] ?? '-').toString(),
        orderSource: 'POS Offline',
        createdAt: o['created_at'] != null ? DateTime.tryParse(o['created_at'].toString()) : null,
        items: itemsList,
        isOffline: true,
      );
    }).toList();
  }

  Future<void> load() async {
    _page = 1;
    _hasMore = true;
    state = const AsyncValue.loading();

    final offlineOrders = _getOfflineOrders();

    try {
      final params = <String, dynamic>{..._tenantQp, 'page': 1, 'per_page': 50};
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
      _hasMore = list.length >= 50;
      final onlineOrders = list.map((e) => OrderData.fromJson(e as Map<String, dynamic>)).toList();
      state = AsyncValue.data([...offlineOrders, ...onlineOrders]);
    } catch (e, st) {
      if (offlineOrders.isNotEmpty) {
        state = AsyncValue.data(offlineOrders);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    _isLoadingMore = true;
    _page++;
    try {
      final params = <String, dynamic>{..._tenantQp, 'page': _page, 'per_page': 50};
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
      _hasMore = list.length >= 50;
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([
        ...current,
        ...list.map((e) => OrderData.fromJson(e as Map<String, dynamic>)),
      ]);
    } catch (_) {}
    _isLoadingMore = false;
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    try {
      await _dio.put(
        '/superadmin/orders/$orderId/status',
        queryParameters: _tenantQp,
        data: {'status': status},
      );
      await load();
    } on DioException catch (e) {
      String msg = e.message ?? 'Gagal update status';
      final data = e.response?.data;
      if (data is Map && data.containsKey('message')) {
        msg = data['message'].toString();
      }
      throw Exception(msg);
    }
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
      case 'pending_sync': return 'Menunggu Sync';
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
        title: const Text('Pesanan'),
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
          final processed = orders.where((o) => o.status == 'pending' || o.status == 'paid' || o.status == 'pending_sync' || o.status == 'processing').toList();
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
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;

  const _OrderCard({
    required this.order,
    required this.fmt,
    required this.statusColor,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = statusColor(order.status);
    final theme = Theme.of(context);
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
                  if (order.isOffline) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.cloud_off, size: 14, color: Colors.orange.shade600),
                  ],
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
              Text(_fmtWIB(order.createdAt),
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
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

  Future<void> _showDetail(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final connectivity = ref.read(connectivityProvider);
    final isOnline = connectivity == ConnectivityStatus.online;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text('Pesanan ${order.orderNumber}'),
            if (order.isOffline) ...[
              const SizedBox(width: 8),
              Icon(Icons.cloud_off, size: 16, color: Colors.orange.shade600),
            ],
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('Status', statusLabel(order.status)),
              _row('Tanggal', _fmtWIB(order.createdAt)),
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
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: theme.colorScheme.primary)),
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
          if (order.status == 'pending' || order.status == 'paid') ...[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            FilledButton(
              onPressed: isOnline ? () => _updateStatus(ctx, ref, 'cancelled', 'Dibatalkan') : null,
              style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
              child: const Text('Tolak'),
            ),
            FilledButton(
              onPressed: isOnline ? () => _updateStatus(ctx, ref, 'processing', 'Diproses') : null,
              child: const Text('Proses'),
            ),
          ] else if (order.status == 'processing') ...[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            FilledButton(
              onPressed: isOnline ? () => _updateStatus(ctx, ref, 'completed', 'Selesai') : null,
              child: const Text('Selesai'),
            ),
          ] else ...[
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ],
        ],
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, String status, String label) async {
    if (order.id == null) return;
    try {
      await ref.read(ordersProvider.notifier).updateOrderStatus(order.id!, status);
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pesanan $label')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
