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
    tempBridgeDir = Directory.systemTemp.createTempSync('ai_bridge_ignore_test_dir');
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

  test('isTaskOrAncestorIgnored logic handles tasks, parents, and worksheets', () {
    final service = AiBridgeService.instance;

    // Reset tasks
    service.tasks.clear();

    final task = AiTask(id: 'task_1', name: 'Task 1', description: 'Desc', parentId: 'folder_1', worksheetId: 'ws_1');
    final folder = AiTask(id: 'folder_1', name: 'Folder 1', description: 'Desc', isFolder: true, parentId: null, worksheetId: 'ws_1');
    final worksheet = AiTask(id: 'ws_1', name: 'WS 1', description: 'Desc', isWorksheet: true, parentId: null);

    service.tasks.addAll([task, folder, worksheet]);

    // Initially none are ignored
    expect(service.isTaskOrAncestorIgnored(task), isFalse);

    // If worksheet is ignored, task is ignored
    worksheet.isIgnored = true;
    expect(service.isTaskOrAncestorIgnored(task), isTrue);

    // Reset worksheet ignore, ignore folder
    worksheet.isIgnored = false;
    folder.isIgnored = true;
    expect(service.isTaskOrAncestorIgnored(task), isTrue);

    // Reset folder ignore, ignore task itself
    folder.isIgnored = false;
    task.isIgnored = true;
    expect(service.isTaskOrAncestorIgnored(task), isTrue);
  });
}
