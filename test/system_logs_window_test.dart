import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/screens/visual_editor/panels/system_logs_window.dart';
import 'package:music_app/services/system_logs_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SystemLogsWindow Pin and Transparency toggle test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    SystemLogsService.instance.addLog('Test log entry');

    bool onCloseCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: NoSplash.splashFactory,
        ),
        home: Scaffold(
          body: Stack(
            children: [
              SystemLogsWindow(
                onClose: () {
                  onCloseCalled = true;
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial state
    expect(SystemLogsWindow.isPinnedOnTopNotifier.value, isFalse);
    expect(onCloseCalled, isFalse);

    // Find Pin on Top button
    final pinButtonFinder = find.byTooltip('Pin on Top');
    expect(pinButtonFinder, findsOneWidget);

    // Tap Pin on Top button
    await tester.tap(pinButtonFinder);
    await tester.pumpAndSettle();

    // Verify state updated to pinned
    expect(SystemLogsWindow.isPinnedOnTopNotifier.value, isTrue);

    // Find Always on Top (Pinned) button
    final pinnedButtonFinder = find.byTooltip('Always on Top (Pinned)');
    expect(pinnedButtonFinder, findsOneWidget);

    // Find transparency button
    final opacityButtonFinder = find.byIcon(Icons.opacity);
    expect(opacityButtonFinder, findsOneWidget);

    // Tap it to cycle opacity
    await tester.tap(opacityButtonFinder);
    await tester.pumpAndSettle();

    // Tap it again
    await tester.tap(opacityButtonFinder);
    await tester.pumpAndSettle();

    // Verify ScrollController is attached
    final listFinder = find.byType(ListView);
    expect(listFinder, findsOneWidget);
    final Scrollable scrollable = tester.widget<Scrollable>(
      find.descendant(of: listFinder, matching: find.byType(Scrollable)).first,
    );
    expect(scrollable.controller, isNotNull);
  });

  test('SystemLogsService configuration serialization, filtering and reordering works', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SystemLogsService.instance;
    await service.init();

    // Verify default configs are created
    expect(service.categoryConfigs.length, equals(LogCategory.values.length));
    expect(service.categoryConfigs.any((e) => e.category == LogCategory.GENERAL), isTrue);

    // Verify filtering based on system log configuration
    final generalConfig = service.categoryConfigs.firstWhere((e) => e.category == LogCategory.GENERAL);
    generalConfig.system = false;
    service.clearLogs();
    service.addLog('Test General Log suppressed', category: LogCategory.GENERAL);
    expect(service.logs.isEmpty, isTrue);

    generalConfig.system = true;
    service.addLog('Test General Log accepted', category: LogCategory.GENERAL);
    expect(service.logs.length, equals(1));
    expect(service.logs.first.message, equals('Test General Log accepted'));

    // Verify reordering configurations
    final firstCat = service.categoryConfigs[0].category;
    final secondCat = service.categoryConfigs[1].category;

    // Move first to second index (newIndex 2 means after second element, which lands at index 1)
    service.reorderConfigs(0, 2);
    expect(service.categoryConfigs[1].category, equals(firstCat));
    expect(service.categoryConfigs[0].category, equals(secondCat));
  });

  testWidgets('SystemLogsWindow filters out hidden categories from top bar chips', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = SystemLogsService.instance;
    if (service.categoryConfigs.isEmpty) {
      service.categoryConfigs.addAll(LogCategory.values.map(
        (cat) => LogTypeConfig(category: cat, system: true, console: true),
      ));
    }

    // Disable system logs for DB category
    final dbConfig = service.categoryConfigs.firstWhere((e) => e.category == LogCategory.DB);
    dbConfig.system = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: NoSplash.splashFactory,
        ),
        home: Scaffold(
          body: Stack(
            children: [
              SystemLogsWindow(
                onClose: () {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // We should see ALL chip and other enabled chips, but DB chip should not be present
    expect(find.text('ALL'), findsOneWidget);
    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('DB'), findsNothing);

    // Reset it back
    dbConfig.system = true;
  });
}
