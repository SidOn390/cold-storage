// File: lib/screens/admin/data_maintenance_screen.dart
//
// Data Maintenance & Sync Utility Screen
// Provides tools for data integrity maintenance and troubleshooting

import 'package:flutter/material.dart';
import 'package:cold_storage/services/firestore_service.dart';
import 'package:cold_storage/utils/app_notifications.dart';
import 'package:cold_storage/widgets/app_background.dart';

class DataMaintenanceScreen extends StatefulWidget {
  const DataMaintenanceScreen({super.key});

  @override
  State<DataMaintenanceScreen> createState() => _DataMaintenanceScreenState();
}

class _DataMaintenanceScreenState extends State<DataMaintenanceScreen> {
  final FirestoreService _firestore = FirestoreService();

  bool _isSyncing = false;
  int? _lastSyncCount;
  String? _lastSyncMessage;

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
              'This screen provides tools to maintain data integrity and fix '
              'inconsistencies in the database.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '• Sync remaining quantities from actual delivery records\n'
              '• Recalculate all receipt remaining stock values\n'
              '• Fix data discrepancies',
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
                      ? Colors.green.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
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
                    '• It is safe to run these operations multiple times\n'
                    '• No data will be deleted, only remaining quantities updated',
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
}
