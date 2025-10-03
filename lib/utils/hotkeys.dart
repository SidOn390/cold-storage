import 'dart:async'; // NEW: Required for StreamSubscription
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// NEW: Import dart:html for web-specific code, with a conditional import
// to avoid errors on mobile.
import 'package:universal_html/html.dart' as html;

// Screen registers the callbacks it wants to handle.
class HotkeyHandlers {
  // ... (No changes in this class)
  final VoidCallback? onSearch;
  final VoidCallback? onExport;
  final VoidCallback? onNewReceipt;
  final VoidCallback? onTogglePaid;
  final VoidCallback? onToggleUnpaid;
  final VoidCallback? onOpenStorage;
  final VoidCallback? onRefresh;
  final VoidCallback? onBack;
  final VoidCallback? onHelp;

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
}

// Inherited widget that exposes the current screen's handlers.
class HotkeyScope extends InheritedWidget {
  // ... (No changes in this class)
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

// Intent classes
class SearchIntent extends Intent {
  const SearchIntent();
}

class ExportIntent extends Intent {
  const ExportIntent();
}

class NewReceiptIntent extends Intent {
  const NewReceiptIntent();
}

// ... (All other intent classes are the same)
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

/// Global installer.
// --- START: CONVERT TO STATEFULWIDGET ---
class AppHotkeys extends StatefulWidget {
  const AppHotkeys({super.key, required this.child});
  final Widget child;

  @override
  State<AppHotkeys> createState() => _AppHotkeysState();
}

class _AppHotkeysState extends State<AppHotkeys> {
  // NEW: Subscription to manage the web event listener
  StreamSubscription<html.KeyboardEvent>? _webKeyListener;

  @override
  void initState() {
    super.initState();
    // NEW: Add the low-level web listener only if we are on the web.
    if (kIsWeb) {
      _webKeyListener = html.window.onKeyDown.listen(_handleWebKeyDown);
    }
  }

  @override
  void dispose() {
    // NEW: Clean up the listener to prevent memory leaks.
    _webKeyListener?.cancel();
    super.dispose();
  }

  /// NEW: This method handles the raw key event from the browser.
  void _handleWebKeyDown(html.KeyboardEvent event) {
    final isMac = html.window.navigator.platform?.startsWith('Mac') ?? false;
    final isCtrlF = event.key == 'f' && (isMac ? event.metaKey : event.ctrlKey);

    if (isCtrlF) {
      // This is the most important part:
      // It stops the browser's default "Find" dialog from appearing.
      event.preventDefault();

      // Now, trigger our Flutter app's search logic.
      _handlersFromFocus(context)?.onSearch?.call();
    }
  }
  // --- END: STATEFULWIDGET LIFECYCLE AND WEB HANDLER ---

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

    // We still keep the Flutter shortcut system for everything else.
    // We remove the Ctrl+F binding from here ONLY on the web,
    // as it's now handled by our manual listener.
    final shortcuts = <ShortcutActivator, Intent>{
      // MODIFIED: Conditionally exclude the SearchIntent on web
      if (!kIsWeb)
        SingleActivator(LogicalKeyboardKey.keyF, control: ctrl, meta: meta):
            const SearchIntent(),

      SingleActivator(LogicalKeyboardKey.keyP, control: ctrl, meta: meta):
          const ExportIntent(),
      SingleActivator(LogicalKeyboardKey.keyN, control: ctrl, meta: meta):
          const NewReceiptIntent(),
      SingleActivator(LogicalKeyboardKey.digit1, control: ctrl, meta: meta):
          const TogglePaidIntent(),
      SingleActivator(LogicalKeyboardKey.digit2, control: ctrl, meta: meta):
          const ToggleUnpaidIntent(),
      SingleActivator(LogicalKeyboardKey.keyK, control: ctrl, meta: meta):
          const OpenStorageIntent(),
      if (!kIsWeb)
        const SingleActivator(LogicalKeyboardKey.keyR, control: true):
            const RefreshIntent(),
      const SingleActivator(LogicalKeyboardKey.escape): const BackIntent(),
      const SingleActivator(LogicalKeyboardKey.f1): const HelpIntent(),
    };

    final actions = <Type, Action<Intent>>{
      SearchIntent: CallbackAction<SearchIntent>(
        onInvoke: (intent) => _handlersFromFocus(context)?.onSearch?.call(),
      ),
      // ... (all other actions are the same)
      ExportIntent: CallbackAction<ExportIntent>(
        onInvoke: (intent) => _handlersFromFocus(context)?.onExport?.call(),
      ),
      NewReceiptIntent: CallbackAction<NewReceiptIntent>(
        onInvoke: (intent) => _handlersFromFocus(context)?.onNewReceipt?.call(),
      ),
      TogglePaidIntent: CallbackAction<TogglePaidIntent>(
        onInvoke: (intent) => _handlersFromFocus(context)?.onTogglePaid?.call(),
      ),
      ToggleUnpaidIntent: CallbackAction<ToggleUnpaidIntent>(
        onInvoke: (intent) =>
            _handlersFromFocus(context)?.onToggleUnpaid?.call(),
      ),
      OpenStorageIntent: CallbackAction<OpenStorageIntent>(
        onInvoke: (intent) =>
            _handlersFromFocus(context)?.onOpenStorage?.call(),
      ),
      RefreshIntent: CallbackAction<RefreshIntent>(
        onInvoke: (intent) => _handlersFromFocus(context)?.onRefresh?.call(),
      ),
      BackIntent: CallbackAction<BackIntent>(
        onInvoke: (intent) => _handlersFromFocus(context)?.onBack?.call(),
      ),
      HelpIntent: CallbackAction<HelpIntent>(
        onInvoke: (intent) => _handlersFromFocus(context)?.onHelp?.call(),
      ),
    };

    return Focus(
      autofocus: true,
      canRequestFocus: true,
      child: Shortcuts(
        shortcuts: shortcuts,
        child: Actions(
          actions: actions,
          child: widget.child, // Use widget.child in a StatefulWidget
        ),
      ),
    );
  }
}
