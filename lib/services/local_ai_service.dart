import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      baseUrl = prefs.getString('ollamaBaseUrl') ?? 'http://localhost:11434';
      defaultModel = prefs.getString('ollamaModel') ?? 'qwen2.5:3b';
      timeoutMs = prefs.getInt('ollamaTimeoutMs') ?? 120000;
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
        return null;
      }
    } catch (e) {
      _lastError = 'Failed to generate text: $e';
      return null;
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
        return null;
      }
    } catch (e) {
      _lastError = 'Failed to send chat: $e';
      return null;
    } finally {
      _setProcessing(false);
    }
  }

  // --- AI UTILITY PIPELINES ---

  /// Utility 1: Prompt Review
  /// Analyzes a prompt for ambiguity, missing reqs, weak constraints, etc.
  Future<String?> reviewPrompt(String userPrompt) async {
    final systemPrompt = '''
You are an expert AI orchestration assistant. Your job is to review the following user prompt for:
- Ambiguity
- Missing requirements
- Weak constraints
- Verbosity
- Hallucination risks

Please format your response strictly with the following sections:
### Identified Problems
(List any issues found)

### Suggested Improvements
(List how to fix them)

### Revised Prompt
(Provide the rewritten, optimized prompt)
''';

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

  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }
}
