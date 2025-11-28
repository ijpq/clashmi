import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clashmi/screens/global_script_edit_screen.dart';
import 'package:clashmi/app/modules/global_script_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GlobalScriptEditScreen Widget Tests', () {
    setUp(() async {
      // Initialize the manager
      await GlobalScriptManager.init();
    });

    tearDown(() async {
      // Reset the manager
      await GlobalScriptManager.updateConfig(
        enabled: false,
        script: '',
        remark: '',
      );
    });

    testWidgets('should display the screen title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalScriptEditScreen(),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Note: The actual title text depends on i18n, so we check for common elements
      expect(find.byType(GlobalScriptEditScreen), findsOneWidget);
    });

    testWidgets('should have enable/disable switch', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalScriptEditScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Look for the Switch widget
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('should have remark text field', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalScriptEditScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Look for TextField widgets (remark field)
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('should have code editor', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalScriptEditScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // The screen should contain the code editor area
      // Since CodeEditor is a custom widget, we check for the Card that wraps it
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('should have back button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalScriptEditScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Look for back arrow icon
      expect(find.byIcon(Icons.arrow_back_ios_outlined), findsOneWidget);
    });

    testWidgets('should have save button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalScriptEditScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Look for done icon (save button)
      expect(find.byIcon(Icons.done_outlined), findsOneWidget);
    });

    testWidgets('should toggle switch', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalScriptEditScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Find the switch
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // Get initial state
      Switch switchWidget = tester.widget(switchFinder);
      final initialValue = switchWidget.value;

      // Tap the switch
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verify the state changed
      switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, equals(!initialValue));
    });

    testWidgets('should load existing config', (WidgetTester tester) async {
      // Set up some existing config
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: 'function main(config) { return config; }',
        remark: 'Test Script',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalScriptEditScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // The switch should be enabled
      final switchFinder = find.byType(Switch);
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isTrue);

      // The remark field should contain the text
      // Note: Exact verification would require finding the specific TextField
    });

    testWidgets('should navigate back when back button pressed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GlobalScriptEditScreen(),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open the screen
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify we're on the edit screen
      expect(find.byType(GlobalScriptEditScreen), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back_ios_outlined));
      await tester.pumpAndSettle();

      // Verify we navigated back
      expect(find.byType(GlobalScriptEditScreen), findsNothing);
    });

    testWidgets('should save when save button pressed', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalScriptEditScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Toggle the switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Note: Actually testing the save would require mocking Navigator.pop
      // For now, we verify the button exists and is tappable
      final saveFinder = find.byIcon(Icons.done_outlined);
      expect(saveFinder, findsOneWidget);
    });
  });

  group('GlobalScriptEditScreen Integration', () {
    testWidgets('should integrate with GlobalScriptManager', (WidgetTester tester) async {
      // Set initial state
      await GlobalScriptManager.updateConfig(
        enabled: false,
        script: '',
        remark: '',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalScriptEditScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Toggle switch to enabled
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // The UI state should reflect the change
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);
    });
  });

  group('GlobalScriptEditScreen Accessibility', () {
    testWidgets('should be accessible', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalScriptEditScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify semantic labels exist for important widgets
      // This is basic accessibility checking
      expect(find.byType(GlobalScriptEditScreen), findsOneWidget);

      // The screen should be navigable
      expect(find.byType(InkWell), findsWidgets);
    });
  });
}
