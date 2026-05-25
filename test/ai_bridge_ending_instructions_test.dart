import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/ai_bridge_service.dart';
import 'package:antigravity_sdk/antigravity_sdk.dart';

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

  test('invokeSubagent SDK prompt appends ending instructions helper', () async {
    final logs = <String>[];
    final client = AntigravityClient.custom(
      onLog: (msg) => logs.add(msg),
    );

    final context = {
      'id': 'test_subagent_prompt',
      'name': 'Test Subagent Prompt',
      'endingInstructions': 'SDK_END_HELPER_99999',
    };
    
    try {
      await client.invokeSubagent(context);
    } catch (_) {}
    
    await Future.delayed(const Duration(milliseconds: 100));

    final execLog = logs.firstWhere((l) => l.contains('Executing: agentapi new-conversation'), orElse: () => '');
    expect(execLog, contains('SDK_END_HELPER_99999'));
  });

  test('invokeSubagent SDK prompt fallback to tasks.json ending instructions', () async {
    final tempDir = Directory.systemTemp.createTempSync('sdk_fallback_test');
    final originalCwd = Directory.current;
    
    Directory.current = tempDir;
    
    Directory('.ai_bridge').createSync();
    File('.ai_bridge/tasks.json').writeAsStringSync(jsonEncode({
      'endingInstructions': 'FALLBACK_SDK_INSTRUCTIONS_8888',
      'tasks': []
    }));

    final logs = <String>[];
    final client = AntigravityClient.custom(
      onLog: (msg) => logs.add(msg),
    );

    final context = {
      'id': 'test_subagent_prompt',
      'name': 'Test Subagent Prompt',
    };
    try {
      await client.invokeSubagent(context);
    } catch (_) {}
    
    await Future.delayed(const Duration(milliseconds: 100));

    Directory.current = originalCwd;
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}

    final execLog = logs.firstWhere((l) => l.contains('Executing: agentapi new-conversation'), orElse: () => '');
    expect(execLog, contains('FALLBACK_SDK_INSTRUCTIONS_8888'));
  });

  test('buildTaskPrompt with replyTypeDirective and extraSuffix formats correctly', () async {
    final service = AiBridgeService.instance;
    await service.init();

    await service.updateInstructions(
      'Primary', 'Master', 'Quick', 'Preview', 'Approved', 'Rejected', 'Hooks', 'Missing', 'Sync',
      'ENDING_HELPER_999',
    );

    final task = AiTask(
      id: 'test_task_complex',
      name: 'Complex Task',
      description: 'Desc',
    );

    final prompt = await service.buildTaskPrompt(
      task,
      replyTypeDirective: 'VOICE_DIRECTIVE_123',
      extraSuffix: 'SUFFIX_FEEDBACK_456',
    );

    expect(prompt, contains('VOICE_DIRECTIVE_123'));
    expect(prompt, contains('SUFFIX_FEEDBACK_456'));
    expect(prompt, contains('ENDING_HELPER_999'));

    final lines = prompt.trim().split('\n');
    expect(lines.length, greaterThan(4));
    expect(lines[lines.length - 1], equals('---'));
    expect(lines[lines.length - 2], equals('ENDING_HELPER_999'));
    expect(lines[lines.length - 4], equals('SUFFIX_FEEDBACK_456'));
  });

  test('_processQueue parses replyTypeDirective and extraSuffix and places endingInstructions at the end', () async {
    final service = AiBridgeService.instance;
    await service.init();

    await service.updateInstructions(
      'Primary', 'Master', 'Quick', 'Preview', 'Approved', 'Rejected', 'Hooks', 'Missing', 'Sync',
      'ENDING_HELPER_999',
    );

    final task = AiTask(
      id: 'test_queue_parsing',
      name: 'Queue parsing test',
      description: 'Desc',
    );
    service.tasks.add(task);

    // Queue a prompt with directives and suffix
    final queuedText = '''
# PRIMARY DIRECTIVES
...
Voice: Custom voice here
Complexity: Concise override

# TASKS TO ADDRESS
Task: Queue parsing test

---
User Rejection Feedback:
Some user feedback details
''';

    final originalMode = service.bridgeMode;
    service.setBridgeMode(AntigravityBridgeMode.cli);
    service.setDryRunMode(true);
    service.forceDiskSaveInTests = true;

    try {
      await service.sendToQueue(queuedText, true, taskIds: [task.id]);

    // Retrieve the active/dispatched prompt from simulated run
    expect(service.activePrompt, isNotNull);
    final finalPrompt = service.activePrompt!.text;

    // Verify it contains the voice and complexity directives early
    expect(finalPrompt, contains('Voice: Custom voice here'));
    expect(finalPrompt, contains('Complexity: Concise override'));

    // Verify it contains the user feedback suffix
    expect(finalPrompt, contains('User Rejection Feedback:'));
    expect(finalPrompt, contains('Some user feedback details'));

    // Verify endingInstructions are at the absolute end (before ---)
    final lines = finalPrompt.trim().split('\n');
    expect(lines.length, greaterThan(3));
    expect(lines[lines.length - 1], equals('---'));
    expect(lines[lines.length - 2], equals('ENDING_HELPER_999'));

    } finally {
      service.setBridgeMode(originalMode);
      service.setDryRunMode(false);
      service.tasks.removeWhere((t) => t.id == 'test_queue_parsing');
    }
  });

  test('AiVerificationCriteria supports notes field in serialization, deserialization and prompt formatting', () async {
    final criteria = AiVerificationCriteria(
      description: 'Check notes capability',
      goal: 'Goal text',
      status: AiVerificationStatus.none,
      notes: 'Initial checklist notes',
    );

    // Serialization
    final jsonMap = criteria.toJson();
    expect(jsonMap['notes'], equals('Initial checklist notes'));

    // Deserialization
    final criteria2 = AiVerificationCriteria.fromJson(jsonMap);
    expect(criteria2.notes, equals('Initial checklist notes'));

    // Prompt Formatting
    final service = AiBridgeService.instance;
    await service.init();
    final task = AiTask(
      id: 'test_notes_task',
      name: 'Task with criteria notes',
      description: 'Checklist notes task description',
      verificationCriteria: [criteria2],
    );

    final prompt = await service.buildTaskPrompt(task);
    expect(prompt, contains('[Notes: Initial checklist notes]'));
  });

  test('AiBridgeService _readAsLinesWithRetry helper behaves correctly', () async {
    final service = AiBridgeService.instance;
    final tempFile = File('${tempBridgeDir.path}/test_retry_lines.txt');

    // Test successful read
    await tempFile.writeAsString('Line 1\nLine 2');
    final lines = await service.readAsLinesWithRetryForTesting(tempFile);
    expect(lines, equals(['Line 1', 'Line 2']));

    // Test failing retry throws when file does not exist
    final nonExistentFile = File('${tempBridgeDir.path}/non_existent_file.txt');
    expect(
      () => service.readAsLinesWithRetryForTesting(nonExistentFile, maxRetries: 2, delay: Duration.zero),
      throwsA(isA<FileSystemException>()),
    );
  });
}
