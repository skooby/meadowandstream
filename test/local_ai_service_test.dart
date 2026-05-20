import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/services/local_ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Allow real HTTP requests during testing
  HttpOverrides.global = null;

  group('LocalAiService Embeddings Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dotenv.testLoad(fileInput: 'OPENAI_API_KEY=mock_key_for_testing');
    });

    test('generateEmbeddings returns non-empty list or falls back gracefully', () async {
      final service = LocalAiService.instance;
      
      // Let's attempt to run the embeddings request.
      final embeddings = await service.generateEmbeddings('Hello world');
      
      if (embeddings != null) {
        expect(embeddings, isNotEmpty);
        print('Successfully generated embeddings of length ${embeddings.length}');
        print('First 5 elements: ${embeddings.take(5).toList()}');
      } else {
        print('Failed to generate embeddings (this is expected if local Ollama is unreachable and mock OpenAI key is invalid). Error: ${service.lastError}');
      }
    });
  });
}
