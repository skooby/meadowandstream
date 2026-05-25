import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:music_app/services/ai_bridge_service.dart';
import 'package:music_app/state/global_task_editor_state.dart';
import 'package:music_app/screens/visual_editor/panels/global_task_editor_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Checklist Item Locking Tests', () {
    setUp(() async {
      dotenv.testLoad(fileInput: 'OPENAI_API_KEY=mock_key_for_testing');
    });

    testWidgets('Verification checklist items are locked when worked on by LLM', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Prepare target task with criteria
      final lockedCriteria = AiVerificationCriteria(
        description: 'Verify LLM lock feature is active',
        goal: 'Lock the UI inputs',
        status: AiVerificationStatus.none,
      );

      final unlockedCriteria = AiVerificationCriteria(
        description: 'Verify unlocked item is editable',
        goal: 'Keep inputs enabled',
        status: AiVerificationStatus.none,
      );

      final mockTask = AiTask(
        id: 'lock_test_task',
        name: 'Lock Test Task',
        description: 'A test task for testing checklist locking.',
        verificationCriteria: [lockedCriteria, unlockedCriteria],
      );

      // 2. Set active prompt targeting the locked criteria description (case-insensitive match)
      AiBridgeService.instance.tasks.clear();
      AiBridgeService.instance.tasks.add(mockTask);
      
      final activePrompt = QueuedPrompt(
        'Work on this item',
        true,
        ['lock_test_task'],
        targetCriteriaDescription: 'verify llm lock feature is active', // lowercase to test case insensitivity
      );
      
      // Store in SharedPreferences so init loads it correctly
      SharedPreferences.setMockInitialValues({
        'ai_bridge_active_prompt': jsonEncode(activePrompt.toJson()),
      });
      AiBridgeService.instance.activePrompt = activePrompt;

      GlobalTaskEditorState.instance.requestEdit(existingTask: mockTask);

      // 3. Pump the GlobalTaskEditorWindow widget
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: GlobalTaskEditorWindow(
              key: const ValueKey('task_editor_lock_test'),
              isDocked: true,
              onClose: () {},
            ),
          ),
        ),
      );

      // Pump frames individually because of the repeating animation inside ChecklistItemContainer
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 4. Verify ChecklistItemContainers borders & parameters are correct
      final itemContainers = find.byType(ChecklistItemContainer);
      expect(itemContainers, findsNWidgets(2));

      // Retrieve states or widget parameters
      final ChecklistItemContainer firstWidget = tester.widget<ChecklistItemContainer>(itemContainers.at(0));
      final ChecklistItemContainer secondWidget = tester.widget<ChecklistItemContainer>(itemContainers.at(1));

      expect(firstWidget.isLocked, isTrue, reason: 'First checklist item should be locked');
      expect(secondWidget.isLocked, isFalse, reason: 'Second checklist item should not be locked');

      // 5. Verify the fields are read-only / editable by inspecting the TextField widgets inside the TextFormFields
      final textFormFieldFinders = find.byType(TextFormField);
      expect(textFormFieldFinders, findsAtLeastNWidgets(2));

      // We search for TextFields inside the first checklist item and second checklist item
      final firstChecklistItemFinder = itemContainers.at(0);
      final secondChecklistItemFinder = itemContainers.at(1);

      // Find TextFormField for description inside the first checklist item
      final firstDescFormFieldFinder = find.descendant(
        of: firstChecklistItemFinder,
        matching: find.byWidgetPredicate((w) => w is TextFormField && w.controller?.text == 'Verify LLM lock feature is active'),
      );
      expect(firstDescFormFieldFinder, findsOneWidget);
      final firstInnerTextField = tester.widget<TextField>(find.descendant(of: firstDescFormFieldFinder, matching: find.byType(TextField)));
      expect(firstInnerTextField.readOnly, isTrue, reason: 'First checklist item description should be readOnly');

      // Find TextFormField for description inside the second checklist item
      final secondDescFormFieldFinder = find.descendant(
        of: secondChecklistItemFinder,
        matching: find.byWidgetPredicate((w) => w is TextFormField && w.controller?.text == 'Verify unlocked item is editable'),
      );
      expect(secondDescFormFieldFinder, findsOneWidget);
      final secondInnerTextField = tester.widget<TextField>(find.descendant(of: secondDescFormFieldFinder, matching: find.byType(TextField)));
      expect(secondInnerTextField.readOnly, isFalse, reason: 'Second checklist item description should not be readOnly');

      // 6. Verify drag indicator replacement with lock icon
      expect(find.byIcon(Icons.lock), findsOneWidget, reason: 'Locked item should display lock icon instead of drag handle');
      expect(find.byIcon(Icons.drag_indicator), findsOneWidget, reason: 'Unlocked item should display drag indicator');
    });
  });
}
