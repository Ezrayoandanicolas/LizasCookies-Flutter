// Main entry point for LizasCookies Flutter App

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/config/app_config.dart';
import 'core/storage/secure_storage.dart';
import 'core/storage/local_storage.dart';
import 'core/sync/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', null);

  const flavorString = String.fromEnvironment('FLAVOR', defaultValue: 'prod');
  final flavor = AppFlavor.values.firstWhere(
    (f) => f.name == flavorString,
    orElse: () => AppFlavor.dev,
  );
  AppConfig.initialize(flavor);

  // Initialize secure storage
  await SecureStorage().getAccessToken(); // Warm up

  // Initialize Hive local storage
  await LocalStorage.init();

  runApp(const ProviderScope(child: LizasCookiesApp()));
}

class LizasCookiesApp extends ConsumerWidget {
  const LizasCookiesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncServiceProvider);
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConfig.instance.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.3),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}