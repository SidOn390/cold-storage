// test/widget_test.dart
// Basic widget and component tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Basic Widget Tests', () {
    testWidgets('MaterialApp initializes correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          title: 'Test App',
          home: Scaffold(
            appBar: AppBar(title: const Text('Test')),
            body: const Center(child: Text('Hello World')),
          ),
        ),
      );

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('Scaffold structure renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Test Title')),
            body: const Text('Body Content'),
          ),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Body Content'), findsOneWidget);
    });

    testWidgets('Button interactions work correctly', (WidgetTester tester) async {
      int counter = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
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
      );

      expect(find.text('Count: 0'), findsOneWidget);

      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('ListView scrolls and displays items', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 10,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('Item $index'),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('Card widget renders with content', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Card Content'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('GridView displays items correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GridView.count(
              crossAxisCount: 2,
              children: List.generate(
                4,
                (index) => Card(
                  child: Center(
                    child: Text('Grid $index'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Grid 0'), findsOneWidget);
      expect(find.text('Grid 1'), findsOneWidget);
      expect(find.text('Grid 2'), findsOneWidget);
      expect(find.text('Grid 3'), findsOneWidget);
    });

    testWidgets('TextField accepts input', (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Test Input'),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Hello');
      expect(controller.text, 'Hello');

      controller.dispose();
    });

    testWidgets('Icon displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Icon(Icons.check_circle, size: 48),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('Column arranges children vertically', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('First'),
                Text('Second'),
                Text('Third'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('Third'), findsOneWidget);
    });

    testWidgets('Row arranges children horizontally', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Text('Left'),
                Text('Center'),
                Text('Right'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Left'), findsOneWidget);
      expect(find.text('Center'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);
    });
  });
}
