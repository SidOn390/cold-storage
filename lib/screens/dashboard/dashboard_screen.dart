// File: lib/screens/dashboard/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:business_management_app/services/auth_service.dart';
import 'package:business_management_app/app_router.dart';
import 'package:business_management_app/widgets/app_background.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
        // The AppBar is now transparent to blend with the gradient
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
      // Extend the gradient behind the AppBar
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
                    // --- FIX 2: Set the header text color to white ---
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                // --- FIX 1: Wrap the GridView to constrain its width ---
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
              ],
            ),
          ),
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
