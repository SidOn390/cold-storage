# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cold Storage Management App - A Flutter application for managing cold storage inventory operations including receipt entry, delivery tracking, billing, and master data management. Built with Firebase backend (Firestore, Auth, Analytics, Crashlytics).

**Current Version:** 1.1.0+1
**Flutter SDK:** ^3.8.1
**Primary Platform:** Cross-platform (Android, iOS, Web)

## Development Commands

### Setup
```bash
flutter pub get
```

### Build & Run
```bash
# Run on connected device/emulator
flutter run

# Run on specific platform
flutter run -d chrome       # Web
flutter run -d android      # Android
flutter run -d ios          # iOS

# Build release
flutter build apk           # Android
flutter build ios           # iOS
flutter build web           # Web
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart
```

### Code Quality
```bash
# Analyze code (uses analysis_options.yaml config)
flutter analyze

# Format code
flutter format .

# Check for outdated dependencies
flutter pub outdated
```

### Linter Configuration
The project uses `flutter_lints` with custom rules in `analysis_options.yaml`:
- `require_trailing_commas: true` - Enforced for better formatting
- `prefer_const_constructors: true` - Performance optimization
- `avoid_print: true` - Use `debugPrint` instead
- `always_declare_return_types: true` - Explicit return types required

### App Icon Generation
```bash
# Generate app icons (configured in pubspec.yaml)
flutter pub run flutter_launcher_icons:main
```

## Architecture & Code Structure

### Core Data Flow

1. **Authentication Layer** (`lib/services/auth_service.dart`, `lib/screens/auth/`)
   - Username-based login mapped to Firebase Auth emails via `emailFromUsername()` utility
   - Session timeout management with automatic logout (`SessionTimeoutService`)
   - Auth state changes routed through `AuthGate` which guards all screens

2. **Master Data Management** (`lib/services/master_service.dart`)
   - **Real-time reactive service** with automatic Firestore synchronization
   - Initialized in `main.dart` on app startup and auto-retries on login if initial attempt fails
   - Uses Firestore snapshots listeners to keep in-memory cache always in sync
   - Provides both synchronous access (cached lists) and reactive streams for UI updates
   - In-memory cached lists: cold storages, products, brands, companies
   - Products include weight field; other masters are simple name entities
   - **Key improvement**: Any changes to master data (add/edit/delete) automatically propagate to all parts of the app

3. **Firestore Service Layer** (`lib/services/firestore_service.dart`)
   - Single service class handling all Firestore CRUD operations
   - Collections: `cold_storages`, `products`, `brands`, `companies`, `receipts`, `deliveries`
   - All master data includes `name_lowercase` field for case-insensitive querying
   - Referential integrity checks: `isBrandInUse()`, `isProductInUse()`, etc.

4. **Receipt & Delivery Workflow**
   - **Receipts** (`Receipt` model): Track inward inventory with receipt number, cold storage, product, brand, company, quantity, rate, payment status
   - **Deliveries** (`Delivery` model): Track outward movement linked to receipt numbers
   - Receipt uniqueness validated by receipt number + cold storage name combination
   - Remaining quantity calculated by receipt entry screen based on deliveries

5. **Backup/Restore System** (`lib/services/backup_service.dart`)
   - Platform-conditional implementation (web vs IO) using conditional imports
   - Exports all Firestore collections to timestamped JSON files
   - Custom serialization handles Firestore types (Timestamp, GeoPoint, DocumentReference)
   - Batch writes (400 docs/batch) for restore operations
   - Schema versioning for forward compatibility

### Navigation & Routing

- Centralized routing in `AppRouter` (`lib/app_router.dart`)
- Route guards check `FirebaseAuth.instance.currentUser` before allowing access
- All routes redirect to `AuthGate` if unauthenticated
- Arguments passed via `settings.arguments` (e.g., `Receipt?` for editing)

### UI Patterns

- **Theme**: Custom theme in `lib/theme/app_theme.dart` using Google Fonts (Lato body, Montserrat headings)
  - Primary color: Deep teal (#00796B)
  - Secondary color: Vibrant coral (#FF7043)
  - Consistent 12px border radius across cards, buttons, inputs
- **Background**: Gradient background via `AppBackground` widget used across screens
- **Hotkeys**: Global keyboard shortcuts managed by `AppHotkeys` widget wrapper in main app builder
  - On web, uses manual event listeners to override browser defaults (e.g., Ctrl+F for search)
  - Available hotkeys: Ctrl+F (search), Ctrl+P (export), Ctrl+N (new receipt), Ctrl+1/2 (toggle paid/unpaid), Ctrl+K (open storage), Esc (back), F1 (help)
  - Screens register handlers via `HotkeyScope` inherited widget
- **Notifications**: Toast-style notifications via `showAppNotification()` utility with typed severity levels (`NotificationType.success/error/info`)
- **PDF Generation**: Reports use `printing` and `pdf` packages for document generation
  - Utility functions in `lib/utils/pdf_utils.dart` provide reusable table and heading widgets

### Platform-Specific Behavior

- **Web**:
  - Firebase Auth persistence set to `LOCAL` (survives page refreshes)
  - Firestore persistence enabled with **unlimited cache size** for better offline support
  - Handles multi-tab scenarios gracefully (persistence only works in first tab)
  - File operations use browser download/upload APIs
  - DOM-level keyboard event interception for browser shortcut prevention
  - Enhanced error handling with debug logging
  - Web utilities available (`lib/utils/web_utils.dart`) for:
    - Online/offline detection
    - Browser clipboard access
    - Browser notifications
    - Viewport configuration
- **Mobile**:
  - Firebase Crashlytics enabled
  - Firebase Analytics active
  - Firestore offline persistence enabled by default
  - Biometric authentication available via `local_auth`
  - Native keyboard shortcuts work normally

## Key Implementation Notes

### Firebase Configuration
- Firebase initialization happens in `main.dart` before app launch
- Platform-specific options in `lib/firebase_options.dart` (auto-generated by FlutterFire CLI)
- Firestore security rules must allow authenticated access to all collections

### Master Data Synchronization
- `MasterService.instance.initialize()` called on app startup
- May fail on web if user not logged in yet (permission denied) - auto-retries on successful login via `AuthGate`
- Uses real-time Firestore listeners - cache updates automatically when data changes
- **No manual refresh needed** after backup restore or master data modifications
- Legacy `loadAllMasters()` method maintained for backward compatibility (now just calls `initialize()`)

### State Management
- No dedicated state management library (Provider, Riverpod, etc.)
- StatefulWidget + StreamBuilder pattern for Firestore real-time updates
- Auth state managed via `FirebaseAuth.instance.authStateChanges()` stream

### Form Validation
- Receipt numbers validated for uniqueness per cold storage
- Master data fields trimmed and normalized to lowercase for duplicate checking
- Delivery quantities validated against remaining receipt quantities

### Session Management
- `SessionTimeoutService` tracks user activity
- `SessionTimeoutListener` widget wraps app to monitor interactions
- Configurable timeout duration, auto-logout on expiry

## Common Patterns

### Adding a new master data type
1. Add collection name to `FirestoreService` with CRUD methods (get, add, update, delete)
2. Add to `MasterService` static lists and `loadAllMasters()`
3. Add referential integrity check method to `FirestoreService` (e.g., `isXInUse()`)
4. Create master screen in `lib/screens/masters/` following existing patterns (use `StreamBuilder` for real-time updates)
5. Add route to `AppRouter` constants and `generateRoute()` switch
6. Add to backup service `_collections` list for data export/import support

### Creating a new screen
1. Create screen widget in appropriate `lib/screens/` subdirectory
2. Add route constant to `AppRouter` class
3. Add route case to `AppRouter.generateRoute()` switch statement
4. Use `screenBuilder()` wrapper for auth guard if needed
5. Wrap with `AppBackground` widget for consistent styling
6. Register hotkey handlers using `HotkeyScope` widget if keyboard shortcuts needed

### Firestore data modeling
- Always include `name_lowercase` for searchable text fields (enables case-insensitive queries)
- Use `Timestamp` for dates (automatically serialized in backup system)
- Document IDs stored as `id` field in model classes (nullable, since new docs don't have IDs yet)
- `toJson()` methods omit `id` (Firestore manages document IDs)
- `fromFirestore()` / `fromSnapshot()` factories parse documents and extract `id` from `DocumentSnapshot`
- Provide `copyWith()` method for immutable updates (see `Receipt` model)

### Error Handling Conventions
- Use `debugPrint()` instead of `print()` (enforced by linter)
- Display user-facing errors via `showAppNotification()` with appropriate `NotificationType`
- Async operations should use try-catch blocks and show feedback dialogs for long operations
- Form validation errors should be inline (using `InputDecoration.errorText`)

## Testing Strategy

- Widget tests in `test/` directory
- No integration tests currently configured
- Firebase emulators not currently used for local testing

## Deployment Notes

- **Android**: Package name likely matches `publish_to` field (Mulchand-Badridas)
  - Build release APK: `flutter build apk --release`
  - Build app bundle: `flutter build appbundle --release`
- **Web**: Static hosting compatible (Firebase Hosting, etc.)
  - Build for web: `flutter build web --release`
  - Important: Ensure `firebase_options.dart` is configured for production
- **iOS**: Requires code signing and provisioning profiles
  - Build for iOS: `flutter build ios --release`
- App icon at `assets/app_icon.png`
- Icons auto-generated using `flutter_launcher_icons` package

## Important Gotchas & Known Issues

### Data Consistency ✅ SOLVED
- ~~When restoring from backup, **always** call `MasterService.loadAllMasters()` afterward to refresh in-memory cache~~ **FIXED**: MasterService now uses real-time listeners that automatically sync all changes
- Master data service initializes on app start - may fail with permission error on web if user not authenticated (automatically retries on login via `AuthGate`)
- All master data changes (add/edit/delete from master screens OR backup restore) now propagate automatically to all screens

### Web-Specific Issues ✅ IMPROVED
- **Hotkeys**: Enhanced DOM event listeners now intercept multiple browser shortcuts:
  - Ctrl+F (Find), Ctrl+P (Print), Ctrl+N (New Window), Ctrl+R (Refresh), Ctrl+K, Ctrl+S (Save)
  - All intercepted shortcuts prevent browser defaults and trigger app actions instead
  - Debug logging shows when shortcuts are intercepted
- **File Picker**: Enhanced with comprehensive error handling:
  - User cancellation properly detected and handled gracefully
  - File size validation (50 MB max) prevents browser crashes
  - UTF-8 encoding validation with clear error messages
  - JSON format validation before attempting restore
  - `FilePickerException` handling for browser-specific issues
- **Firestore Persistence**:
  - Enabled with unlimited cache size for better offline support
  - Handles multi-tab scenario (only one tab can enable persistence)
  - Clear error logging for troubleshooting
- **New Web Utilities** (`lib/utils/web_utils.dart`):
  - Online/offline status detection and monitoring
  - Browser info detection
  - Clipboard API integration
  - Viewport meta tag configuration
  - Browser notification support
  - Custom console logging

### Receipt & Delivery Validation ✅ ACCURATE
- **Receipt Uniqueness**: Receipt numbers are NOT globally unique - uniqueness is scoped to (receipt number + cold storage name)
- **New Service**: `DeliveryValidationService` (`lib/services/delivery_validation_service.dart`)
  - **SOURCE OF TRUTH**: Always calculates remaining quantity from actual delivery records
  - No longer relies on stored `remainingQuantity` field which can become stale
  - Queries all deliveries for a receipt and sums them in real-time
  - Provides comprehensive validation with detailed error messages
- **Key Features**:
  - `calculateRemainingQuantity()` - Real-time calculation from delivery records
  - `validateDelivery()` - Comprehensive pre-save validation with detailed results
  - `syncReceiptRemainingQuantity()` - Fix any discrepancies in stored values
  - `syncAllReceiptsRemainingQuantity()` - Batch sync for data maintenance
  - `getReceiptDeliverySummary()` - Full delivery breakdown with utilization percentage
- **Validation Flow**:
  1. Get receipt's inward quantity
  2. Query ALL deliveries for that receipt
  3. Sum delivered quantities (excluding current delivery if editing)
  4. Calculate remaining: `inwardQuantity - totalDelivered`
  5. Validate attempted quantity against actual remaining
- **Benefits**:
  - Accurate even if manual database changes were made
  - Handles edit scenarios correctly (excludes current delivery from calculation)
  - Prevents over-delivery with real-time checks
  - Debug logging shows calculation breakdown
- **Receipt Editing**:
  - When editing receipts with existing deliveries, consider preventing field changes that would invalidate deliveries

### Referential Integrity ✅ COMPREHENSIVE
- **New Service**: `ReferentialIntegrityService` (`lib/services/referential_integrity_service.dart`)
  - Provides comprehensive integrity checks across ALL collections
  - Supports CASCADE UPDATE operations (automatically update all references when renaming)
  - Supports CASCADE DELETE operations (delete related records together)
  - Returns detailed usage reports with affected collection counts
- **Enhanced Checks**:
  - Cold storage checks now include BOTH receipts AND deliveries
  - All checks use Firestore `.count()` for better performance
  - Detailed reports available via `getDetailedUsage()` method
- **Cascade Operations**:
  - `cascadeUpdateColdStorage()` - Updates receipts AND deliveries
  - `cascadeUpdateProduct()` - Updates all receipts
  - `cascadeUpdateBrand()` - Updates all receipts
  - `cascadeUpdateCompany()` - Updates all receipts
  - `cascadeDeleteReceipt()` - Deletes receipt AND all related deliveries
- **Usage in Master Screens**:
  - Brand master screen now uses CASCADE UPDATE (see `brand_master_screen.dart:104`)
  - When renaming a brand, all receipts automatically update
  - Same pattern should be applied to other master screens (product, cold storage, company)

## Future Considerations

- Consider adding Firebase Security Rules documentation (currently assumed to allow authenticated access)
- Integration tests could be added using Firebase Emulators
- State management library (Riverpod/Provider) could simplify complex state
- Implement offline-first strategy with local conflict resolution
- Add user roles/permissions system if multi-tenant support needed
