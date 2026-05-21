import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/ai_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
    final newInstructions = 'Test recovery phrase for sync error';
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
        jsonEncode({'type': 'PLANNER_RESPONSE', 'step_index': 0}) + '\n'
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
        jsonEncode({'type': 'USER_INPUT', 'step_index': 0}) + '\n'
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
        jsonEncode({'type': 'PLANNER_RESPONSE', 'step_index': 0}) + '\n'
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
}
