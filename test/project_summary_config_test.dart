import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/ai_bridge_service.dart';
import 'package:music_app/services/local_ai_service.dart';
import 'package:flutter/material.dart';
import 'package:music_app/screens/visual_editor/panels/bridge_monitor_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBridgeDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'ai_tasks_delay_seconds': 0.0,
    });
    tempBridgeDir = Directory.systemTemp.createTempSync('project_summary_config_test_dir');
    AiBridgeService.instance.testDirPath = tempBridgeDir.path;
    AiBridgeService.instance.testFilePath = '${tempBridgeDir.path}/tasks.json';
    AiBridgeService.instance.setQueuePaused(false);
    AiBridgeService.instance.setBridgeMode(AntigravityBridgeMode.cli);
  });

  tearDown(() {
    AiBridgeService.instance.setDryRunMode(false);
    AiBridgeService.instance.testDirPath = '.ai_bridge';
    AiBridgeService.instance.testFilePath = '.ai_bridge/tasks.json';
    if (tempBridgeDir.existsSync()) {
      tempBridgeDir.deleteSync(recursive: true);
    }
  });

  test('SharedPreferences project_summary config persistence', () async {
    final prefs = await SharedPreferences.getInstance();

    // Verify initial state is null/unset
    expect(prefs.getString('project_summary'), isNull);

    // Save project_summary
    await prefs.setString('project_summary', '# My Project Summary\n- Task 1\n- Task 2');

    // Retrieve and verify
    final savedSummary = prefs.getString('project_summary');
    expect(savedSummary, '# My Project Summary\n- Task 1\n- Task 2');
  });

  test('PROJECT_SUMMARY.md file build logic', () async {
    final file = File('PROJECT_SUMMARY_TEST.md');
    if (file.existsSync()) {
      file.deleteSync();
    }

    try {
      final summaryText = '# Test Summary\n- Sub-task A';
      await file.writeAsString(summaryText);

      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), summaryText);
    } finally {
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  });

  test('sendToQueue replaces {SUMMARY} tag with absolute file:/// URI path', () async {
    final service = AiBridgeService.instance;
    await service.clearQueue();
    service.setDryRunMode(true);

    // Send a prompt containing {SUMMARY} tag to the queue
    await service.sendToQueue(
      'Check this project summary: {SUMMARY}',
      false,
    );

    // Verify it replaced it in simulatedActions queue logging
    final hasQueueAction = service.simulatedActions.any((a) {
      if (a.type == 'QUEUE') {
        final expectedLink = Uri.file(File('${service.bridgeDirPath}/project_summary.md').absolute.path).toString();
        return a.detail.contains(expectedLink) && !a.detail.contains('{SUMMARY}');
      }
      return false;
    });

    expect(hasQueueAction, isTrue, reason: '{SUMMARY} tag should be replaced with the absolute file URL in the queued prompt');
  });

  test('LocalAiService.generateText replaces {SUMMARY} tag with absolute file:/// URI path', () async {
    final service = LocalAiService.instance;
    try {
      await service.generateText('Check summary: {SUMMARY}');
    } catch (_) {
      // Ignore network errors/timeout
    }

    final expectedLink = Uri.file(File('${AiBridgeService.instance.bridgeDirPath}/project_summary.md').absolute.path).toString();
    expect(service.lastPromptSent, contains(expectedLink));
    expect(service.lastPromptSent, isNot(contains('{SUMMARY}')));
  });

  test('LocalAiService.sendChat replaces {SUMMARY} tag with absolute file:/// URI path', () async {
    final service = LocalAiService.instance;
    try {
      await service.sendChat([
        {'role': 'user', 'content': 'Please review: {SUMMARY}'}
      ]);
    } catch (_) {
      // Ignore network errors/timeout
    }

    final expectedLink = Uri.file(File('${AiBridgeService.instance.bridgeDirPath}/project_summary.md').absolute.path).toString();
    expect(service.lastPromptSent, contains(expectedLink));
    expect(service.lastPromptSent, isNot(contains('{SUMMARY}')));
  });

  testWidgets('AiAssistantTab send prompt works', (WidgetTester tester) async {
    final promptController = ScrollController();
    final outputController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiAssistantTab(
            lastPrompt: 'Hello Prompt',
            lastOutput: 'Hello Output',
            transcriptPath: '.ai_bridge/transcript.jsonl',
            promptScrollController: promptController,
            outputScrollController: outputController,
            isThinking: false,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Switch to AI Assistant Mode
    final toggleBtn = find.text('AI Assistant');
    expect(toggleBtn, findsOneWidget);
    await tester.tap(toggleBtn);
    await tester.pumpAndSettle();

    // Verify input fields
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    final sendButtonFinder = find.text('Send');
    expect(sendButtonFinder, findsOneWidget);

    // Input prompt and send
    await tester.enterText(textFieldFinder, 'Testing prompt send capability');
    await tester.pumpAndSettle();

    final TextField textField = tester.widget<TextField>(textFieldFinder);
    expect(textField.controller?.text, 'Testing prompt send capability');

    await tester.tap(sendButtonFinder);
    await tester.pumpAndSettle();

    // Verify it updates LocalAiService and retains prompt text in display
    expect(textField.controller?.text, 'Testing prompt send capability');
    expect(LocalAiService.instance.lastPromptSent, 'Testing prompt send capability');

    promptController.dispose();
    outputController.dispose();
  });
}
