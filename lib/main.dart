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
import 'app_router.dart';
import '../../services/master_service.dart';
import 'package:cold_storage/theme/app_theme.dart';
import 'package:cold_storage/utils/hotkeys.dart';
import 'widgets/session_timeout_listener.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize MasterService with real-time listeners
  // This will automatically sync all master data changes from Firestore
  try {
    await MasterService.instance.initialize();
    debugPrint('✅ MasterService initialized with real-time sync');
  } catch (e, st) {
    // On Web, this may fail if not logged in yet (permission denied)
    // The service will retry initialization automatically when user logs in
    debugPrint('⚠️ Warning: MasterService initialization deferred: $e');
    debugPrint(st.toString());
  }

  if (kIsWeb) {
    // === WEB-SPECIFIC CONFIGURATION ===

    // 1. Persist login across sessions on Web
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

    // 2. Enable Firestore persistence with tab sync
    // This allows offline access and cross-tab synchronization
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint('✅ Firestore persistence enabled for web');
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        // Multiple tabs open, persistence can only be enabled in one tab at a time
        debugPrint('⚠️ Firestore persistence already enabled in another tab');
      } else {
        debugPrint('❌ Failed to enable Firestore persistence: ${e.message}');
        rethrow;
      }
    }

    // 3. Set up web-specific error handling for uncaught errors
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('❌ Flutter Error: ${details.exception}');
      debugPrint(details.stack.toString());
      // In production, you might want to send this to an error tracking service
    };
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
      title: 'Cold Storage Management App',
      theme: vibrantHorizonTheme,
      initialRoute: AppRouter.authGate,
      onGenerateRoute: AppRouter.generateRoute,
      builder: (context, child) => SessionTimeoutListener(
        child: AppHotkeys(child: child ?? const SizedBox()),
      ),
    );
  }
}
