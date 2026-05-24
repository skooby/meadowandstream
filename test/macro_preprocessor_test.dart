import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/macro_service.dart';
import 'package:music_app/services/ai_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('Macro Preprocessor variable and operator support works', () {
    final macroService = MacroService.instance;
    const script = '''
var bridgeMode = GetBridgeMode()
if (bridgeMode == "desktop")
{
  Log("bridgeMode is desktop")
}
var testVal = 10
if (testVal > 5 && testVal <= 20) {
  Log("testVal matches: == or != inside string is ignored")
}
Log("BridgeMode: " + bridgeMode)
''';
    final result = macroService.preprocess(script);
    expect(result, contains('\$bridgeMode = GetBridgeMode'));
    expect(result, contains('if (\$bridgeMode  -eq  "desktop")'));
    expect(result, contains('\$testVal = 10'));
    expect(result, contains('if (\$testVal  -gt  5 && \$testVal  -le  20)'));
    expect(result, contains('Log "bridgeMode is desktop"'));
    expect(result, contains('Log ("BridgeMode: " + \$bridgeMode)'));
  });

  test('AiBridgeService desktop mode writes desktop to active_mode.txt', () async {
    final service = AiBridgeService.instance;
    final tempBridgeDir = Directory.systemTemp.createTempSync('ai_bridge_test_dir_desktop');
    service.testDirPath = tempBridgeDir.path;
    service.testFilePath = '${tempBridgeDir.path}/tasks.json';
    try {
      await service.init();
      service.setBridgeMode(AntigravityBridgeMode.desktop);
      expect(service.bridgeMode, equals(AntigravityBridgeMode.desktop));
      
      final activeModeFile = File('${tempBridgeDir.path}/active_mode.txt');
      expect(activeModeFile.existsSync(), isTrue);
      expect(activeModeFile.readAsStringSync().trim(), equals('desktop'));
    } finally {
      service.testDirPath = '.ai_bridge';
      service.testFilePath = '.ai_bridge/tasks.json';
      if (tempBridgeDir.existsSync()) {
        tempBridgeDir.deleteSync(recursive: true);
      }
    }
  });

  test('Macro Preprocessor recursively preprocesses nested macro scripts', () {
    final macroService = MacroService.instance;
    final originalMacros = List<Macro>.from(macroService.macros);
    try {
      macroService.macros.clear();
      macroService.macros.addAll([
        Macro(
          id: 'child_macro',
          name: 'SetWindowAntigravity',
          script: '''
var bridgeMode = GetBridgeMode()
if (bridgeMode == "desktop") {
  SwitchWindow("Antigravity - Agentic Desktop")
} else {
  Log("Active mode: \$bridgeMode")
}
WaitMs(200)
''',
        ),
      ]);
      
      const script = '''
BlockInput(true)
Run ("SetWindowAntigravity")
var bridge_mode = GetBridgeMode()
if (bridge_mode == "desktop") {
  Send("^L")
} else {
  Log("Active mode: \$bridge_mode")
}
BlockInput(false)
''';

      final result = macroService.preprocess(script);
      expect(result, contains('\$bridgeMode = GetBridgeMode'));
      expect(result, contains('if (\$bridgeMode  -eq  "desktop")'));
      expect(result, contains('\$bridge_mode = GetBridgeMode'));
      expect(result, contains('if (\$bridge_mode  -eq  "desktop")'));
      expect(result, contains('BlockInput true'));
      expect(result, contains('BlockInput false'));
    } finally {
      macroService.macros.clear();
      macroService.macros.addAll(originalMacros);
    }
  });
}
