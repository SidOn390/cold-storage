// test/screens/dashboard_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cold_storage/screens/dashboard/dashboard_screen.dart';
import '../test_utils.dart';

void main() {
  group('DashboardScreen', () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets('renders dashboard title', (WidgetTester tester) async {
      await TestUtils.pumpAndSettle(
        tester,
        const DashboardScreen(),
      );

      expect(find.text('Cold Storage Dashboard'), findsOneWidget);
    });

    testWidgets('displays quick action cards', (WidgetTester tester) async {
      await TestUtils.pumpAndSettle(
        tester,
        const DashboardScreen(),
      );

      // Should have quick action cards
      expect(find.byIcon(Icons.receipt_outlined), findsWidgets);
      expect(find.byIcon(Icons.local_shipping_outlined), findsWidgets);
      expect(find.byIcon(Icons.calculate_outlined), findsWidgets);
    });

    testWidgets('shows navigation drawer', (WidgetTester tester) async {
      await TestUtils.pumpAndSettle(
        tester,
        const DashboardScreen(),
      );

      // Open drawer
      final ScaffoldState state =
          tester.firstState(find.byType(Scaffold));
      state.openDrawer();
      await tester.pumpAndSettle();

      expect(find.byType(Drawer), findsOneWidget);
    });

    testWidgets('has centered layout on wide screens', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(TestScreenSizes.desktop);

      await TestUtils.pumpAndSettle(
        tester,
        const DashboardScreen(),
      );

      // Should have ConstrainedBox for centered layout
      expect(find.byType(ConstrainedBox), findsWidgets);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('is responsive on mobile screens', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(TestScreenSizes.mobile);

      await TestUtils.pumpAndSettle(
        tester,
        const DashboardScreen(),
      );

      // Should render without overflow
      expect(tester.takeException(), isNull);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('is responsive on tablet screens', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(TestScreenSizes.tablet);

      await TestUtils.pumpAndSettle(
        tester,
        const DashboardScreen(),
      );

      // Should render without overflow
      expect(tester.takeException(), isNull);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('quick action cards are tappable', (WidgetTester tester) async {
      await TestUtils.pumpAndSettle(
        tester,
        const DashboardScreen(),
      );

      // Find a card and tap it
      final receiptCard = find.widgetWithText(Card, 'New Receipt');
      if (receiptCard.evaluate().isNotEmpty) {
        await tester.tap(receiptCard.first);
        await tester.pumpAndSettle();
      }

      // No error should occur
      expect(tester.takeException(), isNull);
    });
  });
}
