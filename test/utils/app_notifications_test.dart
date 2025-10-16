// test/utils/app_notifications_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cold_storage/utils/app_notifications.dart';

void main() {
  group('App Notifications Tests', () {
    testWidgets('NotificationType enum has all expected values', (tester) async {
      expect(NotificationType.values.length, 4);
      expect(NotificationType.values, contains(NotificationType.success));
      expect(NotificationType.values, contains(NotificationType.error));
      expect(NotificationType.values, contains(NotificationType.info));
      expect(NotificationType.values, contains(NotificationType.warning));
    });

    testWidgets('showAppNotification displays success notification',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAppNotification(
                      context: context,
                      message: 'Success message',
                      type: NotificationType.success,
                    );
                  },
                  child: const Text('Show Notification'),
                );
              },
            ),
          ),
        ),
      );

      // Tap the button to show notification
      await tester.tap(find.text('Show Notification'));
      await tester.pump();

      // Wait for animation
      await tester.pump(const Duration(milliseconds: 100));

      // Verify notification message is displayed
      expect(find.text('Success message'), findsOneWidget);
    });

    testWidgets('showAppNotification displays error notification',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAppNotification(
                      context: context,
                      message: 'Error message',
                      type: NotificationType.error,
                    );
                  },
                  child: const Text('Show Error'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Error message'), findsOneWidget);
    });

    testWidgets('showAppNotification displays info notification',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAppNotification(
                      context: context,
                      message: 'Info message',
                      type: NotificationType.info,
                    );
                  },
                  child: const Text('Show Info'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Info'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Info message'), findsOneWidget);
    });

    testWidgets('showAppNotification displays warning notification',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAppNotification(
                      context: context,
                      message: 'Warning message',
                      type: NotificationType.warning,
                    );
                  },
                  child: const Text('Show Warning'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Warning'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Warning message'), findsOneWidget);
    });

    testWidgets('showAppNotification handles long messages', (tester) async {
      const longMessage = 'This is a very long notification message that '
          'contains multiple lines of text to test how the notification '
          'handles lengthy content properly.';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAppNotification(
                      context: context,
                      message: longMessage,
                      type: NotificationType.info,
                    );
                  },
                  child: const Text('Show Long Message'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Long Message'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(longMessage), findsOneWidget);
    });

    testWidgets('showAppNotification handles special characters',
        (tester) async {
      const specialMessage = 'Special chars: @#\$%^&*()_+-=[]{}|;:,.<>?/~`';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAppNotification(
                      context: context,
                      message: specialMessage,
                      type: NotificationType.success,
                    );
                  },
                  child: const Text('Show Special'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Special'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(specialMessage), findsOneWidget);
    });
  });
}
