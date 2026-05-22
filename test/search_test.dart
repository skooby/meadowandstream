import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Search codebase for recovery', () {
    print('=== SEARCHING FOR RECOVERY ===');
    
    // Search tasks.json
    final tasksFile = File('.ai_bridge/tasks.json');
    if (tasksFile.existsSync()) {
      final content = tasksFile.readAsStringSync();
      final Map<String, dynamic> data = jsonDecode(content);
      final tasks = data['tasks'] as List<dynamic>;
      for (final task in tasks) {
        final name = task['name']?.toString() ?? '';
        final desc = task['description']?.toString() ?? '';
        final notes = task['notes']?.toString() ?? '';
        if (name.toLowerCase().contains('recovery') || 
            desc.toLowerCase().contains('recovery') ||
            notes.toLowerCase().contains('recovery')) {
          print('Match in tasks.json: ID ${task['id']} - Name: "$name"');
          print('Description: "$desc"');
          print('Notes: "$notes"');
          print('---');
        }
      }
    } else {
      print('tasks.json not found!');
    }

    // Search lib/
    final libDir = Directory('lib');
    if (libDir.existsSync()) {
      libDir.listSync(recursive: true).forEach((entity) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final fileContent = entity.readAsStringSync();
          if (fileContent.toLowerCase().contains('recovery')) {
            print('Match in file: ${entity.path}');
            final lines = fileContent.split('\n');
            for (int i = 0; i < lines.length; i++) {
              if (lines[i].toLowerCase().contains('recovery')) {
                print('  Line ${i + 1}: ${lines[i].trim()}');
              }
            }
            print('---');
          }
        }
      });
    }
    
    print('=== SEARCH COMPLETED ===');
  });
}
