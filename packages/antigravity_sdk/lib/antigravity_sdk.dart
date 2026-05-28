library antigravity_sdk;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// Data Models
// ---------------------------------------------------------------------------

class AntigravityModel {
  final String id;
  final String displayName;
  final bool supportsReasoning;

  AntigravityModel({
    required this.id,
    required this.displayName,
    this.supportsReasoning = false,
  });
}

class ArtifactUpdate {
  final String taskId;
  final String notes;
  final String summary;
  final List<Map<String, dynamic>> verificationCriteria;

  ArtifactUpdate({
    required this.taskId,
    required this.notes,
    required this.summary,
    required this.verificationCriteria,
  });

  factory ArtifactUpdate.fromJson(Map<String, dynamic> json) {
    return ArtifactUpdate(
      taskId: json['taskId'] ?? '',
      notes: json['notes'] ?? '',
      summary: json['summary'] ?? '',
      verificationCriteria: (json['verificationCriteria'] as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }
}

// ---------------------------------------------------------------------------
// SubagentConnection
// Tracks a single running agentapi conversation.
// ---------------------------------------------------------------------------

class SubagentConnection {
  final String taskId;
  final String agentId; // conversationId returned by agentapi
  final _statusController = StreamController<String>.broadcast();
  bool _closed = false;
  String _currentStatus = 'Connecting...';

  Stream<String> get statusStream => _statusController.stream;
  String get currentStatus => _currentStatus;
  bool get isClosed => _closed;

  SubagentConnection({required this.taskId, required this.agentId}) {
    _statusController.add("Connecting...");
  }

  void updateStatus(String status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void close() {
    _closed = true;
    if (!_statusController.isClosed) {
      _statusController.close();
    }
  }
}

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

class AntigravityConfig {
  /// Path to the language_server.exe binary.
  final String binaryPath;

  /// The gRPC (HTTP/2 cleartext) address of the language server.
  final String lsAddress;

  /// The CSRF token required to authenticate with the language server.
  final String csrfToken;

  /// The active project ID associated with the current workspace.
  final String projectId;

  /// How often to poll get-conversation-metadata for status (in seconds).
  final int pollIntervalSeconds;

  /// Timeout after which we give up polling (in seconds).
  final int timeoutSeconds;

  /// The target model to use for conversations (e.g., flash_lite, flash, pro).
  final String? targetModel;

  /// The API key for Google AI Studio models.
  final String apiKey;

  const AntigravityConfig({
    this.binaryPath = '',
    this.lsAddress = 'localhost:8080',
    this.csrfToken = '6c867a8e-96cc-483d-a132-178ab094abe3',
    this.projectId = '',
    this.pollIntervalSeconds = 3,
    this.timeoutSeconds = 600,
    this.targetModel,
    this.apiKey = '',
  });

  AntigravityConfig copyWith({
    String? binaryPath,
    String? lsAddress,
    String? csrfToken,
    String? projectId,
    int? pollIntervalSeconds,
    int? timeoutSeconds,
    String? targetModel,
    String? apiKey,
  }) {
    return AntigravityConfig(
      binaryPath: binaryPath ?? this.binaryPath,
      lsAddress: lsAddress ?? this.lsAddress,
      csrfToken: csrfToken ?? this.csrfToken,
      projectId: projectId ?? this.projectId,
      pollIntervalSeconds: pollIntervalSeconds ?? this.pollIntervalSeconds,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      targetModel: targetModel ?? this.targetModel,
      apiKey: apiKey ?? this.apiKey,
    );
  }

  /// Resolves the binary path, falling back to the standard Windows install location.
  String get resolvedBinaryPath {
    if (binaryPath.isNotEmpty) return binaryPath;
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      return '$userProfile\\AppData\\Local\\Programs\\Antigravity\\resources\\bin\\language_server.exe';
    }
    return 'language_server';
  }
}

// ---------------------------------------------------------------------------
// AntigravityClient
// Uses subprocess calls to language_server.exe agentapi <subcommand>
// ---------------------------------------------------------------------------

class AntigravityClient {
  static AntigravityClient? _sharedInstance;

  static AntigravityClient get instance {
    _sharedInstance ??= AntigravityClient.custom();
    return _sharedInstance!;
  }

  static set instance(AntigravityClient client) {
    _sharedInstance = client;
  }

  factory AntigravityClient({String? apiKey}) {
    if (apiKey != null && apiKey.isNotEmpty) {
      instance.config = instance.config.copyWith(apiKey: apiKey);
    }
    return instance;
  }

  final _artifactUpdateController = StreamController<ArtifactUpdate>.broadcast();
  AntigravityConfig config;
  final void Function(String)? onLog;

  AntigravityClient.custom({
    this.config = const AntigravityConfig(),
    this.onLog,
    String? apiKey,
  }) {
    if (apiKey != null && apiKey.isNotEmpty) {
      config = config.copyWith(apiKey: apiKey);
    }
    models = AntigravityModelsClient(this);
  }

  late final AntigravityModelsClient models;

  Stream<ArtifactUpdate> get onArtifactUpdate => _artifactUpdateController.stream;

  void _log(String msg) {
    onLog?.call('[Antigravity SDK] $msg');
  }

  // -------------------------------------------------------------------------
  // Low-level subprocess helper
  // -------------------------------------------------------------------------

  void updateConfig(AntigravityConfig newConfig) {
    config = newConfig;
    _log('Updated configuration (targetModel: ${config.targetModel})');
  }

  /// Queries the language server binary for available models.
  Future<List<String>> getAvailableModels() async {
    final binary = config.resolvedBinaryPath;
    List<String> rawTiers = ['flash_lite', 'flash', 'pro'];
    try {
      final result = await Process.run(
        binary,
        ['agentapi'],
        environment: {
          ...Platform.environment,
          'ANTIGRAVITY_LS_ADDRESS': config.lsAddress,
          'ANTIGRAVITY_CSRF_TOKEN': config.csrfToken,
          if (config.apiKey.isNotEmpty) 'ANTIGRAVITY_API_KEY': config.apiKey,
        },
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      final stderr = result.stderr as String;
      final stdout = result.stdout as String;
      final output = '$stdout\n$stderr';
      
      final match = RegExp(r'--model=<([^>]+)>').firstMatch(output);
      if (match != null) {
        final modelsStr = match.group(1);
        if (modelsStr != null) {
          rawTiers = modelsStr.split('|').map((e) => e.trim()).toList();
        }
      }
    } catch (e) {
      _log('Failed to query available models: $e');
    }

    final List<String> versionedModels = [];
    for (final tier in rawTiers) {
      if (tier == 'flash_lite') {
        versionedModels.addAll([
          'gemini-1.5-flash-8b',
          'gemini-2.0-flash-lite',
          'gemini-2.5-flash-lite',
          'llama-3.1-8b',
        ]);
      } else if (tier == 'flash') {
        versionedModels.addAll([
          'gemini-1.5-flash',
          'gemini-2.0-flash',
          'gemini-2.5-flash',
          'gemini-3.5-flash',
          'claude-3-5-haiku',
          'llama-3.1-70b',
        ]);
      } else if (tier == 'pro') {
        versionedModels.addAll([
          'gemini-1.5-pro',
          'gemini-2.0-pro',
          'gemini-2.5-pro',
          'claude-3-5-sonnet',
          'llama-3.1-405b',
        ]);
      } else {
        versionedModels.add(tier);
      }
    }
    return versionedModels;
  }

  String _resolveModelTier(String model) {
    final lower = model.toLowerCase();
    if (lower.contains('lite') || lower.contains('8b')) {
      return 'flash_lite';
    } else if (lower.contains('pro') || lower.contains('sonnet') || lower.contains('405b')) {
      return 'pro';
    } else if (lower.contains('flash') || lower.contains('haiku') || lower.contains('70b')) {
      return 'flash';
    }
    return 'flash';
  }

  Future<Map<String, dynamic>?> _runAgentapi(List<String> args) async {
    final binary = config.resolvedBinaryPath;
    _log('Executing: agentapi ${args.join(' ')}');

    try {
      final env = {
        ...Platform.environment,
        'ANTIGRAVITY_LS_ADDRESS': config.lsAddress,
        'ANTIGRAVITY_CSRF_TOKEN': config.csrfToken,
        if (config.projectId.isNotEmpty) 'ANTIGRAVITY_PROJECT_ID': config.projectId,
        if (config.apiKey.isNotEmpty) 'ANTIGRAVITY_API_KEY': config.apiKey,
      };

      final result = await Process.run(
        binary,
        ['agentapi', ...args],
        environment: env,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      final stdout = result.stdout as String;
      final stderr = result.stderr as String;

      if (stderr.isNotEmpty) {
        _log('STDERR: ${stderr.trim()}');
      }

      if (stdout.isNotEmpty) {
        try {
          final parsed = jsonDecode(stdout.trim()) as Map<String, dynamic>;
          final error = parsed['error'];
          if (error != null && error.toString().isNotEmpty) {
            _log('[Error] $error');
          } else {
            final response = parsed['response'] as Map<String, dynamic>?;
            if (response != null) {
              if (response.containsKey('newConversation')) {
                final newConv = response['newConversation'] as Map<String, dynamic>?;
                if (newConv != null) {
                  final conversationId = newConv['conversationId'] ?? '';
                  _log('[System] Started conversation $conversationId');
                }
              }
            }
          }
          return parsed;
        } catch (e) {
          _log('JSON parse error: $e | stdout: ${stdout.trim()}');
        }
      }

      return {'exitCode': result.exitCode};
    } catch (e) {
      _log('Process.run failed: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // sendPrompt — sends a free-form prompt as a new conversation
  // -------------------------------------------------------------------------

  Future<void> sendPrompt(String text) async {
    _log('sendPrompt: "$text"');
    final args = <String>['new-conversation'];
    if (config.targetModel != null && config.targetModel!.isNotEmpty) {
      args.add('--model=${_resolveModelTier(config.targetModel!)}');
    }
    args.add(text);
    final result = await _runAgentapi(args);
    if (result == null) {
      _log('sendPrompt: no result from agentapi');
      return;
    }
    final conversationId = result['response']?['newConversation']?['conversationId'];
    if (conversationId == null || conversationId.isEmpty) {
      _log('sendPrompt: no conversationId in response');
      return;
    }
    _log('sendPrompt: started conversation $conversationId');

    // Poll for completion to display chat-like messages in the logs
    final connection = SubagentConnection(
      taskId: 'prompt_${DateTime.now().millisecondsSinceEpoch}',
      agentId: conversationId,
    );
    Future.microtask(() async {
      await _pollUntilComplete(connection, conversationId);
    });
  }

  // -------------------------------------------------------------------------
  // invokeSubagent — writes current_task.json and starts a conversation
  // -------------------------------------------------------------------------

  Future<SubagentConnection> invokeSubagent(Map<String, dynamic> context) async {
    final taskId = context['id'] ?? 'unknown_task';

    final connection = SubagentConnection(
      taskId: taskId,
      agentId: 'pending',
    );

    _log('invokeSubagent: preparing task $taskId');

    // Write current_task.json for the agent to consume
    try {
      final taskFile = File('.ai_bridge/current_task.json');
      await taskFile.parent.create(recursive: true);
      await taskFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(context),
        flush: true,
      );
      _log('invokeSubagent: wrote .ai_bridge/current_task.json');
    } catch (e) {
      _log('invokeSubagent: failed to write current_task.json: $e');
      connection.updateStatus('Error: failed to write task context');
      connection.close();
      return connection;
    }

    // Resolve ending instructions from context or tasks.json
    String endingInstructions = context['endingInstructions'] as String? ?? '';
    if (endingInstructions.isEmpty) {
      try {
        final tasksFile = File('.ai_bridge/tasks.json');
        if (tasksFile.existsSync()) {
          final content = tasksFile.readAsStringSync();
          final parsed = jsonDecode(content);
          if (parsed is Map<String, dynamic>) {
            endingInstructions = parsed['endingInstructions'] as String? ?? '';
          }
        }
      } catch (_) {}
    }

    // Kick off background execution
    Future.microtask(() async {
      try {
        final args = <String>['new-conversation'];
        if (config.targetModel != null && config.targetModel!.isNotEmpty) {
          args.add('--model=${_resolveModelTier(config.targetModel!)}');
        }
        var prompt = 'CRITICAL: You MUST read the `.ai_bridge/primary_directives.md` file natively using your tool to understand the GLOBAL CONSTRAINTS and NATIVE SYSTEM HOOKS before proceeding. Failure to do so will break the application.\n\nProcess bridge current_task.json';
        if (endingInstructions.isNotEmpty) {
          prompt += '\n\n$endingInstructions';
        }
        args.add(prompt);
        final result = await _runAgentapi(args);

        if (result == null) {
          _log('invokeSubagent: agentapi returned null');
          connection.updateStatus('Error: agentapi failed');
          connection.close();
          return;
        }

        final response = result['response'];
        final error = result['error'];

        if (error != null && error.toString().isNotEmpty) {
          _log('invokeSubagent: error from agentapi: $error');
          connection.updateStatus('Error: $error');
          connection.close();
          return;
        }

        final conversationId = response?['newConversation']?['conversationId'] as String?;
        if (conversationId == null || conversationId.isEmpty) {
          _log('invokeSubagent: no conversationId in response');
          connection.updateStatus('Error: no conversationId');
          connection.close();
          return;
        }

        _log('invokeSubagent: conversation started → $conversationId');
        connection.updateStatus('Running ($conversationId)');

        // Poll for completion
        await _pollUntilComplete(connection, conversationId);
      } catch (e) {
        _log('invokeSubagent: unexpected error: $e');
        connection.updateStatus('Error: $e');
        connection.close();
      }
    });

    return connection;
  }

  // -------------------------------------------------------------------------
  // Polls get-conversation-metadata until conversation ends or timeout
  // -------------------------------------------------------------------------

  Future<void> _pollUntilComplete(SubagentConnection connection, String conversationId) async {
    final deadline = DateTime.now().add(Duration(seconds: config.timeoutSeconds));
    final pollInterval = Duration(seconds: config.pollIntervalSeconds);
    final loggedSteps = <int>{};

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(pollInterval);

      if (connection.isClosed) return;

      final result = await _runAgentapi(['get-conversation-metadata', conversationId]);
      if (result == null) {
        _log('poll[$conversationId]: null result, retrying...');
        continue;
      }

      final metadata = result['response']?['conversationMetadata']?['metadata'];
      if (metadata == null) {
        _log('poll[$conversationId]: metadata not found yet, retrying...');
        continue;
      }

      // Check if the conversation is complete by looking at nested state data.
      // The transcript file existing indicates completion.
      final brainPath = '${Platform.environment['USERPROFILE'] ?? ''}\\.gemini\\antigravity\\brain\\$conversationId\\.system_generated\\logs\\transcript.jsonl';
      final transcriptFile = File(brainPath);

      if (await transcriptFile.exists()) {
        try {
          final lines = await transcriptFile.readAsLines();
          for (final line in lines) {
            if (line.trim().isEmpty) continue;
            try {
              final step = jsonDecode(line);
              final stepIndex = step['step_index'] as int?;
              if (stepIndex != null && !loggedSteps.contains(stepIndex)) {
                loggedSteps.add(stepIndex);
                final type = step['type'] as String?;
                final content = step['content'] as String?;
                final thinking = step['thinking'] as String?;
                
                if (type == 'USER_INPUT') {
                  String cleanContent = content ?? '';
                  if (cleanContent.contains('<USER_REQUEST>')) {
                    final start = cleanContent.indexOf('<USER_REQUEST>') + '<USER_REQUEST>'.length;
                    final end = cleanContent.indexOf('</USER_REQUEST>');
                    if (end != -1 && end > start) {
                      cleanContent = cleanContent.substring(start, end).trim();
                    }
                  }
                  _log('[User] $cleanContent');
                } else if (type == 'PLANNER_RESPONSE') {
                  final text = (thinking != null && thinking.isNotEmpty) ? thinking : (content ?? '');
                  if (text.isNotEmpty) {
                    _log('[Antigravity] $text');
                  }
                }
              }
            } catch (_) {}
          }

          final lastLine = lines.lastWhere((l) => l.trim().isNotEmpty, orElse: () => '');
          if (lastLine.isNotEmpty) {
            try {
              final step = jsonDecode(lastLine);
              final type = step['type'] as String?;
              final status = step['status'] as String?;
              // PLANNER_RESPONSE with DONE is the final step
              if (type == 'PLANNER_RESPONSE' && status == 'DONE') {
                _log('poll[$conversationId]: completed (transcript final step: PLANNER_RESPONSE DONE)');
                connection.updateStatus('Completed');
                _absorbConversationArtifacts(conversationId, connection.taskId);
                connection.close();
                return;
              }
            } catch (_) {}
          }
        } catch (e) {
          _log('poll[$conversationId]: transcript read error: $e');
        }
      }

      _log('poll[$conversationId]: still running...');
      int size = 0;
      if (await transcriptFile.exists()) {
        try {
          size = await transcriptFile.length();
        } catch (_) {}
      }
      if (size > 0) {
        final dotCount = 3 + ((size / 200).floor() % 8);
        final dots = '.' * dotCount;
        connection.updateStatus('Working$dots (${(size / 1024).toStringAsFixed(1)} KB)');
      } else {
        connection.updateStatus('Working...');
      }
    }

    _log('poll[$conversationId]: timed out after ${config.timeoutSeconds}s');
    connection.updateStatus('Timed out');
    connection.close();
  }

  // -------------------------------------------------------------------------
  // After completion, read any artifact files dropped by the agent
  // -------------------------------------------------------------------------

  void _absorbConversationArtifacts(String conversationId, String taskId) {
    _log('absorbArtifacts[$conversationId]: checking for artifact files...');

    try {
      // Check for .ai_bridge/latest_notes.json
      final notesFile = File('.ai_bridge/latest_notes.json');
      final verificationFile = File('.ai_bridge/latest_verification.json');
      final previewFile = File('.ai_bridge/latest_preview.json');

      String notes = '';
      String summary = '';
      List<Map<String, dynamic>> criteria = [];

      if (notesFile.existsSync()) {
        try {
          final content = notesFile.readAsStringSync();
          final json = jsonDecode(content) as Map<String, dynamic>;
          notes = json['notes']?.toString() ?? '';
          summary = json['summary']?.toString() ?? '';
          _log('absorbArtifacts: loaded notes (${notes.length} chars)');
        } catch (e) {
          _log('absorbArtifacts: notes parse error: $e');
        } finally {
          try {
            notesFile.deleteSync();
            _log('absorbArtifacts: deleted notes file');
          } catch (e) {
            _log('absorbArtifacts: failed to delete notes file: $e');
          }
        }
      }

      if (verificationFile.existsSync()) {
        try {
          final content = verificationFile.readAsStringSync();
          final list = jsonDecode(content) as List;
          criteria = list.map((e) => e as Map<String, dynamic>).toList();
          _log('absorbArtifacts: loaded ${criteria.length} verification criteria');
        } catch (e) {
          _log('absorbArtifacts: verification parse error: $e');
        } finally {
          try {
            verificationFile.deleteSync();
            _log('absorbArtifacts: deleted verification file');
          } catch (e) {
            _log('absorbArtifacts: failed to delete verification file: $e');
          }
        }
      }

      if (previewFile.existsSync()) {
        try {
          final content = previewFile.readAsStringSync();
          final list = jsonDecode(content) as List;
          final previewItems = list.map((e) => e as Map<String, dynamic>).toList();
          // Merge preview into criteria
          criteria.addAll(previewItems.map((item) => {
            ...item,
            'isPreview': true,
          }));
          _log('absorbArtifacts: loaded ${previewItems.length} preview items');
        } catch (e) {
          _log('absorbArtifacts: preview parse error: $e');
        } finally {
          try {
            previewFile.deleteSync();
            _log('absorbArtifacts: deleted preview file');
          } catch (e) {
            _log('absorbArtifacts: failed to delete preview file: $e');
          }
        }
      }

      if (notes.isNotEmpty || criteria.isNotEmpty) {
        _artifactUpdateController.add(ArtifactUpdate(
          taskId: taskId,
          notes: notes,
          summary: summary,
          verificationCriteria: criteria,
        ));
      }
    } catch (e) {
      _log('absorbArtifacts: error: $e');
    }
  }

  void dispose() {
    _artifactUpdateController.close();
  }
}

// ---------------------------------------------------------------------------
// Models Client
// ---------------------------------------------------------------------------

class AntigravityModelsClient {
  final AntigravityClient _client;

  AntigravityModelsClient(this._client);

  Future<List<AntigravityModel>> list() async {
    final rawModels = await _client.getAvailableModels();
    return rawModels.map<AntigravityModel>((m) {
      String displayName = m;
      bool supportsReasoning = m.contains('pro') || m.contains('thinking');
      if (m == 'gemini-1.5-flash-8b') displayName = 'Gemini 1.5 Flash-8B';
      else if (m == 'gemini-1.5-flash') displayName = 'Gemini 1.5 Flash';
      else if (m == 'gemini-1.5-pro') displayName = 'Gemini 1.5 Pro';
      else if (m == 'gemini-2.0-flash-lite') displayName = 'Gemini 2.0 Flash Lite';
      else if (m == 'gemini-2.0-flash') displayName = 'Gemini 2.0 Flash';
      else if (m == 'gemini-2.0-pro') displayName = 'Gemini 2.0 Pro';
      else if (m == 'gemini-2.5-flash-lite') displayName = 'Gemini 2.5 Flash Lite';
      else if (m == 'gemini-2.5-flash') displayName = 'Gemini 2.5 Flash';
      else if (m == 'gemini-3.5-flash') displayName = 'Gemini 3.5 Flash';
      else if (m == 'gemini-2.5-pro') displayName = 'Gemini 2.5 Pro';
      else if (m == 'claude-3-5-sonnet') displayName = 'Claude 3.5 Sonnet';
      else if (m == 'claude-3-5-haiku') displayName = 'Claude 3.5 Haiku';
      else if (m == 'llama-3.1-8b') displayName = 'Llama 3.1 8B';
      else if (m == 'llama-3.1-70b') displayName = 'Llama 3.1 70B';
      else if (m == 'llama-3.1-405b') displayName = 'Llama 3.1 405B';

      return AntigravityModel(
        id: m,
        displayName: displayName,
        supportsReasoning: supportsReasoning,
      );
    }).toList();
  }
}
