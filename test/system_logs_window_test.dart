import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/screens/visual_editor/panels/system_logs_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SystemLogsWindow Pin and Transparency toggle test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    bool onCloseCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              SystemLogsWindow(
                onClose: () {
                  onCloseCalled = true;
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial state
    expect(SystemLogsWindow.isPinnedOnTopNotifier.value, isFalse);
    expect(onCloseCalled, isFalse);

    // Find Pin on Top button
    final pinButtonFinder = find.byTooltip('Pin on Top');
    expect(pinButtonFinder, findsOneWidget);

    // Tap Pin on Top button
    await tester.tap(pinButtonFinder);
    await tester.pumpAndSettle();

    // Verify state updated to pinned
    expect(SystemLogsWindow.isPinnedOnTopNotifier.value, isTrue);

    // Find Always on Top (Pinned) button
    final pinnedButtonFinder = find.byTooltip('Always on Top (Pinned)');
    expect(pinnedButtonFinder, findsOneWidget);

    // Find transparency button
    final opacityButtonFinder = find.byIcon(Icons.opacity);
    expect(opacityButtonFinder, findsOneWidget);

    // Tap it to cycle opacity
    await tester.tap(opacityButtonFinder);
    await tester.pumpAndSettle();

    // Tap it again
    await tester.tap(opacityButtonFinder);
    await tester.pumpAndSettle();
  });
}
