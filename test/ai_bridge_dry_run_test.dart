import 'dart:convert';
import 'dart:io';
import 'dart:async';
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
    tempBridgeDir = Directory.systemTemp.createTempSync('ai_bridge_dry_run_test_dir');
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

  test('AiBridgeService Simulated Dry Run Mode logs actions and simulates queue completion', () async {
    final service = AiBridgeService.instance;
    await service.clearQueue();
    service.setDryRunMode(true);
    expect(service.isDryRunMode, isTrue);
    expect(service.simulatedActions, isEmpty);

    // Simulate sending a prompt to the queue
    await service.sendToQueue(
      'SIMULATED PROMPT',
      false,
      taskIds: ['mock_task_id'],
    );

    // Verify simulated queue log actions
    expect(service.simulatedActions, isNotEmpty);
    final hasQueueAction = service.simulatedActions.any((a) => a.type == 'QUEUE' && a.detail.contains('SIMULATED PROMPT'));
    final hasMetadataAction = service.simulatedActions.any((a) => a.type == 'METADATA' && a.detail.contains('mock_task_id'));
    final hasQueueStatusAction = service.simulatedActions.any((a) => a.type == 'FILE_WRITE' && a.title.contains('queue_status.txt') && a.detail.contains('BUSY'));
    expect(hasQueueAction, isTrue);
    expect(hasMetadataAction, isTrue);
    expect(hasQueueStatusAction, isTrue);

    // Wait for the simulated completion callback to execute
    await Future.delayed(const Duration(milliseconds: 1100));

    // Verify simulation completed log actions and queue clearance
    final hasStateComp = service.simulatedActions.any((a) => a.type == 'STATE' && a.title.contains('Simulation Completed'));
    expect(hasStateComp, isTrue);

    final hasQueueStatusIdle = service.simulatedActions.any((a) => a.type == 'FILE_WRITE' && a.title.contains('queue_status.txt') && a.detail.contains('IDLE'));
    expect(hasQueueStatusIdle, isTrue);

    final hasHotRestartTriggered = service.simulatedActions.any((a) => a.type == 'UPDATE_TRIGGER' && a.title.contains('Trigger UpdateCoverType.hotRestart'));
    expect(hasHotRestartTriggered, isTrue);

    expect(service.activePrompt, isNull);
  });
}
