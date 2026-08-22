import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/providers/tenant_provider.dart';

final adminUsersProvider = StateNotifierProvider<AdminUsersNotifier, AsyncValue<List<Map>>>((ref) {
  final dio = ref.watch(dioClientProvider).dio;
  final tenantQp = ref.watch(tenantQueryProvider).valueOrNull ?? <String, dynamic>{};
  return AdminUsersNotifier(dio, tenantQp);
});

class AdminUsersNotifier extends StateNotifier<AsyncValue<List<Map>>> {
  final Dio _dio;
  final Map<String, dynamic> _tenantQp;

  AdminUsersNotifier(this._dio, this._tenantQp) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({String? search}) async {
    state = const AsyncValue.loading();
    try {
      final params = <String, dynamic>{..._tenantQp};
      if (search != null && search.isNotEmpty) params['search'] = search;
      final res = await _dio.get('/superadmin/users', queryParameters: params);
      final data = res.data;
      List list;
      if (data is Map && data.containsKey('data')) {
        list = data['data'];
      } else if (data is List) {
        list = data;
      } else {
        list = [];
      }
      state = AsyncValue.data(list.map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> create(Map<String, dynamic> payload) async {
    try {
      await _dio.post('/superadmin/users', data: payload, queryParameters: _tenantQp);
      await load();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> update(int id, Map<String, dynamic> payload) async {
    try {
      await _dio.put('/superadmin/users/$id', data: payload, queryParameters: _tenantQp);
      await load();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _dio.delete('/superadmin/users/$id', queryParameters: _tenantQp);
      await load();
      return true;
    } catch (e) {
      return false;
    }
  }
}

const _roles = ['member', 'staff', 'cashier', 'store_manager', 'admin'];

class AdminUserPage extends ConsumerStatefulWidget {
  const AdminUserPage({super.key});

  @override
  ConsumerState<AdminUserPage> createState() => _AdminUserPageState();
}

class _AdminUserPageState extends ConsumerState<AdminUserPage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen User'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari user...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(adminUsersProvider.notifier).load();
                        },
                      )
                    : null,
              ),
              onSubmitted: (v) => ref.read(adminUsersProvider.notifier).load(search: v.trim()),
            ),
          ),
          Expanded(
            child: users.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Gagal memuat', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.read(adminUsersProvider.notifier).load(),
                    child: const Text('Coba Lagi'),
                  ),
                ]),
              ),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('Belum ada user'))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final u = items[index];
                        return _UserCard(user: u);
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, {Map? user}) {
    final nameCtrl = TextEditingController(text: user?['name'] ?? '');
    final emailCtrl = TextEditingController(text: user?['email'] ?? '');
    final passwordCtrl = TextEditingController();
    String role = user?['role']?.toString() ?? 'member';
    final isEdit = user != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _UserFormSheet(
        nameCtrl: nameCtrl,
        emailCtrl: emailCtrl,
        passwordCtrl: passwordCtrl,
        role: role,
        isEdit: isEdit,
        onRoleChanged: (v) => role = v ?? 'member',
        onSave: () async {
          final payload = <String, dynamic>{
            'name': nameCtrl.text.trim(),
            'email': emailCtrl.text.trim(),
            'role': role,
          };
          if (passwordCtrl.text.isNotEmpty) {
            payload['password'] = passwordCtrl.text;
          }
          Navigator.pop(ctx);
          bool success;
          if (isEdit) {
            success = await ref.read(adminUsersProvider.notifier).update(user!['id'], payload);
          } else {
            if (passwordCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password wajib diisi'), backgroundColor: Colors.red),
              );
              return;
            }
            success = await ref.read(adminUsersProvider.notifier).create(payload);
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success ? (isEdit ? 'User diperbarui' : 'User ditambahkan') : 'Gagal menyimpan'),
                backgroundColor: success ? Colors.green : Colors.red,
              ),
            );
          }
        },
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  final Map user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = user['name']?.toString() ?? '-';
    final email = user['email']?.toString() ?? '-';
    final role = user['role']?.toString() ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('$email \u2022 $role', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: PopupMenuButton(
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: Colors.red))),
          ],
          onSelected: (v) async {
            if (v == 'edit') {
              _showEditForm(context, ref, user);
            } else if (v == 'delete') {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Hapus User'),
                  content: Text('Hapus "$name"?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirmed == true) {
                final success = await ref.read(adminUsersProvider.notifier).delete(user['id']);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Berhasil dihapus' : 'Gagal menghapus'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              }
            }
          },
        ),
      ),
    );
  }

  void _showEditForm(BuildContext context, WidgetRef ref, Map user) {
    final nameCtrl = TextEditingController(text: user['name'] ?? '');
    final emailCtrl = TextEditingController(text: user['email'] ?? '');
    final passwordCtrl = TextEditingController();
    String role = user['role']?.toString() ?? 'member';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _UserFormSheet(
        nameCtrl: nameCtrl,
        emailCtrl: emailCtrl,
        passwordCtrl: passwordCtrl,
        role: role,
        isEdit: true,
        onRoleChanged: (v) => role = v ?? 'member',
        onSave: () async {
          final payload = <String, dynamic>{
            'name': nameCtrl.text.trim(),
            'email': emailCtrl.text.trim(),
            'role': role,
          };
          if (passwordCtrl.text.isNotEmpty) {
            payload['password'] = passwordCtrl.text;
          }
          Navigator.pop(ctx);
          final success = await ref.read(adminUsersProvider.notifier).update(user['id'], payload);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success ? 'User diperbarui' : 'Gagal menyimpan'),
                backgroundColor: success ? Colors.green : Colors.red,
              ),
            );
          }
        },
      ),
    );
  }
}

class _UserFormSheet extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final String role;
  final bool isEdit;
  final ValueChanged<String?> onRoleChanged;
  final VoidCallback onSave;

  const _UserFormSheet({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.role,
    required this.isEdit,
    required this.onRoleChanged,
    required this.onSave,
  });

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  late String _selectedRole;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.role;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isEdit ? 'Edit User' : 'Tambah User',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: widget.nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.passwordCtrl,
              decoration: InputDecoration(
                labelText: widget.isEdit ? 'Password (opsional)' : 'Password',
              ),
              obscureText: true,
              validator: (v) {
                if (!widget.isEdit && (v == null || v.trim().isEmpty)) return 'Wajib diisi';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(labelText: 'Role'),
              items: _roles
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.replaceAll('_', ' ').toUpperCase())))
                  .toList(),
              onChanged: (v) {
                setState(() => _selectedRole = v ?? 'member');
                widget.onRoleChanged(v);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    widget.onSave();
                  }
                },
                child: Text(widget.isEdit ? 'Simpan' : 'Tambah'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
