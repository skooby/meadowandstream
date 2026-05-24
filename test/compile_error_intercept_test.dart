import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/ai_bridge_service.dart';
import 'package:music_app/services/antigravity_status_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBridgeDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempBridgeDir = Directory.systemTemp.createTempSync('ai_bridge_test_dir');
    AiBridgeService.instance.testDirPath = tempBridgeDir.path;
    AiBridgeService.instance.testFilePath = '${tempBridgeDir.path}/tasks.json';
    AntigravityStatusService.instance.statusFilePath = '${tempBridgeDir.path}/agent_status.txt';
    AntigravityStatusService.instance.resetState();
  });

  tearDown(() {
    AiBridgeService.instance.testDirPath = '.ai_bridge';
    AiBridgeService.instance.testFilePath = '.ai_bridge/tasks.json';
    AntigravityStatusService.instance.statusFilePath = '.ai_bridge/agent_status.txt';
    AntigravityStatusService.instance.resetState();
    if (tempBridgeDir.existsSync()) {
      tempBridgeDir.deleteSync(recursive: true);
    }
  });

  test('Compile error intercept adds a task named "Fix compile errors"', () async {
    // Access the instance to trigger internal constructor async initialization
    final service = AiBridgeService.instance;
    
    // Wait for the service's asynchronous initialization (_loadFromFile) to complete
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Now we can safely clear the tasks
    service.tasks.clear();
    
    expect(
      service.tasks.any((t) => t.name == 'Fix compile errors'),
      isFalse,
    );

    // Call forceDispatchCompileError to simulate compile error intercept
    await service.forceDispatchCompileError('Mock compiler syntax error');

    expect(
      service.tasks.any((t) => t.name == 'Fix compile errors'),
      isTrue,
    );
  });
}
