// File: lib/widgets/session_timeout_listener.dart
//
// Widget that hooks into user interactions and forwards them to the session
// timeout service so we can log a user out after a period of inactivity.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/session_timeout_service.dart';

class SessionTimeoutListener extends StatefulWidget {
  const SessionTimeoutListener({
    super.key,
    required this.child,
    this.timeout,
  });

  final Widget child;
  final Duration? timeout;

  @override
  State<SessionTimeoutListener> createState() => _SessionTimeoutListenerState();
}

class _SessionTimeoutListenerState extends State<SessionTimeoutListener> {
  final SessionTimeoutService _service = SessionTimeoutService.instance;

  @override
  void initState() {
    super.initState();
    _service.initialize(timeoutOverride: widget.timeout);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void didUpdateWidget(covariant SessionTimeoutListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.timeout != oldWidget.timeout && widget.timeout != null) {
      _service.initialize(timeoutOverride: widget.timeout);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _service.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      _service.recordInteraction();
    }
    return false;
  }

  void _handleInteraction() {
    _service.recordInteraction();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _handleInteraction(),
      onPointerSignal: (_) => _handleInteraction(),
      onPointerUp: (_) => _handleInteraction(),
      child: widget.child,
    );
  }
}
