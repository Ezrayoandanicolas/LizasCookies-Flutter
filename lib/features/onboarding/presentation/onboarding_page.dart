import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/storage/secure_storage.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _currentPage = 0;
  List<_OnboardingItemData> _items = [];
  bool _loading = true;

  static const _fallbackItems = [
    _OnboardingItemData(icon: Icons.cookie, title: 'Cookies Berkualitas', desc: 'Bahan pilihan terbaik'),
    _OnboardingItemData(icon: Icons.local_shipping, title: 'Pengiriman Cepat', desc: 'Aman dan tepat waktu'),
    _OnboardingItemData(icon: Icons.payment, title: 'Pembayaran Mudah', desc: 'Aman dan praktis'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchLandingPage();
  }

  Future<void> _fetchLandingPage() async {
    try {
      final storage = SecureStorage();
      final tenantId = await storage.getSelectedTenantId();
      if (tenantId == null) {
        setState(() { _items = _fallbackItems; _loading = false; });
        return;
      }
      final dio = Dio();
      final response = await dio.get(
        '/public/landing-page',
        queryParameters: {'tenant_id': tenantId},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['sections'] is List) {
        final sections = data['sections'] as List;
        final parsed = sections.map<_OnboardingItemData>((s) {
          final title = (s['title'] ?? s['heading'] ?? '') as String;
          final desc = (s['description'] ?? s['subtitle'] ?? s['body'] ?? '') as String;
          final imageUrl = s['image_url'] ?? s['image'] ?? s['media_url'] as String?;
          return _OnboardingItemData(
            icon: Icons.cookie,
            title: title.isNotEmpty ? title : 'Selamat Datang',
            desc: desc.isNotEmpty ? desc : 'Nikmati cookies terbaik dari kami',
            imageUrl: imageUrl,
          );
        }).toList();
        if (parsed.isNotEmpty && mounted) {
          setState(() { _items = parsed; _loading = false; });
          return;
        }
      }
      setState(() { _items = _fallbackItems; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _items = _fallbackItems; _loading = false; });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    try {
      await SecureStorage().setOnboardingComplete(true);
    } catch (_) {}
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final count = items.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _complete,
                child: const Text('Lewati', style: TextStyle(color: Colors.grey)),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : PageView(
                      controller: _controller,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      children: items.map((item) => _OnboardingItemWidget(item: item)).toList(),
                    ),
            ),
            if (!_loading)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(count, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i ? const Color(0xFFE85D3A) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
            const SizedBox(height: 32),
            if (!_loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage < count - 1) {
                        _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      } else {
                        _complete();
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE85D3A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: Text(_currentPage < count - 1 ? 'Selanjutnya' : 'Mulai Belanja'),
                  ),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _OnboardingItemData {
  final IconData icon;
  final String title;
  final String desc;
  final String? imageUrl;
  const _OnboardingItemData({required this.icon, required this.title, required this.desc, this.imageUrl});
}

class _OnboardingItemWidget extends StatelessWidget {
  final _OnboardingItemData item;
  const _OnboardingItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
              ClipOval(
                child: Image.network(
                  item.imageUrl!,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(color: Color(0xFFFFE8E0), shape: BoxShape.circle),
                    child: Icon(item.icon, size: 64, color: const Color(0xFFE85D3A)),
                  ),
                ),
              )
            else
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(color: Color(0xFFFFE8E0), shape: BoxShape.circle),
                child: Icon(item.icon, size: 64, color: const Color(0xFFE85D3A)),
              ),
            const SizedBox(height: 40),
            Text(item.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(item.desc, style: const TextStyle(fontSize: 15, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
