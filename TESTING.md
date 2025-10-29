# Cold Storage App - Testing Guide

## Overview

This document describes the testing strategy and how to run tests for the Cold Storage Management App.

## Test Structure

```
test/
├── test_utils.dart              # Test utilities and helpers
├── utils/
│   └── date_input_formatter_test.dart  # Date formatter tests
├── screens/
│   ├── dashboard_screen_test.dart      # Dashboard widget tests
│   └── ...                      # Other screen tests
└── widget_test.dart             # Default widget test
```

## Prerequisites

### 1. Firebase Emulators

The app uses Firebase emulators for testing to avoid affecting production data.

**Install Firebase CLI:**
```bash
npm install -g firebase-tools
```

**Initialize Emulators:**
```bash
firebase init emulators
```

Select:
- Authentication Emulator
- Firestore Emulator
- Functions Emulator (optional)

**Start Emulators:**
```bash
firebase emulators:start
```

Emulator ports (configured in `firebase.json`):
- Firestore: 8080
- Auth: 9099
- UI: 4000

## Running Tests

### Run All Tests
```bash
flutter test
```

### Run Specific Test File
```bash
flutter test test/utils/date_input_formatter_test.dart
```

### Run Tests with Coverage
```bash
flutter test --coverage
```

View coverage report:
```bash
genhtml coverage/lcov.info -o coverage/html
start coverage/html/index.html  # Windows
open coverage/html/index.html    # macOS
```

### Run Tests in Watch Mode
```bash
flutter test --watch
```

## Test Categories

### 1. Unit Tests

**Date Input Formatter** (`test/utils/date_input_formatter_test.dart`)
- ✅ Formats 6 digits (DDMMYY) to DD-MM-YY
- ✅ Formats 8 digits (DDMMYYYY) to DD-MM-YYYY
- ✅ Auto-adds hyphens after day and month
- ✅ Validates date ranges (day 1-31, month 1-12)
- ✅ Detects invalid dates (Feb 30, etc.)
- ✅ Handles leap years correctly
- ✅ Parses formatted strings to DateTime
- ✅ Interprets 2-digit years (00-30 = 2000s, 31-99 = 1900s)

### 2. Widget Tests

**Dashboard Screen** (`test/screens/dashboard_screen_test.dart`)
- ✅ Renders dashboard title
- ✅ Displays quick action cards
- ✅ Shows navigation drawer
- ✅ Has centered layout on wide screens (>1000px)
- ✅ Responsive on mobile screens (375x667)
- ✅ Responsive on tablet screens (768x1024)
- ✅ Responsive on desktop screens (1920x1080)
- ✅ Quick action cards are tappable

## Responsive Testing

The app is tested at multiple screen sizes to ensure responsive design:

- **Mobile**: 375x667 (iPhone SE)
- **Tablet**: 768x1024 (iPad)
- **Desktop**: 1920x1080 (Full HD)
- **Wide**: 2560x1440 (2K)

### Centered Layout Requirements

All main screens should be centered on wide screens using:
```dart
Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 800-1200),
    child: // screen content
  ),
)
```

Verified screens:
- ✅ Dashboard (maxWidth: 1000)
- ✅ Receipt List (maxWidth: 1100)
- ✅ Receipt Entry (maxWidth: 700)
- ✅ Delivery Entry (maxWidth: 700)
- ✅ Delivery History (maxWidth: 1200)
- ✅ Billing Checker (maxWidth: 1000)
- ✅ Reports (maxWidth: 1100)
- ✅ Data Maintenance (maxWidth: 800)

## Test Utilities

### TestUtils Class

Provides helpers for Firebase emulator testing:

```dart
// Initialize Firebase with emulators
await TestUtils.initializeFirebase();

// Clear all Firestore data
await TestUtils.clearFirestore();

// Sign in test user
final user = await TestUtils.signInTestUser();

// Seed test data
await TestUtils.seedTestData();

// Pump widget with MaterialApp wrapper
await TestUtils.pumpAndSettle(tester, MyWidget());
```

### Test Screen Sizes

```dart
TestScreenSizes.mobile   // 375x667
TestScreenSizes.tablet   // 768x1024
TestScreenSizes.desktop  // 1920x1080
TestScreenSizes.wide     // 2560x1440
```

### Testing at Different Sizes

```dart
await testAtScreenSize(
  tester,
  MyWidget(),
  TestScreenSizes.desktop,
  'Desktop view',
  () async {
    // Test expectations
    expect(find.byType(ConstrainedBox), findsOneWidget);
  },
);
```

## Continuous Integration

### GitHub Actions (Recommended)

Create `.github/workflows/test.yml`:

```yaml
name: Flutter Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.8.1'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v2
        with:
          files: ./coverage/lcov.info
```

## Test Data

### Seeded Test Data

When running tests with emulators, the following test data is seeded:

**Cold Storages:**
- Test Storage 1
- Test Storage 2

**Products:**
- Test Product 1 (50kg)
- Test Product 2 (25kg)

**Brands:**
- Test Brand 1
- Test Brand 2

**Companies:**
- Test Company 1
- Test Company 2

**Test Receipt:**
- Receipt Number: RCP001
- Storage: Test Storage 1
- Product: Test Product 1
- Quantity: 100
- Status: Unpaid

## Troubleshooting

### Emulators Not Running

Error: `FirebaseException: Failed to get document`

**Solution:**
```bash
firebase emulators:start
```

### Port Already in Use

Error: `Port 8080 is already in use`

**Solution:**
```bash
# Find and kill process
netstat -ano | findstr :8080  # Windows
lsof -i :8080                  # macOS/Linux
```

Or change ports in `firebase.json`.

### Tests Timing Out

If tests are slow or timing out:

```dart
testWidgets('my test', (tester) async {
  // Increase timeout
}, timeout: const Timeout(Duration(seconds: 30)));
```

### Widget Not Found

If `find.byType()` or `find.text()` fails:

```dart
// Debug widget tree
debugDumpApp();

// Or print all widgets
tester.allWidgets.forEach(print);
```

## Best Practices

1. **Always use emulators for tests** - Never test against production Firebase
2. **Clear data between tests** - Use `TestUtils.clearFirestore()`
3. **Test responsive layouts** - Verify at multiple screen sizes
4. **Mock external dependencies** - Don't make real API calls
5. **Keep tests isolated** - Each test should be independent
6. **Use descriptive test names** - Clearly state what's being tested
7. **Test edge cases** - Not just happy paths

## Coverage Goals

- **Unit Tests**: >90% coverage for utilities and services
- **Widget Tests**: All major screens and flows
- **Integration Tests**: Critical user journeys

## Future Improvements

- [ ] Add integration tests for complete user flows
- [ ] Add performance tests for large datasets
- [ ] Add accessibility tests
- [ ] Add golden file tests for UI consistency
- [ ] Set up automated test runs on PR
- [ ] Add test coverage reporting to PR comments
