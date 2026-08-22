import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';

class MemberAddressPage extends ConsumerStatefulWidget {
  const MemberAddressPage({super.key});

  @override
  ConsumerState<MemberAddressPage> createState() => _MemberAddressPageState();
}

class _MemberAddressPageState extends ConsumerState<MemberAddressPage> {
  List<Map> _addresses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioClientProvider).dio;
      final res = await dio.get('/member/addresses');
      final data = res.data;
      List list;
      if (data is Map && data.containsKey('data')) {
        list = data['data'];
      } else if (data is List) {
        list = data;
      } else {
        list = [];
      }
      setState(() {
        _addresses = list.map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addOrEdit({Map? address}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AddressFormSheet(address: address),
    );
    if (result == true) _load();
  }

  Future<void> _delete(Map address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Alamat'),
        content: Text('Hapus alamat "${address['label'] ?? ''}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final dio = ref.read(dioClientProvider).dio;
      await dio.delete('/member/addresses/${address['id']}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alamat dihapus'), backgroundColor: Colors.green),
        );
      }
      _load();
    } catch (e) {
      String msg = 'Gagal menghapus';
      if (e is DioException && e.response?.data != null) {
        msg = e.response!.data['message'] ?? msg;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alamat Saya'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_off_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text('Belum ada alamat', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Text('Tambahkan alamat pengiriman Anda', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _addresses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final a = _addresses[index];
                      final isDefault = a['is_default'] == true || a['is_default'] == 1;
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isDefault
                              ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
                              : BorderSide.none,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      a['label'] ?? '-',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (isDefault)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Utama',
                                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(a['recipient_name'] ?? '-', style: theme.textTheme.bodyMedium),
                              if (a['phone'] != null && a['phone'].toString().isNotEmpty)
                                Text(a['phone'], style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              const SizedBox(height: 4),
                              Text(
                                '${a['address'] ?? ''}, ${a['city'] ?? ''}, ${a['province'] ?? ''} ${a['postal_code'] ?? ''}',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    onPressed: () => _addOrEdit(address: a),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                                    onPressed: () => _delete(a),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddressFormSheet extends ConsumerStatefulWidget {
  final Map? address;
  const _AddressFormSheet({this.address});

  @override
  ConsumerState<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  bool _isDefault = false;
  bool _saving = false;

  bool get isEdit => widget.address != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final a = widget.address!;
      _labelCtrl.text = a['label']?.toString() ?? '';
      _nameCtrl.text = a['recipient_name']?.toString() ?? '';
      _phoneCtrl.text = a['phone']?.toString() ?? '';
      _addressCtrl.text = a['address']?.toString() ?? '';
      _cityCtrl.text = a['city']?.toString() ?? '';
      _provinceCtrl.text = a['province']?.toString() ?? '';
      _postalCtrl.text = a['postal_code']?.toString() ?? '';
      _isDefault = a['is_default'] == true || a['is_default'] == 1;
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _postalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      final dio = ref.read(dioClientProvider).dio;
      final data = {
        'label': _labelCtrl.text.trim(),
        'recipient_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'province': _provinceCtrl.text.trim(),
        'postal_code': _postalCtrl.text.trim(),
        'is_default': _isDefault,
      };

      if (isEdit) {
        await dio.put('/member/addresses/${widget.address!['id']}', data: data);
      } else {
        await dio.post('/member/addresses', data: data);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Alamat diperbarui' : 'Alamat ditambahkan'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      String msg = 'Gagal menyimpan';
      if (e is DioException && e.response?.data != null) {
        msg = e.response!.data['message'] ?? msg;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEdit ? 'Edit Alamat' : 'Tambah Alamat',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              _field(_labelCtrl, 'Label (Rumah, Kantor, dll.)', required: true),
              const SizedBox(height: 12),
              _field(_nameCtrl, 'Nama Penerima', required: true),
              const SizedBox(height: 12),
              _field(_phoneCtrl, 'Telepon', keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _field(_addressCtrl, 'Alamat Lengkap', required: true, maxLines: 2),
              const SizedBox(height: 12),
              _field(_cityCtrl, 'Kota/Kabupaten', required: true),
              const SizedBox(height: 12),
              _field(_provinceCtrl, 'Provinsi', required: true),
              const SizedBox(height: 12),
              _field(_postalCtrl, 'Kode Pos', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Jadikan alamat utama'),
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Simpan Perubahan' : 'Tambah Alamat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool required = false, int maxLines = 1, TextInputType? keyboardType}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
