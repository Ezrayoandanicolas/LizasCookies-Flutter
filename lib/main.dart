// Main entry point for LizasCookies Flutter App

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/config/app_config.dart';
import 'core/ota/ota_service.dart';
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

  // Initialize package info for OTA updates
  await AppUpdateInfo.init();

  runApp(const ProviderScope(child: LizasCookiesApp()));
}

class LizasCookiesApp extends ConsumerStatefulWidget {
  const LizasCookiesApp({super.key});

  @override
  ConsumerState<LizasCookiesApp> createState() => _LizasCookiesAppState();
}

class _LizasCookiesAppState extends ConsumerState<LizasCookiesApp> {
  bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_updateChecked) {
        _updateChecked = true;
        _checkForUpdate();
      }
    });
  }

  void _checkForUpdate() async {
    try {
      final ota = OtaService();
      final updateInfo = await ota.checkForUpdate();
      if (updateInfo != null && mounted) {
        _showUpdateDialog(updateInfo, ota);
      }
    } catch (_) {}
  }

  void _showUpdateDialog(dynamic updateInfo, OtaService ota) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo.forceUpdate,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Update Tersedia'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versi ${updateInfo.version} (${updateInfo.build})'),
            if (updateInfo.changelog.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(updateInfo.changelog, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ],
        ),
        actions: [
          if (!updateInfo.forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Nanti Saja'),
            ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _downloadUpdate(updateInfo, ota);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadUpdate(dynamic updateInfo, OtaService ota) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DownloadProgressDialog(ota: ota, downloadUrl: updateInfo.downloadUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
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

class _DownloadProgressDialog extends StatefulWidget {
  final OtaService ota;
  final String downloadUrl;

  const _DownloadProgressDialog({required this.ota, required this.downloadUrl});

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      await widget.ota.downloadAndInstall(widget.downloadUrl, (progress) {
        if (mounted) setState(() => _progress = progress);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mengunduh Update'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Text('Gagal: $_error', style: const TextStyle(color: Colors.red))
          else ...[
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            const SizedBox(height: 12),
            Text(_progress > 0 ? '${(_progress * 100).toInt()}%' : 'Mengunduh...'),
          ],
        ],
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
      ],
    );
  }
}