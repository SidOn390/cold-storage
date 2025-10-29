// File: lib/screens/masters/masters_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:cold_storage/app_router.dart';
import 'package:cold_storage/widgets/app_background.dart';
import 'package:cold_storage/services/user_management_service.dart';
import 'package:cold_storage/models/app_user.dart';
import 'package:cold_storage/models/user_role.dart';

class MastersMenuScreen extends StatefulWidget {
  const MastersMenuScreen({super.key});

  @override
  State<MastersMenuScreen> createState() => _MastersMenuScreenState();
}

class _MastersMenuScreenState extends State<MastersMenuScreen> {
  final UserManagementService _userService = UserManagementService();
  AppUser? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _userService.getCurrentUser();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allItems = <_MasterItem>[
      const _MasterItem(
        title: 'Cold Storages',
        icon: Icons.inventory_2_outlined,
        route: AppRouter.coldStorageMaster,
      ),
      const _MasterItem(
        title: 'Product Types',
        icon: Icons.category_outlined,
        route: AppRouter.productTypeMaster,
      ),
      const _MasterItem(
        title: 'Brands',
        icon: Icons.branding_watermark_outlined,
        route: AppRouter.brandMaster,
      ),
      const _MasterItem(
        title: 'Companies',
        icon: Icons.apartment_outlined,
        route: AppRouter.companyMaster,
      ),
      const _MasterItem(
        title: 'Rent Rates',
        icon: Icons.payments_outlined,
        route: AppRouter.rentRateMaster,
      ),
      const _MasterItem(
        title: 'Data Maintenance',
        icon: Icons.settings_suggest_outlined,
        route: AppRouter.dataMaintenance,
        isSuperAdminOnly: true,
      ),
      const _MasterItem(
        title: 'User Management',
        icon: Icons.people_outline,
        route: AppRouter.userManagement,
        isSuperAdminOnly: true,
      ),
      const _MasterItem(
        title: 'Backup Encryption Tools',
        icon: Icons.lock_clock_outlined,
        route: AppRouter.backupEncryptionTools,
        isSuperAdminOnly: true,
      ),
    ];

    // Filter items based on user role
    final isSuperAdmin = _currentUser?.role == UserRole.superAdmin;
    final items = allItems.where((item) {
      if (item.isSuperAdminOnly) {
        return isSuperAdmin;
      }
      return true;
    }).toList();

    return Scaffold(
      // 2. Make Scaffold and AppBar transparent
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Masters'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // 3. Wrap the body content with AppBackground
      body: AppBackground(
        // 4. Use SafeArea to avoid system UI (like status bar)
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
                          onTap: () => Navigator.pushNamed(context, item.route),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  item.icon,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  item.title,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleSmall
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
      ),
    );
  }
}

class _MasterItem {
  final String title;
  final IconData icon;
  final String route;
  final bool isSuperAdminOnly;

  const _MasterItem({
    required this.title,
    required this.icon,
    required this.route,
    this.isSuperAdminOnly = false,
  });
}
