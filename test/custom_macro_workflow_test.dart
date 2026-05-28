import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/ai_bridge_service.dart';
import 'package:antigravity_sdk/antigravity_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBridgeDir;
  late Directory tempRulesDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'ai_tasks_delay_seconds': 0.0,
      'antigravity_model': 'gemini-2.0-flash',
    });
    tempBridgeDir = Directory.systemTemp.createTempSync('ai_bridge_rules_test_dir');
    tempRulesDir = Directory.systemTemp.createTempSync('ai_agent_rules_test_dir');
    
    AiBridgeService.instance.testDirPath = tempBridgeDir.path;
    AiBridgeService.instance.testFilePath = '${tempBridgeDir.path}/tasks.json';
    AiBridgeService.instance.testRulesDirPath = tempRulesDir.path;
    AiBridgeService.instance.setQueuePaused(false);
    AiBridgeService.instance.setBridgeMode(AntigravityBridgeMode.sdk);
  });

  tearDown(() {
    AiBridgeService.instance.setDryRunMode(false);
    AiBridgeService.instance.testDirPath = '.ai_bridge';
    AiBridgeService.instance.testFilePath = '.ai_bridge/tasks.json';
    AiBridgeService.instance.testRulesDirPath = '.agent/rules';
    
    if (tempBridgeDir.existsSync()) {
      tempBridgeDir.deleteSync(recursive: true);
    }
    if (tempRulesDir.existsSync()) {
      tempRulesDir.deleteSync(recursive: true);
    }
  });

  test('Custom Rule Parsing works correctly', () {
    const rawRuleContent = '''---
trigger: "/use-flash"
action: "route-harness"
---
For all subsequent tasks and sub-agent generation, explicitly invoke the gemini-3.5-flash runtime.''';

    final rule = parseCustomRule(rawRuleContent);
    expect(rule, isNotNull);
    expect(rule!.trigger, equals('/use-flash'));
    expect(rule.action, equals('route-harness'));
    expect(rule.body, contains('invoke the gemini-3.5-flash runtime'));

    final model = extractModelFromRuleBody(rule.body);
    expect(model, equals('gemini-3.5-flash'));
  });

  test('AiBridgeService intercepts Slash Command Override trigger and updates model routing', () async {
    // Write rule file into temp rules directory
    final ruleFile = File('${tempRulesDir.path}/switch.md');
    await ruleFile.writeAsString('''---
trigger: "/use-flash"
action: "route-harness"
---
For all subsequent tasks and sub-agent generation, explicitly invoke the gemini-3.5-flash runtime.''', flush: true);

    final service = AiBridgeService.instance;
    await service.clearQueue();
    service.setDryRunMode(true);

    // Initial check of preferences and config
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('antigravity_model'), equals('gemini-2.0-flash'));
    expect(service.antigravityClient.config.targetModel, equals('gemini-2.0-flash'));

    // Send the slash command prompt
    await service.sendToQueue('/use-flash', false);

    // Expecting interception:
    // 1. SharedPreferences must be updated to gemini-3.5-flash
    expect(prefs.getString('antigravity_model'), equals('gemini-3.5-flash'));
    // 2. Client configuration must have updated
    expect(service.antigravityClient.config.targetModel, equals('gemini-3.5-flash'));
    
    // 3. Prompt must be intercepted and NOT added to the LLM queue
    expect(service.pendingPrompts, isEmpty);
    expect(service.activePrompt, isNull);
    
    // 4. The trigger log action must be recorded
    final hasTriggerAction = service.simulatedActions.any(
      (a) => a.type == 'RULE_TRIGGERED' && a.title == '/use-flash' && a.detail.contains('gemini-3.5-flash')
    );
    expect(hasTriggerAction, isTrue);
  });

  test('Choosing LO | HI model tier dynamically configures the Antigravity client on dispatch', () async {
    final service = AiBridgeService.instance;
    await service.clearQueue();
    service.setDryRunMode(true);
    service.setBridgeMode(AntigravityBridgeMode.sdk);

    final prefs = await SharedPreferences.getInstance();
    
    // Configure specific LO/HI models
    await prefs.setString('antigravity_lo_model', 'my-low-model');
    await prefs.setString('antigravity_hi_model', 'my-high-model');

    // 1. Set to LO model
    service.setUseHiModel(false);
    expect(service.useHiModel, isFalse);

    // When we process queue or send a prompt, LO model should be chosen
    await service.sendToQueue('test low model prompt', false);
    expect(prefs.getString('antigravity_model'), equals('my-low-model'));
    expect(service.antigravityClient.config.targetModel, equals('my-low-model'));

    // Clear queue to reset _activePrompt
    await service.clearQueue();

    // 2. Set to HI model
    service.setUseHiModel(true);
    expect(service.useHiModel, isTrue);

    await service.sendToQueue('test high model prompt', false);
    expect(prefs.getString('antigravity_model'), equals('my-high-model'));
    expect(service.antigravityClient.config.targetModel, equals('my-high-model'));
  });

  test('Executing task dynamically configures the Antigravity client to correct model tier', () async {
    final service = AiBridgeService.instance;
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('antigravity_lo_model', 'my-low-model');
    await prefs.setString('antigravity_hi_model', 'my-high-model');

    final task = AiTask(id: 'task-test-model-1', name: 'Test Task', isWorksheet: false, description: '');
    service.tasks.add(task);

    // Use LO model
    service.setUseHiModel(false);
    
    try {
      await service.executeTask(task);
    } catch (_) {}

    expect(prefs.getString('antigravity_model'), equals('my-low-model'));
    expect(service.antigravityClient.config.targetModel, equals('my-low-model'));

    // Use HI model
    service.setUseHiModel(true);

    try {
      await service.executeTask(task);
    } catch (_) {}

    expect(prefs.getString('antigravity_model'), equals('my-high-model'));
    expect(service.antigravityClient.config.targetModel, equals('my-high-model'));
  });
}
