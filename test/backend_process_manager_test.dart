import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/backend_process_manager.dart';
import 'dart:io';

void main() {
  group('BackendProcessManager Tests', () {
    test('getResolvedStartupCommand handles empty and antigravity-server', () {
      final manager = BackendProcessManager();
      
      final emptyResult = manager.getResolvedStartupCommand('');
      final defaultResult = manager.getResolvedStartupCommand('antigravity-server');
      
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'] ?? '';
        final expectedPath = '$userProfile\\AppData\\Local\\Programs\\Antigravity\\resources\\bin\\language_server.exe';
        if (File(expectedPath).existsSync()) {
          expect(emptyResult, contains('language_server.exe'));
          expect(emptyResult, contains('--standalone'));
          expect(defaultResult, contains('language_server.exe'));
          expect(defaultResult, contains('--standalone'));
        } else {
          // If standard path doesn't exist, it should return the original command
          expect(emptyResult, equals(''));
          expect(defaultResult, equals('antigravity-server'));
        }
      } else {
        expect(emptyResult, equals(''));
        expect(defaultResult, equals('antigravity-server'));
      }
    });

    test('getResolvedStartupCommand auto-appends flags for raw language_server.exe path', () {
      final manager = BackendProcessManager();
      final rawPath = r'C:\SomePath\language_server.exe';
      final resolved = manager.getResolvedStartupCommand(rawPath);
      
      if (Platform.isWindows) {
        expect(resolved, contains(rawPath));
        expect(resolved, contains('--standalone'));
        expect(resolved, contains('--http_server_port 8080'));
      } else {
        expect(resolved, equals(rawPath));
      }
    });

    test('getResolvedStartupCommand does not append duplicate flags', () {
      final manager = BackendProcessManager();
      final withFlags = r'C:\SomePath\language_server.exe --standalone --http_server_port 8089';
      final resolved = manager.getResolvedStartupCommand(withFlags);
      expect(resolved, equals(withFlags));
    });
  });
}
