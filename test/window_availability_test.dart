import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tool Window Availability Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('bridge_monitor is in initialDefaults and loaded custom defaults', () async {
      await AppToolWindows.loadCustom();
      final hasMonitor = AppToolWindows.available.any((w) => w.id == 'bridge_monitor');
      expect(hasMonitor, isTrue);

      final monitorDef = AppToolWindows.getDef('bridge_monitor');
      expect(monitorDef.name, equals('Bridge Monitor'));
      expect(monitorDef.shortLabel, equals('Mon'));
    });

    test('loadCustom merges bridge_monitor even if cached defs exists but is missing it', () async {
      // Mock existing saved windows that do not have bridge_monitor (e.g. from an older version of the app)
      final oldDefs = [
        {
          'id': 'task_editor',
          'iconCodePoint': Icons.edit_note.codePoint,
          'iconFontFamily': Icons.edit_note.fontFamily,
          'color': Colors.lightBlueAccent.value,
          'name': 'Task Editor',
          'shortLabel': 'Edit',
          'description': ''
        }
      ];

      SharedPreferences.setMockInitialValues({
        've_custom_tool_windows_defs': jsonEncode(oldDefs),
      });

      await AppToolWindows.loadCustom();

      // Verify that task_editor is loaded
      expect(AppToolWindows.available.any((w) => w.id == 'task_editor'), isTrue);

      // Verify that bridge_monitor was auto-added because it is in initialDefaults
      expect(AppToolWindows.available.any((w) => w.id == 'bridge_monitor'), isTrue);
    });

    test('ve_windowAvailability defaults missing bridge_monitor to all', () async {
      // Mock ve_windowAvailability missing bridge_monitor
      final initialAvailability = {
        'task_editor': ['none'],
        'color_picker': ['Development'],
      };
      
      SharedPreferences.setMockInitialValues({
        've_windowAvailability': jsonEncode(initialAvailability),
      });
      
      final prefs = await SharedPreferences.getInstance();
      final availStr = prefs.getString('ve_windowAvailability');
      expect(availStr, isNotNull);
      
      final Map<String, dynamic> parsed = jsonDecode(availStr!);
      final windowAvailability = parsed.map((k, v) => MapEntry(k, List<String>.from(v)));
      
      // Our logic to ensure defaults
      for (final w in AppToolWindows.available) {
        if (!windowAvailability.containsKey(w.id)) {
          windowAvailability[w.id] = ['all'];
        }
      }
      
      // Verify that the missing ones are defaulted to ['all']
      expect(windowAvailability['bridge_monitor'], equals(['all']));
      expect(windowAvailability['ai_bridge'], equals(['all']));
      // Verify existing ones are preserved
      expect(windowAvailability['task_editor'], equals(['none']));
      expect(windowAvailability['color_picker'], equals(['Development']));
    });
  });
}
