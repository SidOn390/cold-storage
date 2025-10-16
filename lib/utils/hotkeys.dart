import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import universal_html for web-specific code
import 'package:universal_html/html.dart' as html;

/// Callbacks that screens can register to handle global keyboard shortcuts.
class HotkeyHandlers {
  const HotkeyHandlers({
    this.onSearch,
    this.onExport,
    this.onNewReceipt,
    this.onTogglePaid,
    this.onToggleUnpaid,
    this.onOpenStorage,
    this.onRefresh,
    this.onBack,
    this.onHelp,
  });

  final VoidCallback? onSearch;
  final VoidCallback? onExport;
  final VoidCallback? onNewReceipt;
  final VoidCallback? onTogglePaid;
  final VoidCallback? onToggleUnpaid;
  final VoidCallback? onOpenStorage;
  final VoidCallback? onRefresh;
  final VoidCallback? onBack;
  final VoidCallback? onHelp;
}

/// Inherited widget that exposes the current screen's hotkey handlers.
class HotkeyScope extends InheritedWidget {
  const HotkeyScope({super.key, required this.handlers, required super.child});

  final HotkeyHandlers handlers;

  static HotkeyHandlers? of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HotkeyScope>();
    return scope?.handlers;
  }

  @override
  bool updateShouldNotify(HotkeyScope oldWidget) =>
      handlers != oldWidget.handlers;
}

// Intent classes for Flutter's Actions/Shortcuts system
class SearchIntent extends Intent {
  const SearchIntent();
}

class ExportIntent extends Intent {
  const ExportIntent();
}

class NewReceiptIntent extends Intent {
  const NewReceiptIntent();
}

class TogglePaidIntent extends Intent {
  const TogglePaidIntent();
}

class ToggleUnpaidIntent extends Intent {
  const ToggleUnpaidIntent();
}

class OpenStorageIntent extends Intent {
  const OpenStorageIntent();
}

class RefreshIntent extends Intent {
  const RefreshIntent();
}

class BackIntent extends Intent {
  const BackIntent();
}

class HelpIntent extends Intent {
  const HelpIntent();
}

/// Global hotkey manager that wraps the entire app.
///
/// On web, this uses DOM event listeners to intercept browser shortcuts
/// before they trigger default browser behavior (like Ctrl+F, Ctrl+P, etc).
/// On mobile/desktop, it uses Flutter's standard Shortcuts/Actions system.
class AppHotkeys extends StatefulWidget {
  const AppHotkeys({super.key, required this.child});

  final Widget child;

  @override
  State<AppHotkeys> createState() => _AppHotkeysState();
}

class _AppHotkeysState extends State<AppHotkeys> {
  StreamSubscription<html.KeyboardEvent>? _webKeyListener;

  @override
  void initState() {
    super.initState();
    // Set up web-specific keyboard event interception
    if (kIsWeb) {
      _webKeyListener = html.window.onKeyDown.listen(_handleWebKeyDown);
    }
  }

  @override
  void dispose() {
    _webKeyListener?.cancel();
    super.dispose();
  }

  /// Handles raw keyboard events on web to prevent browser defaults.
  ///
  /// This method intercepts common browser shortcuts and prevents their
  /// default behavior, then triggers the corresponding app action.
  void _handleWebKeyDown(html.KeyboardEvent event) {
    final isMac = html.window.navigator.platform?.startsWith('Mac') ?? false;
    final ctrlOrMeta = isMac ? event.metaKey : event.ctrlKey;
    final key = event.key?.toLowerCase();

    // Map of shortcuts that should be intercepted on web
    final shouldPrevent = <String, VoidCallback?>{
      'f': () => _handlersFromFocus(context)?.onSearch?.call(), // Ctrl+F: Find
      'p': () => _handlersFromFocus(context)?.onExport?.call(), // Ctrl+P: Print
      'n': () => _handlersFromFocus(context)?.onNewReceipt?.call(), // Ctrl+N: New
      'k': () => _handlersFromFocus(context)?.onOpenStorage?.call(), // Ctrl+K
      's': null, // Ctrl+S: Save (prevent default, let Flutter handle)
    };

    // Check if this is a shortcut we want to intercept
    if (ctrlOrMeta && key != null && shouldPrevent.containsKey(key)) {
      event.preventDefault();
      event.stopPropagation();

      // Invoke the handler if available
      final handler = shouldPrevent[key];
      handler?.call();

      debugPrint('🔧 Intercepted browser shortcut: Ctrl+${key.toUpperCase()}');
    }

    // Handle Ctrl+1 and Ctrl+2 (these use 'digit' event codes)
    if (ctrlOrMeta) {
      if (key == '1') {
        event.preventDefault();
        _handlersFromFocus(context)?.onTogglePaid?.call();
      } else if (key == '2') {
        event.preventDefault();
        _handlersFromFocus(context)?.onToggleUnpaid?.call();
      }
    }

    // Prevent Ctrl+R (browser refresh) on web
    if (ctrlOrMeta && key == 'r') {
      event.preventDefault();
      _handlersFromFocus(context)?.onRefresh?.call();
      debugPrint('🔧 Prevented browser refresh, triggered app refresh');
    }
  }

  bool get _isMacLike {
    final p = defaultTargetPlatform;
    return p == TargetPlatform.macOS || p == TargetPlatform.iOS;
  }

  HotkeyHandlers? _handlersFromFocus(BuildContext fallback) {
    final focusedCtx = FocusManager.instance.primaryFocus?.context;
    return HotkeyScope.of(focusedCtx ?? fallback);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = !_isMacLike;
    final meta = _isMacLike;

    // Define keyboard shortcuts
    // On web, we exclude shortcuts that are handled by the DOM listener
    final shortcuts = <ShortcutActivator, Intent>{
      // Search (Ctrl+F) - on web, handled by DOM listener
      if (!kIsWeb)
        SingleActivator(LogicalKeyboardKey.keyF, control: ctrl, meta: meta):
            const SearchIntent(),

      // Export/Print (Ctrl+P) - on web, handled by DOM listener
      if (!kIsWeb)
        SingleActivator(LogicalKeyboardKey.keyP, control: ctrl, meta: meta):
            const ExportIntent(),

      // New receipt (Ctrl+N) - on web, handled by DOM listener
      if (!kIsWeb)
        SingleActivator(LogicalKeyboardKey.keyN, control: ctrl, meta: meta):
            const NewReceiptIntent(),

      // Toggle paid (Ctrl+1) - on web, handled by DOM listener
      if (!kIsWeb)
        SingleActivator(LogicalKeyboardKey.digit1, control: ctrl, meta: meta):
            const TogglePaidIntent(),

      // Toggle unpaid (Ctrl+2) - on web, handled by DOM listener
      if (!kIsWeb)
        SingleActivator(LogicalKeyboardKey.digit2, control: ctrl, meta: meta):
            const ToggleUnpaidIntent(),

      // Open storage (Ctrl+K) - on web, handled by DOM listener
      if (!kIsWeb)
        SingleActivator(LogicalKeyboardKey.keyK, control: ctrl, meta: meta):
            const OpenStorageIntent(),

      // Refresh (Ctrl+R) - on web, handled by DOM listener
      if (!kIsWeb)
        const SingleActivator(LogicalKeyboardKey.keyR, control: true):
            const RefreshIntent(),

      // Back (Escape) - works on all platforms
      const SingleActivator(LogicalKeyboardKey.escape): const BackIntent(),

      // Help (F1) - works on all platforms
      const SingleActivator(LogicalKeyboardKey.f1): const HelpIntent(),
    };

    // Define actions for each intent
    final actions = <Type, Action<Intent>>{
      SearchIntent: CallbackAction<SearchIntent>(
        onInvoke: (intent) {
          _handlersFromFocus(context)?.onSearch?.call();
          return null;
        },
      ),
      ExportIntent: CallbackAction<ExportIntent>(
        onInvoke: (intent) {
          _handlersFromFocus(context)?.onExport?.call();
          return null;
        },
      ),
      NewReceiptIntent: CallbackAction<NewReceiptIntent>(
        onInvoke: (intent) {
          _handlersFromFocus(context)?.onNewReceipt?.call();
          return null;
        },
      ),
      TogglePaidIntent: CallbackAction<TogglePaidIntent>(
        onInvoke: (intent) {
          _handlersFromFocus(context)?.onTogglePaid?.call();
          return null;
        },
      ),
      ToggleUnpaidIntent: CallbackAction<ToggleUnpaidIntent>(
        onInvoke: (intent) {
          _handlersFromFocus(context)?.onToggleUnpaid?.call();
          return null;
        },
      ),
      OpenStorageIntent: CallbackAction<OpenStorageIntent>(
        onInvoke: (intent) {
          _handlersFromFocus(context)?.onOpenStorage?.call();
          return null;
        },
      ),
      RefreshIntent: CallbackAction<RefreshIntent>(
        onInvoke: (intent) {
          _handlersFromFocus(context)?.onRefresh?.call();
          return null;
        },
      ),
      BackIntent: CallbackAction<BackIntent>(
        onInvoke: (intent) {
          _handlersFromFocus(context)?.onBack?.call();
          return null;
        },
      ),
      HelpIntent: CallbackAction<HelpIntent>(
        onInvoke: (intent) {
          _handlersFromFocus(context)?.onHelp?.call();
          return null;
        },
      ),
    };

    return Focus(
      autofocus: true,
      canRequestFocus: true,
      child: Shortcuts(
        shortcuts: shortcuts,
        child: Actions(
          actions: actions,
          child: widget.child,
        ),
      ),
    );
  }
}
