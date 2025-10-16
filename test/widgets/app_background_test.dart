// test/widgets/app_background_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cold_storage/widgets/app_background.dart';

void main() {
  group('AppBackground Widget Tests', () {
    testWidgets('AppBackground renders with child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppBackground(
              child: Text('Test Child'),
            ),
          ),
        ),
      );

      expect(find.text('Test Child'), findsOneWidget);
    });

    testWidgets('AppBackground renders Container as base', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppBackground(
              child: SizedBox.shrink(),
            ),
          ),
        ),
      );

      // AppBackground should contain a Container
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('AppBackground child is properly nested', (tester) async {
      const testKey = Key('test-child');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppBackground(
              child: Text('Nested Child', key: testKey),
            ),
          ),
        ),
      );

      final childWidget = tester.widget<Text>(find.byKey(testKey));
      expect(childWidget.data, 'Nested Child');
    });

    testWidgets('AppBackground works with complex child widgets',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppBackground(
              child: Column(
                children: [
                  const Text('Title'),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Button'),
                  ),
                  const TextField(
                    decoration: InputDecoration(labelText: 'Input'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Button'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('AppBackground maintains child widget state', (tester) async {
      int counter = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppBackground(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      Text('Count: $counter'),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            counter++;
                          });
                        },
                        child: const Text('Increment'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('AppBackground works with ListView child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppBackground(
              child: ListView(
                children: const [
                  ListTile(title: Text('Item 1')),
                  ListTile(title: Text('Item 2')),
                  ListTile(title: Text('Item 3')),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
    });

    testWidgets('AppBackground works with GridView child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppBackground(
              child: GridView.count(
                crossAxisCount: 2,
                children: const [
                  Card(child: Text('Grid 1')),
                  Card(child: Text('Grid 2')),
                  Card(child: Text('Grid 3')),
                  Card(child: Text('Grid 4')),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Grid 1'), findsOneWidget);
      expect(find.text('Grid 2'), findsOneWidget);
      expect(find.text('Grid 3'), findsOneWidget);
      expect(find.text('Grid 4'), findsOneWidget);
    });
  });
}
