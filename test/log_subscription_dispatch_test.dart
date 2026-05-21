import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/ai_bridge_service.dart';
import 'package:music_app/services/system_logs_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Log subscription intercepts runtime errors, debounces, and dispatches task', () async {
    final service = AiBridgeService.instance;
    await service.init();
    
    // Clear any existing tasks
    service.tasks.clear();

    // Initially not busy, so errors won't be processed
    expect(service.isThinking, isFalse);

    // Set busy state to simulate active task/thinking state
    service.setAntigravityBusyForTesting(true);
    expect(service.isThinking, isTrue);

    // Add normal log - should not trigger error handling
    SystemLogsService.instance.addLog('Some normal user log message');

    // Add layout overflow log
    SystemLogsService.instance.addLog('A RenderFlex overflowed by 45 pixels on the bottom.');

    // Wait for the 1.5 second debounce timer to expire
    await Future.delayed(const Duration(milliseconds: 2000));

    // Verify task 'Fix runtime errors' was created
    expect(
      service.tasks.any((t) => t.name == 'Fix runtime errors'),
      isTrue,
    );

    // Verify the task details contain the error message
    final task = service.tasks.firstWhere((t) => t.name == 'Fix runtime errors');
    expect(task.notes, contains('RenderFlex overflowed'));

    // Clean up
    service.setAntigravityBusyForTesting(false);
  });
}
