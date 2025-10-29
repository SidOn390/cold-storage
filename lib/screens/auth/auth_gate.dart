// File: lib/screens/auth/auth_gate.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/master_service.dart';
import 'login_screen.dart';
import '../dashboard/dashboard_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;

          // Initialize MasterService when user logs in
          if (user != null) {
            _ensureMasterServiceInitialized();
          }

          return user == null ? const LoginScreen() : const DashboardScreen();
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }

  Future<void> _ensureMasterServiceInitialized() async {
    // Ensure MasterService is initialized after successful login
    // This handles the case where initialization failed at app startup
    // because the user wasn't authenticated yet (common on web)
    try {
      debugPrint('🔄 Initializing MasterService after login...');
      await MasterService.instance.initialize();
      debugPrint('✅ MasterService initialized');
    } catch (e) {
      // Initialization already completed or failed - safe to ignore
      debugPrint('⚠️ Service initialization error (may be already initialized): $e');
    }
  }
}
