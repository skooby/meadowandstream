import 'dart:convert';
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

  test('AiBridgeService Simulated Dry Run Mode logs the same steps as live mode', () async {
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

    // --- Synchronous queue-entry steps (logged immediately in sendToQueue) ---
    expect(service.simulatedActions, isNotEmpty);
    final hasQueueAction = service.simulatedActions.any((a) => a.type == 'QUEUE' && a.detail.contains('SIMULATED PROMPT'));
    final hasMetadataAction = service.simulatedActions.any((a) => a.type == 'METADATA' && a.detail.contains('mock_task_id'));
    final hasQueueStatusBusy = service.simulatedActions.any((a) => a.type == 'FILE_WRITE' && a.title.contains('queue_status.txt') && a.detail.contains('BUSY'));
    expect(hasQueueAction, isTrue, reason: 'QUEUE action should be logged synchronously');
    expect(hasMetadataAction, isTrue, reason: 'METADATA action should be logged synchronously');
    expect(hasQueueStatusBusy, isTrue, reason: 'queue_status.txt BUSY should be logged synchronously');

    // Wait for async dispatch (_sendToAiAgent) + simulated agent output + _processStatusChange to run
    await Future.delayed(const Duration(milliseconds: 1500));

    // --- Dispatch-time steps (logged in _sendToAiAgent, async after sendToQueue) ---
    final hasDispatchLog = service.simulatedActions.any((a) => a.type == 'STATE' && a.title.contains('Dispatch Prompt'));
    final hasMacroLog = service.simulatedActions.any((a) => a.type == 'MACRO' && a.detail.contains('BridgeConnect'));
    final hasVbsLog = service.simulatedActions.any((a) => a.type == 'VBS_SCRIPT');
    final hasStatusBusy = service.simulatedActions.any((a) => a.type == 'STATUS_WRITE' && a.detail == 'BUSY');
    expect(hasDispatchLog, isTrue, reason: 'Dispatch Prompt STATE should be logged');
    expect(hasMacroLog, isTrue, reason: 'BridgeConnect MACRO should be logged');
    expect(hasVbsLog, isTrue, reason: 'VBS_SCRIPT should be logged');
    expect(hasStatusBusy, isTrue, reason: 'agent_status.txt BUSY should be logged');

    // --- Simulated agent output steps (dry-run only, stand-ins for real LLM file writes) ---
    final hasAgentNotes = service.simulatedActions.any((a) =>
        a.type == 'FILE_WRITE' && a.title.contains('Agent Output: latest_notes.json'));
    final hasAgentVerif = service.simulatedActions.any((a) =>
        a.type == 'FILE_WRITE' && a.title.contains('Agent Output: latest_verification.json'));
    final hasAgentIdle = service.simulatedActions.any((a) =>
        a.type == 'STATUS_WRITE' && a.title.contains('Agent Output: agent_status.txt') && a.detail == 'IDLE');
    expect(hasAgentNotes, isTrue, reason: 'Simulated agent notes write should be logged');
    expect(hasAgentVerif, isTrue, reason: 'Simulated agent verification write should be logged');
    expect(hasAgentIdle, isTrue, reason: 'Simulated agent IDLE status write should be logged');

    // --- _processStatusChange shared steps (identical in both modes) ---
    final hasDartAnalyzeLog = service.simulatedActions.any((a) =>
        a.type == 'STATE' && a.title.startsWith('Dart Analyze:'));
    final hasStatusIngestion = service.simulatedActions.any((a) =>
        a.type == 'STATE' && a.title.contains('Status Ingestion'));
    final hasIdleDetected = service.simulatedActions.any((a) =>
        a.type == 'STATE' && a.title.contains('IDLE Detected'));
    final hasAgentStatusConfirmed = service.simulatedActions.any((a) =>
        a.type == 'FILE_WRITE' && a.title == 'Write agent_status.txt' && a.detail == 'IDLE');
    final hasQueueStatusIdle = service.simulatedActions.any((a) =>
        a.type == 'FILE_WRITE' && a.title.contains('queue_status.txt') && a.detail == 'IDLE');
    final hasHotRestart = service.simulatedActions.any((a) =>
        a.type == 'UPDATE_TRIGGER' && a.title == 'Hot Restart');
    expect(hasDartAnalyzeLog, isTrue, reason: 'Dart Analyze STATE step should be logged');
    expect(hasStatusIngestion, isTrue, reason: 'Status Ingestion STATE should be logged');
    expect(hasIdleDetected, isTrue, reason: 'IDLE Detected STATE should be logged');
    expect(hasAgentStatusConfirmed, isTrue, reason: 'agent_status.txt IDLE FILE_WRITE should be logged');
    expect(hasQueueStatusIdle, isTrue, reason: 'queue_status.txt IDLE should be logged');
    expect(hasHotRestart, isTrue, reason: 'Hot Restart UPDATE_TRIGGER should be logged in both modes');

    // The real hot restart must NOT have been executed
    final hasRealHotRestartTriggered = service.simulatedActions.any((a) =>
        a.type == 'UPDATE_TRIGGER' && a.title.contains('Trigger UpdateCoverType.hotRestart'));
    expect(hasRealHotRestartTriggered, isFalse, reason: 'Real hot restart must not fire in dry-run mode');

    // Simulation-specific noise steps should be gone
    final hasOldSimComp = service.simulatedActions.any((a) => a.title == 'Simulation Completed');
    final hasOldVerifBuild = service.simulatedActions.any((a) => a.title == 'Simulation verif list build');
    final hasOldMatchingCriteria = service.simulatedActions.any((a) => a.title == 'Matching criteria');
    expect(hasOldSimComp, isFalse, reason: '"Simulation Completed" noise step should be removed');
    expect(hasOldVerifBuild, isFalse, reason: '"Simulation verif list build" noise step should be removed');
    expect(hasOldMatchingCriteria, isFalse, reason: '"Matching criteria" noise step should be removed');

    expect(service.activePrompt, isNull);
  });
}
