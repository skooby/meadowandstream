import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/ai_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBridgeDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempBridgeDir = Directory.systemTemp.createTempSync('ai_bridge_commit_name_test');
    
    final service = AiBridgeService.instance;
    service.testDirPath = tempBridgeDir.path;
    service.testFilePath = '${tempBridgeDir.path}/tasks.json';
    File('${tempBridgeDir.path}/tasks.json').writeAsStringSync('{"tasks":[],"primaryDirectives":""}');
    
    await Future.delayed(const Duration(milliseconds: 50));
  });

  tearDown(() {
    AiBridgeService.instance.testDirPath = '.ai_bridge';
    AiBridgeService.instance.testFilePath = '.ai_bridge/tasks.json';
    if (tempBridgeDir.existsSync()) {
      tempBridgeDir.deleteSync(recursive: true);
    }
  });

  test('generateCommitName formats name with summary and notes correctly', () {
    final service = AiBridgeService.instance;

    // Test task 1: only name
    final task1 = AiTask(id: '1', name: 'Task One', description: 'desc');
    expect(service.generateCommitName([task1]), equals('Task One'));

    // Test task 2: name and summary
    final task2 = AiTask(id: '2', name: 'Task Two', description: 'desc', summary: 'feat');
    expect(service.generateCommitName([task2]), equals('Task Two [feat]'));

    // Test task 3: name, summary, and notes
    final task3 = AiTask(id: '3', name: 'Task Three', description: 'desc', summary: 'fix', notes: 'added check');
    expect(service.generateCommitName([task3]), equals('Task Three [fix] (Note: added check)'));

    // Test task 4: name and notes (no summary)
    final task4 = AiTask(id: '4', name: 'Task Four', description: 'desc', notes: 'cleanup code');
    expect(service.generateCommitName([task4]), equals('Task Four (Note: cleanup code)'));

    // Test multiple tasks combined
    expect(service.generateCommitName([task2, task4]), equals('Task Two [feat] | Task Four (Note: cleanup code)'));
  });
}
