import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:antigravity_sdk/antigravity_sdk.dart';
import 'package:music_app/services/ai_bridge_service.dart';
import 'package:music_app/services/antigravity_status_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBridgeDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempBridgeDir = Directory.systemTemp.createTempSync('ai_bridge_git_test_dir');
    
    // Trigger constructor so that background _initClient runs
    final service = AiBridgeService.instance;
    service.testDirPath = tempBridgeDir.path;
    service.testFilePath = '${tempBridgeDir.path}/tasks.json';
    
    // Write an empty valid tasks list structure to the temp tasks file
    File('${tempBridgeDir.path}/tasks.json').writeAsStringSync('{"tasks":[],"primaryDirectives":""}');

    // Wait for the constructor's async initialization to finish completely
    await Future.delayed(const Duration(milliseconds: 500));

    service.stepIndexAtDispatch = null;
    service.promptDispatchedAt = null;
    service.isPromptDispatched = false;
    AntigravityStatusService.instance.statusFilePath = '${tempBridgeDir.path}/agent_status.txt';
    AntigravityStatusService.instance.resetState();
  });

  tearDown(() {
    final debugFile = File('${tempBridgeDir.path}/bridge_error_debug.txt');
    if (debugFile.existsSync()) {
      print('DEBUG FILE CONTENTS:');
      print(debugFile.readAsStringSync());
    }
    AiBridgeService.instance.testDirPath = '.ai_bridge';
    AiBridgeService.instance.testFilePath = '.ai_bridge/tasks.json';
    AiBridgeService.instance.stepIndexAtDispatch = null;
    AiBridgeService.instance.promptDispatchedAt = null;
    AiBridgeService.instance.isPromptDispatched = false;
    AntigravityStatusService.instance.statusFilePath = '.ai_bridge/agent_status.txt';
    AntigravityStatusService.instance.resetState();
    if (tempBridgeDir.existsSync()) {
      tempBridgeDir.deleteSync(recursive: true);
    }
  });

  test('forceDispatchGitPushError adds error task, puts at front, and queues rejection prompt', () async {
    final service = AiBridgeService.instance;

    final mockClient = MockAntigravityClient();
    final originalClient = service.antigravityClient;
    service.antigravityClient = mockClient;

    try {
      // Clear existing tasks
      service.tasks.clear();

      // Call forceDispatchGitPushError
      const testError = 'Git push failed: origin Rejected due to secrets scanning';
      await service.forceDispatchGitPushError(testError);

      // Verify task is added
      final pushErrorTasks = service.tasks.where((t) => t.name.toLowerCase() == 'fix git push errors').toList();
      expect(pushErrorTasks.length, equals(1));
      final task = pushErrorTasks.first;

      expect(task.description, contains('The recent attempt to push committed changes to the remote repository failed.'));
      expect(task.notes, equals(testError));

      // Verify bridge_error.txt is written
      final errFile = File('${tempBridgeDir.path}/bridge_error.txt');
      expect(errFile.existsSync(), isTrue);
      expect(errFile.readAsStringSync(), equals(testError));

      // Verify prompt is queued/sent
      expect(mockClient.sentPrompts.isNotEmpty, isTrue);
      final sentText = mockClient.sentPrompts.first;
      expect(sentText, contains('Fix git push errors'));
    } finally {
      service.antigravityClient = originalClient;
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

  @override
  Future<SubagentConnection> invokeSubagent(Map<String, dynamic> context) async {
    final taskId = context['id'] ?? 'unknown_task';
    sentPrompts.add('Fix git push errors: ${context['name'] ?? ''}');
    final connection = SubagentConnection(
      taskId: taskId,
      agentId: 'mock_agent',
    );
    Future.microtask(() {
      connection.updateStatus('Completed');
    });
    return connection;
  }
}
