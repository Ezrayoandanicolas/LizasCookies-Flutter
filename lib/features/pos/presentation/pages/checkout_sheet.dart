import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../cart/data/cart_provider.dart';
import '../../../catalog/data/products_provider.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/utils/currency_formatter.dart';



class CheckoutSheet extends ConsumerStatefulWidget {
  final bool isPage;
  const CheckoutSheet({super.key, this.isPage = false});

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  String _paymentMethod = 'Tunai';
  bool _usePpn = true;
  final _ppnRate = 0.11;
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _processing = false;

  static const _methods = ['Tunai', 'QRIS', 'Transfer Bank', 'Kartu'];

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal {
    final cart = ref.read(cartProvider);
    return cart.total;
  }

  double get _tax => _usePpn ? _subtotal * _ppnRate : 0;
  double get _grandTotal => _subtotal + _tax;

  double get _amountPaid {
    return double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;
  }

  double get _change => _amountPaid - _grandTotal;

  void _onAmountChanged(String value) {
    final raw = value.replaceAll('.', '').replaceAll(',', '');
    if (raw.isEmpty) {
      setState(() {});
      return;
    }
    final number = int.tryParse(raw);
    if (number == null) return;
    final formatted = number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() {});
  }

  Future<void> _processPayment() async {
    if (_processing) return;

    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) return;

    if (_paymentMethod == 'Tunai' && _amountPaid < _grandTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah bayar kurang dari total')),
      );
      return;
    }

    setState(() => _processing = true);

    try {
      final connectivity = ref.read(connectivityProvider);
      final isOnline = connectivity == ConnectivityStatus.online;

      final items = cart.items
          .map((item) => {
                'product_id': item.productId,
                'quantity': item.quantity,
              })
          .toList();

      final body = <String, dynamic>{
        'items': items,
        'payment_method': _paymentMethod.toLowerCase().replaceAll(' ', '_'),
        'order_source': 'direct',
        'notes': _notesController.text.isNotEmpty ? _notesController.text : null,
      };

      if (_paymentMethod == 'Tunai') {
        body['discount_amount'] = 0;
      }

      if (isOnline) {
        final dio = ref.read(dioClientProvider).dio;
        await dio.post('/cashier/pos/orders', data: body);
      } else {
        final orderId = const Uuid().v4();
        final orderData = {
          'id': orderId,
          'endpoint': '/cashier/pos/orders',
          'body': body,
          'status': 'pending_sync',
          'retry_count': 0,
          'created_at': DateTime.now().toIso8601String(),
        };
        await LocalStorage.saveOfflineOrder(orderId, orderData);
      }

      if (!mounted) return;

      ref.read(cartProvider.notifier).clear();
      ref.read(productsProvider.notifier).load();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOnline
                ? 'Pembayaran berhasil!'
                : 'Order tersimpan offline, akan disync saat online',
          ),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );

      if (widget.isPage) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses: $e'),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Checkout',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildItemSection(cart),
                    const SizedBox(height: 20),
                    _buildSummarySection(),
                    const SizedBox(height: 20),
                    _buildPaymentSection(),
                    if (_paymentMethod == 'Tunai') ...[
                      const SizedBox(height: 16),
                      _buildCashSection(),
                    ],
                    const SizedBox(height: 12),
                    _buildNotesSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemSection(CartState cart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item (${cart.itemCount})',
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...cart.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.quantity} x ${CurrencyFormatter.idr(item.price)}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.idr(item.total),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildSummarySection() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _summaryRow('Subtotal', CurrencyFormatter.idr(_subtotal)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PPN (11%)',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: _usePpn,
                  onChanged: (v) => setState(() => _usePpn = v),
                ),
              ),
            ],
          ),
          if (_usePpn) ...[
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                CurrencyFormatter.idr(_tax),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
          const Divider(height: 24),
          _summaryRow(
            'Total',
            CurrencyFormatter.idr(_grandTotal),
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 15 : 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: bold ? Theme.of(context).colorScheme.primary : Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: bold ? Theme.of(context).colorScheme.primary : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Metode Pembayaran',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _methods.map((method) {
            final isSelected = _paymentMethod == method;
            final icon = _paymentIcon(method);
            return GestureDetector(
              onTap: () => setState(() => _paymentMethod = method),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[300]!,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 18,
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      method,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _paymentIcon(String method) {
    switch (method) {
      case 'Tunai':
        return Icons.payments_outlined;
      case 'QRIS':
        return Icons.qr_code_2;
      case 'Transfer Bank':
        return Icons.account_balance;
      case 'Kartu':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }

  Widget _buildCashSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Jumlah Bayar',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: _onAmountChanged,
          decoration: InputDecoration(
            hintText: 'Masukkan jumlah bayar',
            prefixText: 'Rp ',
            prefixStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700]),
            filled: true,
            fillColor: const Color(0xFFF0EDEA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600),
        ),
        if (_amountPaid > 0) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _change >= 0
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kembalian',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _change >= 0
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFD32F2F),
                  ),
                ),
                Text(
                  _change >= 0
                      ? CurrencyFormatter.idr(_change)
                      : '-${CurrencyFormatter.idr(_change.abs())}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _change >= 0
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFD32F2F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Catatan (opsional)',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Tambahkan catatan...',
            filled: true,
            fillColor: const Color(0xFFF0EDEA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final canPay = !_processing &&
        ref.read(cartProvider).items.isNotEmpty &&
        (_paymentMethod != 'Tunai' || _amountPaid >= _grandTotal);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grand Total',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                  CurrencyFormatter.idr(_grandTotal),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: canPay ? _processPayment : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _processing
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Text(
                        'Bayar Sekarang',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
