import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../catalog/data/products_provider.dart';
import '../../../cart/data/cart_provider.dart';
import '../../../orders/presentation/pages/orders_page.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/network/connectivity_provider.dart';
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
      body: Column(
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
          productsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (products) {
              final categories = products
                  .expand((p) => p.categories)
                  .toSet()
                  .toList();
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
                      final isSelected = _selectedCategory == null;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutBack,
                        child: FilterChip(
                          label: const Text('Semua'),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = null),
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
                    final isSelected = _selectedCategory == cat;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      child: FilterChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
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
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).orientation == Orientation.landscape ? 8 : 4,
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
      bottomNavigationBar: cart.itemCount > 0
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

class _ProductCard extends ConsumerWidget {
  final ProductItem product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);
    final inCart =
        cart.items.where((i) => i.productId == product.id).toList();
    final qtyInCart = inCart.isNotEmpty ? inCart.first.quantity : 0;

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
                      errorWidget: (_, __, ___) => Icon(
                        Icons.cookie,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.cookie,
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
            child: Text(
              product.name,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
            child: Text(
              CurrencyFormatter.idr(product.price),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
                fontSize: 10,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
            child: Text(
              'Stok: ${product.stock}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: product.stock > 0
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.error,
                fontSize: 9,
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            child: qtyInCart > 0
                ? _QtyControls(productId: product.id, qty: qtyInCart)
                : SizedBox(
                    width: double.infinity,
                    height: 26,
                    child: FilledButton.tonal(
                      onPressed: () {
                        ref.read(cartProvider.notifier).addItem(
                              product.id,
                              product.name,
                              product.price,
                              image: product.image,
                            );
                      },
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text('Tambah',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ),
          ),
        ],
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
