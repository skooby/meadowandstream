import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

void main() {
  group('Fallback Encoding Parser Tests', () {
    String mockParseAlgorithm(List<int> bytes) {
      String decoded = '';
      try {
        decoded = utf8.decode(bytes);
      } catch (e) {
        if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
          final chars = <int>[];
          for (int i = 2; i < bytes.length - 1; i += 2) {
            chars.add(bytes[i] | (bytes[i + 1] << 8));
          }
          decoded = String.fromCharCodes(chars);
        } else {
          final stripped = bytes.where((b) => b != 0).toList();
          decoded = String.fromCharCodes(stripped);
        }
      }
      return decoded;
    }

    test('Should decode standard UTF-8 correctly', () {
      final inputStr = 'Hello World - Standard UTF-8';
      final bytes = utf8.encode(inputStr);
      final decoded = mockParseAlgorithm(bytes);
      expect(decoded, equals(inputStr));
    });

    test('Should decode UTF-16LE with BOM correctly', () {
      final inputStr = 'Hello World - UTF-16LE format';
      // Simulate UTF-16LE BOM (0xFF, 0xFE)
      final bytes = <int>[0xFF, 0xFE];
      for (int i = 0; i < inputStr.length; i++) {
        final codeUnit = inputStr.codeUnitAt(i);
        bytes.add(codeUnit & 0xFF);
        bytes.add((codeUnit >> 8) & 0xFF);
      }
      final decoded = mockParseAlgorithm(bytes);
      expect(decoded, equals(inputStr));
    });

    test('Should decode null-stripped ASCII correctly when UTF-8 fails without BOM', () {
      final inputStr = 'Hello World - Null Stripped';
      // Simulate raw ASCII interleaved with null bytes (like some bad terminal pipes)
      // And prepend an invalid UTF-8 byte to force catch block
      final bytes = <int>[0xFF]; // Invalid UTF-8 start byte
      for (int i = 0; i < inputStr.length; i++) {
        bytes.add(inputStr.codeUnitAt(i));
        bytes.add(0); // Null byte
      }
      final decoded = mockParseAlgorithm(bytes);
      expect(decoded, equals('\xFF' + inputStr));
    });
  });
}
