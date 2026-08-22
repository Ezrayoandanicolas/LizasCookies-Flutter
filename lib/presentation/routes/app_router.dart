import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/secure_storage.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/domain/entities/auth_entity.dart';
import '../../features/catalog/presentation/pages/home_page.dart';
import '../../features/catalog/presentation/pages/product_detail_page.dart';
import '../../features/catalog/presentation/pages/category_page.dart';
import '../../features/catalog/presentation/pages/search_page.dart';
import '../../features/store/presentation/pages/store_selection_page.dart';
import '../../features/tenant/presentation/pages/tenant_selection_page.dart';
import '../../features/pos/presentation/pages/pos_page.dart';
import '../../features/orders/presentation/pages/orders_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/admin_category_page.dart';
import '../../features/admin/presentation/pages/admin_product_page.dart';
import '../../features/admin/presentation/pages/admin_stock_page.dart';
import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/expenses/presentation/pages/expense_page.dart';
import '../../features/admin/presentation/pages/admin_user_page.dart';
import '../../features/admin/presentation/pages/admin_store_page.dart';
import '../../features/admin/presentation/pages/admin_expense_category_page.dart';
import '../../features/member/presentation/pages/member_orders_page.dart';
import '../../features/member/presentation/pages/member_address_page.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_theme.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: AppConfig.instance.enableLogging,
    routes: [
      GoRoute(path: '/splash', name: 'splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/onboarding', name: 'onboarding', builder: (_, __) => const OnboardingPage()),
      GoRoute(path: '/login', name: 'login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', name: 'register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/forgot-password', name: 'forgotPassword', builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(path: '/store-select', name: 'storeSelect', builder: (_, __) => const StoreSelectionPage()),
      GoRoute(path: '/tenant-select', name: 'tenantSelect', builder: (_, __) => const TenantSelectionPage()),

      // Pushed pages with smooth transitions
      GoRoute(
        path: '/pos', name: 'pos',
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: POSPage(),
          transitionsBuilder: _slideLeftTransition,
        ),
      ),
      GoRoute(
        path: '/orders', name: 'orders',
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: OrdersPage(),
          transitionsBuilder: _slideLeftTransition,
        ),
      ),
      GoRoute(
        path: '/member/orders', name: 'memberOrders',
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: MemberOrdersPage(),
          transitionsBuilder: _slideLeftTransition,
        ),
      ),
      GoRoute(
        path: '/member/addresses', name: 'memberAddresses',
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: MemberAddressPage(),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      GoRoute(
        path: '/admin', name: 'admin',
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: AdminDashboardPage(),
          transitionsBuilder: _slideLeftTransition,
        ),
      ),
      GoRoute(
        path: '/admin/categories', name: 'adminCategories',
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: AdminCategoryListPage(),
          transitionsBuilder: _slideLeftTransition,
        ),
      ),
      GoRoute(
        path: '/admin/products', name: 'adminProducts',
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: AdminProductListPage(),
          transitionsBuilder: _slideLeftTransition,
        ),
      ),
      GoRoute(
        path: '/admin/stock', name: 'adminStock',
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: StockPage(),
          transitionsBuilder: _slideLeftTransition,
        ),
      ),
      GoRoute(
        path: '/admin/analytics', name: 'adminAnalytics',
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: AnalyticsPage(),
          transitionsBuilder: _slideLeftTransition,
        ),
      ),
      GoRoute(
        path: '/admin/expenses', name: 'adminExpenses',
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: ExpensePage(),
          transitionsBuilder: _slideLeftTransition,
        ),
      ),
      GoRoute(
        path: '/admin/users', name: 'adminUsers',
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: AdminUserPage(),
          transitionsBuilder: _slideLeftTransition,
        ),
      ),
      GoRoute(
        path: '/admin/stores', name: 'adminStores',
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: AdminStorePage(),
          transitionsBuilder: _slideLeftTransition,
        ),
      ),
      GoRoute(
        path: '/admin/expense-categories', name: 'adminExpenseCategories',
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: AdminExpenseCategoryPage(),
          transitionsBuilder: _slideLeftTransition,
        ),
      ),
      GoRoute(
        path: '/admin/product/add', name: 'adminProductAdd',
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: AdminProductFormPage(),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      GoRoute(
        path: '/admin/product/edit/:id', name: 'adminProductEdit',
        pageBuilder: (_, state) => CustomTransitionPage(
          child: AdminProductFormPage(productId: state.pathParameters['id']),
          transitionsBuilder: _slideUpTransition,
        ),
      ),

      // Main shell with bottom nav
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) => MainScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              name: 'home',
              builder: (_, __) => const HomePage(),
              routes: [
                GoRoute(
                  path: 'product/:id', name: 'productDetail',
                  pageBuilder: (_, state) => CustomTransitionPage(
                    child: ProductDetailPage(productId: state.pathParameters['id']!),
                    transitionsBuilder: _slideUpTransition,
                  ),
                ),
                GoRoute(path: 'category/:id', name: 'category', builder: (_, state) => CategoryPage(categoryId: state.pathParameters['id']!)),
                GoRoute(path: 'search', name: 'search', builder: (_, __) => const SearchPage()),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/orders-tab',
              name: 'ordersTab',
              builder: (_, __) => Consumer(
                builder: (context, ref, _) {
                  final auth = ref.watch(authNotifierProvider);
                  if (auth is Authenticated && (auth.user.isStaff || auth.user.isAdmin)) {
                    return const OrdersPage();
                  }
                  return const MemberOrdersPage();
                },
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/pos-tab',
              name: 'posTab',
              builder: (_, __) => const POSPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', name: 'profile', builder: (_, __) => const ProfilePage()),
          ]),
        ],
      ),
    ],
    errorBuilder: (_, __) => const NotFoundPage(),
  );
});

// MD3-style page transitions with spring/bounce
Widget _slideLeftTransition(
  BuildContext context, Animation<double> animation,
  Animation<double> secondaryAnimation, Widget child,
) {
  final tween = Tween(begin: const Offset(0.4, 0.0), end: Offset.zero)
      .chain(CurveTween(curve: Curves.easeOutCubic));
  final fadeTween = Tween(begin: 0.0, end: 1.0)
      .chain(CurveTween(curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));
  return SlideTransition(
    position: animation.drive(tween),
    child: FadeTransition(
      opacity: animation.drive(fadeTween),
      child: child,
    ),
  );
}

Widget _slideUpTransition(
  BuildContext context, Animation<double> animation,
  Animation<double> secondaryAnimation, Widget child,
) {
  final tween = Tween(begin: const Offset(0.0, 0.2), end: Offset.zero)
      .chain(CurveTween(curve: Curves.easeOutBack));
  final fadeTween = Tween(begin: 0.0, end: 1.0)
      .chain(CurveTween(curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
  return SlideTransition(
    position: animation.drive(tween),
    child: FadeTransition(
      opacity: animation.drive(fadeTween),
      child: child,
    ),
  );
}

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioClientProvider).dio;
      await dio.post('/v1/forgot-password', data: {'email': _emailCtrl.text.trim()});
      setState(() => _submitted = true);
    } catch (_) {
      setState(() => _submitted = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Lupa Kata Sandi')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: _submitted
                ? Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Column(
                      children: [
                        Icon(Icons.support_agent_rounded, size: 72, color: theme.colorScheme.primary),
                        const SizedBox(height: 24),
                        Text('Hubungi Admin', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Text(
                          'Untuk mereset kata sandi, silakan hubungi admin melalui WhatsApp atau email support kami.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Kembali ke Login')),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 60),
                      Icon(Icons.lock_reset_rounded, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 20),
                      Text('Reset Kata Sandi', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                        'Masukkan email akun Anda. Kami akan mengarahkan Anda ke admin untuk mereset kata sandi.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Email wajib diisi';
                          if (!v.contains('@')) return 'Format email tidak valid';
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'Masukkan email Anda',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Kirim', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    String name = 'Guest';
    String subtitle = 'Belum masuk';
    String role = '';
    if (authState is Authenticated) {
      name = authState.user.name;
      subtitle = authState.user.email;
      role = authState.user.role ?? '';
    }

    String themeLabel = 'Sistem';
    IconData themeIcon = Icons.brightness_auto;
    if (themeMode == ThemeMode.light) {
      themeLabel = 'Terang';
      themeIcon = Icons.light_mode;
    } else if (themeMode == ThemeMode.dark) {
      themeLabel = 'Gelap';
      themeIcon = Icons.dark_mode;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 40,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(Icons.person, size: 40, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 12),
          Center(child: Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
          Center(child: Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          if (role.isNotEmpty) ...[
            const SizedBox(height: 4),
            Center(child: Text(role.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, letterSpacing: 1, fontWeight: FontWeight.w600))),
          ],
          const SizedBox(height: 24),
          const Divider(),
          _menuItem(Icons.shopping_bag, 'Pesanan Saya', () => context.push('/orders')),
          _menuItem(Icons.receipt_long, 'Riwayat Pesanan', () => context.push('/member/orders')),
          _menuItem(Icons.location_on, 'Alamat Saya', () => context.push('/member/addresses')),
          _menuItem(themeIcon, 'Mode Tampilan: $themeLabel', () {
            showDialog(
              context: context,
              builder: (ctx) => SimpleDialog(
                title: const Text('Mode Tampilan'),
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('Sistem'),
                    subtitle: const Text('Ikuti pengaturan perangkat'),
                    value: ThemeMode.system,
                    groupValue: themeMode,
                    onChanged: (v) { ref.read(themeModeProvider.notifier).setMode(v!); Navigator.pop(ctx); },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Terang'),
                    subtitle: const Text('Mode light'),
                    value: ThemeMode.light,
                    groupValue: themeMode,
                    onChanged: (v) { ref.read(themeModeProvider.notifier).setMode(v!); Navigator.pop(ctx); },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Gelap'),
                    subtitle: const Text('Mode dark'),
                    value: ThemeMode.dark,
                    groupValue: themeMode,
                    onChanged: (v) { ref.read(themeModeProvider.notifier).setMode(v!); Navigator.pop(ctx); },
                  ),
                ],
              ),
            );
          }),
          _menuItem(Icons.help_outline, 'Bantuan', () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Bantuan'),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Butuh bantuan? Hubungi kami:'),
                    SizedBox(height: 12),
                    Row(children: [Icon(Icons.email, size: 18), SizedBox(width: 8), Text('support@lizascookies.id')]),
                    SizedBox(height: 8),
                    Row(children: [Icon(Icons.phone, size: 18), SizedBox(width: 8), Text('0812-3456-7890')]),
                    SizedBox(height: 8),
                    Row(children: [Icon(Icons.language, size: 18), SizedBox(width: 8), Text('lizascookies.id')]),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
                ],
              ),
            );
          }),
          const Divider(),
          _menuItem(Icons.logout, 'Keluar', () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Keluar'),
                content: const Text('Yakin ingin keluar?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar', style: TextStyle(color: Colors.red))),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              final secureStorage = ref.read(secureStorageProvider);
              await secureStorage.clearSelectedTenant();
              await secureStorage.clearSelectedStore();
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            }
          }, color: Colors.red),
        ],
      ),
    );
  }

  static Widget _menuItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const MainScaffold({required this.navigationShell, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState is Authenticated ? authState.user : null;
    final isStaff = user?.isStaff ?? false;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(index),
        destinations: isStaff
            ? const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Pesanan'),
                NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'POS'),
                NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
              ]
            : const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Pesanan'),
                NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'POS'),
                NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
              ],
      ),
    );
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('404')));
}
