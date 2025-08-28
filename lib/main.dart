// File: lib/main.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuth, Persistence;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'app_router.dart';
import 'screens/auth/auth_gate.dart';
import '../../services/master_service.dart';
import 'package:business_management_app/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // --- START OF CHANGE: safely preload master data ---
  try {
    await MasterService.loadAllMasters();
    debugPrint('✅ Master data preloaded successfully');
  } catch (e, st) {
    // On Web, this will catch permission-denied if not logged in yet
    debugPrint('⚠️ Warning: could not preload master data: $e');
    debugPrint(st.toString());
  }
  // --- END OF CHANGE ---

  if (kIsWeb) {
    // Persist login across sessions on Web
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

    // Enable Firestore persistence with tab sync, ignore if already enabled
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') {
        // Re-throw if it's a different error
        rethrow;
      }
    }
  } else {
    // Mobile-only: initialize Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    } catch (_) {
      // Ignore if unavailable
    }
    // Firestore offline persistence is enabled by default on mobile
  }

  // Analytics: only on mobile
  if (!kIsWeb) {
    await FirebaseAnalytics.instance.logAppOpen();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Business Management App',
      theme: vibrantHorizonTheme,
      initialRoute: AppRouter.authGate,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
