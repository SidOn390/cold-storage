// File: lib/screens/admin/data_maintenance_screen.dart
//
// Data Maintenance & Sync Utility Screen
// Provides tools for data integrity maintenance and troubleshooting

import 'package:flutter/material.dart';
import 'package:cold_storage/services/firestore_service.dart';
import 'package:cold_storage/services/data_purge_service.dart';
import 'package:cold_storage/utils/app_notifications.dart';
import 'package:cold_storage/widgets/app_background.dart';

class DataMaintenanceScreen extends StatefulWidget {
  const DataMaintenanceScreen({super.key});

  @override
  State<DataMaintenanceScreen> createState() => _DataMaintenanceScreenState();
}

class _DataMaintenanceScreenState extends State<DataMaintenanceScreen> {
  final FirestoreService _firestore = FirestoreService();
  final DataPurgeService _purgeService = DataPurgeService.instance;

  bool _isSyncing = false;
  int? _lastSyncCount;
  String? _lastSyncMessage;

  bool _isLoadingStats = false;
  bool _isPurging = false;
  PurgeStatistics? _purgeStats;
  String? _lastPurgeMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Data Maintenance'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                  _buildSyncSection(),
                  const SizedBox(height: 24),
                  _buildPurgeSection(),
                  const SizedBox(height: 24),
                  _buildWarningCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Data Maintenance Tools',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'This screen provides tools to maintain data integrity and manage '
              'database size.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '• Sync remaining quantities from actual delivery records\n'
              '• Recalculate all receipt remaining stock values\n'
              '• Purge old data (older than 3 years) to maintain performance',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sync Remaining Quantities',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Recalculates remaining quantity for ALL receipts by querying '
              'actual delivery records. This fixes any discrepancies between '
              'stored values and reality.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_lastSyncMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: _lastSyncCount! > 0
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: _lastSyncCount! > 0
                        ? Colors.green
                        : Colors.blue,
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _lastSyncCount! > 0
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      color: _lastSyncCount! > 0
                          ? Colors.green
                          : Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _lastSyncMessage!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _syncAllReceipts,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync),
              label: Text(_isSyncing ? 'Syncing...' : 'Sync All Receipts'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade700,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Important Notes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Sync operations read all delivery records from the database\n'
                    '• Large datasets may take some time to process\n'
                    '• It is safe to run sync operations multiple times\n'
                    '• Purge operations PERMANENTLY DELETE old data - use with caution\n'
                    '• Only fully delivered receipts (remaining = 0) can be purged\n'
                    '• Data retention: Current year + past 2 years (3 years total)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncAllReceipts() async {
    setState(() {
      _isSyncing = true;
      _lastSyncMessage = null;
    });

    try {
      final syncedCount = await _firestore.syncAllReceiptsRemainingQuantity();

      if (mounted) {
        setState(() {
          _isSyncing = false;
          _lastSyncCount = syncedCount;
          _lastSyncMessage = syncedCount > 0
              ? 'Successfully updated $syncedCount receipt(s)'
              : 'All receipts are already in sync';
        });

        showAppNotification(
          context: context,
          message: syncedCount > 0
              ? 'Sync complete: $syncedCount receipt(s) updated'
              : 'All receipts already in sync',
          type: syncedCount > 0
              ? NotificationType.success
              : NotificationType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _lastSyncMessage = 'Error during sync: $e';
          _lastSyncCount = 0;
        });

        showAppNotification(
          context: context,
          message: 'Sync failed: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  Widget _buildPurgeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.delete_sweep_outlined,
                  color: Theme.of(context).colorScheme.error,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Purge Old Data',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Delete receipts older than 3 years (keeps current year + past 2 years). '
              'Only fully delivered receipts (remaining quantity = 0) will be deleted. '
              'This will also delete related deliveries and rent bills.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            // Statistics display
            if (_purgeStats != null) ...[
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Analysis (before ${_purgeStats!.cutoffDateString})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow('Total old receipts', '${_purgeStats!.totalOldReceipts}', Colors.grey),
                    _buildStatRow('├─ Deletable (fully delivered)', '${_purgeStats!.deletableReceipts}', Colors.green),
                    _buildStatRow('└─ Cannot delete (has stock)', '${_purgeStats!.nonDeletableReceipts}', Colors.orange),
                    const Divider(height: 16),
                    _buildStatRow('Related deliveries', '${_purgeStats!.relatedDeliveries}', Colors.blue),
                    _buildStatRow('Related rent bills', '${_purgeStats!.relatedBills}', Colors.purple),
                    const Divider(height: 16),
                    _buildStatRow(
                      'Total items to delete',
                      '${_purgeStats!.deletableReceipts + _purgeStats!.relatedDeliveries + _purgeStats!.relatedBills}',
                      Colors.red,
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Last purge message
            if (_lastPurgeMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.green, width: 1.0),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _lastPurgeMessage!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoadingStats || _isPurging ? null : _loadPurgeStatistics,
                    icon: _isLoadingStats
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.analytics_outlined),
                    label: Text(_isLoadingStats ? 'Analyzing...' : 'Analyze Data'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16.0),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_purgeStats == null ||
                               _purgeStats!.deletableReceipts == 0 ||
                               _isLoadingStats ||
                               _isPurging)
                        ? null
                        : _confirmAndPurge,
                    icon: _isPurging
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delete_forever),
                    label: Text(_isPurging ? 'Purging...' : 'Purge Old Data'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.all(16.0),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPurgeStatistics() async {
    setState(() {
      _isLoadingStats = true;
      _lastPurgeMessage = null;
    });

    try {
      final stats = await _purgeService.getOldDataStatistics();

      if (mounted) {
        setState(() {
          _isLoadingStats = false;
          _purgeStats = stats;
        });

        if (stats.deletableReceipts == 0 && stats.totalOldReceipts == 0) {
          showAppNotification(
            context: context,
            message: 'No old data found. All receipts are within the 3-year retention period.',
            type: NotificationType.info,
          );
        } else if (stats.deletableReceipts == 0 && stats.nonDeletableReceipts > 0) {
          showAppNotification(
            context: context,
            message: 'Found ${stats.nonDeletableReceipts} old receipt(s), but they cannot be deleted (still have remaining stock).',
            type: NotificationType.warning,
          );
        } else {
          showAppNotification(
            context: context,
            message: 'Analysis complete: ${stats.deletableReceipts} receipt(s) ready for deletion',
            type: NotificationType.success,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });

        showAppNotification(
          context: context,
          message: 'Analysis failed: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _confirmAndPurge() async {
    if (_purgeStats == null || _purgeStats!.deletableReceipts == 0) return;

    final totalToDelete = _purgeStats!.deletableReceipts +
                         _purgeStats!.relatedDeliveries +
                         _purgeStats!.relatedBills;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Data Purge'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will PERMANENTLY DELETE:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text('• ${_purgeStats!.deletableReceipts} receipts (before ${_purgeStats!.cutoffDateString})'),
              Text('• ${_purgeStats!.relatedDeliveries} deliveries'),
              Text('• ${_purgeStats!.relatedBills} rent bills'),
              const Divider(height: 24),
              Text(
                'Total: $totalToDelete items',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: const Text(
                  '⚠️ This action CANNOT be undone!\n\nOnly fully delivered receipts (remaining = 0) will be deleted.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _executePurge();
    }
  }

  Future<void> _executePurge() async {
    setState(() {
      _isPurging = true;
      _lastPurgeMessage = null;
    });

    try {
      final result = await _purgeService.purgeOldData();

      if (mounted) {
        setState(() {
          _isPurging = false;
          _purgeStats = null; // Clear stats to force re-analysis
          _lastPurgeMessage =
              'Successfully deleted ${result.receiptsDeleted} receipts, '
              '${result.deliveriesDeleted} deliveries, and ${result.billsDeleted} bills. '
              '${result.skippedReceipts > 0 ? '(${result.skippedReceipts} incomplete receipts skipped)' : ''}';
        });

        showAppNotification(
          context: context,
          message: 'Purge complete: ${result.totalDeleted} items deleted',
          type: NotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPurging = false;
        });

        showAppNotification(
          context: context,
          message: 'Purge failed: $e',
          type: NotificationType.error,
        );
      }
    }
  }
}
