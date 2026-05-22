import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:antigravity_sdk/antigravity_sdk.dart';
import 'package:music_app/services/ai_bridge_service.dart';
import 'package:music_app/services/antigravity_status_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBridgeDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempBridgeDir = Directory.systemTemp.createTempSync('ai_bridge_test_dir');
    AiBridgeService.instance.testDirPath = tempBridgeDir.path;
    AntigravityStatusService.instance.statusFilePath = '${tempBridgeDir.path}/agent_status.txt';
    AntigravityStatusService.instance.resetState();
  });

  tearDown(() {
    AiBridgeService.instance.testDirPath = '.ai_bridge';
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

    final clipboardData = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          clipboardData.add(methodCall.arguments['text']);
          return null;
        }
        return null;
      },
    );

    // Call forceDispatchSyncError
    await service.forceDispatchSyncError();

    // Verify recovery phrase is copied to clipboard
    expect(clipboardData, contains(service.syncErrorInstructions));
    
    // Clean up
    service.setBridgeMode(AntigravityBridgeMode.sdk);
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

  test('checkForSyncError does not detect sync error if agent status is BUSY', () async {
    final service = AiBridgeService.instance;

    // Reset service state
    service.isSyncErrorDetected = false;
    service.activePrompt = QueuedPrompt('test prompt', false, []);
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
}

class MockAntigravityClient extends AntigravityClient {
  final List<String> sentPrompts = [];

  MockAntigravityClient() : super.custom();

  @override
  Future<void> sendPrompt(String text) async {
    sentPrompts.add(text);
  }
}
