import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'system_logs_service.dart';

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
  String clarityPrompt = 'Determine if the following prompt is clear? "{PROMPT}"';
  String clarityResponseFormat = 'binary'; // 'binary' enforces YES/NO output
  String rewritePrompt = 'Rewrite this prompt to make it clearer, more precise, and direct. Keep it brief. The prompt is: {PROMPT}';
  String generateTaskPrompt = 'You are a helpful project planning assistant. Given a task description, generate a concise task title and a list of specific, actionable checklist items. Each checklist item must be a single clear sentence describing one concrete action. Return 3 to 8 checklist items. Do not add numbering or bullet symbols.\n\nTask description: "{DESCRIPTION}"';

  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      baseUrl = prefs.getString('ollamaBaseUrl') ?? 'http://localhost:11434';
      defaultModel = prefs.getString('ollamaModel') ?? 'qwen2.5:3b';
      timeoutMs = prefs.getInt('ollamaTimeoutMs') ?? 120000;
      final rawClarity = prefs.getString('ollamaClarityPrompt') ?? 'Determine if the following prompt is clear? "{PROMPT}"';
      // Support JSON format: {"prompt": "...", "responseFormat": "binary"}
      try {
        final decoded = jsonDecode(rawClarity);
        if (decoded is Map && decoded.containsKey('prompt')) {
          clarityPrompt = decoded['prompt'] as String;
          clarityResponseFormat = (decoded['responseFormat'] as String? ?? 'binary').toLowerCase();
        } else {
          clarityPrompt = rawClarity;
          clarityResponseFormat = 'binary'; // default to binary for plain-string prompts
        }
      } catch (_) {
        clarityPrompt = rawClarity;
        clarityResponseFormat = 'binary';
      }
      rewritePrompt = prefs.getString('ollamaRewritePrompt') ?? 'Rewrite this prompt to make it clearer, more precise, and direct. Keep it brief. The prompt is: {PROMPT}';
      generateTaskPrompt = prefs.getString('ollamaGenerateTaskPrompt') ?? 'You are a helpful project planning assistant. Given a task description, generate a concise task title and a list of specific, actionable checklist items. Each checklist item must be a single clear sentence describing one concrete action. Return 3 to 8 checklist items. Do not add numbering or bullet symbols.\n\nTask description: "{DESCRIPTION}"';
      notifyListeners();
    } catch (_) {}
  }
  
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  /// Last prompt that was sent to the AI Assistant (any call path).
  String _lastPromptSent = '';
  String get lastPromptSent => _lastPromptSent;

  /// Last response received from the AI Assistant (any call path).
  String _lastResponseReceived = '';
  String get lastResponseReceived => _lastResponseReceived;

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
    Map<String, dynamic>? format, // Ollama structured output schema
  }) async {
    final usedModel = model ?? defaultModel;
    SystemLogsService.instance.addLog(
      '[AI] generateText | prompt: ${prompt.length > 120 ? '${prompt.substring(0, 120)}…' : prompt}',
      category: LogCategory.AI,
    );
    // Track the outgoing prompt so the Bridge Monitor I/O tab can display it.
    _lastPromptSent = prompt;
    _lastResponseReceived = '';
    notifyListeners();
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
            'model': usedModel,
            'prompt': prompt,
            'stream': false,
          };
          if (options.isNotEmpty) body['options'] = options;
          if (format != null) body['format'] = format;

          SystemLogsService.instance.addLog(
            '[AI] generateText attempt $attempt → POST $baseUrl/api/generate',
            category: LogCategory.AI,
          );

          final response = await http.post(
            Uri.parse('$baseUrl/api/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          ).timeout(Duration(milliseconds: timeoutMs));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final result = data['response'] as String?;
            SystemLogsService.instance.addLog(
              '[AI] generateText success | response: ${result != null && result.length > 120 ? '${result.substring(0, 120)}…' : result}',
              category: LogCategory.AI,
            );
            if (result != null) {
              _lastResponseReceived = result;
              notifyListeners();
            }
            return result;
          } else {
            _lastError = 'Server returned ${response.statusCode}: ${response.body}';
            SystemLogsService.instance.addLog(
              '[AI] generateText attempt $attempt failed | $_lastError',
              category: LogCategory.AI,
            );
          }
        } catch (e) {
          _lastError = 'Attempt $attempt failed: $e';
          SystemLogsService.instance.addLog(
            '[AI] generateText attempt $attempt error | $e',
            category: LogCategory.AI,
          );
        }
        if (attempt < 2) await Future.delayed(Duration(milliseconds: 1000 * attempt));
      }
      SystemLogsService.instance.addLog(
        '[AI] generateText → falling back to OpenAI',
        category: LogCategory.AI,
      );
      final fallback = await _fallbackToOpenAI(messages, temperature: temperature);
      if (fallback != null) {
        _lastResponseReceived = fallback;
        notifyListeners();
      }
      return fallback;
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
    Map<String, dynamic>? format, // Ollama structured output schema
  }) async {
    final usedModel = model ?? defaultModel;
    final userMsg = messages.lastWhere((m) => m['role'] == 'user', orElse: () => {})['content'] ?? '';
    SystemLogsService.instance.addLog(
      '[AI] sendChat | user: ${userMsg.length > 120 ? '${userMsg.substring(0, 120)}…' : userMsg}',
      category: LogCategory.AI,
    );
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
            'model': usedModel,
            'messages': messages,
            'stream': false,
          };
          if (options.isNotEmpty) body['options'] = options;
          if (format != null) body['format'] = format;

          SystemLogsService.instance.addLog(
            '[AI] sendChat attempt $attempt → POST $baseUrl/api/chat',
            category: LogCategory.AI,
          );

          final response = await http.post(
            Uri.parse('$baseUrl/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          ).timeout(Duration(milliseconds: timeoutMs));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final result = data['message']['content'] as String?;
            SystemLogsService.instance.addLog(
              '[AI] sendChat success | response: ${result != null && result.length > 120 ? '${result.substring(0, 120)}…' : result}',
              category: LogCategory.AI,
            );
            return result;
          } else {
            _lastError = 'Server returned ${response.statusCode}: ${response.body}';
            SystemLogsService.instance.addLog(
              '[AI] sendChat attempt $attempt failed | $_lastError',
              category: LogCategory.AI,
            );
          }
        } catch (e) {
          _lastError = 'Attempt $attempt failed: $e';
          SystemLogsService.instance.addLog(
            '[AI] sendChat attempt $attempt error | $e',
            category: LogCategory.AI,
          );
        }
        if (attempt < 2) await Future.delayed(Duration(milliseconds: 1000 * attempt));
      }
      SystemLogsService.instance.addLog(
        '[AI] sendChat → falling back to OpenAI',
        category: LogCategory.AI,
      );
      return await _fallbackToOpenAI(messages, temperature: temperature);
    } finally {
      _setProcessing(false);
    }
  }

  // --- AI UTILITY PIPELINES ---

  /// Utility 1: Prompt Review
  /// Analyzes a prompt for ambiguity, missing reqs, weak constraints, etc.
  Future<String?> reviewPrompt(String userPrompt) async {
    SystemLogsService.instance.addLog(
      '[AI] reviewPrompt called | prompt: ${userPrompt.length > 120 ? '${userPrompt.substring(0, 120)}…' : userPrompt}',
      category: LogCategory.AI,
    );
    final systemPrompt = clarityPrompt;

    // We use a low temperature for deterministic orchestration tasks
    final result = await sendChat(
      [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      temperature: 0.2,
      topP: 0.9,
    );
    SystemLogsService.instance.addLog(
      '[AI] reviewPrompt result | ${result ?? 'null (failed)'}',
      category: LogCategory.AI,
    );
    return result;
  }

  /// Checks if a checklist item prompt is clear.
  /// Returns a record: (isUnclear, notes) where notes is an explanation when unclear.
  /// Uses Ollama structured output to guarantee the response schema.
  Future<(bool, String?)?> checkClarity(String promptText) async {
    final isBinary = clarityResponseFormat == 'binary';

    final userPrompt = clarityPrompt.contains('{PROMPT}')
        ? clarityPrompt.replaceAll('{PROMPT}', promptText)
        : '$clarityPrompt $promptText';

    SystemLogsService.instance.addLog(
      '[AI] checkClarity | prompt: ${promptText.length > 80 ? '${promptText.substring(0, 80)}…' : promptText}',
      category: LogCategory.AI,
    );

    if (isBinary) {
      // Schema: no 'description' on notes — small models treat it as example content
      // and hallucinate. The notes instruction is baked into the prompt text instead.
      const schema = <String, dynamic>{
        'type': 'object',
        'properties': {
          'answer': {
            'type': 'string',
            'enum': ['YES', 'NO'],
          },
          'notes': {
            'type': 'string',
          },
        },
        'required': ['answer', 'notes'],
      };

      final raw = await generateText(
        userPrompt,
        format: schema,
        temperature: 0.0,
        numPredict: 120,
      );

      if (raw == null) {
        SystemLogsService.instance.addLog('[AI] checkClarity | no response', category: LogCategory.AI);
        return null;
      }

      try {
        final decoded = jsonDecode(raw);
        final answer = (decoded['answer'] as String? ?? '').toUpperCase();
        final notes = decoded['notes'] as String?;
        final isUnclear = answer == 'NO';
        SystemLogsService.instance.addLog(
          '[AI] checkClarity | answer=$answer unclear=$isUnclear | notes: ${notes ?? ''}',
          category: LogCategory.AI,
        );
        return (isUnclear, isUnclear ? notes : null);
      } catch (e) {
        // Fallback if JSON parse fails
        final isUnclear = raw.trim().toUpperCase().contains('NO');
        SystemLogsService.instance.addLog(
          '[AI] checkClarity | JSON parse failed, fallback → unclear=$isUnclear | raw: $raw',
          category: LogCategory.AI,
        );
        return (isUnclear, null);
      }
    } else {
      final result = await generateText(userPrompt, temperature: 0.0);
      if (result == null) return null;
      final isUnclear = result.trim().toUpperCase().contains('NO');
      SystemLogsService.instance.addLog(
        '[AI] checkClarity | response: "${result.trim()}" → unclear=$isUnclear',
        category: LogCategory.AI,
      );
      return (isUnclear, null);
    }
  }

  /// Utility 1b: Task Generator
  /// Given a description, returns a structured task title + checklist items.
  /// Uses Ollama structured output to guarantee the response schema.
  Future<({String title, List<String> checklistItems})?> generateTask(String description) async {
    SystemLogsService.instance.addLog(
      '[AI] generateTask called | desc: ${description.length > 120 ? '${description.substring(0, 120)}…' : description}',
      category: LogCategory.AI,
    );

    const schema = <String, dynamic>{
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'checklistItems': {
          'type': 'array',
          'items': {'type': 'string'},
        },
      },
      'required': ['title', 'checklistItems'],
    };

    final prompt = generateTaskPrompt.replaceAll('{DESCRIPTION}', description);

    final raw = await generateText(
      prompt,
      format: schema,
      temperature: 0.3,
      numPredict: 400,
    );

    if (raw == null) {
      SystemLogsService.instance.addLog('[AI] generateTask | no response', category: LogCategory.AI);
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      final title = (decoded['title'] as String? ?? '').trim();
      final items = (decoded['checklistItems'] as List<dynamic>? ?? [])
          .map((e) => (e as String).trim())
          .where((e) => e.isNotEmpty)
          .toList();
      SystemLogsService.instance.addLog(
        '[AI] generateTask | title="$title" items=${items.length}',
        category: LogCategory.AI,
      );
      return (title: title, checklistItems: items);
    } catch (e) {
      SystemLogsService.instance.addLog('[AI] generateTask | JSON parse failed: $e | raw: $raw', category: LogCategory.AI);
      return null;
    }
  }

  /// Utility 2: Task Summarizer
  /// Summarizes workflow notes into objectives, completed, pending, etc.
  Future<String?> summarizeTask(String taskNotes) async {
    SystemLogsService.instance.addLog(
      '[AI] summarizeTask called | notes length: ${taskNotes.length} chars',
      category: LogCategory.AI,
    );
    final systemPrompt = '''
You are an expert project manager. Summarize the following task notes into a concise status report.
Include the following sections:
- **Objectives**
- **Completed**
- **Pending/Next Actions**
- **Blockers (if any)**

Keep the output brief, highly structured, and strictly derived from the provided notes.
''';

    final result = await sendChat(
      [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': taskNotes},
      ],
      temperature: 0.2,
      topP: 0.9,
    );
    SystemLogsService.instance.addLog(
      '[AI] summarizeTask result | ${result != null ? 'success (${result.length} chars)' : 'null (failed)'}',
      category: LogCategory.AI,
    );
    return result;
  }

  Future<String?> _fallbackToOpenAI(List<Map<String, String>> messages, {double? temperature}) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _lastError = '$_lastError (OpenAI fallback failed: No API Key found in .env)';
      SystemLogsService.instance.addLog(
        '[AI] OpenAI fallback skipped | no API key in .env',
        category: LogCategory.AI,
      );
      return null;
    }

    SystemLogsService.instance.addLog(
      '[AI] OpenAI fallback → POST https://api.openai.com/v1/chat/completions (gpt-4o-mini)',
      category: LogCategory.AI,
    );

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
        final result = data['choices'][0]['message']['content'] as String?;
        SystemLogsService.instance.addLog(
          '[AI] OpenAI fallback success | response: ${result != null && result.length > 120 ? '${result.substring(0, 120)}…' : result}',
          category: LogCategory.AI,
        );
        return result;
      } else {
        _lastError = 'OpenAI fallback failed: ${response.statusCode} - ${response.body}';
        SystemLogsService.instance.addLog(
          '[AI] OpenAI fallback failed | $_lastError',
          category: LogCategory.AI,
        );
        return null;
      }
    } catch (e) {
      _lastError = 'OpenAI fallback error: $e';
      SystemLogsService.instance.addLog(
        '[AI] OpenAI fallback error | $e',
        category: LogCategory.AI,
      );
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
