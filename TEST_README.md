# Testing Guide for Cold Storage App

This document explains how to run automated tests for the Cold Storage Management App using Firebase Emulators.

## Prerequisites

1. **Firebase CLI** installed
   ```bash
   npm install -g firebase-tools
   ```

2. **Java Runtime** (required for Firestore emulator)
   - Download from: https://www.java.com/download/

3. **Flutter** installed and configured

## Test Types

### 1. Unit Tests (`test/rent_calculation_test.dart`)

Tests pure calculation logic without Firebase:
- 15-day increment calculations
- Monthly rent calculations
- Labour charge calculations
- Seasonal rent calculations
- GST calculations
- Edge cases

**Run:** `flutter test test/rent_calculation_test.dart`

### 2. Integration Tests (`test/rent_integration_test.dart`)

Tests complete workflows with Firebase Emulators:
- RentRateService with Firestore
- Complete bill generation flow
- Multiple deliveries handling
- Bill saving and retrieval
- Sequential bill number generation

**Run:** See "Running Integration Tests" below

## Running Tests

### Option 1: Using the Test Script (Windows)

Simply double-click: `test_with_emulators.bat`

This script will:
1. Start Firebase Emulators
2. Wait for initialization
3. Run all tests
4. Stop emulators

### Option 2: Manual Steps

#### Step 1: Start Firebase Emulators

```bash
firebase emulators:start --only firestore,auth
```

Wait until you see:
```
✔  All emulators ready!
┌─────────────┬────────────────┬─────────────────────────────────┐
│ Emulator    │ Host:Port      │ View in Emulator Suite          │
├─────────────┼────────────────┼─────────────────────────────────┤
│ Auth        │ localhost:9099 │ http://localhost:4000/auth      │
│ Firestore   │ localhost:8080 │ http://localhost:4000/firestore │
└─────────────┴────────────────┴─────────────────────────────────┘
```

#### Step 2: Run Tests (in another terminal)

Run all tests:
```bash
flutter test
```

Run specific test file:
```bash
flutter test test/rent_calculation_test.dart
flutter test test/rent_integration_test.dart
```

Run with verbose output:
```bash
flutter test --reporter expanded
```

#### Step 3: Stop Emulators

Press `Ctrl+C` in the emulator terminal, or:
```bash
firebase emulators:stop
```

## Test Configuration

### Emulator Ports (firebase.json)

- **Firestore:** localhost:8080
- **Authentication:** localhost:9099
- **Emulator UI:** http://localhost:4000

### Test Helper (`test/test_helper.dart`)

Provides utilities for:
- `setupFirebaseEmulators()` - Initialize Firebase with emulators
- `clearFirestoreData()` - Clean database between tests
- `signInTestUser()` - Create and sign in test user
- `addTestMasterData()` - Add test master data
- `addTestRentRate()` - Add test rent rates
- `addTestReceipt()` - Add test receipts
- `addTestDelivery()` - Add test deliveries

## Writing New Tests

### Example: Unit Test

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cold_storage/services/rent_calculation_service.dart';

void main() {
  test('Should calculate rent correctly', () {
    final service = RentCalculationService();
    final result = service.calculateMonthlyRent(
      quantity: 100,
      monthlyRatePerUnit: 10,
      rentalMonths: 1.5,
    );
    expect(result, 1500.0);
  });
}
```

### Example: Integration Test

```dart
import 'package:flutter_test/flutter_test.dart';
import 'test_helper.dart';

void main() {
  setUpAll(() async {
    await TestHelper.setupFirebaseEmulators();
  });

  setUp(() async {
    await TestHelper.clearFirestoreData();
    final user = await TestHelper.signInTestUser();
    await TestHelper.addTestUserDocument(uid: user.user!.uid);
  });

  test('Should save rent rate to Firestore', () async {
    // Your test code here
  });
}
```

## Troubleshooting

### Issue: "No Firebase App has been created"

**Solution:** Make sure you call `TestHelper.setupFirebaseEmulators()` in `setUpAll()`

### Issue: "Emulator connection refused"

**Solution:** Ensure emulators are running before running tests

### Issue: "Tests are slow"

**Solution:**
- Clear data only when needed
- Use `setUp()` instead of `setUpAll()` for data that changes
- Run specific test files instead of all tests

### Issue: "Java not found"

**Solution:** Install Java Runtime Environment (JRE) from https://www.java.com/download/

### Issue: "Port already in use"

**Solution:**
```bash
# Find and kill process using port 8080
netstat -ano | findstr :8080
taskkill /PID <process_id> /F
```

## Best Practices

1. **Isolation:** Clear data between tests using `clearFirestoreData()`
2. **Independence:** Each test should be runnable independently
3. **Fast:** Keep tests focused and avoid unnecessary waits
4. **Clear:** Use descriptive test names and organize with `group()`
5. **Comprehensive:** Test happy paths, edge cases, and error conditions

## Test Coverage

Current test coverage:

- ✅ **Unit Tests:** 22 tests covering all calculation methods
- ✅ **Integration Tests:** 9 tests covering complete workflows
- ✅ **Total:** 31 automated tests

### Areas Covered:
- Rent calculation logic (15-day increments)
- Monthly vs Seasonal rent types
- Labour charges
- GST calculations
- RentRateService CRUD operations
- Complete bill generation
- Multiple deliveries
- Bill persistence
- Bill number generation

## CI/CD Integration

To run tests in CI/CD pipeline:

```yaml
# Example GitHub Actions workflow
- name: Start Firebase Emulators
  run: firebase emulators:start --only firestore,auth &

- name: Wait for emulators
  run: sleep 10

- name: Run tests
  run: flutter test

- name: Stop emulators
  run: firebase emulators:stop
```

## Additional Resources

- [Firebase Emulator Suite Documentation](https://firebase.google.com/docs/emulator-suite)
- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Firestore Testing Guide](https://firebase.google.com/docs/emulator-suite/connect_firestore)
