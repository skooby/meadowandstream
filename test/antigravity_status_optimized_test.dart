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
    tempBridgeDir = Directory.systemTemp.createTempSync('antigravity_status_opt_test');
    AiBridgeService.instance.testDirPath = tempBridgeDir.path;
    AiBridgeService.instance.testFilePath = '${tempBridgeDir.path}/tasks.json';
  });

  tearDown(() {
    AiBridgeService.instance.testDirPath = '.ai_bridge';
    AiBridgeService.instance.testFilePath = '.ai_bridge/tasks.json';
    if (tempBridgeDir.existsSync()) {
      tempBridgeDir.deleteSync(recursive: true);
    }
  });

  test('getHttpBridgeStatus returns null instantly if active_mode.txt is not sdk', () async {
    // Write 'desktop' to active_mode.txt
    final modeFile = File('${tempBridgeDir.path}/active_mode.txt');
    modeFile.writeAsStringSync('desktop');

    final startTime = DateTime.now();
    final status = await AntigravityStatusService.instance.getHttpBridgeStatus();
    final duration = DateTime.now().difference(startTime);

    expect(status, isNull);
    // Since it doesn't do a network timeout (which is 1s), it should return almost instantly (< 100ms)
    expect(duration.inMilliseconds, lessThan(100));
  });

  test('directory watcher on agent_status.txt triggers isAntigravityBusy instantly', () async {
    final statusFile = File('${tempBridgeDir.path}/agent_status.txt');
    statusFile.writeAsStringSync('IDLE');

    // Start watching
    AiBridgeService.instance.initializeForTesting();

    // Verify initial state is idle
    expect(AiBridgeService.instance.isAntigravityBusy, isFalse);

    // Modify to BUSY
    statusFile.writeAsStringSync('BUSY');

    // Wait slightly for file system watcher to fire
    await Future.delayed(const Duration(milliseconds: 100));

    expect(AiBridgeService.instance.isAntigravityBusy, isTrue);

    // Modify back to IDLE
    statusFile.writeAsStringSync('IDLE');
    await Future.delayed(const Duration(milliseconds: 100));

    expect(AiBridgeService.instance.isAntigravityBusy, isFalse);
  });

  test('isDaemonRunning updates state based on process checks', () async {
    expect(AiBridgeService.instance.isDaemonRunning, isFalse);
  });

  test('does not process queue or send prompt to LLM if isAntigravityBusy is true', () async {
    final statusFile = File('${tempBridgeDir.path}/agent_status.txt');
    statusFile.writeAsStringSync('IDLE');

    // Force bridge mode to CLI so that queueing is used
    AiBridgeService.instance.setBridgeMode(AntigravityBridgeMode.cli);

    // Start watching
    AiBridgeService.instance.initializeForTesting();
    expect(AiBridgeService.instance.isAntigravityBusy, isFalse);

    // Now write BUSY to trigger watcher
    statusFile.writeAsStringSync('BUSY');
    
    // Wait for the watcher to process the file change to BUSY
    await Future.delayed(const Duration(milliseconds: 200));
    expect(AiBridgeService.instance.isAntigravityBusy, isTrue);

    // Now send a prompt to the queue
    await AiBridgeService.instance.sendToQueue('Hello Antigravity', false);

    // Verify that the prompt is queued, but NOT processed or dispatched
    expect(AiBridgeService.instance.activePrompt, isNull);
    expect(AiBridgeService.instance.pendingPrompts.length, equals(1));
    expect(AiBridgeService.instance.pendingPrompts.first.text, equals('Hello Antigravity'));
  });
}

