import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/ai_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBridgeDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempBridgeDir = Directory.systemTemp.createTempSync('ai_bridge_ending_inst_test_dir');
    AiBridgeService.instance.testDirPath = tempBridgeDir.path;
    AiBridgeService.instance.testFilePath = '${tempBridgeDir.path}/tasks.json';
    AiBridgeService.instance.forceDiskSaveInTests = true;
  });

  tearDown(() {
    AiBridgeService.instance.forceDiskSaveInTests = false;
    AiBridgeService.instance.testDirPath = '.ai_bridge';
    AiBridgeService.instance.testFilePath = '.ai_bridge/tasks.json';
    if (tempBridgeDir.existsSync()) {
      tempBridgeDir.deleteSync(recursive: true);
    }
  });

  test('Ending Instructions Helper is correctly saved and loaded in preferences', () async {
    final service = AiBridgeService.instance;
    await service.init();

    // Verify updating instructions saves them
    await service.updateInstructions(
      'Primary Directives',
      'Master Directives',
      'Quick Instructions',
      'Preview Mode',
      'Preview Approved',
      'Preview Rejected',
      'System Hooks',
      'Missing Files',
      'Sync Error',
      'CUSTOM ENDING INSTRUCTIONS HELPER',
    );

    expect(service.endingInstructions, equals('CUSTOM ENDING INSTRUCTIONS HELPER'));

    // Check that it wrote the file correctly and serialized endingInstructions
    final file = File('${tempBridgeDir.path}/tasks.json');
    expect(await file.exists(), isTrue);

    final contents = await file.readAsString();
    final json = jsonDecode(contents) as Map<String, dynamic>;
    expect(json['endingInstructions'], equals('CUSTOM ENDING INSTRUCTIONS HELPER'));

    // Re-init the service to load from file and verify it restores endingInstructions
    final service2 = AiBridgeService.instance;
    await service2.init();
    expect(service2.endingInstructions, equals('CUSTOM ENDING INSTRUCTIONS HELPER'));
  });

  test('buildTaskPrompt appends the Ending Instructions Helper correctly at the end of the prompt', () async {
    final service = AiBridgeService.instance;
    await service.init();

    await service.updateInstructions(
      'Primary', 'Master', 'Quick', 'Preview', 'Approved', 'Rejected', 'Hooks', 'Missing', 'Sync',
      'END_HELPER_STRING_12345',
    );

    final task = AiTask(
      id: 'test_task_prompt',
      name: 'Test Task Prompt',
      description: 'Task Description text',
      status: AiTaskStatus.open,
      isFolder: false,
      isWorksheet: false,
      isWorksheetVisible: true,
      isNote: false,
      isKnowledgeSummary: false,
      isRead: true,
      parentId: null,
      verificationCriteria: [
        AiVerificationCriteria(
          description: 'Task Criterion 1',
          goal: '',
          isVerified: false,
          status: AiVerificationStatus.none,
        ),
      ],
    );

    final prompt = await service.buildTaskPrompt(task);

    // Verify it contains the ending instruction helper
    expect(prompt, contains('END_HELPER_STRING_12345'));

    // Verify that the ending instruction helper is positioned at the end of the prompt,
    // right before the closing '---'
    final lines = prompt.trim().split('\n');
    expect(lines.length, greaterThan(2));
    expect(lines[lines.length - 1], equals('---'));
    expect(lines[lines.length - 2], equals('END_HELPER_STRING_12345'));
  });
}
