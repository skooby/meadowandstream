import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:antigravity_sdk/antigravity_sdk.dart';
import 'package:music_app/services/ai_bridge_service.dart';
import 'package:music_app/services/antigravity_status_service.dart';
import 'package:music_app/services/system_logs_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBridgeDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempBridgeDir = Directory.systemTemp.createTempSync('ai_bridge_test_dir');
    AiBridgeService.instance.testDirPath = tempBridgeDir.path;
    AiBridgeService.instance.stepIndexAtDispatch = null;
    AiBridgeService.instance.promptDispatchedAt = null;
    AiBridgeService.instance.isPromptDispatched = false;
    AntigravityStatusService.instance.statusFilePath = '${tempBridgeDir.path}/agent_status.txt';
    AntigravityStatusService.instance.resetState();
  });

  tearDown(() {
    AiBridgeService.instance.testDirPath = '.ai_bridge';
    AiBridgeService.instance.stepIndexAtDispatch = null;
    AiBridgeService.instance.promptDispatchedAt = null;
    AiBridgeService.instance.isPromptDispatched = false;
    AntigravityStatusService.instance.statusFilePath = '.ai_bridge/agent_status.txt';
    AntigravityStatusService.instance.resetState();
    if (tempBridgeDir.existsSync()) {
      tempBridgeDir.deleteSync(recursive: true);
    }
  });

  test('AI Bridge Sync Error detection state management and serialization', () async {
    final service = AiBridgeService.instance;
    
    // Initially false
    expect(service.isSyncErrorDetected, isFalse);

    // Can dismiss when false
    service.dismissSyncError();
    expect(service.isSyncErrorDetected, isFalse);

    // Verify default sync error instructions
    expect(service.syncErrorInstructions, contains('AI Bridge Sync Error:'));

    // Update instructions and verify they serialize/deserialize and update local state
    const newInstructions = 'Test recovery phrase for sync error';
    await service.updateInstructions(
      service.primaryDirectives,
      service.instructions,
      service.quickInstructions,
      service.previewModeInstructions,
      service.previewApprovedInstructions,
      service.previewRejectedInstructions,
      service.systemHooksInstructions,
      service.missingFilesInstructions,
      newInstructions,
    );

    expect(service.syncErrorInstructions, equals(newInstructions));
  });

  test('forceDispatchSyncError resets the detection flag', () async {
    final service = AiBridgeService.instance;

    // Set detection to true explicitly
    service.isSyncErrorDetected = true;
    expect(service.isSyncErrorDetected, isTrue);

    await service.forceDispatchSyncError();
    expect(service.isSyncErrorDetected, isFalse);
  });

  test('forceDispatchSyncError dispatches recovery phrase in CLI mode', () async {
    final service = AiBridgeService.instance;
    service.setBridgeMode(AntigravityBridgeMode.cli);

    final mockClient = MockAntigravityClient();
    final originalClient = service.antigravityClient;
    service.antigravityClient = mockClient;

    try {
      // Call forceDispatchSyncError
      await service.forceDispatchSyncError();

      // Verify recovery phrase is sent via the API client
      expect(mockClient.sentPrompts, contains(service.syncErrorInstructions));
    } finally {
      // Restore original client
      service.antigravityClient = originalClient;
      service.setBridgeMode(AntigravityBridgeMode.sdk);
    }
  });

  test('forceDispatchSyncError dispatches recovery phrase in SDK mode', () async {
    final service = AiBridgeService.instance;
    service.setBridgeMode(AntigravityBridgeMode.sdk);

    final mockClient = MockAntigravityClient();
    final originalClient = service.antigravityClient;
    service.antigravityClient = mockClient;

    try {
      // Call forceDispatchSyncError
      await service.forceDispatchSyncError();

      // Verify recovery phrase is sent via the API client
      expect(mockClient.sentPrompts, contains(service.syncErrorInstructions));
    } finally {
      // Restore original client
      service.antigravityClient = originalClient;
    }
  });

  test('checkForSyncError detects sync error when PLANNER_RESPONSE is the last step and elapsed time > 15s', () async {
    final service = AiBridgeService.instance;

    // Reset service state
    service.isSyncErrorDetected = false;
    service.activePrompt = QueuedPrompt('test prompt', false, []);
    service.isPromptDispatched = true;
    service.antigravityLastChangeObservedAt = DateTime.now().subtract(const Duration(seconds: 20));

    // Create a temporary directory for our mock brain
    final tempDir = Directory.systemTemp.createTempSync('ai_bridge_test_brain');
    try {
      // Create a mock transcript.jsonl inside it
      final transcriptFile = File('${tempDir.path}/transcript.jsonl');
      await transcriptFile.writeAsString(
        '${jsonEncode({'type': 'PLANNER_RESPONSE', 'step_index': 0})}\n'
      );

      // Run check with the custom brain directory
      await service.checkForSyncError(customBrainDir: tempDir, customNow: DateTime.now());

      // Should detect sync error
      expect(service.isSyncErrorDetected, isTrue);
    } finally {
      // Clean up local state
      service.activePrompt = null;
      service.isSyncErrorDetected = false;
      service.antigravityLastChangeObservedAt = null;
      
      // Clean up temporary files
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('checkForSyncError does not detect sync error if last step is not PLANNER_RESPONSE', () async {
    final service = AiBridgeService.instance;

    // Reset service state
    service.isSyncErrorDetected = false;
    service.activePrompt = QueuedPrompt('test prompt', false, []);
    service.isPromptDispatched = true;
    service.antigravityLastChangeObservedAt = DateTime.now().subtract(const Duration(seconds: 20));

    final tempDir = Directory.systemTemp.createTempSync('ai_bridge_test_brain_no_err');
    try {
      final transcriptFile = File('${tempDir.path}/transcript.jsonl');
      await transcriptFile.writeAsString(
        '${jsonEncode({'type': 'USER_INPUT', 'step_index': 0})}\n'
      );

      await service.checkForSyncError(customBrainDir: tempDir, customNow: DateTime.now());

      expect(service.isSyncErrorDetected, isFalse);
    } finally {
      // Clean up local state
      service.activePrompt = null;
      service.isSyncErrorDetected = false;
      service.antigravityLastChangeObservedAt = null;

      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('checkForSyncError does not detect sync error if elapsed time is 15 seconds or less', () async {
    final service = AiBridgeService.instance;

    // Reset service state
    service.isSyncErrorDetected = false;
    service.activePrompt = QueuedPrompt('test prompt', false, []);
    service.isPromptDispatched = true;
    service.antigravityLastChangeObservedAt = DateTime.now().subtract(const Duration(seconds: 10));

    final tempDir = Directory.systemTemp.createTempSync('ai_bridge_test_brain_short');
    try {
      final transcriptFile = File('${tempDir.path}/transcript.jsonl');
      await transcriptFile.writeAsString(
        '${jsonEncode({'type': 'PLANNER_RESPONSE', 'step_index': 0})}\n'
      );

      await service.checkForSyncError(customBrainDir: tempDir, customNow: DateTime.now());

      expect(service.isSyncErrorDetected, isFalse);
    } finally {
      // Clean up local state
      service.activePrompt = null;
      service.isSyncErrorDetected = false;
      service.antigravityLastChangeObservedAt = null;

      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('checkForSyncError does not detect sync error if prompt is not dispatched yet', () async {
    final service = AiBridgeService.instance;

    // Reset service state
    service.isSyncErrorDetected = false;
    service.activePrompt = QueuedPrompt('test prompt', false, []);
    service.isPromptDispatched = false; // Mock not dispatched yet
    service.antigravityLastChangeObservedAt = DateTime.now().subtract(const Duration(seconds: 20));

    final tempDir = Directory.systemTemp.createTempSync('ai_bridge_test_brain_not_disp');
    try {
      final transcriptFile = File('${tempDir.path}/transcript.jsonl');
      await transcriptFile.writeAsString(
        '${jsonEncode({'type': 'PLANNER_RESPONSE', 'step_index': 0})}\n'
      );

      await service.checkForSyncError(customBrainDir: tempDir, customNow: DateTime.now());

      // Should NOT detect sync error because it is not dispatched
      expect(service.isSyncErrorDetected, isFalse);
    } finally {
      // Clean up local state
      service.activePrompt = null;
      service.isSyncErrorDetected = false;
      service.antigravityLastChangeObservedAt = null;

      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('checkForSyncError does not detect sync error if agent status is BUSY', () async {
    final service = AiBridgeService.instance;

    // Reset service state
    service.isSyncErrorDetected = false;
    service.activePrompt = QueuedPrompt('test prompt', false, []);
    service.isPromptDispatched = true;
    service.antigravityLastChangeObservedAt = DateTime.now().subtract(const Duration(seconds: 20));

    // Create a mock agent_status.txt with 'BUSY'
    final statusFile = File('${tempBridgeDir.path}/agent_status.txt');
    await statusFile.writeAsString('BUSY');

    final tempDir = Directory.systemTemp.createTempSync('ai_bridge_test_brain_busy');
    try {
      final transcriptFile = File('${tempDir.path}/transcript.jsonl');
      await transcriptFile.writeAsString(
        '${jsonEncode({'type': 'PLANNER_RESPONSE', 'step_index': 0})}\n'
      );

      await service.checkForSyncError(customBrainDir: tempDir, customNow: DateTime.now());

      // Should NOT detect sync error because status is BUSY
      expect(service.isSyncErrorDetected, isFalse);
    } finally {
      // Clean up local state
      service.activePrompt = null;
      service.isSyncErrorDetected = false;
      service.antigravityLastChangeObservedAt = null;

      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('AntigravityStatusService getHttpBridgeStatus handles offline gracefully', () async {
    final status = await AntigravityStatusService.instance.getHttpBridgeStatus();
    expect(status, isNull);
  });

  test('AntigravityStatusService debug toggle works with SharedPreferences', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = AntigravityStatusService.instance;
    service.resetState();
    await prefs.setBool('antigravity_status_debug', true);

    final logs = <String>[];
    await runZoned(() async {
      await service.checkHttpBridgeBusy();
    }, zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        logs.add(line);
      },
    ));
    expect(logs.any((l) => l.contains('[AntigravityStatusService]')), isTrue);

    service.resetState();
    await prefs.setBool('antigravity_status_debug', false);
    logs.clear();
    await runZoned(() async {
      await service.checkHttpBridgeBusy();
    }, zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        logs.add(line);
      },
    ));
    expect(logs.any((l) => l.contains('[AntigravityStatusService]')), isFalse);
  });

  test('AntigravityStatusService enableStatusBridgeLogs config suppresses or permits logging with deduplication', () async {
    final logs = <String>[];
    final service = AntigravityStatusService.instance;
    service.resetState();
    
    // Test that logs are suppressed by default (when enableStatusBridgeLogs is false)
    await runZoned(() async {
      await service.checkHttpBridgeBusy();
    }, zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        logs.add(line);
      },
    ));
    expect(logs.any((l) => l.contains('[AntigravityStatusService]')), isFalse);
  });

  test('_processStatusChange ignores conversational text and transitions successfully', () async {
    final service = AiBridgeService.instance;
    service.isSyncErrorDetected = false;
    service.activePrompt = QueuedPrompt('test prompt', false, []);
    
    final tempDir = Directory.systemTemp.createTempSync('ai_bridge_test_brain_conv_ignore');
    service.testBrainDir = tempDir;

    try {
      final transcriptFile = File('${tempDir.path}/transcript.jsonl');
      await transcriptFile.writeAsString(
        '${jsonEncode({
          'source': 'MODEL',
          'type': 'PLANNER_RESPONSE',
          'content': 'I have completed the task and updated both files. Here is the summary of my work.'
        })}\n'
      );

      final statusFile = File('${tempBridgeDir.path}/agent_status.txt');
      await statusFile.writeAsString('PREVIEW');

      await service.processStatusChangeForTesting('PREVIEW');

      expect(service.isSyncErrorDetected, isFalse);
      expect(service.activePrompt, isNull);
    } finally {
      service.activePrompt = null;
      service.isSyncErrorDetected = false;
      service.testBrainDir = null;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('AntigravityStatusService isCliBusy recent age check prevents auto-recovery', () async {
    final statusFile = File('${tempBridgeDir.path}/agent_status.txt');
    await statusFile.writeAsString('BUSY');

    // Since it was modified just now, it is within 60 minutes and must return busy (true)
    // without triggering any auto-recovery to IDLE.
    final isBusy = await AntigravityStatusService.instance.isCliBusy();
    expect(isBusy, isTrue);
    expect(statusFile.readAsStringSync(), equals('BUSY'));
  });

  test('Determining busy state of ai bridge and writing status in tasks', () async {
    final statusFile = File('${tempBridgeDir.path}/agent_status.txt');
    await statusFile.writeAsString('BUSY');

    // 1. Determine busy state from AntigravityStatusService
    final isBusy = await AntigravityStatusService.instance.isCliBusy();
    expect(isBusy, isTrue);

    // 2. Mock sending to queue / status update to verify it writes status correctly
    final service = AiBridgeService.instance;
    await service.init();
    
    // Add a dummy task
    final task = await service.addTask('Test task busy state', 'description');
    expect(task.status, equals(AiTaskStatus.open));

    // Simulate sending task to bridge (updates status to inTesting)
    await service.updateTaskStatus(task.id, AiTaskStatus.inTesting);
    
    // Retrieve the updated task and check
    final updatedTask = service.tasks.firstWhere((t) => t.id == task.id);
    expect(updatedTask.status, equals(AiTaskStatus.inTesting));

    // Cleanup
    await service.deleteTask(task.id);
  });

  test('LogCategory.SYNC is used to log sync errors and actions to SystemLogsService', () async {
    final service = AiBridgeService.instance;
    SystemLogsService.instance.clearLogs();
    expect(SystemLogsService.instance.logs.where((l) => l.category == LogCategory.SYNC), isEmpty);

    // 1. Log on dismissSyncError
    service.dismissSyncError();
    var syncLogs = SystemLogsService.instance.logs.where((l) => l.category == LogCategory.SYNC).toList();
    expect(syncLogs, isNotEmpty);
    expect(syncLogs.first.message, contains('dismissed/cleared'));

    // 2. Log on forceDispatchSyncError
    SystemLogsService.instance.clearLogs();
    final mockClient = MockAntigravityClient();
    final originalClient = service.antigravityClient;
    service.antigravityClient = mockClient;

    try {
      await service.forceDispatchSyncError();
      syncLogs = SystemLogsService.instance.logs.where((l) => l.category == LogCategory.SYNC).toList();
      expect(syncLogs, isNotEmpty);
      expect(syncLogs.first.message, contains('Dispatched sync recovery prompt'));
    } finally {
      service.antigravityClient = originalClient;
    }
  });

  test('AntigravityStatusService isCliBusy recent age check prevents auto-recovery for intermediate ages (e.g. 30 minutes)', () async {
    final statusFile = File('${tempBridgeDir.path}/agent_status.txt');
    await statusFile.writeAsString('BUSY');

    // Simulate file modified 30 minutes ago
    final backThen = DateTime.now().subtract(const Duration(minutes: 30));
    await statusFile.setLastModified(backThen);

    // With 60 minutes threshold, it must still be considered busy (true)
    // and must NOT be auto-recovered to IDLE.
    final isBusy = await AntigravityStatusService.instance.isCliBusy();
    expect(isBusy, isTrue);
    expect(statusFile.readAsStringSync(), equals('BUSY'));
  });

  test('AiBridgeService isThinking detects recent activity even if agent_status.txt is IDLE', () {
    final service = AiBridgeService.instance;
    service.antigravityLastChangeObservedAtForTesting = null;
    service.setAntigravityBusyForTesting(false);

    // Initial state: not thinking
    expect(service.isThinking, isFalse);

    // Update last activity to 5 seconds ago
    service.antigravityLastChangeObservedAtForTesting = DateTime.now().subtract(const Duration(seconds: 5));
    expect(service.isThinking, isTrue);

    // Update last activity to 25 seconds ago (exceeding 20s threshold)
    service.antigravityLastChangeObservedAtForTesting = DateTime.now().subtract(const Duration(seconds: 25));
    expect(service.isThinking, isFalse);

    // Clean up
    service.antigravityLastChangeObservedAtForTesting = null;
  });

  test('AiBridgeService ignores CLI and SYNC log categories when scanning for runtime errors', () async {
    final service = AiBridgeService.instance;
    await service.init();
    
    // Simulate being in a thinking state so errors could be buffered
    service.antigravityLastChangeObservedAtForTesting = DateTime.now();
    expect(service.isThinking, isTrue);

    // Clear system logs and add a mock CLI log containing an exception/error
    SystemLogsService.instance.clearLogs();
    service.tasks.removeWhere((t) => t.name.toLowerCase().contains('fix runtime errors'));
    SystemLogsService.instance.addLog('TOOL ERROR: Exception: something broke', category: LogCategory.CLI);
    SystemLogsService.instance.addLog('AI Bridge Sync: Unhandled Exception: failed', category: LogCategory.SYNC);
    
    // Trigger log processing manually
    service.handleSystemLogsChangedForTesting();

    // Verify no tasks were spawned and no rejections queued
    final fixTasks = service.tasks.where((t) => t.name.toLowerCase().contains('fix runtime errors')).toList();
    expect(fixTasks, isEmpty);

    // Clean up
    service.antigravityLastChangeObservedAtForTesting = null;
  });

  test('_processStatusChange flags sync error when required files are missing after IDLE', () async {
    final service = AiBridgeService.instance;
    await service.init();
    service.isSyncErrorDetected = false;

    // Create a task and set active processing task ID
    final task = await service.addTask('Test missing files task', 'desc');
    service.activePrompt = QueuedPrompt('test prompt', false, [task.id]);
    service.activeProcessingTaskIdForTesting = task.id;

    final tempDir = Directory.systemTemp.createTempSync('ai_bridge_test_missing');
    service.testBrainDir = tempDir;

    try {
      // Mock a transcript where the MODEL response does NOT have bridge_notes and has no conversational text
      final transcriptFile = File('${tempDir.path}/transcript.jsonl');
      await transcriptFile.writeAsString(
        '${jsonEncode({
          'source': 'MODEL',
          'type': 'PLANNER_RESPONSE',
          'content': 'please send the block screen message.'
        })}\n'
      );

      final statusFile = File('${tempBridgeDir.path}/agent_status.txt');
      await statusFile.writeAsString('IDLE');

      // Run status change processing
      await service.processStatusChangeForTesting('IDLE');

      // It should flag a sync error because latest_notes.json (and tags) is missing
      expect(service.isSyncErrorDetected, isTrue);
      // It should revert agent_status.txt to BUSY
      expect(statusFile.readAsStringSync(), equals('BUSY'));
    } finally {
      // Cleanup
      service.activePrompt = null;
      service.activeProcessingTaskIdForTesting = null;
      service.isSyncErrorDetected = false;
      service.testBrainDir = null;
      await service.deleteTask(task.id);
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('clearQueue resets tasks in submitted status back to none', () async {
    final service = AiBridgeService.instance;
    final task = await service.addTask('Test Clear Queue Task', 'desc');
    final criteria = [
      AiVerificationCriteria(description: 'Criteria 1', status: AiVerificationStatus.submitted, goal: 'goal'),
      AiVerificationCriteria(description: 'Criteria 2', status: AiVerificationStatus.none, goal: 'goal'),
    ];
    await service.updateTaskDetails(task.id, task.name, task.description, verificationCriteria: criteria);

    await service.clearQueue();

    final updatedTask = service.tasks.firstWhere((t) => t.id == task.id);
    expect(updatedTask.verificationCriteria[0].status, equals(AiVerificationStatus.none));
    expect(updatedTask.verificationCriteria[1].status, equals(AiVerificationStatus.none));

    await service.deleteTask(task.id);
  });

  test('_processStatusChange only transitions targeted submitted criteria to pendingReview', () async {
    final service = AiBridgeService.instance;
    final task = await service.addTask('Test Targeted Ingestion Task', 'desc');
    final criteria = [
      AiVerificationCriteria(description: 'Item 1', status: AiVerificationStatus.submitted, goal: 'goal'),
      AiVerificationCriteria(description: 'Item 2', status: AiVerificationStatus.submitted, goal: 'goal'),
    ];
    await service.updateTaskDetails(task.id, task.name, task.description, verificationCriteria: criteria);

    // Mock active prompt targeting only "Item 1"
    service.activePrompt = QueuedPrompt('Prompt text', false, [task.id], targetCriteriaDescription: 'Item 1');
    service.activeProcessingTaskIdForTesting = task.id;

    // Mock transcript
    final tempDir = Directory('${Directory.systemTemp.path}/ai_bridge_test_dir_${DateTime.now().millisecondsSinceEpoch}');
    tempDir.createSync(recursive: true);
    service.testBrainDir = tempDir;

    final transcriptFile = File('${tempDir.path}/transcript.jsonl');
    await transcriptFile.writeAsString(
      '${jsonEncode({
        'source': 'MODEL',
        'type': 'PLANNER_RESPONSE',
        'content': '<bridge_notes>{"notes": "Item 1 completed", "summary": "Item 1 completed"}</bridge_notes>'
      })}\n'
    );

    // Create notes and verification files
    final notesFile = File('${service.testDirPath}/latest_notes.json');
    notesFile.writeAsStringSync('{"notes": "Item 1 completed", "summary": "Item 1 completed"}');
    final verificationFile = File('${service.testDirPath}/latest_verification.json');
    verificationFile.writeAsStringSync('[]');

    try {
      await service.processStatusChangeForTesting('IDLE');

      final updatedTask = service.tasks.firstWhere((t) => t.id == task.id);
      expect(updatedTask.verificationCriteria[0].status, equals(AiVerificationStatus.pendingReview));
      expect(updatedTask.verificationCriteria[1].status, equals(AiVerificationStatus.submitted));
    } finally {
      service.activePrompt = null;
      service.activeProcessingTaskIdForTesting = null;
      service.testBrainDir = null;
      if (notesFile.existsSync()) notesFile.deleteSync();
      if (verificationFile.existsSync()) verificationFile.deleteSync();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      await service.deleteTask(task.id);
    }
  });

  test('_processQueue dynamically compiles prompt at dispatch time', () async {
    final service = AiBridgeService.instance;
    final task = await service.addTask('Dynamic Prompt Task', 'Initial Task Desc');
    
    service.setBridgeMode(AntigravityBridgeMode.cli);

    try {
      // Set activePrompt to dummy to prevent immediate processing
      service.activePrompt = QueuedPrompt('dummy', false, []);

      // Queue our prompt
      await service.sendToQueue('# PRIMARY DIRECTIVES\nOld Statically Compiled Prompt', false, taskIds: [task.id]);

      // Change the task details in the DB after queuing
      await service.updateTaskDetails(task.id, 'Dynamic Prompt Task', 'Updated Task Desc');

      // Clear the dummy active prompt and reset busy state so processQueue executes
      service.activePrompt = null;
      service.isAntigravityBusyForTesting = false;

      // Trigger processQueue
      await service.processQueueForTesting();

      expect(service.activePrompt, isNotNull);
      expect(service.activePrompt!.text, contains('Updated Task Desc'));
      expect(service.activePrompt!.text, isNot(contains('Old Statically Compiled Prompt')));
    } finally {
      service.setBridgeMode(AntigravityBridgeMode.sdk);
      service.activePrompt = null;
      await service.deleteTask(task.id);
    }
  });

  test('active prompt states are persisted on save and restored on init, and BUSY is preserved if activePrompt is not null', () async {
    final service = AiBridgeService.instance;
    service.setBridgeMode(AntigravityBridgeMode.cli);

    try {
      final activePrompt = QueuedPrompt('Active Prompt Test Content', true, ['task-123'], targetCriteriaDescription: 'criteria-xyz');
      service.activePrompt = activePrompt;
      service.activeProcessingTaskIdForTesting = 'task-123';
      service.isPromptDispatched = true;

      await service.saveQueueStateForTesting();

      service.activePrompt = null;
      service.activeProcessingTaskIdForTesting = null;
      service.isPromptDispatched = false;

      expect(service.activePrompt, isNull);
      expect(service.activeProcessingTaskId, isNull);
      expect(service.isPromptDispatchedForTesting, isFalse);

      final statusFile = File('${service.testDirPath}/agent_status.txt');
      statusFile.writeAsStringSync('BUSY');

      await service.init();

      expect(service.activePrompt, isNotNull);
      expect(service.activePrompt!.text, equals('Active Prompt Test Content'));
      expect(service.activePrompt!.targetCriteriaDescription, equals('criteria-xyz'));
      expect(service.activeProcessingTaskId, equals('task-123'));
      expect(service.isPromptDispatchedForTesting, isTrue);

      expect(statusFile.readAsStringSync().trim().toUpperCase(), equals('BUSY'));

      await service.clearQueue();

      expect(service.activePrompt, isNull);
      expect(service.activeProcessingTaskId, isNull);
      expect(service.isPromptDispatchedForTesting, isFalse);
      expect(statusFile.readAsStringSync().trim().toUpperCase(), equals('IDLE'));
    } finally {
      service.setBridgeMode(AntigravityBridgeMode.sdk);
      service.activePrompt = null;
      service.activeProcessingTaskIdForTesting = null;
      service.isPromptDispatched = false;
    }
  });
}

class MockAntigravityClient extends AntigravityClient {
  final List<String> sentPrompts = [];

  MockAntigravityClient() : super.custom();

  @override
  Future<void> sendPrompt(String text) async {
    sentPrompts.add(text);
  }
}
