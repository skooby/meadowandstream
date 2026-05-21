import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/system_logs_service.dart';
import 'package:music_app/services/error_scanner.dart';

void main() {
  group('ErrorScanner tests', () {
    test('matches layout overflow errors', () {
      const log1 = 'A RenderFlex overflowed by 24 pixels on the right.';
      const log2 = 'BoxConstraints forces an infinite anchor along with unbounded height.';
      
      final err1 = ErrorScanner.scan(log1);
      final err2 = ErrorScanner.scan(log2);
      
      expect(err1, isNotNull);
      expect(err1!.category, equals(ErrorCategory.layout));
      expect(err2, isNotNull);
      expect(err2!.category, equals(ErrorCategory.layout));
    });

    test('matches runtime exceptions and type errors', () {
      const log1 = 'Null check operator used on a null value';
      const log2 = 'Unhandled Exception: RangeError (index): Invalid value: Not in range 0..5, inclusive: 6';
      const log3 = 'TypeError: type "String" is not a subtype of type "int" of "index"';
      
      final err1 = ErrorScanner.scan(log1);
      final err2 = ErrorScanner.scan(log2);
      final err3 = ErrorScanner.scan(log3);
      
      expect(err1, isNotNull);
      expect(err1!.category, equals(ErrorCategory.runtime));
      expect(err2, isNotNull);
      expect(err2!.category, equals(ErrorCategory.runtime));
      expect(err3, isNotNull);
      expect(err3!.category, equals(ErrorCategory.runtime));
    });

    test('matches test failures', () {
      const log1 = '★ [FAIL] widget tests: should render correctly';
      const log2 = 'Expected: <true>\n  Actual: <false>';
      
      final err1 = ErrorScanner.scan(log1);
      final err2 = ErrorScanner.scan(log2);
      
      expect(err1, isNotNull);
      expect(err1!.category, equals(ErrorCategory.test));
      expect(err2, isNotNull);
      expect(err2!.category, equals(ErrorCategory.test));
    });

    test('matches dependency failures', () {
      const log1 = 'Because music_app depends on path_provider >=2.0.0 which depends on path_provider_platform_interface, version solving failed.';
      const log2 = 'pub get failed (69)';
      
      final err1 = ErrorScanner.scan(log1);
      final err2 = ErrorScanner.scan(log2);
      
      expect(err1, isNotNull);
      expect(err1!.category, equals(ErrorCategory.dependency));
      expect(err2, isNotNull);
      expect(err2!.category, equals(ErrorCategory.dependency));
    });

    test('returns null for non-error logs', () {
      const log1 = 'Loading audio waveform for track Meadow + Stream...';
      const log2 = '✔ Macro Completed: Run Tests';
      
      expect(ErrorScanner.scan(log1), isNull);
      expect(ErrorScanner.scan(log2), isNull);
    });
  });
}
