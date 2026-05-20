import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/ai_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Compile error intercept adds a task named "Fix compile errors"', () async {
    SharedPreferences.setMockInitialValues({});
    
    // Clear initial tasks
    AiBridgeService.instance.tasks.clear();
    
    expect(
      AiBridgeService.instance.tasks.any((t) => t.name == 'Fix compile errors'),
      isFalse,
    );

    // Call forceDispatchCompileError to simulate compile error intercept
    await AiBridgeService.instance.forceDispatchCompileError('Mock compiler syntax error');

    expect(
      AiBridgeService.instance.tasks.any((t) => t.name == 'Fix compile errors'),
      isTrue,
    );
  });
}
