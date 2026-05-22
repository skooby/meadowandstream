import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/ai_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Compile error intercept adds a task named "Fix compile errors"', () async {
    SharedPreferences.setMockInitialValues({
      'ai_tasks_delay_seconds': 0,
    });
    
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
