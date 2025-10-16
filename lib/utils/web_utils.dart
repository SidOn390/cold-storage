// File: lib/utils/web_utils.dart
//
// Web-specific utilities and helpers for browser environment.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

/// Web-specific utilities for browser environment optimization.
class WebUtils {
  /// Prevent default browser context menu (right-click menu).
  /// Useful for web apps that want a native app feel.
  static void disableContextMenu() {
    if (!kIsWeb) return;

    html.document.onContextMenu.listen((event) {
      event.preventDefault();
    });
    debugPrint('🔧 Browser context menu disabled');
  }

  /// Enable context menu (default browser behavior).
  static void enableContextMenu() {
    if (!kIsWeb) return;
    // Context menu is enabled by default, nothing to do
    debugPrint('🔧 Browser context menu enabled');
  }

  /// Set the browser window title dynamically.
  static void setWindowTitle(String title) {
    if (!kIsWeb) return;
    html.document.title = title;
  }

  /// Detect if the app is running in an iframe.
  static bool isInIframe() {
    if (!kIsWeb) return false;
    return html.window.self != html.window.top;
  }

  /// Get browser information.
  static Map<String, String> getBrowserInfo() {
    if (!kIsWeb) return {};

    final navigator = html.window.navigator;
    return {
      'userAgent': navigator.userAgent,
      'platform': navigator.platform ?? 'unknown',
      'language': navigator.language,
      'cookieEnabled': navigator.cookieEnabled.toString(),
      'onLine': html.window.navigator.onLine.toString(),
    };
  }

  /// Check if the browser is online.
  static bool isOnline() {
    if (!kIsWeb) return true; // Assume online on non-web platforms
    return html.window.navigator.onLine ?? true;
  }

  /// Listen to online/offline status changes.
  /// Returns a Stream that emits true when online, false when offline.
  static Stream<bool> onlineStatusStream() {
    if (!kIsWeb) {
      // On non-web, always return online
      return Stream.value(true);
    }

    final controller = StreamController<bool>.broadcast();

    html.window.onOnline.listen((_) {
      debugPrint('🌐 Browser is ONLINE');
      controller.add(true);
    });

    html.window.onOffline.listen((_) {
      debugPrint('📡 Browser is OFFLINE');
      controller.add(false);
    });

    // Add current state immediately
    controller.add(isOnline());

    return controller.stream;
  }

  /// Prevent the browser from caching specific resources.
  /// This can help ensure users always get the latest version.
  static void preventBrowserCaching() {
    if (!kIsWeb) return;

    final meta = html.MetaElement()
      ..name = 'Cache-Control'
      ..content = 'no-cache, no-store, must-revalidate';

    html.document.head?.append(meta);
    debugPrint('🔧 Browser caching prevention meta tag added');
  }

  /// Set viewport meta tag for better mobile web experience.
  static void setViewportMeta({
    double initialScale = 1.0,
    double minimumScale = 1.0,
    double maximumScale = 1.0,
    bool userScalable = false,
    String width = 'device-width',
  }) {
    if (!kIsWeb) return;

    // Check if viewport meta already exists
    final existing = html.document.head?.querySelector('meta[name="viewport"]');
    if (existing != null) {
      existing.remove();
    }

    final meta = html.MetaElement()
      ..name = 'viewport'
      ..content = 'width=$width, '
          'initial-scale=$initialScale, '
          'minimum-scale=$minimumScale, '
          'maximum-scale=$maximumScale, '
          'user-scalable=${userScalable ? "yes" : "no"}';

    html.document.head?.append(meta);
    debugPrint('🔧 Viewport meta tag configured');
  }

  /// Copy text to clipboard using the browser's clipboard API.
  static Future<bool> copyToClipboard(String text) async {
    if (!kIsWeb) return false;

    try {
      await html.window.navigator.clipboard?.writeText(text);
      debugPrint('📋 Text copied to clipboard');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to copy to clipboard: $e');
      return false;
    }
  }

  /// Show browser notification (requires permission).
  static Future<void> showNotification({
    required String title,
    String? body,
    String? icon,
  }) async {
    if (!kIsWeb) return;

    try {
      final permission = await html.Notification.requestPermission();
      if (permission == 'granted') {
        html.Notification(
          title,
          body: body,
          icon: icon,
        );
      }
    } catch (e) {
      debugPrint('❌ Browser notification failed: $e');
    }
  }

  /// Log browser console message (appears in browser DevTools).
  static void consoleLog(String message, {String level = 'log'}) {
    if (!kIsWeb) return;

    switch (level) {
      case 'error':
        html.window.console.error(message);
        break;
      case 'warn':
        html.window.console.warn(message);
        break;
      case 'info':
        html.window.console.info(message);
        break;
      default:
        html.window.console.log(message);
    }
  }
}
