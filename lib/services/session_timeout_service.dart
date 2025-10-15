// File: lib/services/session_timeout_service.dart
//
// Centralized session timeout manager that tracks user inactivity and
// automatically signs the user out after a configurable duration.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

class SessionTimeoutService with WidgetsBindingObserver {
  SessionTimeoutService._internal();

  static final SessionTimeoutService instance =
      SessionTimeoutService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Duration _timeoutDuration = const Duration(minutes: 15);
  Timer? _inactivityTimer;
  StreamSubscription<User?>? _authSubscription;
  bool _initialized = false;

  void initialize({Duration? timeoutOverride}) {
    if (_initialized) {
      if (timeoutOverride != null &&
          timeoutOverride != _timeoutDuration &&
          _auth.currentUser != null) {
        _timeoutDuration = timeoutOverride;
        _restartTimer();
      }
      return;
    }

    _timeoutDuration = timeoutOverride ?? _timeoutDuration;
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = _auth.authStateChanges().listen(_handleAuthChange);
    _initialized = true;

    if (_auth.currentUser != null) {
      _startTimer();
    }
  }

  void dispose() {
    if (!_initialized) {
      return;
    }
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _cancelTimer();
    _initialized = false;
  }

  void recordInteraction() {
    if (_auth.currentUser == null) {
      _cancelTimer();
      return;
    }
    _restartTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_auth.currentUser == null) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      recordInteraction();
    }
  }

  void _handleAuthChange(User? user) {
    if (user == null) {
      _cancelTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    _cancelTimer();
    _inactivityTimer = Timer(_timeoutDuration, _handleTimeout);
  }

  void _restartTimer() {
    if (_auth.currentUser == null) {
      return;
    }
    _cancelTimer();
    _inactivityTimer = Timer(_timeoutDuration, _handleTimeout);
  }

  void _cancelTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  Future<void> _handleTimeout() async {
    if (_auth.currentUser == null) {
      return;
    }

    try {
      await _auth.signOut();
    } catch (_) {
      // Ignore sign-out exceptions; user can retry manually.
    }
  }
}
