import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SharedPreferences project_summary config persistence', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Verify initial state is null/unset
    expect(prefs.getString('project_summary'), isNull);

    // Save project_summary
    await prefs.setString('project_summary', '# My Project Summary\n- Task 1\n- Task 2');

    // Retrieve and verify
    final savedSummary = prefs.getString('project_summary');
    expect(savedSummary, '# My Project Summary\n- Task 1\n- Task 2');
  });

  test('PROJECT_SUMMARY.md file build logic', () async {
    final file = File('PROJECT_SUMMARY_TEST.md');
    if (file.existsSync()) {
      file.deleteSync();
    }

    try {
      final summaryText = '# Test Summary\n- Sub-task A';
      await file.writeAsString(summaryText);

      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), summaryText);
    } finally {
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  });
}
