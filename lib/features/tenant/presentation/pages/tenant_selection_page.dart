import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/storage/secure_storage.dart';

class TenantSelectionPage extends ConsumerStatefulWidget {
  const TenantSelectionPage({super.key});

  @override
  ConsumerState<TenantSelectionPage> createState() => _TenantSelectionPageState();
}

class _TenantSelectionPageState extends ConsumerState<TenantSelectionPage> {
  List<Map<String, dynamic>> _tenants = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final secureStorage = ref.read(secureStorageProvider);
      final deviceId = await secureStorage.getOrCreateDeviceId();

      final dio = Dio(BaseOptions(baseUrl: AppConfig.instance.apiBaseUrl));
      final res = await dio.post('/public/tenant-access', data: {
        'device_id': deviceId,
        'device_name': await _getDeviceName(),
      });

      final data = res.data;
      List list;
      if (data is List) {
        list = data;
      } else if (data is Map && data.containsKey('data')) {
        list = data['data'];
      } else {
        list = [];
      }
      setState(() {
        _tenants = list.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat data tenant: $e';
        _isLoading = false;
      });
    }
  }

  Future<String> _getDeviceName() async {
    return Platform.operatingSystem.toUpperCase();
  }

  Future<void> _selectTenant(Map<String, dynamic> tenant) async {
    final tenantId = tenant['id'];
    if (tenantId == null) return;

    final secureStorage = ref.read(secureStorageProvider);
    await secureStorage.saveSelectedTenantId(tenantId);

    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFE85D3A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.store, size: 44, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Lizas Cookies',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pilih toko Anda untuk melanjutkan',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Pilih Tenant', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                const SizedBox(height: 12),
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _loadTenants,
                                  child: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _tenants.isEmpty
                          ? const Center(child: Text('Tidak ada tenant tersedia'))
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: _tenants.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final tenant = _tenants[index];
                                return _TenantCard(
                                  tenant: tenant,
                                  onTap: () => _selectTenant(tenant),
                                );
                              },
                            ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TenantCard extends StatelessWidget {
  final Map<String, dynamic> tenant;
  final VoidCallback onTap;

  const _TenantCard({required this.tenant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = tenant['name'] ?? '-';
    final slug = tenant['slug'] ?? '-';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.business, color: Color(0xFFE85D3A), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Slug: $slug', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
