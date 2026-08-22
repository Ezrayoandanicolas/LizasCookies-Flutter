import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/providers/tenant_provider.dart';

final expensesProvider =
    StateNotifierProvider<ExpensesNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final dio = ref.watch(dioClientProvider).dio;
  final tenantQp =
      ref.watch(tenantQueryProvider).valueOrNull ?? <String, dynamic>{};
  return ExpensesNotifier(dio, tenantQp);
});

final expenseCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final tenantQp =
      ref.watch(tenantQueryProvider).valueOrNull ?? <String, dynamic>{};
  final res =
      await dio.get('/superadmin/expense-categories', queryParameters: tenantQp);
  final data = res.data;
  if (data is List) {
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return [];
});

class ExpensesNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Dio _dio;
  final Map<String, dynamic> _tenantQp;
  int _page = 1;
  bool _hasMore = true;

  bool get hasMore => _hasMore;

  ExpensesNotifier(this._dio, this._tenantQp) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    _page = 1;
    _hasMore = true;
    state = const AsyncValue.loading();
    try {
      final params = <String, dynamic>{..._tenantQp, 'page': 1, 'per_page': 20};
      final res = await _dio.get('/superadmin/expenses', queryParameters: params);
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
        list.map((e) => Map<String, dynamic>.from(e)).toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    _page++;
    try {
      final params = <String, dynamic>{..._tenantQp, 'page': _page, 'per_page': 20};
      final res = await _dio.get('/superadmin/expenses', queryParameters: params);
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
        ...list.map((e) => Map<String, dynamic>.from(e)),
      ]);
    } catch (_) {}
  }

  Future<void> add({
    required String title,
    required String amount,
    required int expenseCategoryId,
    required String expenseDate,
    String? description,
    String? paymentMethod,
  }) async {
    await _dio.post('/superadmin/expenses', data: {
      'title': title,
      'amount': amount,
      'expense_category_id': expenseCategoryId,
      'expense_date': expenseDate,
      if (description != null && description.isNotEmpty) 'description': description,
      if (paymentMethod != null && paymentMethod.isNotEmpty) 'payment_method': paymentMethod,
    });
    await fetch();
  }

  Future<bool> update(int id, {
    required String title,
    required String amount,
    required int expenseCategoryId,
    required String expenseDate,
    String? description,
    String? paymentMethod,
  }) async {
    try {
      await _dio.put('/superadmin/expenses/$id', data: {
        'title': title,
        'amount': amount,
        'expense_category_id': expenseCategoryId,
        'expense_date': expenseDate,
        if (description != null && description.isNotEmpty) 'description': description,
        if (paymentMethod != null && paymentMethod.isNotEmpty) 'payment_method': paymentMethod,
      });
      await fetch();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> remove(int id) async {
    try {
      await _dio.delete('/superadmin/expenses/$id');
      await fetch();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class ExpensePage extends ConsumerStatefulWidget {
  const ExpensePage({super.key});

  @override
  ConsumerState<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends ConsumerState<ExpensePage> {
  final _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification &&
        notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
      ref.read(expensesProvider.notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengeluaran'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
      ),
      backgroundColor: theme.colorScheme.primaryContainer,
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        onPressed: () => _showAddExpenseSheet(context),
        child: const Icon(Icons.add),
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat data: $e',
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(expensesProvider.notifier).fetch(),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (expenses) => RefreshIndicator(
          onRefresh: () => ref.read(expensesProvider.notifier).fetch(),
          child: expenses.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Text(
                        'Belum ada pengeluaran',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ],
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: expenses.length + (ref.read(expensesProvider.notifier).hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == expenses.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _ExpenseCard(
                        expense: expenses[index],
                        currencyFormat: _currencyFormat,
                        onEdit: () => _showEditExpenseSheet(context, expenses[index]),
                        onDelete: () => _confirmDelete(context, expenses[index]),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }

  void _showAddExpenseSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _AddExpenseSheet(
          onSuccess: () {
            Navigator.of(ctx).pop();
            ref.read(expensesProvider.notifier).fetch();
          },
        ),
      ),
    );
  }

  void _showEditExpenseSheet(BuildContext context, Map<String, dynamic> expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _AddExpenseSheet(
          expense: expense,
          onSuccess: () {
            Navigator.of(ctx).pop();
            ref.read(expensesProvider.notifier).fetch();
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Map<String, dynamic> expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pengeluaran'),
        content: Text('Hapus "${expense['description']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await ref.read(expensesProvider.notifier).remove(expense['id']);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Berhasil dihapus' : 'Gagal menghapus'),
          backgroundColor: success ? Colors.green : Colors.red,
        ));
      }
    }
  }
}

class _ExpenseCard extends StatelessWidget {
  final Map<String, dynamic> expense;
  final NumberFormat currencyFormat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseCard({
    required this.expense,
    required this.currencyFormat,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final description = expense['title']?.toString() ?? expense['description'] ?? '-';
    final amount = expense['amount'] ?? '0';
    final expenseDate = expense['expense_date'] ?? '';
    final category = expense['expense_category'];
    final categoryName = category != null ? category['name'] ?? '-' : '-';
    final notes = expense['notes'];

    String formattedDate = '';
    if (expenseDate.isNotEmpty) {
      try {
        final parsed = DateTime.parse(expenseDate);
        formattedDate = DateFormat('dd MMM yyyy', 'id_ID').format(parsed);
      } catch (_) {
        formattedDate = expenseDate;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Row(
          children: [
            Expanded(
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              currencyFormat.format(double.tryParse(amount.toString()) ?? 0),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                _Tag(label: categoryName),
                const SizedBox(width: 8),
                if (formattedDate.isNotEmpty)
                  Text(
                    formattedDate,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
              ],
            ),
            if (notes != null && notes.toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                notes,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(
                value: 'delete',
                child: Text('Hapus', style: TextStyle(color: Colors.red))),
          ],
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;

  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _AddExpenseSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  final Map<String, dynamic>? expense;

  const _AddExpenseSheet({required this.onSuccess, this.expense});

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  int? _selectedCategoryId;
  String? _selectedPaymentMethod = 'cash';
  bool _saving = false;

  bool get _isEdit => widget.expense != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final e = widget.expense!;
      _descCtrl.text = e['title']?.toString() ?? e['description'] ?? '';
      _amountCtrl.text = e['amount']?.toString() ?? '';
      _notesCtrl.text = e['notes'] ?? '';
      _selectedCategoryId = e['expense_category_id'] as int?;
      _selectedPaymentMethod = e['payment_method']?.toString() ?? 'cash';
      final dateStr = e['expense_date'] as String?;
      if (dateStr != null && dateStr.isNotEmpty) {
        try {
          _selectedDate = DateTime.parse(dateStr);
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori pengeluaran')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final amount = _amountCtrl.text.trim().replaceAll('.', '').replaceAll(',', '');
      if (_isEdit) {
        final success = await ref.read(expensesProvider.notifier).update(
              widget.expense!['id'],
              title: _descCtrl.text.trim(),
              amount: amount,
              expenseCategoryId: _selectedCategoryId!,
              expenseDate: dateStr,
              description: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
              paymentMethod: _selectedPaymentMethod,
            );
        if (success) {
          widget.onSuccess();
        }
      } else {
        await ref.read(expensesProvider.notifier).add(
              title: _descCtrl.text.trim(),
              amount: amount,
              expenseCategoryId: _selectedCategoryId!,
              expenseDate: dateStr,
              description: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
              paymentMethod: _selectedPaymentMethod,
            );
        widget.onSuccess();
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data is Map
            ? (e.response?.data['message'] ?? 'Gagal menyimpan')
            : 'Gagal menyimpan';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.toString())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              _isEdit ? 'Edit Pengeluaran' : 'Tambah Pengeluaran',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Judul',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah (Rp)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                      final n = int.tryParse(v.replaceAll('.', '').replaceAll(',', ''));
                      if (n == null || n <= 0) return 'Masukkan angka valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _selectedPaymentMethod,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Metode Bayar',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payment),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Tunai')),
                      DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                      DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                      DropdownMenuItem(value: 'card', child: Text('Kartu')),
                      DropdownMenuItem(value: 'other', child: Text('Lainnya')),
                    ],
                    onChanged: (v) => setState(() => _selectedPaymentMethod = v),
                  ),
                  const SizedBox(height: 14),
                  categoriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Gagal load kategori: $e',
                        style: const TextStyle(color: Colors.red)),
                    data: (categories) => DropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: categories
                          .map((c) => DropdownMenuItem<int>(
                                value: c['id'] as int,
                                child: Text(c['name'] ?? '-'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                      validator: (v) => v == null ? 'Pilih kategori' : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tanggal',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        DateFormat('dd MMM yyyy', 'id_ID').format(_selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _saving
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Simpan',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
