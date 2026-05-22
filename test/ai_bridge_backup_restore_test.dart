import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/ai_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File file;
  late File backupFile;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('ai_bridge_test_');
    final service = AiBridgeService.instance;
    service.testDirPath = tempDir.path;
    service.testFilePath = '${tempDir.path}/tasks.json';
    service.forceDiskSaveInTests = true;

    file = File(service.filePath);
    backupFile = File('${service.filePath}.bak');
  });

  tearDown(() async {
    final service = AiBridgeService.instance;
    service.forceDiskSaveInTests = false;
    service.testDirPath = '.ai_bridge';
    service.testFilePath = '.ai_bridge/tasks.json';
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });


  test('AiBridgeService writes tasks.json.bak during saveTasks() and restores it when tasks.json is corrupted', () async {
    final service = AiBridgeService.instance;

    // Clean start for the test case, handle OS locks gracefully
    try {
      if (file.existsSync()) await file.delete();
    } catch (_) {}
    try {
      if (backupFile.existsSync()) await backupFile.delete();
    } catch (_) {}

    // Verify saving tasks creates both the main file and the backup file
    await service.saveTasks();

    // Wait for the 500ms local save lock delay in _save() finally block to elapse
    await Future.delayed(const Duration(milliseconds: 600));

    expect(file.existsSync(), isTrue);
    expect(backupFile.existsSync(), isTrue);

    final content1 = await file.readAsString();
    final backupContent1 = await backupFile.readAsString();
    expect(content1, equals(backupContent1));

    // Verify that the backup content is valid JSON matching the schema
    final Map<String, dynamic> schema = jsonDecode(backupContent1);
    expect(schema.containsKey('tasks'), isTrue);

    // Now corrupt the main tasks.json file with invalid JSON
    await file.writeAsString('{{{ invalid json content', flush: true);

    // Reset last parse error state
    service.dismissJsonParseError();
    expect(service.lastJsonParseError, isNull);

    // Call loadFromFileForTesting
    await service.loadFromFileForTesting();

    // Verify recovery:
    // 1. The main file should have been rewritten with the backup's valid content
    final restoredContent = await file.readAsString();
    expect(restoredContent, equals(backupContent1));

    // 2. An error message should have been recorded informing of the restoration
    expect(service.lastJsonParseError, contains('restored from backup'));
  });

  test('AiBridgeService restores from backup when tasks.json has valid JSON but invalid schema', () async {
    final service = AiBridgeService.instance;

    // Set up a valid backup file
    await service.saveTasks();
    await Future.delayed(const Duration(milliseconds: 600));

    final validBackupContent = await backupFile.readAsString();

    // Write valid JSON but completely invalid schema to tasks.json (e.g. missing both 'tasks' and 'primaryDirectives')
    await file.writeAsString('{"invalid_key": "some_value"}', flush: true);

    // Reset last parse error state
    service.dismissJsonParseError();

    // Call loadFromFileForTesting
    await service.loadFromFileForTesting();

    // Verify recovery:
    // 1. The main file should have been rewritten with the backup's valid content
    final restoredContent = await file.readAsString();
    expect(restoredContent, equals(validBackupContent));

    // 2. An error message should have been recorded informing of the restoration
    expect(service.lastJsonParseError, contains('restored from backup'));
  });
}
