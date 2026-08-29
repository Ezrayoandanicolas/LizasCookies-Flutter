import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/connectivity_provider.dart' show connectivityProvider, ConnectivityStatus;
import '../../core/network/dio_client.dart';
import '../../core/storage/local_storage.dart';
import '../../core/sync/sync_history_item.dart';
import '../../features/catalog/data/products_provider.dart';

class SyncService {
  final Ref _ref;
  ProviderSubscription<ConnectivityStatus>? _connectivitySubscription;
  Timer? _periodicTimer;
  bool _isSyncing = false;
  final _syncStateController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get syncStateStream => _syncStateController.stream;

  SyncService(this._ref);

  bool get isSyncing => _isSyncing;

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
      if (current == ConnectivityStatus.online && !_isSyncing) {
        processPendingOrders();
      }
    });

    final current = _ref.read(connectivityProvider);
    if (current == ConnectivityStatus.online) {
      processPendingOrders();
    }
  }

  Future<void> manualSync() async {
    if (_isSyncing) return;
    await processPendingOrders();
  }

  Future<void> processPendingOrders() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _syncStateController.add(const SyncState.syncing());

    final orders = LocalStorage.getAllPendingOrders();
    if (orders.isEmpty) {
      _isSyncing = false;
      _syncStateController.add(const SyncState.idle());
      return;
    }

    bool anySynced = false;
    int syncedCount = 0;
    int failedCount = 0;

    for (int i = 0; i < orders.length; i++) {
      final order = orders[i];
      final id = order['id'] as String;
      final endpoint = order['endpoint'] as String;
      final body = Map<String, dynamic>.from(order['body'] as Map);
      final retryCount = (order['retry_count'] as num?)?.toInt() ?? 0;
      final method = (order['method'] as String?) ?? 'POST';

      final desc = _describeEndpoint(endpoint, body);

      _syncStateController.add(SyncState.syncingItem(
        current: i + 1,
        total: orders.length,
        description: desc,
      ));

      if (retryCount >= AppConstants.maxRetries) {
        await _logHistory(SyncHistoryItem(
          id: '$id-$retryCount',
          type: _typeFromEndpoint(endpoint),
          status: SyncStatus.skipped,
          endpoint: endpoint,
          method: method,
          description: '$desc (max retry tercapai)',
          timestamp: DateTime.now(),
          retryCount: retryCount,
          requestBody: body,
        ));
        await LocalStorage.removeOfflineOrder(id);
        failedCount++;
        continue;
      }

      try {
        final dio = _ref.read(dioClientProvider).dio;
        final response = await dio.post(endpoint, data: body);
        await LocalStorage.removeOfflineOrder(id);
        anySynced = true;
        syncedCount++;

        await _logHistory(SyncHistoryItem(
          id: '$id-${DateTime.now().millisecondsSinceEpoch}',
          type: _typeFromEndpoint(endpoint),
          status: SyncStatus.success,
          endpoint: endpoint,
          method: method,
          description: desc,
          httpStatusCode: response.statusCode,
          timestamp: DateTime.now(),
          retryCount: retryCount,
          requestBody: body,
        ));
      } on DioException catch (e) {
        final updated = Map<String, dynamic>.from(order);
        updated['retry_count'] = retryCount + 1;
        await LocalStorage.saveOfflineOrder(id, updated);
        failedCount++;

        String errorMsg = e.message ?? e.toString();
        int? statusCode = e.response?.statusCode;
        final data = e.response?.data;
        if (data is Map && data.containsKey('message')) {
          errorMsg = data['message'].toString();
        }

        await _logHistory(SyncHistoryItem(
          id: '$id-${DateTime.now().millisecondsSinceEpoch}',
          type: _typeFromEndpoint(endpoint),
          status: SyncStatus.failed,
          endpoint: endpoint,
          method: method,
          description: desc,
          error: errorMsg,
          httpStatusCode: statusCode,
          timestamp: DateTime.now(),
          retryCount: retryCount + 1,
          requestBody: body,
        ));
      } catch (e) {
        final updated = Map<String, dynamic>.from(order);
        updated['retry_count'] = retryCount + 1;
        await LocalStorage.saveOfflineOrder(id, updated);
        failedCount++;

        await _logHistory(SyncHistoryItem(
          id: '$id-${DateTime.now().millisecondsSinceEpoch}',
          type: _typeFromEndpoint(endpoint),
          status: SyncStatus.failed,
          endpoint: endpoint,
          method: method,
          description: desc,
          error: e.toString(),
          timestamp: DateTime.now(),
          retryCount: retryCount + 1,
          requestBody: body,
        ));
      }
    }

    if (anySynced) {
      try {
        _ref.read(productsProvider.notifier).load();
      } catch (_) {}
    }

    _isSyncing = false;
    _syncStateController.add(SyncState.completed(
      synced: syncedCount,
      failed: failedCount,
    ));

    try {
      _ref.read(syncHistoryProvider.notifier).refresh();
    } catch (_) {}
  }

  Future<void> _logHistory(SyncHistoryItem item) async {
    await LocalStorage.addSyncHistory(item.toJson());
  }

  SyncType _typeFromEndpoint(String endpoint) {
    if (endpoint.contains('/orders') || endpoint.contains('/pos/')) {
      return SyncType.order;
    }
    if (endpoint.contains('/stock')) {
      return SyncType.stock;
    }
    return SyncType.other;
  }

  String _describeEndpoint(String endpoint, Map<String, dynamic> body) {
    if (endpoint.contains('/orders') || endpoint.contains('/pos/')) {
      final items = body['items'] as List?;
      final itemCount = items?.length ?? 0;
      final total = body['total'] ?? body['grand_total'] ?? '';
      return 'Pesanan ($itemCount item, Rp$total)';
    }
    if (endpoint.contains('/stock')) {
      final productName = body['product_name'] ?? body['name'] ?? 'Produk';
      final qty = body['quantity'] ?? body['qty'] ?? '';
      return 'Stok: $productName ($qty)';
    }
    final parts = endpoint.split('/');
    final last = parts.where((p) => p.isNotEmpty).last;
    return 'Sync: $last';
  }

  void dispose() {
    _connectivitySubscription?.close();
    _periodicTimer?.cancel();
    _syncStateController.close();
  }
}

class SyncState {
  final bool syncing;
  final int? currentItem;
  final int? totalItems;
  final String? currentDescription;
  final int? syncedCount;
  final int? failedCount;

  const SyncState({
    required this.syncing,
    this.currentItem,
    this.totalItems,
    this.currentDescription,
    this.syncedCount,
    this.failedCount,
  });

  const SyncState.idle()
      : syncing = false,
        currentItem = null,
        totalItems = null,
        currentDescription = null,
        syncedCount = null,
        failedCount = null;

  const SyncState.syncing()
      : syncing = true,
        currentItem = null,
        totalItems = null,
        currentDescription = null,
        syncedCount = null,
        failedCount = null;

  const SyncState.syncingItem({
    required int current,
    required int total,
    required String description,
  })  : syncing = true,
        currentItem = current,
        totalItems = total,
        currentDescription = description,
        syncedCount = null,
        failedCount = null;

  const SyncState.completed({
    required int synced,
    required int failed,
  })  : syncing = false,
        currentItem = null,
        totalItems = null,
        currentDescription = null,
        syncedCount = synced,
        failedCount = failed;
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref);
  service.start();
  ref.onDispose(service.dispose);
  return service;
});

class SyncHistoryNotifier extends StateNotifier<List<SyncHistoryItem>> {
  SyncHistoryNotifier() : super(_load());

  static List<SyncHistoryItem> _load() {
    final raw = LocalStorage.getAllSyncHistory();
    return raw.map((e) => SyncHistoryItem.fromJson(e)).toList();
  }

  void refresh() {
    state = _load();
  }
}

final syncHistoryProvider = StateNotifierProvider<SyncHistoryNotifier, List<SyncHistoryItem>>((ref) {
  final notifier = SyncHistoryNotifier();
  ref.listen(syncServiceProvider, (_, __) {});
  return notifier;
});
