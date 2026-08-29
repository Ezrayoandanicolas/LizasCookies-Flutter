import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/sync/sync_history_item.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/network/connectivity_provider.dart';

class SyncStatusPage extends ConsumerStatefulWidget {
  const SyncStatusPage({super.key});

  @override
  ConsumerState<SyncStatusPage> createState() => _SyncStatusPageState();
}

class _SyncStatusPageState extends ConsumerState<SyncStatusPage> {
  SyncState _currentSyncState = const SyncState.idle();

  @override
  void initState() {
    super.initState();
    final syncService = ref.read(syncServiceProvider);
    syncService.syncStateStream.listen((state) {
      if (mounted) setState(() => _currentSyncState = state);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = ref.watch(syncHistoryProvider);
    final connectivity = ref.watch(connectivityProvider);
    final isOnline = connectivity == ConnectivityStatus.online;
    final syncService = ref.read(syncServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Sinkronisasi'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _clearHistory(context, ref),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildLiveStatusCard(theme, isOnline, syncService),
          if (_currentSyncState.syncing && _currentSyncState.currentDescription != null)
            _buildProgressCard(theme),
          if (_currentSyncState.syncedCount != null || _currentSyncState.failedCount != null)
            _buildResultBanner(theme),
          const Divider(height: 1),
          Expanded(
            child: history.isEmpty
                ? _buildEmptyState(theme)
                : _buildHistoryList(theme, history),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatusCard(ThemeData theme, bool isOnline, SyncService syncService) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOnline ? Icons.wifi : Icons.wifi_off,
                size: 20,
                color: isOnline ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 10),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isOnline ? Colors.green : Colors.red,
                ),
              ),
              const Spacer(),
              if (syncService.isSyncing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: isOnline ? () => syncService.manualSync() : null,
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Sync Manual'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Semua data offline (pesanan, stok) akan dikirim ke server saat online.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(ThemeData theme) {
    final current = _currentSyncState.currentItem ?? 0;
    final total = _currentSyncState.totalItems ?? 1;
    final desc = _currentSyncState.currentDescription ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Menyinkronkan $current/$total...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: current / total,
            minHeight: 3,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              desc,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.primary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultBanner(ThemeData theme) {
    final synced = _currentSyncState.syncedCount ?? 0;
    final failed = _currentSyncState.failedCount ?? 0;
    final isAllSuccess = failed == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isAllSuccess ? Colors.green.shade50 : Colors.orange.shade50,
      child: Row(
        children: [
          Icon(
            isAllSuccess ? Icons.check_circle : Icons.warning_amber,
            size: 18,
            color: isAllSuccess ? Colors.green.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 10),
          Text(
            'Berhasil: $synced  •  Gagal: $failed',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isAllSuccess ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync, size: 48, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'Belum ada riwayat sinkronisasi',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Riwayat akan muncul setelah\nada data yang disinkronkan',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(ThemeData theme, List<SyncHistoryItem> history) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm:ss', 'id_ID');

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: history.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
      itemBuilder: (context, index) {
        final item = history[index];
        final timeStr = dateFormat.format(item.timestamp);

        return _SyncHistoryTile(
          item: item,
          timeStr: timeStr,
          theme: theme,
        );
      },
    );
  }

  void _clearHistory(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Riwayat'),
        content: const Text('Yakin ingin menghapus semua riwayat sinkronisasi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              await LocalStorage.clearSyncHistory();
              ref.read(syncHistoryProvider.notifier).refresh();
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Riwayat dihapus')),
                );
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SyncHistoryTile extends StatelessWidget {
  final SyncHistoryItem item;
  final String timeStr;
  final ThemeData theme;

  const _SyncHistoryTile({
    required this.item,
    required this.timeStr,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildIcon(),
      title: Text(
        item.description,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            '${item.method} ${item.endpoint}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.access_time, size: 12, color: theme.colorScheme.outline),
              const SizedBox(width: 4),
              Text(
                '$timeStr WIB',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.outline,
                ),
              ),
              if (item.httpStatusCode != null) ...[
                const SizedBox(width: 8),
                Text(
                  'HTTP ${item.httpStatusCode}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
          if (item.error != null) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.error!,
                style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      isThreeLine: item.error != null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildIcon() {
    switch (item.status) {
      case SyncStatus.success:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, size: 18, color: Colors.green.shade700),
        );
      case SyncStatus.failed:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.close, size: 18, color: Colors.red.shade700),
        );
      case SyncStatus.syncing:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue.shade700,
            ),
          ),
        );
      case SyncStatus.skipped:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.skip_next, size: 18, color: Colors.orange.shade700),
        );
    }
  }
}
