import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/connectivity_provider.dart' show connectivityProvider, ConnectivityStatus;
import '../../core/network/dio_client.dart';
import '../../core/storage/local_storage.dart';
import '../../features/catalog/data/products_provider.dart';

class SyncService {
  final Ref _ref;
  ProviderSubscription<ConnectivityStatus>? _connectivitySubscription;
  Timer? _periodicTimer;

  SyncService(this._ref);

  void start() {
    _connectivitySubscription = _ref.listen<ConnectivityStatus>(
      connectivityProvider,
      (previous, current) {
        if (current == ConnectivityStatus.online) {
          processPendingOrders();
        }
      },
    );

    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final current = _ref.read(connectivityProvider);
      if (current == ConnectivityStatus.online) {
        processPendingOrders();
      }
    });

    final current = _ref.read(connectivityProvider);
    if (current == ConnectivityStatus.online) {
      processPendingOrders();
    }
  }

  Future<void> processPendingOrders() async {
    final orders = LocalStorage.getAllPendingOrders();
    if (orders.isEmpty) return;

    bool anySynced = false;

    for (final order in orders) {
      final id = order['id'] as String;
      final endpoint = order['endpoint'] as String;
      final body = order['body'] as Map<String, dynamic>;
      final retryCount = (order['retry_count'] as num?)?.toInt() ?? 0;

      if (retryCount >= AppConstants.maxRetries) {
        await LocalStorage.removeOfflineOrder(id);
        continue;
      }

      try {
        final dio = _ref.read(dioClientProvider).dio;
        await dio.post(endpoint, data: body);
        await LocalStorage.removeOfflineOrder(id);
        anySynced = true;
      } catch (_) {
        final updated = Map<String, dynamic>.from(order);
        updated['retry_count'] = retryCount + 1;
        await LocalStorage.saveOfflineOrder(id, updated);
      }
    }

    if (anySynced) {
      try {
        _ref.read(productsProvider.notifier).load();
      } catch (_) {}
    }
  }

  void dispose() {
    _connectivitySubscription?.close();
    _periodicTimer?.cancel();
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref);
  service.start();
  ref.onDispose(service.dispose);
  return service;
});
