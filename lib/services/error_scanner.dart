import 'system_logs_service.dart';

class ErrorScanner {
  // Pre-compiled regular expressions for error categories

  // Layout errors: RenderFlex overflow, unbounded height/width constraints, RenderBox layout errors
  static final RegExp _layoutRegExp = RegExp(
    r'(A RenderFlex overflowed by|RenderFlex overflowed by|unbounded height|unbounded width|RenderBox was not laid out|needsLayout|constraints do not allow)',
    caseSensitive: false,
  );

  // Runtime errors: Null pointer checks, index out of range, unhandled exception/error stack traces
  static final RegExp _runtimeRegExp = RegExp(
    r'(Null check operator used on a null value|RangeError|Unhandled Exception:|NoSuchMethodError:|TypeError:|Exception:|Error: |FlutterError|StateError|ArgumentError|FormatError)',
    caseSensitive: false,
  );

  // Test errors: Expected vs Actual, [FAIL] tags, failed tests
  static final RegExp _testRegExp = RegExp(
    r'(Expected: .*?\n\s*Actual:|\[FAIL\]|★ \[FAIL\]|test failed|Test failed|FAIL: )',
    caseSensitive: false,
  );

  // Dependency errors: pub get failures, mismatched sdk constraints, package resolution failures
  static final RegExp _dependencyRegExp = RegExp(
    r'(pub get failed|dependency resolution failed|resolution failed|mismatched sdk|Because \S+ depends on \S+)',
    caseSensitive: false,
  );

  /// Scans a log message line and categorizes it if it matches one of the error categories.
  /// Returns a [DetectedError] if matched, or `null` if no match.
  static DetectedError? scan(String line) {
    if (line.isEmpty) return null;

    if (_layoutRegExp.hasMatch(line)) {
      return DetectedError(line, ErrorCategory.layout);
    }
    if (_runtimeRegExp.hasMatch(line)) {
      return DetectedError(line, ErrorCategory.runtime);
    }
    if (_testRegExp.hasMatch(line)) {
      return DetectedError(line, ErrorCategory.test);
    }
    if (_dependencyRegExp.hasMatch(line)) {
      return DetectedError(line, ErrorCategory.dependency);
    }

    return null;
  }
}
