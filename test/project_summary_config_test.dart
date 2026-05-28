import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/ai_bridge_service.dart';

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
}
