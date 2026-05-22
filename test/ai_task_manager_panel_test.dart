import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/ai_bridge_service.dart';
import 'package:music_app/screens/visual_editor/panels/ai_task_manager_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiTaskManagerPanel Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AiBridgeService.instance.isSyncErrorDetected = false;
      AiBridgeService.instance.tasks.clear();
    });

    testWidgets('Renders the AI Task Manager Panel and verifies sync error banner display/unstick flow', (WidgetTester tester) async {
      // 1. Set larger screen size to avoid layout overflows in test
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 2. Pump the widget with sync error set to false initially
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiTaskManagerPanel(
              isDocked: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify settings button is visible
      expect(find.byTooltip('Prompt Helper Settings'), findsOneWidget);

      // Verify that sync error banner is NOT visible initially
      expect(find.text('AI BRIDGE SYNC ERROR DETECTED'), findsNothing);

      // 3. Trigger sync error state in the service
      AiBridgeService.instance.isSyncErrorDetected = true;
      
      // Pump to reflect the state change in UI
      await tester.pump();

      // Verify that the sync error banner is now visible
      expect(find.text('AI BRIDGE SYNC ERROR DETECTED'), findsOneWidget);
      expect(find.text('UNSTICK BRIDGE'), findsOneWidget);

      // 4. Tap the UNSTICK BRIDGE button to trigger recovery phrase flow
      await tester.tap(find.text('UNSTICK BRIDGE'));
      await tester.pumpAndSettle();

      // Verify that the sync error flag is reset to false
      expect(AiBridgeService.instance.isSyncErrorDetected, isFalse);

      // Verify that the banner is dismissed
      expect(find.text('AI BRIDGE SYNC ERROR DETECTED'), findsNothing);
    });
  });
}
