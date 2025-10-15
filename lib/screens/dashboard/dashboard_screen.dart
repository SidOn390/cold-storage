// File: lib/screens/dashboard/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cold_storage/services/auth_service.dart';
import 'package:cold_storage/app_router.dart';
import 'package:cold_storage/widgets/app_background.dart';
import 'package:cold_storage/services/backup_service.dart';
import 'package:cold_storage/services/master_service.dart';
import 'package:cold_storage/utils/app_notifications.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final username = email.contains('@') ? email.split('@').first : email;
    final greeting = 'Welcome back, ${_capitalize(username)}!';

    final items = <_DashboardItem>[
      const _DashboardItem(
        title: 'Receipt Entry',
        icon: Icons.receipt_long_outlined,
        route: AppRouter.receiptEntry,
      ),
      const _DashboardItem(
        title: 'Receipt List',
        icon: Icons.list_alt_outlined,
        route: AppRouter.receiptList,
      ),
      const _DashboardItem(
        title: 'Delivery Entry',
        icon: Icons.delivery_dining_outlined,
        route: AppRouter.deliveryEntry,
      ),
      const _DashboardItem(
        title: 'Delivery History',
        icon: Icons.history_outlined,
        route: AppRouter.deliveryHistory,
      ),
      const _DashboardItem(
        title: 'Billing Checker',
        icon: Icons.payment_outlined,
        route: AppRouter.billingChecker,
      ),
      const _DashboardItem(
        title: 'Reports',
        icon: Icons.picture_as_pdf_outlined,
        route: AppRouter.reports,
      ),
      const _DashboardItem(
        title: 'Masters',
        icon: Icons.settings_outlined,
        route: AppRouter.mastersMenu,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 100.0, 24.0, 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.terrain, size: 64, color: Colors.white),
                      const SizedBox(height: 8),
                      Text(
                        'COLD STORAGE',
                        style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  greeting,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000.0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.1,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () =>
                                Navigator.pushNamed(context, item.route),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item.icon,
                                    size: 40,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    item.title,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Data utilities',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _exportBackup,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Backup'),
                    ),
                    FilledButton.icon(
                      onPressed: _importBackup,
                      icon: const Icon(Icons.upload_outlined),
                      label: const Text('Restore'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportBackup() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    _showLoadingDialog(navigator, 'Exporting backup...');

    final service = BackupService();
    final result = await service.exportToLocal();

    if (navigator.mounted) {
      navigator.pop();
    }

    if (!mounted) return;

    if (result.success) {
      final location = result.locationMessage ?? 'backup file';
      showAppNotification(
        context: context,
        message: 'Backup saved to $location',
        type: NotificationType.success,
      );
    } else {
      final message = result.error ?? 'Backup failed.';
      final lowered = message.toLowerCase();
      final type = lowered.contains('cancelled')
          ? NotificationType.info
          : NotificationType.error;
      showAppNotification(context: context, message: message, type: type);
    }
  }

  Future<void> _importBackup() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final confirmed = await showDialog<bool>(
      context: navigator.context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import backup'),
        content: const Text(
          'Importing a backup will overwrite existing documents with the same '
          'IDs. This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    _showLoadingDialog(navigator, 'Importing backup...');

    final service = BackupService();
    final result = await service.importFromLocal();

    if (navigator.mounted) {
      navigator.pop();
    }

    if (!mounted) return;

    if (result.success) {
      await MasterService.loadAllMasters();
      if (!mounted) return;
      final source = result.source ?? 'backup file';
      showAppNotification(
        context: context,
        message: 'Data restored from $source',
        type: NotificationType.success,
      );
    } else {
      final message = result.error ?? 'Restore failed.';
      final lowered = message.toLowerCase();
      final type = lowered.contains('selected')
          ? NotificationType.info
          : NotificationType.error;
      showAppNotification(context: context, message: message, type: type);
    }
  }

  void _showLoadingDialog(NavigatorState navigator, String message) {
    showDialog<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _DashboardItem {
  final String title;
  final IconData icon;
  final String route;

  const _DashboardItem({
    required this.title,
    required this.icon,
    required this.route,
  });
}
