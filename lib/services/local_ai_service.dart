import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as path;
import 'system_logs_service.dart';
import 'ai_bridge_service.dart';

class LocalAiService extends ChangeNotifier {
  // Singleton pattern for easy access
  static final LocalAiService instance = LocalAiService._internal();
  LocalAiService._internal() {
    loadConfig();
  }

  factory LocalAiService() => instance;

  String baseUrl = 'http://localhost:11434';
  String defaultModel = 'qwen2.5:3b';

  /// Returns the custom context model when one has been built, otherwise the base model.
  String get effectiveModel => customModelName.isNotEmpty ? customModelName : defaultModel;

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
      customModelName = prefs.getString('ollamaCustomModelName') ?? '';
      customModelBase = prefs.getString('ollamaCustomModelBase') ?? '';
      customModelContextLength = prefs.getInt('ollamaCustomModelContextLength') ?? 4096;
      customModelSummaryTrimLength = prefs.getInt('ollamaCustomModelSummaryTrimLength') ?? 3000;
      final referenceFilesRaw = prefs.getStringList('ollamaCustomModelReferenceFiles');
      if (referenceFilesRaw != null) {
        customModelReferenceFiles = referenceFilesRaw;
      } else {
        // Default to including project_summary.md
        final defaultSummaryPath = '${AiBridgeService.instance.bridgeDirPath}/project_summary.md';
        customModelReferenceFiles = [defaultSummaryPath];
      }
      notifyListeners();
    } catch (_) {}
  }
  
  // --- Project context cache ---
  String? _cachedProjectSummary;

  /// Reads project_summary.md from the bridge directory once and caches the result.
  /// Returns an empty string if the file cannot be read.
  Future<String> _loadProjectSummary() async {
    if (_cachedProjectSummary != null) return _cachedProjectSummary!;
    try {
      final file = File('${AiBridgeService.instance.bridgeDirPath}/project_summary.md');
      if (await file.exists()) {
        _cachedProjectSummary = await file.readAsString();
        SystemLogsService.instance.addLog(
          '[AI] project_summary.md loaded (${_cachedProjectSummary!.length} chars)',
          category: LogCategory.AI,
        );
      } else {
        _cachedProjectSummary = '';
        SystemLogsService.instance.addLog(
          '[AI] project_summary.md not found — context will be omitted',
          category: LogCategory.AI,
        );
      }
    } catch (e) {
      _cachedProjectSummary = '';
      SystemLogsService.instance.addLog(
        '[AI] Failed to load project_summary.md: $e',
        category: LogCategory.AI,
      );
    }
    return _cachedProjectSummary!;
  }

  /// Clears the cached summary so it will be re-read on next use.
  void invalidateProjectSummaryCache() {
    _cachedProjectSummary = null;
  }

  // --- Custom Modelfile support ---

  /// The name of the custom Ollama model baked with project context (e.g. "gorilla-engine").
  /// Empty string means no custom model has been built yet.
  String customModelName = '';

  /// The base model the custom model was derived from (e.g. "qwen2.5:3b").
  String customModelBase = '';

  /// The num_ctx (context window size in tokens) baked into the custom model.
  /// Defaults to 4096. Set before building to change it.
  int customModelContextLength = 4096;

  /// Max characters of project_summary.md to include in the Modelfile system prompt.
  /// ~4 chars per token: 3000 chars ≈ 750 tokens. Defaults to 3000.
  int customModelSummaryTrimLength = 3000;

  List<String> customModelReferenceFiles = [];

  Future<void> addReferenceFile(String filePath) async {
    if (!customModelReferenceFiles.contains(filePath)) {
      customModelReferenceFiles.add(filePath);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('ollamaCustomModelReferenceFiles', customModelReferenceFiles);
      notifyListeners();
    }
  }

  Future<void> removeReferenceFile(String filePath) async {
    if (customModelReferenceFiles.contains(filePath)) {
      customModelReferenceFiles.remove(filePath);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('ollamaCustomModelReferenceFiles', customModelReferenceFiles);
      notifyListeners();
    }
  }

  String getFileSizeString(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        final bytes = file.lengthSync();
        if (bytes < 1024) return '$bytes B';
        if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return 'File not found';
    } catch (_) {
      return 'Unknown size';
    }
  }

  /// Generates a Modelfile from the current customModelReferenceFiles and runs
  /// `ollama create <name>` to bake the project context into a persistent model.
  /// Returns null on success, or an error message string on failure.
  Future<String?> buildAndInstallModelfile(String modelName, String baseModel) async {
    final buffer = StringBuffer();
    for (final filePath in customModelReferenceFiles) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final content = await file.readAsString();
          final fileName = path.basename(filePath);
          buffer.writeln('### Reference File: $fileName');
          buffer.writeln(content);
          buffer.writeln();
        }
      } catch (e) {
        SystemLogsService.instance.addLog(
          '[AI] Failed to read reference file $filePath: $e',
          category: LogCategory.ERROR,
        );
      }
    }

    final combinedContent = buffer.toString();

    // Trim summary to the configured character limit
    final trimmedSummary = combinedContent.length > customModelSummaryTrimLength
        ? '${combinedContent.substring(0, customModelSummaryTrimLength)}…'
        : combinedContent;
    final systemPrompt = trimmedSummary.isNotEmpty
        ? 'You are a project assistant for the following project. Use this context when evaluating tasks and checklist items:\n\n$trimmedSummary'
        : 'You are a helpful project assistant specializing in software development task management.';

    final modelfileContent = 'FROM $baseModel\nPARAMETER num_ctx $customModelContextLength\nSYSTEM """\n$systemPrompt\n"""\n';
    final modelfilePath = '${AiBridgeService.instance.bridgeDirPath}/Modelfile';

    try {
      // Write the Modelfile to disk
      await File(modelfilePath).writeAsString(modelfileContent);
      SystemLogsService.instance.addLog(
        '[AI] Modelfile written to $modelfilePath',
        category: LogCategory.AI,
      );

      // Run: ollama create <modelName> -f <modelfilePath>
      final result = await Process.run(
        'ollama',
        ['create', modelName, '-f', modelfilePath],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        customModelName = modelName;
        customModelBase = baseModel;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ollamaCustomModelName', modelName);
        await prefs.setString('ollamaCustomModelBase', baseModel);
        await prefs.setInt('ollamaCustomModelContextLength', customModelContextLength);
        await prefs.setInt('ollamaCustomModelSummaryTrimLength', customModelSummaryTrimLength);
        // Invalidate the model list so the new model appears in the dropdown
        notifyListeners();
        SystemLogsService.instance.addLog(
          '[AI] ollama create "$modelName" succeeded',
          category: LogCategory.AI,
        );
        return null; // success
      } else {
        final err = '${result.stdout}\n${result.stderr}'.trim();
        SystemLogsService.instance.addLog(
          '[AI] ollama create "$modelName" failed (exit ${result.exitCode}): $err',
          category: LogCategory.AI,
        );
        return err.isNotEmpty ? err : 'ollama create exited with code ${result.exitCode}';
      }
    } catch (e) {
      SystemLogsService.instance.addLog(
        '[AI] buildAndInstallModelfile error: $e',
        category: LogCategory.AI,
      );
      return e.toString();
    }
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
    final summaryLink = Uri.file(File('${AiBridgeService.instance.bridgeDirPath}/project_summary.md').absolute.path).toString();
    final processedPrompt = prompt.replaceAll('{SUMMARY}', summaryLink);
    final usedModel = model ?? effectiveModel;
    SystemLogsService.instance.addLog(
      '[AI] generateText | prompt: ${processedPrompt.length > 120 ? '${processedPrompt.substring(0, 120)}…' : processedPrompt}',
      category: LogCategory.AI,
    );
    // Track the outgoing prompt so the Bridge Monitor I/O tab can display it.
    // Fields are set BEFORE _setProcessing so the single notifyListeners() it
    // fires carries the updated prompt values — avoids calling notifyListeners()
    // synchronously inside a mouse-event callback (_debugDuringDeviceUpdate crash).
    _lastPromptSent = processedPrompt;
    _lastResponseReceived = '';
    _setProcessing(true);
    try {
      final messages = [{'role': 'user', 'content': processedPrompt}];
      
      await _startOllamaIfNeeded();

      for (int attempt = 1; attempt <= 2; attempt++) {
        try {
          final options = <String, dynamic>{};
          if (temperature != null) options['temperature'] = temperature;
          if (topP != null) options['top_p'] = topP;
          if (numPredict != null) options['num_predict'] = numPredict;

          final body = <String, dynamic>{
            'model': usedModel,
            'prompt': processedPrompt,
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
    final summaryLink = Uri.file(File('${AiBridgeService.instance.bridgeDirPath}/project_summary.md').absolute.path).toString();
    final processedMessages = messages.map((m) {
      final content = m['content'] ?? '';
      return content.contains('{SUMMARY}')
          ? {...m, 'content': content.replaceAll('{SUMMARY}', summaryLink)}
          : m;
    }).toList();
    final usedModel = model ?? effectiveModel;
    final userMsg = processedMessages.lastWhere((m) => m['role'] == 'user', orElse: () => {})['content'] ?? '';
    SystemLogsService.instance.addLog(
      '[AI] sendChat | user: ${userMsg.length > 120 ? '${userMsg.substring(0, 120)}…' : userMsg}',
      category: LogCategory.AI,
    );
    _lastPromptSent = userMsg;
    _lastResponseReceived = '';
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
            'messages': processedMessages,
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
            if (result != null) {
              _lastResponseReceived = result;
              notifyListeners();
            }
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
      final fallback = await _fallbackToOpenAI(processedMessages, temperature: temperature);
      if (fallback != null) {
        _lastResponseReceived = fallback;
        notifyListeners();
      }
      return fallback;
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
    // We use a low temperature for deterministic orchestration tasks
    final result = await sendChat(
      [
        {'role': 'system', 'content': clarityPrompt},
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
    String? apiKey;
    try {
      apiKey = dotenv.env['OPENAI_API_KEY'];
    } catch (_) {}
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
    String? apiKey;
    try {
      apiKey = dotenv.env['OPENAI_API_KEY'];
    } catch (_) {}
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

  @visibleForTesting
  void setProcessingForTesting(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }
}
