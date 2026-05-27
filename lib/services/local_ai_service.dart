import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocalAiService extends ChangeNotifier {
  // Singleton pattern for easy access
  static final LocalAiService instance = LocalAiService._internal();
  LocalAiService._internal() {
    loadConfig();
  }

  factory LocalAiService() => instance;

  String baseUrl = 'http://localhost:11434';
  String defaultModel = 'qwen2.5:3b';
  int timeoutMs = 120000;
  String clarityPrompt = 'Review this prompt for clarity and return YES or NO as an answer. The prompt is';

  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      baseUrl = prefs.getString('ollamaBaseUrl') ?? 'http://localhost:11434';
      defaultModel = prefs.getString('ollamaModel') ?? 'qwen2.5:3b';
      timeoutMs = prefs.getInt('ollamaTimeoutMs') ?? 120000;
      clarityPrompt = prefs.getString('ollamaClarityPrompt') ?? 'Review this prompt for clarity and return YES or NO as an answer. The prompt is';
      notifyListeners();
    } catch (_) {}
  }
  
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;
  
  String? _lastError;
  String? get lastError => _lastError;

  /// Checks if the Ollama service is reachable
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse(baseUrl)).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Attempts to natively spawn the Ollama process if it's currently unreachable
  Future<void> _startOllamaIfNeeded() async {
    if (await checkHealth()) return;

    try {
      if (Platform.isWindows) {
        await Process.start('ollama', ['serve'], runInShell: true);
      } else if (Platform.isMacOS || Platform.isLinux) {
        await Process.start('ollama', ['serve']);
      }
      
      // Wait up to 5 seconds for the daemon to spin up
      for (int i = 0; i < 5; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (await checkHealth()) return;
      }
    } catch (e) {
      debugPrint('Failed to start Ollama natively: $e');
    }
  }

  /// Sends a simple prompt to the /api/generate endpoint
  Future<String?> generateText(
    String prompt, {
    String? model,
    double? temperature,
    double? topP,
    int? numPredict,
  }) async {
    _setProcessing(true);
    try {
      final messages = [{'role': 'user', 'content': prompt}];
      
      await _startOllamaIfNeeded();

      for (int attempt = 1; attempt <= 2; attempt++) {
        try {
          final options = <String, dynamic>{};
          if (temperature != null) options['temperature'] = temperature;
          if (topP != null) options['top_p'] = topP;
          if (numPredict != null) options['num_predict'] = numPredict;

          final body = <String, dynamic>{
            'model': model ?? defaultModel,
            'prompt': prompt,
            'stream': false,
          };
          if (options.isNotEmpty) {
            body['options'] = options;
          }

          final response = await http.post(
            Uri.parse('$baseUrl/api/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          ).timeout(Duration(milliseconds: timeoutMs));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            return data['response'];
          } else {
            _lastError = 'Server returned ${response.statusCode}: ${response.body}';
          }
        } catch (e) {
          _lastError = 'Attempt $attempt failed: $e';
        }
        if (attempt < 2) await Future.delayed(Duration(milliseconds: 1000 * attempt));
      }
      return await _fallbackToOpenAI(messages, temperature: temperature);
    } finally {
      _setProcessing(false);
    }
  }

  /// Sends a structured chat completion to the /api/chat endpoint
  Future<String?> sendChat(
    List<Map<String, String>> messages, {
    String? model,
    double? temperature,
    double? topP,
    int? numPredict,
  }) async {
    _setProcessing(true);
    try {
      await _startOllamaIfNeeded();

      for (int attempt = 1; attempt <= 2; attempt++) {
        try {
          final options = <String, dynamic>{};
          if (temperature != null) options['temperature'] = temperature;
          if (topP != null) options['top_p'] = topP;
          if (numPredict != null) options['num_predict'] = numPredict;

          final body = <String, dynamic>{
            'model': model ?? defaultModel,
            'messages': messages,
            'stream': false,
          };
          if (options.isNotEmpty) {
            body['options'] = options;
          }

          final response = await http.post(
            Uri.parse('$baseUrl/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          ).timeout(Duration(milliseconds: timeoutMs));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            return data['message']['content'];
          } else {
            _lastError = 'Server returned ${response.statusCode}: ${response.body}';
          }
        } catch (e) {
          _lastError = 'Attempt $attempt failed: $e';
        }
        if (attempt < 2) await Future.delayed(Duration(milliseconds: 1000 * attempt));
      }
      return await _fallbackToOpenAI(messages, temperature: temperature);
    } finally {
      _setProcessing(false);
    }
  }

  // --- AI UTILITY PIPELINES ---

  /// Utility 1: Prompt Review
  /// Analyzes a prompt for ambiguity, missing reqs, weak constraints, etc.
  Future<String?> reviewPrompt(String userPrompt) async {
    final systemPrompt = clarityPrompt;

    // We use a low temperature for deterministic orchestration tasks
    return await sendChat(
      [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      temperature: 0.2,
      topP: 0.9,
    );
  }

  /// Utility 2: Task Summarizer
  /// Summarizes workflow notes into objectives, completed, pending, etc.
  Future<String?> summarizeTask(String taskNotes) async {
    final systemPrompt = '''
You are an expert project manager. Summarize the following task notes into a concise status report.
Include the following sections:
- **Objectives**
- **Completed**
- **Pending/Next Actions**
- **Blockers (if any)**

Keep the output brief, highly structured, and strictly derived from the provided notes.
''';

    return await sendChat(
      [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': taskNotes},
      ],
      temperature: 0.2,
      topP: 0.9,
    );
  }

  Future<String?> _fallbackToOpenAI(List<Map<String, String>> messages, {double? temperature}) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _lastError = '$_lastError (OpenAI fallback failed: No API Key found in .env)';
      return null;
    }

    try {
      final body = <String, dynamic>{
        'model': 'gpt-4o-mini',
        'messages': messages,
      };
      if (temperature != null) {
        body['temperature'] = temperature;
      }

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(body),
      ).timeout(Duration(milliseconds: timeoutMs));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        _lastError = 'OpenAI fallback failed: ${response.statusCode} - ${response.body}';
        return null;
      }
    } catch (e) {
      _lastError = 'OpenAI fallback error: $e';
      return null;
    }
  }

  /// Generates vector embeddings for a given text
  Future<List<double>?> generateEmbeddings(
    String text, {
    String? model,
  }) async {
    _setProcessing(true);
    try {
      await _startOllamaIfNeeded();

      for (int attempt = 1; attempt <= 2; attempt++) {
        try {
          final body = <String, dynamic>{
            'model': model ?? 'nomic-embed-text',
            'input': text,
          };

          // Try standard /api/embed endpoint
          final response = await http.post(
            Uri.parse('$baseUrl/api/embed'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          ).timeout(Duration(milliseconds: timeoutMs));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['embeddings'] != null && data['embeddings'] is List && (data['embeddings'] as List).isNotEmpty) {
              final embeddingList = data['embeddings'] as List;
              return (embeddingList[0] as List).map<double>((e) => (e as num).toDouble()).toList();
            }
          } else {
            // Fallback to older /api/embeddings endpoint if /api/embed fails
            final fallbackBody = <String, dynamic>{
              'model': model ?? 'nomic-embed-text',
              'prompt': text,
            };
            final fallbackResponse = await http.post(
              Uri.parse('$baseUrl/api/embeddings'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(fallbackBody),
            ).timeout(Duration(milliseconds: timeoutMs));

            if (fallbackResponse.statusCode == 200) {
              final data = jsonDecode(fallbackResponse.body);
              if (data['embedding'] != null && data['embedding'] is List) {
                return (data['embedding'] as List).map<double>((e) => (e as num).toDouble()).toList();
              }
            }
            _lastError = 'Server returned ${response.statusCode}: ${response.body}';
          }
        } catch (e) {
          _lastError = 'Attempt $attempt failed: $e';
        }
        if (attempt < 2) await Future.delayed(Duration(milliseconds: 1000 * attempt));
      }
      
      // Fallback to OpenAI embeddings
      return await _fallbackToOpenAIEmbeddings(text);
    } finally {
      _setProcessing(false);
    }
  }

  Future<List<double>?> _fallbackToOpenAIEmbeddings(String text) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _lastError = '$_lastError (OpenAI embeddings fallback failed: No API Key found in .env)';
      return null;
    }

    try {
      final body = <String, dynamic>{
        'model': 'text-embedding-3-small',
        'input': text,
      };

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/embeddings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(body),
      ).timeout(Duration(milliseconds: timeoutMs));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final embeddingList = data['data'][0]['embedding'] as List;
        return embeddingList.map<double>((e) => (e as num).toDouble()).toList();
      } else {
        _lastError = 'OpenAI embeddings fallback failed: ${response.statusCode} - ${response.body}';
        return null;
      }
    } catch (e) {
      _lastError = 'OpenAI embeddings fallback error: $e';
      return null;
    }
  }

  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }
}
