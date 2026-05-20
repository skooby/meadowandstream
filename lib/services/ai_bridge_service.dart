import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:uuid/uuid.dart';
import 'auto_backup_service.dart';
import 'macro_service.dart';
import 'version_control_service.dart';
import 'sandbox_service.dart';
import 'package:antigravity_sdk/antigravity_sdk.dart';
import 'backend_process_manager.dart';
import 'system_logs_service.dart';

enum UpdateCoverType { hotReload, hotRestart, rebuild }

enum AntigravityBridgeMode { sdk, cli }


enum AiTaskStatus { open, inProgress, inTesting, inReview, completed, bug }

enum AiTaskPriority { none, low, medium, high, urgent }

AiTaskStatus _parseLegacyStatus(String? status) {
  if (status == 'queued') return AiTaskStatus.inProgress;
  if (status == 'queuedBug') return AiTaskStatus.bug;
  return AiTaskStatus.values.firstWhere(
    (e) => e.name == status,
    orElse: () => AiTaskStatus.open,
  );
}

class AiReviewQuestion {
  String question;
  List<String> options;
  String? selectedOption;

  AiReviewQuestion(
      {required this.question, required this.options, this.selectedOption});

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'selectedOption': selectedOption,
      };

  factory AiReviewQuestion.fromJson(Map<String, dynamic> json) =>
      AiReviewQuestion(
        question: json['question'] ?? '',
        options: (json['options'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        selectedOption: json['selectedOption'],
      );
}


enum AiVerificationStatus { none, pendingReview, verified, ignored }

class AiVerificationCriteria {
  String description;
  String goal;
  bool isVerified;
  AiVerificationStatus status;
  String? proof;
  bool requestClarification;
  int tryCount;
  List<String> attachments;
  bool isCommitted;
  bool isPreview;

  AiVerificationCriteria({
    required this.description,
    this.goal = '',
    this.isVerified = false,
    this.status = AiVerificationStatus.none,
    this.proof,
    this.requestClarification = false,
    this.tryCount = 0,
    this.isCommitted = false,
    this.isPreview = false,
    List<String>? attachments,
  }) : attachments = attachments ?? [];


  Map<String, dynamic> toJson() => {
        'description': description,
        'goal': goal,
        'isVerified': isVerified,
        'status': status.name,
        'proof': proof,
        'requestClarification': requestClarification,
        'tryCount': tryCount,
        'attachments': attachments,
        'isCommitted': isCommitted,
        'isPreview': isPreview,
      };

  factory AiVerificationCriteria.fromJson(Map<String, dynamic> json) {
    AiVerificationStatus parsedStatus = AiVerificationStatus.none;
    if (json.containsKey('status') && json['status'] != null) {
      parsedStatus = AiVerificationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AiVerificationStatus.none,
      );
    } else if (json.containsKey('isVerified') && json['isVerified'] == true) {
      parsedStatus = AiVerificationStatus.pendingReview;
    }

    return AiVerificationCriteria(
      description: json['description'] ?? '',
      goal: json['goal'] ?? '',
      isVerified: json['isVerified'] ?? false,
      status: parsedStatus,
      proof: json['proof'],
      requestClarification: json['requestClarification'] ?? false,
      tryCount: json['tryCount'] ?? 0,
      isCommitted: json['isCommitted'] ?? false,
      isPreview: json['isPreview'] ?? false,
      attachments: json['attachments'] != null
          ? List<String>.from(json['attachments'])
          : [],
    );
  }
}

class AiWorksheet {
  String id;
  String name;
  int iconCodePoint;
  bool isVisible;

  AiWorksheet({
    required this.id,
    required this.name,
    this.iconCodePoint = 0xe6bd, // Icons.work
    this.isVisible = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'isVisible': isVisible,
    };
  }

  factory AiWorksheet.fromJson(Map<String, dynamic> json) {
    return AiWorksheet(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      iconCodePoint: json['iconCodePoint'] ?? 0xe6bd,
      isVisible: json['isVisible'] ?? true,
    );
  }
}

class AiTask {
  String id;
  String name;
  String description;
  String summary;
  String notes;
  String implementationQuestion;
  List<AiReviewQuestion> reviewQuestions;
  List<AiVerificationCriteria> verificationCriteria;
  AiTaskStatus status;
  AiTaskPriority priority;
  bool isFolder;
  bool isWorksheet;
  bool isWorksheetVisible;
  String? parentId;
  String? worksheetId;
  int? highlightColor;
  int? iconBackgroundColor;
  int? iconColor;
  int? toolbarIconColor;
  int? iconCodePoint;
  bool isRead;
  bool isNote;
  bool isKnowledgeSummary;
  bool preventDeletion;
  bool applyLocksToChildren;
  bool isReadOnly;
  bool isIgnored;
  String llmPromptStyleOverride;
  AiTask? proposedChanges;
  List<String> fileAttachments;
  List<String> hyperlinks;
  String? commitHash;
  String? commitDate;

  AiTask({
    required this.id,
    required this.name,
    required this.description,
    this.summary = '',
    this.notes = '',
    this.implementationQuestion = '',
    List<AiReviewQuestion>? reviewQuestions,
    List<AiVerificationCriteria>? verificationCriteria,
    this.status = AiTaskStatus.open,
    this.priority = AiTaskPriority.none,
    this.isFolder = false,
    this.isWorksheet = false,
    this.isWorksheetVisible = true,
    this.parentId,
    this.worksheetId,
    this.highlightColor,
    this.iconBackgroundColor,
    this.iconColor,
    this.toolbarIconColor,
    this.iconCodePoint,
    this.isRead = false,
    this.isNote = false,
    this.isKnowledgeSummary = false,
    this.preventDeletion = false,
    this.applyLocksToChildren = false,
    this.isReadOnly = false,
    this.isIgnored = false,
    this.llmPromptStyleOverride = 'Use Default',
    this.proposedChanges,
    this.commitHash,
    this.commitDate,
    List<String>? fileAttachments,
    List<String>? hyperlinks,
  })  : reviewQuestions = reviewQuestions ?? [],
        verificationCriteria = verificationCriteria ?? [],
        fileAttachments = fileAttachments ?? [],
        hyperlinks = hyperlinks ?? [];

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {
      'id': id,
      'name': name,
      'description': description,
      'summary': summary,
      'notes': notes,
      'implementationQuestion': implementationQuestion,
      'reviewQuestions': reviewQuestions.map((e) => e.toJson()).toList(),
      'verificationCriteria':
          verificationCriteria.map((e) => e.toJson()).toList(),
      'status': status.name,
      'priority': priority.name,
      'isFolder': isFolder,
      'isWorksheet': isWorksheet,
      'isWorksheetVisible': isWorksheetVisible,
      'isNote': isNote,
      'isKnowledgeSummary': isKnowledgeSummary,
      'isRead': isRead,
      'preventDeletion': preventDeletion,
      'applyLocksToChildren': applyLocksToChildren,
      'isReadOnly': isReadOnly,
      'isIgnored': isIgnored,
      'llmPromptStyleOverride': llmPromptStyleOverride,
      'fileAttachments': fileAttachments,
      'hyperlinks': hyperlinks,
      'commitHash': commitHash,
      'commitDate': commitDate,
    };
    if (parentId != null) map['parentId'] = parentId;
    if (worksheetId != null) map['worksheetId'] = worksheetId;
    if (highlightColor != null) map['highlightColor'] = highlightColor;
    if (iconBackgroundColor != null)
      map['iconBackgroundColor'] = iconBackgroundColor;
    if (iconColor != null) map['iconColor'] = iconColor;
    if (toolbarIconColor != null) map['toolbarIconColor'] = toolbarIconColor;
    if (iconCodePoint != null) map['iconCodePoint'] = iconCodePoint;
    if (proposedChanges != null)
      map['proposedChanges'] = proposedChanges!.toJson();
    return map;
  }

  factory AiTask.fromJson(Map<String, dynamic> json) {
    return AiTask(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      summary: json['summary'] ?? '',
      notes: json['notes'] ?? '',
      implementationQuestion: json['implementationQuestion'] ?? '',
      reviewQuestions: (json['reviewQuestions'] as List<dynamic>?)
              ?.map((e) => AiReviewQuestion.fromJson(e))
              .toList() ??
          [],
      verificationCriteria: (json['verificationCriteria'] as List<dynamic>?)
              ?.map((e) => AiVerificationCriteria.fromJson(e))
              .toList() ??
          [],
      status: _parseLegacyStatus(json['status']),
      priority: AiTaskPriority.values.firstWhere(
        (e) => e.name == (json['priority'] ?? 'none'),
        orElse: () => AiTaskPriority.none,
      ),
      isFolder: json['isFolder'] ?? false,
      isWorksheet: json['isWorksheet'] ?? false,
      isWorksheetVisible: json['isWorksheetVisible'] ?? true,
      parentId: json['parentId'],
      worksheetId: json['worksheetId'],
      highlightColor: json['highlightColor'] ?? json['color'],
      iconBackgroundColor: json['iconBackgroundColor'] ?? json['color'],
      iconColor: json['iconColor'] ?? json['textColor'],
      toolbarIconColor: json['toolbarIconColor'],
      iconCodePoint: json['iconCodePoint'],
      isRead: json['isRead'] ?? false,
      isNote: json['isNote'] ?? false,
      isKnowledgeSummary: json['isKnowledgeSummary'] ?? false,
      preventDeletion: json['preventDeletion'] ?? false,
      applyLocksToChildren: json['applyLocksToChildren'] ?? false,
      isReadOnly: json['isReadOnly'] ?? false,
      isIgnored: json['isIgnored'] ?? false,
      llmPromptStyleOverride: json['llmPromptStyleOverride'] ?? 'Use Default',
      proposedChanges: json['proposedChanges'] != null
          ? AiTask.fromJson(json['proposedChanges'])
          : null,
      fileAttachments: json['fileAttachments'] != null
          ? List<String>.from(json['fileAttachments'])
          : [],
      hyperlinks: json['hyperlinks'] != null
          ? List<String>.from(json['hyperlinks'])
          : [],
      commitHash: json['commitHash'] as String?,
      commitDate: json['commitDate'] as String?,
    );
  }
}

class TimelineCommit {
  final String id;
  final List<String> taskIds;
  final String title;
  final String summary;
  final String commitHash;
  final String commitDate;
  final String verifiedNotes;

  TimelineCommit({
    required this.id,
    required this.taskIds,
    required this.title,
    required this.summary,
    required this.commitHash,
    required this.commitDate,
    this.verifiedNotes = '',
  });

  TimelineCommit copyWith({
    String? id,
    List<String>? taskIds,
    String? title,
    String? summary,
    String? commitHash,
    String? commitDate,
    String? verifiedNotes,
  }) {
    return TimelineCommit(
      id: id ?? this.id,
      taskIds: taskIds ?? this.taskIds,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      commitHash: commitHash ?? this.commitHash,
      commitDate: commitDate ?? this.commitDate,
      verifiedNotes: verifiedNotes ?? this.verifiedNotes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskIds': taskIds,
    'title': title,
    'summary': summary,
    'commitHash': commitHash,
    'commitDate': commitDate,
    'verifiedNotes': verifiedNotes,
  };

  factory TimelineCommit.fromJson(Map<String, dynamic> json) => TimelineCommit(
    id: json['id'] ?? const Uuid().v4(),
    taskIds: (json['taskIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    title: json['title'] ?? '',
    summary: json['summary'] ?? '',
    commitHash: json['commitHash'] ?? '',
    commitDate: json['commitDate'] ?? '',
    verifiedNotes: json['verifiedNotes'] ?? '',
  );
}

class QueuedPrompt {
  final String text;
  final bool block;
  final List<String>? taskIds;
  DateTime? completedAt;

  QueuedPrompt(this.text, this.block, this.taskIds, {this.completedAt});

  Map<String, dynamic> toJson() => {
        'text': text,
        'block': block,
        'taskIds': taskIds,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory QueuedPrompt.fromJson(Map<String, dynamic> json) {
    final taskIdsData = json['taskIds'] as List<dynamic>?;
    return QueuedPrompt(
      json['text'] as String,
      json['block'] == true,
      taskIdsData?.map((e) => e.toString()).toList(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
    );
  }
}

class AiBridgeService extends ChangeNotifier with WindowListener {
  static final AiBridgeService instance = AiBridgeService._internal();

  late final AntigravityClient antigravityClient;

  AiBridgeService._internal() {
    _initClient();
  }

  Future<void> _ensureBackendRunning() async {
    final prefs = await SharedPreferences.getInstance();
    final startupCmd = prefs.getString('antigravity_startup_command') ?? 'antigravity-server';
    final resolvedCmd = BackendProcessManager().getResolvedStartupCommand(startupCmd);

    // Parse port
    int port = 8080;
    final portMatch = RegExp(r'--http_server_port\s+([^\s]+)').firstMatch(resolvedCmd);
    if (portMatch != null) {
      port = int.tryParse(portMatch.group(1)!.replaceAll('"', '').replaceAll("'", "")) ?? 8080;
    }

    try {
      final socket = await Socket.connect('127.0.0.1', port, timeout: const Duration(seconds: 1));
      socket.destroy();
      debugPrint('[AiBridgeService] Antigravity daemon is already running on port $port.');
    } catch (e) {
      debugPrint('[AiBridgeService] Antigravity daemon unreachable on port $port. Attempting auto-spawn...');
      try {
        await BackendProcessManager().spawnBackend(startupCmd);
        await Future.delayed(const Duration(seconds: 4)); // Wait for server to bind
      } catch (spawnErr) {
        debugPrint('[AiBridgeService] Auto-spawn failed: $spawnErr');
      }
    }
  }

  Future<void> _initClient() async {
    final prefs = await SharedPreferences.getInstance();
    final binaryPath = prefs.getString('antigravity_binary_path') ?? '';
    final startupCmd = prefs.getString('antigravity_startup_command') ?? 'antigravity-server';
    final resolvedCmd = BackendProcessManager().getResolvedStartupCommand(startupCmd);

    // Dynamically parse CSRF token from the startup command
    String csrfToken = '6c867a8e-96cc-483d-a132-178ab094abe3';
    final csrfMatch = RegExp(r'--csrf_token\s+([^\s]+)').firstMatch(resolvedCmd);
    if (csrfMatch != null) {
      csrfToken = csrfMatch.group(1)!.replaceAll('"', '').replaceAll("'", "");
    }

    // Dynamically parse address / hostport from preferences or startup command
    final baseUrl = prefs.getString('antigravity_base_url') ?? 'http://localhost:8080';
    var lsAddress = baseUrl.replaceFirst(RegExp(r'^https?://'), '');
    if (lsAddress.endsWith('/')) {
      lsAddress = lsAddress.substring(0, lsAddress.length - 1);
    }
    if (lsAddress.startsWith('localhost')) {
      lsAddress = lsAddress.replaceFirst('localhost', '127.0.0.1');
    }
    
    // If the base url has a host but no port, or if we want to fallback to the parsed port from startup command
    if (!lsAddress.contains(':')) {
      final portMatch = RegExp(r'--http_server_port\s+([^\s]+)').firstMatch(resolvedCmd);
      if (portMatch != null) {
        final port = portMatch.group(1)!.replaceAll('"', '').replaceAll("'", "");
        lsAddress = '$lsAddress:$port';
      } else {
        lsAddress = '$lsAddress:8080';
      }
    }

    // Dynamically resolve the project ID for the current workspace
    String projectId = '';
    final envId = Platform.environment['ANTIGRAVITY_PROJECT_ID'];
    if (envId != null && envId.isNotEmpty) {
      projectId = envId;
    } else {
      try {
        final userProfile = Platform.environment['USERPROFILE'] ?? '';
        final projectsDir = Directory('$userProfile\\.gemini\\config\\projects');
        if (await projectsDir.exists()) {
          final currentPathNormalized = Directory.current.absolute.path.replaceAll('\\', '/').toLowerCase();
          await for (final entity in projectsDir.list()) {
            if (entity is File && entity.path.endsWith('.json')) {
              try {
                final content = await entity.readAsString();
                final json = jsonDecode(content);
                final id = json['id'] as String?;
                final resources = json['projectResources']?['resources'] as List?;
                if (resources != null && id != null) {
                  for (final res in resources) {
                    final folderUri = res['gitFolder']?['folderUri'] as String?;
                    if (folderUri != null) {
                      final decodedUri = Uri.decodeFull(folderUri).replaceAll('\\', '/').toLowerCase();
                      if (decodedUri.contains(currentPathNormalized)) {
                        projectId = id;
                        break;
                      }
                    }
                  }
                }
              } catch (_) {}
              if (projectId.isNotEmpty) break;
            }
          }
        }
      } catch (e) {
        debugPrint('[AiBridgeService] Error scanning projects configuration directory: $e');
      }
    }

    final targetModel = prefs.getString('antigravity_model') ?? 'gemini-2.0-flash';

    debugPrint('[AiBridgeService] Configured Antigravity SDK with address: $lsAddress, token: $csrfToken, projectId: $projectId, model: $targetModel');

    final apiKey = prefs.getString('antigravity_api_key') ?? '';

    antigravityClient = AntigravityClient.custom(
      config: AntigravityConfig(
        binaryPath: binaryPath,
        lsAddress: lsAddress,
        csrfToken: csrfToken,
        projectId: projectId,
        targetModel: targetModel,
        apiKey: apiKey,
      ),
      onLog: (logMessage) {
        SystemLogsService.instance.addLog(logMessage, category: LogCategory.AI);
      },
    );
    AntigravityClient.instance = antigravityClient;

    // Fetch and log available models at start for testing
    Future.microtask(() async {
      try {
        final models = await AntigravityClient().models.list();
        final sb = StringBuffer('Available Antigravity Models:\n');
        for (final m in models) {
          sb.writeln('  - ${m.id} (${m.displayName}) [reasoning: ${m.supportsReasoning}]');
        }
        final logMsg = sb.toString();
        debugPrint('[AiBridgeService] $logMsg');
        SystemLogsService.instance.addLog('[AiBridgeService] $logMsg', category: LogCategory.AI);
      } catch (e) {
        final errMsg = 'Error listing models at startup: $e';
        debugPrint('[AiBridgeService] $errMsg');
        SystemLogsService.instance.addLog('[AiBridgeService] $errMsg', category: LogCategory.AI);
      }
    });

    // Subscribe to artifact updates
    antigravityClient.onArtifactUpdate.listen((update) {
      final taskIdx = _tasks.indexWhere((t) => t.id == update.taskId);
      if (taskIdx != -1) {
        if (update.notes.isNotEmpty) {
          final dateStr = DateTime.now().toLocal().toString().substring(0, 16);
          final entry = '### Update - $dateStr\n${update.notes}\n\n---\n\n';
          if (_tasks[taskIdx].notes.trim().isNotEmpty) {
            _tasks[taskIdx].notes = entry + _tasks[taskIdx].notes;
          } else {
            _tasks[taskIdx].notes = entry.trim();
          }
        }
        if (update.summary.isNotEmpty) {
          _tasks[taskIdx].summary = update.summary;
        }
        if (update.verificationCriteria.isNotEmpty) {
          final existing = _tasks[taskIdx].verificationCriteria;
          final incoming = update.verificationCriteria
              .map((c) => AiVerificationCriteria.fromJson(c))
              .toList();

          final merged = <AiVerificationCriteria>[];
          final usedIncoming = <String>{};

          for (var ext in existing) {
            final extDescNorm = ext.description.trim();
            final matchIndex = incoming.indexWhere((inc) => inc.description.trim() == extDescNorm);

            if (matchIndex != -1) {
              final match = incoming[matchIndex];
              usedIncoming.add(match.description);

              // Preserve verified/ignored/pendingReview status set by user in UI
              final resolvedStatus = ext.status != AiVerificationStatus.none ? ext.status : match.status;
              final resolvedIsVerified = ext.isVerified || match.isVerified;

              merged.add(AiVerificationCriteria(
                description: ext.description,
                goal: (match.goal.isNotEmpty) ? match.goal : ext.goal,
                isVerified: resolvedIsVerified,
                status: resolvedStatus,
                proof: match.proof ?? ext.proof,
                requestClarification: match.requestClarification || ext.requestClarification,
                tryCount: match.tryCount > ext.tryCount ? match.tryCount : ext.tryCount,
                attachments: ext.attachments.isNotEmpty ? ext.attachments : match.attachments,
                isCommitted: ext.isCommitted || match.isCommitted,
                isPreview: ext.isPreview || match.isPreview,
              ));
            } else {
              // Not found in incoming, keep the existing item intact
              merged.add(ext);
            }
          }

          // Add any new incoming criteria (e.g. preview items or newly added ones)
          for (var inc in incoming) {
            if (!usedIncoming.contains(inc.description)) {
              merged.add(inc);
            }
          }

          _tasks[taskIdx].verificationCriteria = merged;
        }
        _save();
        notifyListeners();
      }
    });

    init();
  }

  Future<void> updateAntigravityConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final binaryPath = prefs.getString('antigravity_binary_path') ?? '';
    final startupCmd = prefs.getString('antigravity_startup_command') ?? 'antigravity-server';
    final resolvedCmd = BackendProcessManager().getResolvedStartupCommand(startupCmd);

    // Dynamically parse CSRF token from the startup command
    String csrfToken = '6c867a8e-96cc-483d-a132-178ab094abe3';
    final csrfMatch = RegExp(r'--csrf_token\s+([^\s]+)').firstMatch(resolvedCmd);
    if (csrfMatch != null) {
      csrfToken = csrfMatch.group(1)!.replaceAll('"', '').replaceAll("'", "");
    }

    // Dynamically parse address / hostport from preferences or startup command
    final baseUrl = prefs.getString('antigravity_base_url') ?? 'http://localhost:8080';
    var lsAddress = baseUrl.replaceFirst(RegExp(r'^https?://'), '');
    if (lsAddress.endsWith('/')) {
      lsAddress = lsAddress.substring(0, lsAddress.length - 1);
    }
    if (lsAddress.startsWith('localhost')) {
      lsAddress = lsAddress.replaceFirst('localhost', '127.0.0.1');
    }
    
    if (!lsAddress.contains(':')) {
      final portMatch = RegExp(r'--http_server_port\s+([^\s]+)').firstMatch(resolvedCmd);
      if (portMatch != null) {
        final port = portMatch.group(1)!.replaceAll('"', '').replaceAll("'", "");
        lsAddress = '$lsAddress:$port';
      } else {
        lsAddress = '$lsAddress:8080';
      }
    }

    String projectId = '';
    final envId = Platform.environment['ANTIGRAVITY_PROJECT_ID'];
    if (envId != null && envId.isNotEmpty) {
      projectId = envId;
    } else {
      try {
        final userProfile = Platform.environment['USERPROFILE'] ?? '';
        final projectsDir = Directory('$userProfile\\.gemini\\config\\projects');
        if (await projectsDir.exists()) {
          final currentPathNormalized = Directory.current.absolute.path.replaceAll('\\', '/').toLowerCase();
          await for (final entity in projectsDir.list()) {
            if (entity is File && entity.path.endsWith('.json')) {
              try {
                final content = await entity.readAsString();
                final json = jsonDecode(content);
                final id = json['id'] as String?;
                final resources = json['projectResources']?['resources'] as List?;
                if (resources != null && id != null) {
                  for (final res in resources) {
                    final folderUri = res['gitFolder']?['folderUri'] as String?;
                    if (folderUri != null) {
                      final decodedUri = Uri.decodeFull(folderUri).replaceAll('\\', '/').toLowerCase();
                      if (decodedUri.contains(currentPathNormalized)) {
                        projectId = id;
                        break;
                      }
                    }
                  }
                }
              } catch (_) {}
              if (projectId.isNotEmpty) break;
            }
          }
        }
      } catch (e) {
        debugPrint('[AiBridgeService] Error scanning projects configuration directory: $e');
      }
    }

    final targetModel = prefs.getString('antigravity_model') ?? 'gemini-2.0-flash';

    debugPrint('[AiBridgeService] Updating Antigravity SDK Config with address: $lsAddress, token: $csrfToken, projectId: $projectId, model: $targetModel');

    final apiKey = prefs.getString('antigravity_api_key') ?? '';

    antigravityClient.updateConfig(
      AntigravityConfig(
        binaryPath: binaryPath,
        lsAddress: lsAddress,
        csrfToken: csrfToken,
        projectId: projectId,
        targetModel: targetModel,
        apiKey: apiKey,
      ),
    );
  }

  final String _dirPath = '.ai_bridge';
  final String _filePath = '.ai_bridge/tasks.json';

  StreamSubscription<FileSystemEvent>? _watchSubscription;
  StreamSubscription<FileSystemEvent>? _libWatchSubscription;
  StreamSubscription<FileSystemEvent>? _rootWatchSubscription;
  bool _isSavingLocally = false;

  @override
  void dispose() {
    windowManager.removeListener(this);
    _watchSubscription?.cancel();
    _libWatchSubscription?.cancel();
    _rootWatchSubscription?.cancel();
    _antigravityPollTimer?.cancel();
    _queueCleanupTimer?.cancel();
    super.dispose();
  }

  List<AiTask> get worksheets => _tasks.where((t) => t.isWorksheet).toList();
  List<AiTask> _tasks = [];
  List<AiTask> get tasks => _tasks;

  List<TimelineCommit> _timelineHistory = [];
  List<TimelineCommit> get timelineHistory => _timelineHistory;

  final Map<String, List<String>> _uncommittedCompletedCriteria = {};

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _isUndoRedoing = false;

  bool _showUpdateCover = false;
  bool get showUpdateCover => _showUpdateCover;

  UpdateCoverType _updateCoverType = UpdateCoverType.hotReload;
  UpdateCoverType get updateCoverType => _updateCoverType;

  UpdateCoverType? _pendingUpdateType;

  bool _isQueuePaused = false;
  bool get isQueuePaused => _isQueuePaused;

  bool _wasQueuePausedForFocus = false;

  bool _isPreviewMode = false;
  bool get isPreviewMode => _isPreviewMode;

  bool _isIqMode = false;
  bool get isIqMode => _isIqMode;

  void setPreviewMode(bool p) {
    _isPreviewMode = p;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool('ai_queue_preview_mode', p));
    notifyListeners();
  }

  void setIqMode(bool p) {
    _isIqMode = p;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool('ai_queue_iq_mode', p));
    notifyListeners();
  }

  void setQueuePaused(bool p) {
    _isQueuePaused = p;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool('ai_queue_paused', p));
    _processQueue();
    notifyListeners();
  }

  AntigravityBridgeMode _bridgeMode = AntigravityBridgeMode.sdk;
  AntigravityBridgeMode get bridgeMode => _bridgeMode;

  void setBridgeMode(AntigravityBridgeMode mode) async {
    _bridgeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('antigravity_bridge_mode', mode.name);
  }

  final List<QueuedPrompt> _pendingPrompts = [];
  final List<QueuedPrompt> _completedPrompts = [];
  QueuedPrompt? _activePrompt;

  List<QueuedPrompt> get pendingPrompts => _pendingPrompts;
  List<QueuedPrompt> get completedPrompts => _completedPrompts;
  QueuedPrompt? get activePrompt => _activePrompt;

  String? _activeProcessingTaskId;
  DateTime? _activeProcessingTaskAssignedAt;
  int _compileErrorLoopCount = 0;
  bool _isHandlingAgentStatus = false;

  final Map<String, SubagentConnection> _activeAgents = {};
  Map<String, SubagentConnection> get activeAgents => Map.unmodifiable(_activeAgents);

  List<String> get activeTaskIds => _activeAgents.keys.toList();
  List<String> get pipelineTaskIds => [];
  List<String> get completedTaskIds => [];

  String _buildTaskPathName(AiTask task) {
    final path = <String>[];
    AiTask? current = task;
    final visited = <String>{};
    while (current != null) {
      if (visited.contains(current.id)) break;
      visited.add(current.id);
      path.insert(0, current.name);
      
      if (current.parentId != null) {
        current = _tasks.cast<AiTask?>().firstWhere(
          (t) => t?.id == current!.parentId,
          orElse: () => null,
        );
      } else if (current.worksheetId != null && !current.isWorksheet) {
        current = _tasks.cast<AiTask?>().firstWhere(
          (t) => t?.id == current!.worksheetId,
          orElse: () => null,
        );
      } else {
        current = null;
      }
    }
    return path.join(' > ');
  }

  void _writeCurrentTaskFile(String taskId) {
    try {
      final taskIdx = _tasks.indexWhere((t) => t.id == taskId);
      if (taskIdx == -1) return;
      final task = _tasks[taskIdx];
      final json = task.toJson();
      json['name'] = _buildTaskPathName(task);
      if (json['verificationCriteria'] != null) {
        final List<dynamic> vcList = json['verificationCriteria'] as List<dynamic>;
        json['verificationCriteria'] = vcList.where((e) => e['isPreview'] != true).toList();
      }
      File('$_dirPath/current_task.json').writeAsStringSync(jsonEncode(json));
    } catch (e) {
      debugPrint('Failed to write current_task.json: $e');
    }
  }

  Future<void> sendToQueue(String text, bool blockScreen,
      {List<String>? taskIds, bool insertFirst = false}) async {
    if (_bridgeMode == AntigravityBridgeMode.sdk) {
      if (taskIds != null && taskIds.isNotEmpty) {
        await SandboxService.instance.addToSandbox(taskIds);
        final taskId = taskIds.first;
        final taskIdx = _tasks.indexWhere((t) => t.id == taskId);
        if (taskIdx != -1) {
          await executeTask(_tasks[taskIdx]);
        }
      } else {
        await _ensureBackendRunning();
        await antigravityClient.sendPrompt(text);
      }
    } else {
      if (insertFirst) {
        _pendingPrompts.insert(0, QueuedPrompt(text, blockScreen, taskIds));
      } else {
        _pendingPrompts.add(QueuedPrompt(text, blockScreen, taskIds));
      }

      if (taskIds != null && taskIds.isNotEmpty) {
        await SandboxService.instance.addToSandbox(taskIds);
        if (!insertFirst) {
          _writeCurrentTaskFile(taskIds.first);
        }
      }

      await _saveQueueState();
      notifyListeners();

      if (_activeProcessingTaskId == null && _activePrompt == null) {
        await _processQueue();
      }
    }
  }

  Future<void> executeTask(AiTask task) async {
    await _ensureBackendRunning();
    final json = task.toJson();
    json['name'] = _buildTaskPathName(task);
    final connection = await antigravityClient.invokeSubagent(json);
    _activeAgents[task.id] = connection;
    notifyListeners();

    connection.statusStream.listen((status) {
      if (status == "Completed") {
        _activeAgents.remove(task.id);
        _isAntigravityBusy = false;
        _antigravityLastChangeObservedAt = null;
        triggerPendingUpdate(force: true);
      }
      notifyListeners();
    });
  }

  Future<void> _sendToAiAgent(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    await MacroService.instance.executeTrigger('BridgeConnect');

    final int myPid = pid;
    final vbsFile = File('$_dirPath/paste.vbs');
    if (!vbsFile.parent.existsSync()) {
      vbsFile.parent.createSync(recursive: true);
    }
    await vbsFile.writeAsString('''
Set wshShell = CreateObject("WScript.Shell")
WScript.Sleep 600
wshShell.SendKeys "^v"
WScript.Sleep 200
wshShell.SendKeys "~"
WScript.Sleep 300
wshShell.AppActivate $myPid
''');
    await Process.run('wscript', [vbsFile.path]);

    final statusFile = File('$_dirPath/agent_status.txt');
    await statusFile.writeAsString('BUSY');
  }

  String? _lastJsonParseError;
  String? get lastJsonParseError => _lastJsonParseError;

  void dismissJsonParseError() {
    _lastJsonParseError = null;
    notifyListeners();
  }

  void forceNextQueueItem() {
    _activeProcessingTaskId = null;
    _activeProcessingTaskAssignedAt = null;
    _activePrompt = null;
    notifyListeners();
    _processQueue();
  }

  Future<void> _saveQueueState() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> encoded =
        _pendingPrompts.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('ai_bridge_queue', encoded);
    final List<String> encodedCompleted =
        _completedPrompts.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('ai_bridge_completed_queue', encodedCompleted);
  }

  Future<void> _processQueue() async {
    if (_isQueuePaused) return;

    if (_activeProcessingTaskId != null || _activePrompt != null) {
      return;
    }

    if (_pendingPrompts.isNotEmpty) {
      final nextPrompt = _pendingPrompts.first;

      if (nextPrompt.taskIds != null && nextPrompt.taskIds!.isNotEmpty) {
        _activeProcessingTaskId = nextPrompt.taskIds!.first;
        _activeProcessingTaskAssignedAt = DateTime.now();

        try {
          final task = _tasks.firstWhere((t) => t.id == _activeProcessingTaskId!);
          if (task.priority == AiTaskPriority.high || task.priority == AiTaskPriority.urgent) {
             final desc = 'Auto-Checkpoint before ${task.name}';
             final hash = await VersionControlService.instance.createRestorePoint(desc);
             if (hash.isNotEmpty && !hash.startsWith('No changes') && !hash.startsWith('Failed') && !hash.startsWith('Local')) {
               await appendCheckpointToTimeline(desc, hash);
             }
          }
        } catch (_) {}
      } else {
        _activeProcessingTaskId = null;
        _activeProcessingTaskAssignedAt = null;
      }

      _activePrompt = nextPrompt;
      _pendingPrompts.removeAt(0);
      await _saveQueueState();
      notifyListeners();

      // Natively wait 8 seconds before dispatch to IDE to guarantee the queue settles perfectly and hot reloads reset focus securely
      await Future.delayed(const Duration(seconds: 8));

      await _sendToAiAgent(nextPrompt.text);
      setScreenBlockerEnabled(nextPrompt.block);
    }
  }

  void clearQueue() {
    _activeAgents.clear();
    _activeProcessingTaskId = null;
    _activePrompt = null;
    _pendingPrompts.clear();
    _completedPrompts.clear();
    _saveQueueState();
    notifyListeners();
  }

  void removeFromQueue(QueuedPrompt prompt) {
    _pendingPrompts.remove(prompt);
    _completedPrompts.remove(prompt);
    _saveQueueState();
    notifyListeners();
  }

  Future<void> forceDispatchCompileError(String errorLog) async {
    try {
      if (_activeProcessingTaskId != null) {
        await _absorbOrphanedFiles(_activeProcessingTaskId!);
      }

      if (_compileErrorLoopCount >= 3) {
        _isQueuePaused = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('ai_queue_paused', true);
        _compileErrorLoopCount = 0;

        try {
          File('$_dirPath/bridge_error.txt').writeAsStringSync('CRITICAL: AI failed to fix compile errors 3 times in a row. Queue paused automatically to prevent infinite loop.');
        } catch (_) {}

        _activeProcessingTaskId = null;
        _activeProcessingTaskAssignedAt = null;
        _activePrompt = null;
        notifyListeners();
        return;
      }

      _tasks.removeWhere((t) => t.name.toLowerCase() == 'fix compile errors');

      _compileErrorLoopCount++;

      final task = await addTask(
        'Fix compile errors',
        'The recent Hot Reload/Restart resulted in compilation errors. Fix them immediately.',
        notes: errorLog,
        status: AiTaskStatus.inProgress,
      );

      if (_tasks.isNotEmpty && _tasks.first.id != task.id) {
        await reorderBefore(task.id, _tasks.first.id);
      }

      _isQueuePaused = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ai_queue_paused', false);

      try {
        File('$_dirPath/bridge_error.txt').writeAsStringSync(errorLog);
      } catch (_) {}

      const promptText =
          '# PRIMARY DIRECTIVES\nVoice: Direct / Robotic\nComplexity: Concise\n\nCRITICAL COMPILER REJECTION! You violently broke the application build! I have natively intercepted your code changes and they failed background validation.\nRead the massive compilation failure log inside .ai_bridge/bridge_error.txt immediately. Patch the syntax errors dynamically and DO NOT push IDLE again until you have structurally verified your fix.';

      final p = QueuedPrompt(promptText, true, [task.id]);
      _pendingPrompts.insert(0, p);
      await _saveQueueState();

      _activeProcessingTaskId = null;
      _activeProcessingTaskAssignedAt = null;
      _activePrompt = null;
      notifyListeners();

      await _processQueue();
    } catch (e, st) {
      try {
        File('$_dirPath/bridge_error_debug.txt')
            .writeAsStringSync('forceDispatchCompileError crashed:\n\n$e\n$st');
      } catch (_) {}
    }
  }




  Future<void> _absorbOrphanedFiles(String taskId) async {
    try {
      final taskIdx = _tasks.indexWhere((t) => t.id == taskId);
      if (taskIdx == -1) return;
      bool changed = false;

      // Absorb Notes
      final notesFile = File('$_dirPath/latest_notes.json');
      if (notesFile.existsSync()) {
        try {
          final content = notesFile.readAsStringSync();
          notesFile.deleteSync();
          final jsonMap = jsonDecode(content);
          final parsedSummary = jsonMap['summary']?.toString().trim() ?? '';
          String parsedNotes = jsonMap['notes']?.toString().trim() ?? '';
          if (parsedSummary.isNotEmpty) {
            if (parsedNotes.isNotEmpty) {
              parsedNotes = '**$parsedSummary**\n\n$parsedNotes';
            } else {
              parsedNotes = '**$parsedSummary**';
            }
          }
          if (parsedNotes.isNotEmpty) {
            final dateStr = DateTime.now().toLocal().toString().substring(0, 16);
            final entry = '### Update - $dateStr\n$parsedNotes\n\n---\n\n';
            if (_tasks[taskIdx].notes.trim().isNotEmpty) {
              _tasks[taskIdx].notes = entry + _tasks[taskIdx].notes;
            } else {
              _tasks[taskIdx].notes = entry.trim();
            }
            changed = true;
          }
        } catch (_) {}
      }

      // Absorb Verification
      final verificationFile = File('$_dirPath/latest_verification.json');
      if (verificationFile.existsSync()) {
        try {
          final content = verificationFile.readAsStringSync();
          verificationFile.deleteSync();
          final List<dynamic> jsonList = jsonDecode(content);
          for (var item in jsonList) {
            final desc = item['description']?.toString().trim() ?? '';
            final proof = item['proof']?.toString().trim();
            if (desc.isNotEmpty) {
              final vcIdx = _tasks[taskIdx].verificationCriteria.indexWhere((vc) => vc.description == desc);
              if (vcIdx != -1) {
                _tasks[taskIdx].verificationCriteria[vcIdx].proof = proof;
                changed = true;
              }
            }
          }
        } catch (_) {}
      }

      // Absorb Preview
      final previewFile = File('$_dirPath/latest_preview.json');
      if (previewFile.existsSync()) {
        try {
          final content = previewFile.readAsStringSync();
          previewFile.deleteSync();
          final List<dynamic> jsonList = jsonDecode(content);
          final newItems = jsonList.map((e) => AiVerificationCriteria(
            description: e['description']?.toString() ?? 'Preview item',
            goal: e['goal']?.toString() ?? '',
            status: AiVerificationStatus.pendingReview,
            isVerified: false,
            isPreview: true,
          )).toList();
          _tasks[taskIdx].verificationCriteria.addAll(newItems);
          changed = true;
        } catch (_) {}
      }

    } catch (_) {}
  }



  void dismissUpdateCover() {
    _showUpdateCover = false;
    notifyListeners();
  }

  void showUpdateCoverFor(UpdateCoverType type) {
    if (!_showUpdateCover || _updateCoverType != type) {
      _updateCoverType = type;
      _showUpdateCover = true;
      notifyListeners();
    }
  }

  bool isWindowFocused = true;

  @override
  void onWindowFocus() {
    isWindowFocused = true;
    if (_pendingUpdateType != null && !isThinking) {
      triggerPendingUpdate();
    }
  }

  @override
  void onWindowBlur() {
    isWindowFocused = false;
  }

  bool _screenBlockerEnabledForCurrentTaskPhase = true;
  void setScreenBlockerEnabled(bool enabled) {
    _screenBlockerEnabledForCurrentTaskPhase = enabled;
  }

  Set<AiTaskStatus> _activeExportStatuses = {
    AiTaskStatus.inProgress,
    AiTaskStatus.bug
  };

  AiTaskStatus _defaultNewStatus = AiTaskStatus.open;
  AiTaskStatus get defaultNewStatus => _defaultNewStatus;

  AiTaskPriority _filterPriority = AiTaskPriority.none;
  AiTaskPriority get filterPriority => _filterPriority;

  void setFilterPriority(AiTaskPriority p) async {
    _filterPriority = p;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_tasks_filter_priority', p.name);
  }

  Future<void> syncPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final exportStatusesStrs =
        prefs.getStringList('ai_tasks_export_statuses') ??
            ['inProgress', 'bug'];
    _activeExportStatuses = exportStatusesStrs
        .map((s) => AiTaskStatus.values.firstWhere((e) => e.name == s,
            orElse: () => AiTaskStatus.inProgress))
        .toSet();

    final defaultStatusStr = prefs.getString('ai_tasks_new_status') ?? 'open';
    _defaultNewStatus = AiTaskStatus.values.firstWhere(
        (e) => e.name == defaultStatusStr,
        orElse: () => AiTaskStatus.open);

    final filterPriorityStr =
        prefs.getString('ai_tasks_filter_priority') ?? 'none';
    _filterPriority = AiTaskPriority.values.firstWhere(
        (e) => e.name == filterPriorityStr,
        orElse: () => AiTaskPriority.none);
  }

  bool _isAntigravityBusy = false;
  Map<String, DateTime> _antigravityLastModifiedTimes = {};
  DateTime? _antigravityLastChangeObservedAt;
  Timer? _antigravityPollTimer;
  Timer? _queueCleanupTimer;

  bool get isThinking =>
      _activeAgents.isNotEmpty ||
      _isAntigravityBusy ||
      _activePrompt != null;


  void _startWatchingAntigravity() {
    if (kIsWeb || (!Platform.isWindows && !Platform.isMacOS)) return;

    final String userProfile = Platform.environment['USERPROFILE'] ?? '';
    if (userProfile.isEmpty) return;
    final brainDir =
        Directory('$userProfile\\.gemini\\antigravity\\brain');

    _antigravityPollTimer =
        Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        bool foundBusy = false;
        if (brainDir.existsSync()) {
          final entities = brainDir.listSync(recursive: true, followLinks: false).whereType<File>();
          for (final file in entities) {
            if (file.path.endsWith('transcript.jsonl') ||
                file.path.endsWith('overview.txt')) {
              final stat = file.statSync();
              final prev = _antigravityLastModifiedTimes[file.path];
              if (prev != stat.modified) {
                _antigravityLastChangeObservedAt = DateTime.now();
              }
              _antigravityLastModifiedTimes[file.path] = stat.modified;
            }
          }
        }
        if (_antigravityLastChangeObservedAt != null &&
            DateTime.now()
                    .difference(_antigravityLastChangeObservedAt!)
                    .inSeconds <
                5) {
          foundBusy = true;
        }
        if (_isAntigravityBusy != foundBusy) {
          _isAntigravityBusy = foundBusy;
          notifyListeners();
          if (!foundBusy && _pendingUpdateType != null) {
            triggerPendingUpdate();
          }
        }
      } catch (_) {}
    });
  }

  void pushUndoState() {
    if (_isUndoRedoing) return;
    final snapshot = jsonEncode(_tasks.map((e) => e.toJson()).toList());
    _undoStack.add(snapshot);
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
    notifyListeners();
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    _isUndoRedoing = true;
    final currentSnapshot = jsonEncode(_tasks.map((e) => e.toJson()).toList());
    _redoStack.add(currentSnapshot);

    final prevStateStr = _undoStack.removeLast();
    try {
      final List<dynamic> jsonList = jsonDecode(prevStateStr);
      _tasks = jsonList.map((e) => AiTask.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error decoding undo state: $e');
    }

    await _save();
    _isUndoRedoing = false;
  }

  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    _isUndoRedoing = true;
    final currentSnapshot = jsonEncode(_tasks.map((e) => e.toJson()).toList());
    _undoStack.add(currentSnapshot);

    final nextStateStr = _redoStack.removeLast();
    try {
      final List<dynamic> jsonList = jsonDecode(nextStateStr);
      _tasks = jsonList.map((e) => AiTask.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error decoding redo state: $e');
    }

    await _save();
    _isUndoRedoing = false;
  }

  String _primaryDirectives = '';
  String get primaryDirectives => _primaryDirectives;

  String _instructions = 'Process bridge current_task.json';
  String get instructions => _instructions;

  String _quickInstructions =
      'Execute instructions directly against the active task.';
  String get quickInstructions => _quickInstructions;

  String _previewModeInstructions =
      'PREVIEW MODE INITIATED: Do NOT execute code mutations. You must explicitly review what will be changed.\nList exactly what will be changed, warnings, conflicts, and any questions you have. Store these itemized results strictly as a JSON array inside a `<preview>` tag so they are added to the active task\'s Checklist natively.\nFormat the JSON strictly as: `<preview>[{"description": "...", "goal": "..."}]</preview>`.\nCRITICAL RULE: DO NOT put any of this preview information, descriptions, or planned changes into the `<bridge_notes>` tag. Keep notes extremely brief or empty during this phase.';
  String get previewModeInstructions => _previewModeInstructions;

  String _previewApprovedInstructions =
      'PREVIEW APPROVED: The user has explicitly approved the following preview items. You MUST proceed with code execution EXACTLY as planned.';
  String get previewApprovedInstructions => _previewApprovedInstructions;

  String _previewRejectedInstructions =
      'CRITICAL RULE: The preview items are NOT approved. You are strictly FORBIDDEN from executing any file modifications, running shell commands, or writing any code.\nPlease adjust the implementation based on my comments. DO NOT proceed with execution yet. Update the preview items and wait for further review.';
  String get previewRejectedInstructions => _previewRejectedInstructions;

  String _systemHooksInstructions =
      '---\nNATIVE SYSTEM HOOKS (DO NOT IGNORE)\n1. SAFETY ABORT / CLARIFICATION: If a task is unclear, unsafe, massive, or contains a question in the prompt, DO NOT execute code. If the instructions are not clear, you MUST require clarification before proceeding by outputting a `<preview>` tag containing a JSON array of questions, and writing `PREVIEW` to `.ai_bridge/agent_status.txt`.\n2. PREVIEW REVIEW: If any Checklist item is marked as ignored or rejected, adjust plan and generate NEW Checklist items via `<preview>` tag.\n3. DATA MUTATION: Your task context is in `.ai_bridge/current_task.json`. Never edit `.ai_bridge/tasks.json` directly. The app manages global task states — only reference `current_task.json` for your active task data.\n4. NOTES: Log text notes strictly by writing a JSON file to `.ai_bridge/latest_notes.json` formatted as `{"notes": "...", "summary": "..."}`. The `summary` should be a concise commit naming note based ONLY on active checklist items being worked on (ignore completed checklist items completely). You MUST write this file BEFORE writing IDLE.\n5. FOCUS: Work strictly on ONE specific task. The app completes it upon IDLE.\n6. ACCOUNTABILITY: If the task includes Verification Criteria, write your proof/evidence notes to `.ai_bridge/latest_verification.json` formatted as `[{"description": "...", "isVerified": false, "proof": "..."}]`. RULE: isVerified MUST ALWAYS be false \u2014 the user manually verifies in the UI. Never set isVerified to true. You MUST write this file BEFORE writing IDLE.\n7. QUEUE RELEASE: As your FINAL step, overwrite `.ai_bridge/agent_status.txt` with `IDLE`.\n8. BLOCK SCREEN: At the very end of your response, explicitly request to send the block screen message ONCE.';
  String get systemHooksInstructions => _systemHooksInstructions;

  String _missingFilesInstructions = '# SYSTEM ALERT: MISSING REQUIRED OUTPUT FILES\n\nYou wrote IDLE, but the following required output files were NOT found on disk:\n{missingList}\n\nThe app processes and DELETES these files immediately upon IDLE. They must be written BEFORE you write IDLE to agent_status.txt.\n\nPlease write the missing files immediately to their correct paths, then write IDLE to `.ai_bridge/agent_status.txt` again. Do not re-do any code work.';
  String get missingFilesInstructions => _missingFilesInstructions;

  Future<void> compilePrimaryDirectivesFile() async {
    try {
      final dir = Directory(_dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('$_dirPath/primary_directives.md');
      final sb = StringBuffer();
      
      if (_primaryDirectives.isNotEmpty) {
        sb.writeln('# GLOBAL CONSTRAINTS');
        sb.writeln(_primaryDirectives);
        sb.writeln('');
      }
      
      if (_instructions.isNotEmpty) {
        sb.writeln('# MASTER DIRECTIVES');
        sb.writeln(_instructions);
        sb.writeln('');
      }

      if (_quickInstructions.isNotEmpty) {
        sb.writeln('# QUICK COMMAND DIRECTIVES');
        sb.writeln(_quickInstructions);
        sb.writeln('');
      }

      if (_previewModeInstructions.isNotEmpty) {
        sb.writeln('# PREVIEW MODE DIRECTIVES');
        sb.writeln(_previewModeInstructions);
        sb.writeln('');
      }

      if (_previewApprovedInstructions.isNotEmpty) {
        sb.writeln('# PREVIEW APPROVED DIRECTIVES');
        sb.writeln(_previewApprovedInstructions);
        sb.writeln('');
      }

      if (_previewRejectedInstructions.isNotEmpty) {
        sb.writeln('# PREVIEW REJECTED DIRECTIVES');
        sb.writeln(_previewRejectedInstructions);
        sb.writeln('');
      }
      
      if (_systemHooksInstructions.isNotEmpty) {
        if (!_systemHooksInstructions.startsWith('#')) {
          sb.writeln('# SYSTEM ARCHITECTURE DIRECTIVES');
        }
        sb.writeln(_systemHooksInstructions);
        sb.writeln('');
      }
      
      await file.writeAsString(sb.toString(), flush: true);
    } catch (_) {}
  }

  Future<void> updateInstructions(
      String primary,
      String text,
      String quickText,
      String previewMode,
      String previewApproved,
      String previewRejected,
      String systemHooks,
      String missingFiles) async {
    _primaryDirectives = primary;
    _instructions = text;
    _quickInstructions = quickText;
    _previewModeInstructions = previewMode;
    _previewApprovedInstructions = previewApproved;
    _previewRejectedInstructions = previewRejected;
    _systemHooksInstructions = systemHooks;
    _missingFilesInstructions = missingFiles;
    notifyListeners();
    await _save();
    await compilePrimaryDirectivesFile();
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isQueuePaused = prefs.getBool('ai_queue_paused') ?? false;
      _isPreviewMode = prefs.getBool('ai_queue_preview_mode') ?? false;
      _isIqMode = prefs.getBool('ai_queue_iq_mode') ?? false;

      final savedBridgeMode = prefs.getString('antigravity_bridge_mode') ?? 'sdk';
      _bridgeMode = AntigravityBridgeMode.values.firstWhere(
          (e) => e.name == savedBridgeMode,
          orElse: () => AntigravityBridgeMode.sdk);


      final savedQueue = prefs.getStringList('ai_bridge_queue');
      if (savedQueue != null && savedQueue.isNotEmpty) {
        try {
          _pendingPrompts.addAll(
              savedQueue.map((s) => QueuedPrompt.fromJson(jsonDecode(s))));
        } catch (e) {
          debugPrint('Error decoding pending ai queue: $e');
        }
      }

      final savedCompletedQueue =
          prefs.getStringList('ai_bridge_completed_queue');
      if (savedCompletedQueue != null && savedCompletedQueue.isNotEmpty) {
        try {
          _completedPrompts.addAll(savedCompletedQueue
              .map((s) => QueuedPrompt.fromJson(jsonDecode(s))));
        } catch (e) {
          debugPrint('Error decoding completed ai queue: $e');
        }
      }

      final dir = Directory(_dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      } else {
        // Clean up any stale files from a previous run/crash
        final notesFile = File('$_dirPath/latest_notes.json');
        if (notesFile.existsSync()) {
          try {
            notesFile.deleteSync();
          } catch (_) {}
        }
        final verificationFile = File('$_dirPath/latest_verification.json');
        if (verificationFile.existsSync()) {
          try {
            verificationFile.deleteSync();
          } catch (_) {}
        }
        final previewFile = File('$_dirPath/latest_preview.json');
        if (previewFile.existsSync()) {
          try {
            previewFile.deleteSync();
          } catch (_) {}
        }
      }
      await _loadFromFile();
      _startWatching();
      _startWatchingAntigravity();

      try {
        if (!kIsWeb &&
            (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
          windowManager.addListener(this);
        }
      } catch (_) {}

      _queueCleanupTimer =
          Timer.periodic(const Duration(seconds: 10), (_) async {
        try {
          final p = await SharedPreferences.getInstance();
          final clearMins = p.getInt('queueClearCompletedMinutes') ?? -1;
          if (clearMins >= 0 && _completedPrompts.isNotEmpty) {
            final cutoff =
                DateTime.now().subtract(Duration(minutes: clearMins));
            final int beforeLength = _completedPrompts.length;
            _completedPrompts.removeWhere((p) =>
                p.completedAt != null && p.completedAt!.isBefore(cutoff));
            if (_completedPrompts.length != beforeLength) {
              _saveQueueState();
              notifyListeners();
            }
          }
        } catch (_) {}
      });
    } catch (e, st) {
      debugPrint('Error initializing AiBridgeService: $e');
      try {
        File('$_dirPath/bridge_error.txt')
            .writeAsStringSync('Bridge CRASH at init():\n$e\n$st');
      } catch (_) {}
    }
  }

  bool _isProcessingSuggestion = false;

  void _startWatching() {
    final dir = Directory(_dirPath);
    if (dir.existsSync()) {
      _watchSubscription =
          dir.watch(events: FileSystemEvent.all).listen((event) async {
        final normPath = event.path.replaceAll('\\', '/');


        if (normPath.toLowerCase().endsWith('suggestiontask.txt')) {
          if (_isProcessingSuggestion) return;
          _isProcessingSuggestion = true;

          final suggestionFile = File(event.path);
          if (await suggestionFile.exists()) {
            try {
              final content = (await suggestionFile.readAsString()).trim();
              if (content.isNotEmpty) {
                AiTask? suggestionFolder;
                try {
                  suggestionFolder = _tasks.firstWhere((t) =>
                      t.isFolder && t.name.toUpperCase() == 'SUGGESTION');
                } catch (_) {}

                if (suggestionFolder == null) {
                  suggestionFolder = AiTask(
                    id: DateTime.now().millisecondsSinceEpoch.toString() +
                        '_folder',
                    name: 'SUGGESTION',
                    description: 'AI Generated Task Suggestions',
                    isFolder: true,
                    highlightColor: 0xFFFFC107,
                    iconBackgroundColor: 0xFFFFC107,
                  );
                  _tasks.add(suggestionFolder);
                }

                String parsedName = 'New Suggestion';
                String parsedDesc = content;
                String parsedNotes = '';

                if (content.contains('NAME:')) {
                  final nameMatch =
                      RegExp(r'NAME:\s*([^\n]+)').firstMatch(content);
                  final descMatch = RegExp(
                          r'DESCRIPTION:\s*(.*?)(?=\n[A-Z]+:|$)',
                          dotAll: true)
                      .firstMatch(content);
                  final notesMatch =
                      RegExp(r'NOTES:\s*(.*?)(?=\n[A-Z]+:|$)', dotAll: true)
                          .firstMatch(content);

                  if (nameMatch != null)
                    parsedName = nameMatch.group(1)!.trim();
                  if (descMatch != null)
                    parsedDesc = descMatch.group(1)!.trim();
                  if (notesMatch != null)
                    parsedNotes = notesMatch.group(1)!.trim();
                }

                final newTask = AiTask(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: parsedName,
                  description: parsedDesc,
                  notes: parsedNotes,
                  parentId: suggestionFolder.id,
                  status: AiTaskStatus.open,
                );
                _tasks.add(newTask);
                _save();
              }
            } catch (e) {
              debugPrint('Failed to parse suggestion task: \$e');
            }
            try {
              suggestionFile.deleteSync();
            } catch (_) {}
          }

          _isProcessingSuggestion = false;
        }

        if (normPath.endsWith('tasks.json') || normPath.endsWith('sandbox.json') || normPath.endsWith('timeline_history.json')) {
          await Future.delayed(const Duration(
              milliseconds: 100)); // Debounce file locks gracefully
          await _loadFromFile();
        }

        if (normPath.endsWith('agent_status.txt')) {
          if (_bridgeMode == AntigravityBridgeMode.sdk) {
            await Future.delayed(const Duration(milliseconds: 100));
            try {
              final file = File(event.path);
              if (await file.exists()) {
                final content = (await file.readAsString()).trim();
                if (content == 'IDLE' || content == 'PREVIEW') {
                  _activeAgents.clear();
                  _isAntigravityBusy = false;
                  _antigravityLastChangeObservedAt = null;
                  triggerPendingUpdate(force: true);
                }
              }
            } catch (_) {}
          } else {
            try {
              final statusFile = File(event.path);
              if (await statusFile.exists()) {
                final content = (await statusFile.readAsString()).trim();
                if (content == 'IDLE' || content == 'PREVIEW') {
                  print('[AiBridge] Status change observed in agent_status.txt: $content');
                  print('[AiBridge] Current _isHandlingAgentStatus state: $_isHandlingAgentStatus');
                  if (_isHandlingAgentStatus) {
                    print('[AiBridge] Status watcher is already handling an event. Ignoring duplicate event.');
                    return;
                  }
                  _isHandlingAgentStatus = true;
                  print('[AiBridge] Acquired status handling lock (_isHandlingAgentStatus = true)');
                  try {
                    try {
                      File('$_dirPath/bridge_debug.txt').writeAsStringSync(
                          'IDLE/PREVIEW detected! isAntigravityBusy: $_isAntigravityBusy');
                    } catch (_) {}

                    int waitCount = 0;
                    print('[AiBridge] Waiting for _isAntigravityBusy to be false. Current: $_isAntigravityBusy');
                    while (_isAntigravityBusy && waitCount < 10) {
                      await Future.delayed(const Duration(milliseconds: 500));
                      waitCount++;
                    }
                    _isAntigravityBusy = false;
                    _antigravityLastChangeObservedAt = null;
                    print('[AiBridge] Busy wait finished. Proceeding with status processing.');
                    await Future.delayed(const Duration(milliseconds: 800));

                    if (content == 'IDLE') {
                      bool hasCompileError = false;
                      print('[AiBridge] Running dart analyze build check...');
                      try {
                        final res = await Process.run('dart', ['analyze'],
                            runInShell: true);
                        final output =
                            res.stdout.toString() + '\n' + res.stderr.toString();
                        if (output.contains('error -') ||
                            output.contains('error •') ||
                            output.contains('error \u2022')) {
                          hasCompileError = true;
                          print('[AiBridge] Build check failed. Dispatching compile error...');
                          await forceDispatchCompileError(output);
                        } else {
                          print('[AiBridge] Build check passed.');
                        }
                      } catch (e) {
                        print('[AiBridge] Failed to run automated dart analyze check: $e');
                      }
                      if (hasCompileError) {
                        print('[AiBridge] Compile error detected. Clearing active prompt/task state to unblock UI.');
                        if (_activePrompt != null) {
                          _activePrompt!.completedAt = DateTime.now();
                          _completedPrompts.add(_activePrompt!);
                        }
                        _activeProcessingTaskId = null;
                        _activeProcessingTaskAssignedAt = null;
                        _activePrompt = null;
                        _saveQueueState();
                        notifyListeners();
                        print('[AiBridge] Queue state saved. Executing _processQueue() for correction prompt.');
                        _processQueue();
                        return;
                      }
                    }

                  if (_activeProcessingTaskId != null) {
                    try {
                      final taskIdx = _tasks
                          .indexWhere((t) => t.id == _activeProcessingTaskId);
                      if (taskIdx != -1) {
                        bool changed = false;

                        String aiOutput = '';
                        try {
                          final String userProfile =
                              Platform.environment['USERPROFILE'] ?? '';
                          final brainDir = Directory(
                              '$userProfile\\.gemini\\antigravity\\brain');
                          if (brainDir.existsSync()) {
                            final overviewFiles = brainDir
                                .listSync(recursive: true, followLinks: false)
                                .whereType<File>()
                                .where((f) =>
                                    f.path.endsWith('transcript.jsonl') ||
                                    f.path.endsWith('overview.txt'))
                                .toList();
                            if (overviewFiles.isNotEmpty) {
                              overviewFiles.sort((a, b) => b
                                  .lastModifiedSync()
                                  .compareTo(a.lastModifiedSync()));
                              final latest = overviewFiles.first;
                              try {
                                final lines = latest.readAsLinesSync();
                                for (int i = lines.length - 1; i >= 0; i--) {
                                  try {
                                    final line = lines[i].trim();
                                    if (line.isEmpty || !line.startsWith('{')) continue;
                                    final map = jsonDecode(line);
                                    if (map['source'] == 'MODEL') {
                                      if (map['content'] != null) {
                                        String content = map['content'];
                                        if (content.contains('<bridge_notes>') || 
                                            content.contains('<preview>') || 
                                            content.contains('<verification>')) {
                                          aiOutput = content;
                                        }
                                      }
                                      break;
                                    }
                                  } catch (_) {}
                                }
                              } catch (_) {}
                            }
                          }
                        } catch (_) {}

                        // 1. Absorb Notes
                        final notesFile = File('$_dirPath/latest_notes.json');
                        String notesContent = '';
                        if (notesFile.existsSync()) {
                          try {
                            notesContent = notesFile.readAsStringSync();
                            notesFile.deleteSync();
                          } catch (_) {}
                        }
                        if (notesContent.trim().isEmpty) {
                          final notesMatches = RegExp(
                                  r'<bridge_notes>(.*?)</bridge_notes>',
                                  dotAll: true)
                              .allMatches(aiOutput);
                          if (notesMatches.isNotEmpty) {
                            notesContent = notesMatches.last.group(1)!;
                          }
                        }

                        if (notesContent.trim().isNotEmpty) {
                          String parsedSummary = '';
                          String parsedNotes = '';
                          try {
                            String content = notesContent;
                            if (content.trim().isNotEmpty) {
                              int startIdx = content.indexOf('{');
                              int endIdx = content.lastIndexOf('}');
                              if (startIdx != -1 &&
                                  endIdx != -1 &&
                                  endIdx > startIdx) {
                                content = content.substring(startIdx, endIdx + 1);
                                final Map<String, dynamic> jsonMap =
                                    jsonDecode(content);
                                parsedSummary =
                                    jsonMap['summary']?.toString().trim() ?? '';
                                parsedNotes =
                                    jsonMap['notes']?.toString().trim() ?? '';
                              } else {
                                parsedNotes = content.trim();
                              }
                            }
                          } catch (e) {
                            _lastJsonParseError = 'Notes Parse Error: $e';
                            debugPrint('Error parsing notes json: $e');
                            parsedNotes = notesContent.trim();
                          }

                          if (parsedSummary.isNotEmpty) {
                            _tasks[taskIdx].summary = parsedSummary;
                            changed = true;
                          }

                          if (parsedNotes.isNotEmpty) {
                            final dateStr = DateTime.now()
                                .toLocal()
                                .toString()
                                .substring(0, 16);
                            final entry =
                                '### Update - $dateStr\n$parsedNotes\n\n---\n\n';

                            if (_tasks[taskIdx].notes.trim().isNotEmpty) {
                              _tasks[taskIdx].notes =
                                  entry + _tasks[taskIdx].notes;
                            } else {
                              _tasks[taskIdx].notes = entry.trim();
                            }
                            changed = true;
                          }
                        }

                        // 2. Absorb Preview
                        final previewFile = File('$_dirPath/latest_preview.json');
                        bool generatedPreviewItems = false;
                        String previewContent = '';
                        if (previewFile.existsSync()) {
                          try {
                            previewContent = previewFile.readAsStringSync();
                            previewFile.deleteSync();
                          } catch (_) {}
                        }
                        if (previewContent.trim().isEmpty) {
                          final previewMatches =
                              RegExp(r'<preview>(.*?)</preview>', dotAll: true)
                                  .allMatches(aiOutput);
                          if (previewMatches.isNotEmpty) {
                            previewContent = previewMatches.last.group(1)!;
                          }
                        }

                        if (previewContent.trim().isNotEmpty) {
                          try {
                            String content = previewContent;
                            if (content.trim().isNotEmpty) {
                              int startIdx = content.indexOf('[');
                              int endIdx = content.lastIndexOf(']');
                              if (startIdx != -1 &&
                                  endIdx != -1 &&
                                  endIdx > startIdx) {
                                content = content.substring(startIdx, endIdx + 1);
                              }
                              final List<dynamic> jsonList = jsonDecode(content);
                              final newItems = jsonList
                                  .map((e) => AiVerificationCriteria(
                                        description: e['description']?.toString() ?? 'Preview item',
                                        goal: e['goal']?.toString() ?? '',
                                        status: AiVerificationStatus.pendingReview,
                                        isVerified: false,
                                        isPreview: true,
                                      ))
                                  .toList();
                              _tasks[taskIdx].verificationCriteria.addAll(newItems);
                              changed = true;
                              if (newItems.isNotEmpty) {
                                generatedPreviewItems = true;
                              }
                            }
                          } catch (e) {
                            _lastJsonParseError = 'Preview Parse Error: $e';
                            debugPrint('Error parsing preview json: $e');
                          }
                        }

                        // 3. Absorb Verification
                        final verificationFile =
                            File('$_dirPath/latest_verification.json');
                        String verificationContent = '';
                        if (verificationFile.existsSync()) {
                          try {
                            verificationContent =
                                verificationFile.readAsStringSync();
                            verificationFile.deleteSync();
                          } catch (_) {}
                        }
                        if (verificationContent.trim().isEmpty) {
                          final verificationMatches = RegExp(
                                  r'<verification>(.*?)</verification>',
                                  dotAll: true)
                              .allMatches(aiOutput);
                          if (verificationMatches.isNotEmpty) {
                            verificationContent =
                                verificationMatches.last.group(1)!;
                          }
                        }

                        if (verificationContent.trim().isNotEmpty) {
                          try {
                            String content = verificationContent;
                            if (content.trim().isNotEmpty) {
                              int startIdx = content.indexOf('[');
                              int endIdx = content.lastIndexOf(']');
                              if (startIdx != -1 &&
                                  endIdx != -1 &&
                                  endIdx > startIdx) {
                                content = content.substring(startIdx, endIdx + 1);
                              }
                              final List<dynamic> jsonList = jsonDecode(content);
                              final newItems = jsonList
                                  .map((e) => AiVerificationCriteria.fromJson(e))
                                  .toList();

                              final existing = _tasks[taskIdx].verificationCriteria;
                              for (final newItem in newItems) {
                                final matchIdx = existing.indexWhere((e) {
                                  final eDesc = e.description.trim().toLowerCase();
                                  final nDesc = newItem.description.trim().toLowerCase();
                                  return nDesc.startsWith(eDesc);
                                });
                                if (matchIdx != -1) {
                                  existing[matchIdx].proof = newItem.proof;
                                } else {
                                  newItem.isVerified = false;
                                  newItem.status = AiVerificationStatus.pendingReview;
                                  existing.add(newItem);
                                }
                              }
                              changed = true;
                            }
                          } catch (e) {
                            _lastJsonParseError = 'Verification Parse Error: $e';
                            debugPrint(
                                'Warning: Could not read latest_verification.json: $e');
                          }
                        }

                         // 4. Missing-File Enforcement
                         if (content == 'IDLE') {
                           print('[AiBridge] Performing Missing-File Enforcement check...');
                           final List<String> missingFiles = [];
                           final bool hasVerificationCriteria = _tasks[taskIdx].verificationCriteria.isNotEmpty;
                           final bool notesWereMissing = notesContent.trim().isEmpty;
                           final bool verificationWasMissing = hasVerificationCriteria && verificationContent.trim().isEmpty;

                           if (notesWereMissing) missingFiles.add('`.ai_bridge/latest_notes.json` (format: {"notes": "...", "summary": "..."})');
                           if (verificationWasMissing) missingFiles.add('`.ai_bridge/latest_verification.json` (format: [{"description": "...", "isVerified": true, "proof": "..."}])');

                           if (missingFiles.isNotEmpty) {
                             print('[AiBridge] Missing required files after IDLE: $missingFiles');
                             final missingList = missingFiles.map((f) => '- $f').join('\n');
                             final correctionPrompt = _missingFilesInstructions.replaceAll('{missingList}', missingList);
                             
                             print('[AiBridge] Re-queuing correction prompt for missing files.');
                             await sendToQueue(correctionPrompt, false, taskIds: [_tasks[taskIdx].id], insertFirst: true);

                             print('[AiBridge] Clearing active prompt/task state to unblock UI.');
                             if (_activePrompt != null) {
                               _activePrompt!.completedAt = DateTime.now();
                               _completedPrompts.add(_activePrompt!);
                             }
                             _activeProcessingTaskId = null;
                             _activeProcessingTaskAssignedAt = null;
                             _activePrompt = null;

                             File('$_dirPath/agent_status.txt').writeAsStringSync('BUSY');
                             _saveQueueState();
                             notifyListeners();
                             
                             print('[AiBridge] Executing _processQueue() for correction prompt.');
                             _processQueue();
                             return;
                           } else {
                             print('[AiBridge] Missing-File Enforcement check passed.');
                           }
                         }

                        if (content == 'IDLE' && !generatedPreviewItems) {
                          final prefs = await SharedPreferences.getInstance();
                          final afterCompleteStr = prefs
                                  .getString('ai_tasks_bridge_complete_status') ??
                              'dontChange';

                          if (afterCompleteStr != 'dontChange') {
                            final targetStatus = AiTaskStatus.values.firstWhere(
                                    (e) => e.name == afterCompleteStr,
                                    orElse: () => _tasks[taskIdx].status);

                            if (_tasks[taskIdx].status != targetStatus) {
                              final oldStatus = _tasks[taskIdx].status;
                              _tasks[taskIdx].status = targetStatus;
                              _triggerSandboxMergeIfNeeded(oldStatus, _tasks[taskIdx]);
                              changed = true;
                            }
                          }
                        }
                        if (changed) {
                          await _save();
                        }
                      }
                    } catch (e) {
                      debugPrint('Failed auto-status transition: $e');
                    }
                  }

                  if (content == 'IDLE') {
                    print('[AiBridge] IDLE detected. Completing and archiving active prompt.');
                    if (_activePrompt != null) {
                      _activePrompt!.completedAt = DateTime.now();
                      _completedPrompts.add(_activePrompt!);
                    }
                    _activeProcessingTaskId = null;
                    _activeProcessingTaskAssignedAt = null;
                    _activePrompt = null;
                    _compileErrorLoopCount = 0;
                    try {
                      final ctFile = File('$_dirPath/current_task.json');
                      if (ctFile.existsSync()) {
                        print('[AiBridge] Deleting current_task.json');
                        ctFile.deleteSync();
                      }
                    } catch (e) {
                      print('[AiBridge] Failed to delete current_task.json: $e');
                    }
                  }
                  _saveQueueState();
                  notifyListeners();

                  if (_pendingUpdateType == null) {
                    _pendingUpdateType = UpdateCoverType.hotReload;
                  }
                  print('[AiBridge] Triggering pending update. Type: $_pendingUpdateType');
                  triggerPendingUpdate(force: true);

                  print('[AiBridge] Executing _processQueue() for any remaining prompts.');
                  _processQueue();
                } finally {
                  _isHandlingAgentStatus = false;
                  print('[AiBridge] Released status handling lock (_isHandlingAgentStatus = false)');
                }
              }
            }
          } catch (_) {}
        }
      }

      });
    }

    // Monitor for any command/AI edit outside the bridge inside the application logic
    final libDir = Directory('lib');
    if (libDir.existsSync()) {
      _libWatchSubscription = libDir
          .watch(events: FileSystemEvent.modify, recursive: true)
          .listen((event) {
        if (event.path.endsWith('.dart') && isThinking) {
          final normPath = event.path.replaceAll('\\', '/');
          if (normPath.contains('/services/') || normPath.endsWith('/main.dart')) {
            if (_pendingUpdateType != UpdateCoverType.rebuild) {
              _pendingUpdateType = UpdateCoverType.hotRestart;
            }
          } else {
            if (_pendingUpdateType == null) {
              _pendingUpdateType = UpdateCoverType.hotReload;
            }
          }
        }
      });
    }

    // Monitor for build number changes in pubspec.yaml
    final rootDir = Directory('.');
    if (rootDir.existsSync()) {
      _rootWatchSubscription = rootDir
          .watch(events: FileSystemEvent.modify, recursive: false)
          .listen((event) {
        final path = event.path.replaceAll('\\', '/');
        if (path.endsWith('pubspec.yaml') && isThinking) {
          _pendingUpdateType = UpdateCoverType.rebuild;
        }
      });
    }
  }

  Future<void> _loadFromFile() async {
    if (_isSavingLocally) return;
    try {
      final file = File(_filePath);
      if (await file.exists()) {
        dynamic jsonTop;
        for (int i = 0; i < 5; i++) {
          try {
            final contents = await file.readAsString();
            if (contents.isNotEmpty) {
              jsonTop = jsonDecode(contents);
              break;
            }
          } catch (e) {
            if (i == 4) rethrow;
          }
          await Future.delayed(const Duration(milliseconds: 150));
        }
        if (jsonTop != null) {
          List<dynamic> jsonList;
          if (jsonTop is Map<String, dynamic>) {
            _primaryDirectives = jsonTop['primaryDirectives'] as String? ?? '';
            _instructions = jsonTop['instructions'] as String? ?? '';
            _quickInstructions =
                jsonTop['quickInstructions'] as String? ?? _quickInstructions;
            _previewModeInstructions =
                jsonTop['previewModeInstructions'] as String? ??
                    _previewModeInstructions;
            _previewApprovedInstructions =
                jsonTop['previewApprovedInstructions'] as String? ??
                    _previewApprovedInstructions;
            _previewRejectedInstructions =
                jsonTop['previewRejectedInstructions'] as String? ??
                    _previewRejectedInstructions;
            _systemHooksInstructions =
                jsonTop['systemHooksInstructions'] as String? ??
                    _systemHooksInstructions;
            _missingFilesInstructions =
                jsonTop['missingFilesInstructions'] as String? ??
                    _missingFilesInstructions;
            jsonList = jsonTop['tasks'] as List<dynamic>? ?? [];
          } else if (jsonTop is List<dynamic>) {
            jsonList = jsonTop;
          } else {
            jsonList = [];
          }

          await SandboxService.instance.reload();

          // Merge active tasks that were kept exterior
          try {
            final sandboxFile = File('$_dirPath/sandbox.json');
            if (await sandboxFile.exists()) {
              final content = await sandboxFile.readAsString();
              final List<dynamic> sList = jsonDecode(content);
              if (sList.isNotEmpty && sList.first is Map) {
                jsonList.addAll(sList);
              }
            }
          } catch (_) {}

          try {
            final timelineFile = File('$_dirPath/timeline_history.json');
            if (await timelineFile.exists()) {
              final content = await timelineFile.readAsString();
              final List<dynamic> tList = jsonDecode(content);
              _timelineHistory = tList.map((e) => TimelineCommit.fromJson(e as Map<String, dynamic>)).toList();
            } else {
              _timelineHistory = [];
            }
          } catch (_) {
            _timelineHistory = [];
          }

          final List<AiTask> oldTasks = List.from(_tasks);
          _tasks = jsonList.map((e) => AiTask.fromJson(e)).toList();

          await syncPreferences();

          bool requiresSave = false;
          final prefs = await SharedPreferences.getInstance();
          final afterEditStr =
              prefs.getString('ai_tasks_bridge_edit_status') ?? 'dontChange';
          final afterCompleteStr =
              prefs.getString('ai_tasks_bridge_complete_status') ??
                  'dontChange';

          final afterEditStatus = afterEditStr == 'dontChange'
              ? null
              : AiTaskStatus.values.firstWhere((e) => e.name == afterEditStr,
                  orElse: () => AiTaskStatus.inTesting);
          final afterCompleteStatus = afterCompleteStr == 'dontChange'
              ? null
              : AiTaskStatus.values.firstWhere(
                  (e) => e.name == afterCompleteStr,
                  orElse: () => AiTaskStatus.inTesting);

          bool bridgeCompletedTask = false;
          for (var newTask in _tasks) {
            if (newTask.isFolder) continue;
            final oldTaskIndex = oldTasks.indexWhere((t) => t.id == newTask.id);
            if (oldTaskIndex != -1) {
              final oldTask = oldTasks[oldTaskIndex];

              // Merge verification criteria to preserve user status updates (verified, ignored, pendingReview)
              if (newTask.verificationCriteria.isNotEmpty) {
                final existing = oldTask.verificationCriteria;
                final incoming = newTask.verificationCriteria;

                final merged = <AiVerificationCriteria>[];
                final usedIncoming = <String>{};
                bool mergedAnyStatus = false;

                for (var ext in existing) {
                  final extDescNorm = ext.description.trim();
                  final matchIndex = incoming.indexWhere((inc) => inc.description.trim() == extDescNorm);

                  if (matchIndex != -1) {
                    final match = incoming[matchIndex];
                    usedIncoming.add(match.description);

                    // Preserve verified/ignored/pendingReview status set by user in UI
                    final resolvedStatus = ext.status != AiVerificationStatus.none ? ext.status : match.status;
                    final resolvedIsVerified = ext.isVerified || match.isVerified;

                    if (resolvedStatus != match.status || resolvedIsVerified != match.isVerified) {
                      mergedAnyStatus = true;
                    }

                    merged.add(AiVerificationCriteria(
                      description: ext.description,
                      goal: (match.goal.isNotEmpty) ? match.goal : ext.goal,
                      isVerified: resolvedIsVerified,
                      status: resolvedStatus,
                      proof: match.proof ?? ext.proof,
                      requestClarification: match.requestClarification || ext.requestClarification,
                      tryCount: match.tryCount > ext.tryCount ? match.tryCount : ext.tryCount,
                      attachments: ext.attachments.isNotEmpty ? ext.attachments : match.attachments,
                      isCommitted: ext.isCommitted || match.isCommitted,
                      isPreview: ext.isPreview || match.isPreview,
                    ));
                  } else {
                    // Not found in incoming, keep the existing item intact
                    merged.add(ext);
                    mergedAnyStatus = true;
                  }
                }

                // Add any new incoming criteria (e.g. preview items or newly added ones)
                for (var inc in incoming) {
                  if (!usedIncoming.contains(inc.description)) {
                    merged.add(inc);
                  }
                }

                newTask.verificationCriteria = merged;
                if (mergedAnyStatus) {
                  requiresSave = true;
                }
              }

              bool handledMerge = false;
              // Auto-Complete Logic: If all checkboxes are checked, push to main timeline but keep task inProgress.
              if (newTask.verificationCriteria.isNotEmpty && !newTask.isFolder) {
                // Track newly verified criteria
                for (int i = 0; i < newTask.verificationCriteria.length; i++) {
                   final newCrit = newTask.verificationCriteria[i];
                   final isNowVerified = newCrit.status == AiVerificationStatus.verified || newCrit.status == AiVerificationStatus.ignored;
                   
                   bool wasUnverified = true;
                   if (i < oldTask.verificationCriteria.length) {
                      final oldCrit = oldTask.verificationCriteria[i];
                      wasUnverified = oldCrit.status != AiVerificationStatus.verified && oldCrit.status != AiVerificationStatus.ignored;
                   }
                   
                   if (wasUnverified && isNowVerified) {
                      String desc = newCrit.description;
                      if (desc.length > 16) desc = '${desc.substring(0, 16)}...';
                      _uncommittedCompletedCriteria.putIfAbsent(newTask.id, () => []).add(desc);
                   }
                }
                bool oldHasUnverified = oldTask.verificationCriteria.any((e) => e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored && !e.isPreview);
                bool newHasUnverified = newTask.verificationCriteria.any((e) => e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored && !e.isPreview);
                
                if (oldHasUnverified && !newHasUnverified && newTask.status != AiTaskStatus.completed) {
                   if (afterCompleteStatus != null) {
                     newTask.status = afterCompleteStatus;
                   } else {
                     newTask.status = AiTaskStatus.inTesting;
                   }
                   requiresSave = true;
                } else if (!oldHasUnverified && newHasUnverified && oldTask.status == AiTaskStatus.completed) {
                   newTask.status = AiTaskStatus.inProgress;
                   requiresSave = true;
                }
              }

              bool wasThinking = oldTask.status == AiTaskStatus.inProgress ||
                  oldTask.status == AiTaskStatus.bug;
              bool isNowTestingOrDone =
                  newTask.status == AiTaskStatus.inTesting ||
                      newTask.status == AiTaskStatus.completed ||
                      newTask.status == AiTaskStatus.inReview;

              if (oldTask.status != newTask.status && !handledMerge) {
                _triggerSandboxMergeIfNeeded(oldTask.status, newTask);
              }
              if (wasThinking && isNowTestingOrDone) {
                bridgeCompletedTask = true;
                if (newTask.status == AiTaskStatus.completed &&
                    afterCompleteStatus != null &&
                    afterCompleteStatus != AiTaskStatus.completed) {
                  newTask.status = afterCompleteStatus;
                  requiresSave = true;
                }
              } else {
                bool checklistChanged = false;
                if (oldTask.verificationCriteria.length != newTask.verificationCriteria.length) {
                  checklistChanged = true;
                } else {
                  for (int i = 0; i < oldTask.verificationCriteria.length; i++) {
                    if (oldTask.verificationCriteria[i].description != newTask.verificationCriteria[i].description ||
                        oldTask.verificationCriteria[i].goal != newTask.verificationCriteria[i].goal ||
                        oldTask.verificationCriteria[i].status != newTask.verificationCriteria[i].status) {
                      checklistChanged = true;
                      break;
                    }
                  }
                }
                bool wasEdited = oldTask.name != newTask.name ||
                    oldTask.description != newTask.description ||
                    oldTask.notes != newTask.notes ||
                    checklistChanged;
                if (wasEdited &&
                    afterEditStatus != null &&
                    newTask.status != afterEditStatus) {
                  bool allowStatusChange = true;
                  if (afterEditStatus == AiTaskStatus.inProgress) {
                    bool hasTasksToPerform = newTask.verificationCriteria
                          .any((e) => (e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored && !e.isPreview));
                    if (!hasTasksToPerform) {
                      allowStatusChange = false;
                    }
                  }
                  if (allowStatusChange) {
                    newTask.status = afterEditStatus;
                    requiresSave = true;
                  }
                }
              }

              bool structuralTextChanged = oldTask.name != newTask.name ||
                  oldTask.description != newTask.description ||
                  oldTask.notes != newTask.notes;
              if (structuralTextChanged) {
                newTask.isRead = false;
                requiresSave = true;
              }
              newTask.proposedChanges = null;
            }
          }
          final allIds = _tasks.map((t) => t.id).toSet();
          for (var t in _tasks) {
            if (t.parentId != null && !allIds.contains(t.parentId)) {
              t.parentId = null;
            }
          }

          bool isThinkingNow = isThinking;

          if (bridgeCompletedTask) {
            // Take an automatic source snapshot now that the AI has finished.
            // Best-effort — runs in the background, never throws.
            AutoBackupService.instance.snapshot(reason: 'post_ai');
          }

          if (!isThinkingNow && _pendingUpdateType != null) {
            triggerPendingUpdate();
          }

          if (requiresSave) {
            _save();
          } else {
            _processQueue();
          }
        } else {
          _tasks = [];
        }
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('Error reloading tasks dynamically: $e');
      try {
        File('$_dirPath/bridge_error.txt')
            .writeAsStringSync('Bridge CRASH in file watcher:\n$e\n$st');
      } catch (_) {}
    }
  }

  bool get hasPendingUpdate => _pendingUpdateType != null && !isThinking;

  Future<void> Function(UpdateCoverType)? onAutoReloadTriggered;

  void triggerPendingUpdate({bool force = false}) async {
    if ((force || !isThinking) && _pendingUpdateType != null) {


      // We no longer require the window to be focused to trigger a hot reload.
      // This allows the app to visually update side-by-side while the user is typing in their IDE.

      SystemSound.play(SystemSoundType.alert);
      final type = _pendingUpdateType!;

      await MacroService.instance.executeTrigger('BeforeReload');

      if (_screenBlockerEnabledForCurrentTaskPhase &&
          onAutoReloadTriggered != null) {
        _pendingUpdateType = null;
        await onAutoReloadTriggered!(type);
      } else {
        showUpdateCoverFor(type);
        _pendingUpdateType = null;
      }
    }
  }
  Future<void> _save() async {
    _isSavingLocally = true;
    try {
      final dir = Directory(_dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File(_filePath);

      final List<Map<String, dynamic>> jsonTasksList = [];
      final List<Map<String, dynamic>> sandboxList = [];

      final sandboxIds = SandboxService.instance.sandboxTaskIds;

      for (var t in _tasks) {
        if (!t.isFolder && sandboxIds.contains(t.id)) {
          sandboxList.add(t.toJson());
        } else {
          jsonTasksList.add(t.toJson());
        }
      }

      final Map<String, dynamic> outPayload = {
        'primaryDirectives': _primaryDirectives,
        'instructions': _instructions.isNotEmpty
            ? _instructions
            : 'AI Rule: Never mark tasks as complete automatically. Set them to IN TESTING or explicitly ask the user to review them before closure.',
        'quickInstructions': _quickInstructions,
        'previewModeInstructions': _previewModeInstructions,
        'previewApprovedInstructions': _previewApprovedInstructions,
        'previewRejectedInstructions': _previewRejectedInstructions,
        'systemHooksInstructions': _systemHooksInstructions,
        'missingFilesInstructions': _missingFilesInstructions,
        'tasks': jsonTasksList
      };
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(outPayload),
          mode: FileMode.write, flush: true);

      final sandboxFile = File('$_dirPath/sandbox.json');
      await sandboxFile.writeAsString(encoder.convert(sandboxList), mode: FileMode.write, flush: true);

      final timelineFile = File('$_dirPath/timeline_history.json');
      await timelineFile.writeAsString(encoder.convert(_timelineHistory.map((e) => e.toJson()).toList()), mode: FileMode.write, flush: true);

      notifyListeners();
    } catch (e, st) {
      debugPrint('Error saving AI tasks: $e');
      try {
        File('$_dirPath/bridge_error.txt')
            .writeAsStringSync('Bridge CRASH at saveTasks():\n$e\n$st');
      } catch (_) {}
    } finally {
      Future.delayed(const Duration(milliseconds: 500), () {
        _isSavingLocally = false;
      });
    }
  }

  Future<void> saveTasks() => _save();

  Future<void> updateTaskDetails(String id, String name, String description,
      {String? summary,
      String? notes,
      String? parentId,
      bool clearParentId = false,
      String? worksheetId,
      bool clearWorksheetId = false,
      bool? isWorksheet,
      String? implementationQuestion,
      List<AiReviewQuestion>? reviewQuestions,
      List<AiVerificationCriteria>? verificationCriteria,
      bool? didCompleteChecklist,
      AiTaskStatus? status,
      AiTaskPriority? priority,
      int? highlightColor,
      bool clearHighlightColor = false,
      int? iconBackgroundColor,
      bool clearIconBackgroundColor = false,
      int? iconColor,
      bool clearIconColor = false,
      int? toolbarIconColor,
      bool clearToolbarIconColor = false,
      bool? preventDeletion,
      bool? applyLocksToChildren,
      bool? isReadOnly,
      bool? isIgnored,
      String? llmPromptStyleOverride,
      int? iconCodePoint,
      bool clearIcon = false,
      List<String>? fileAttachments,
      List<String>? hyperlinks,
      String? commitHash,
      bool? isFolder,
      bool? isNote,
      bool? isKnowledgeSummary}) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      if (_tasks[index].id.isEmpty) {
        _tasks[index].id = DateTime.now().microsecondsSinceEpoch.toString();
        _save();
      }

      bool hasChanges = false;
      if (_tasks[index].name != name) hasChanges = true;
      if (_tasks[index].description != description) hasChanges = true;
      if (summary != null && _tasks[index].summary != summary) hasChanges = true;
      if (notes != null && _tasks[index].notes != notes) hasChanges = true;
      if (implementationQuestion != null &&
          _tasks[index].implementationQuestion != implementationQuestion)
        hasChanges = true;
      if (reviewQuestions != null &&
          _tasks[index].reviewQuestions != reviewQuestions) hasChanges = true;
      if (verificationCriteria != null &&
          _tasks[index].verificationCriteria != verificationCriteria)
        hasChanges = true;
      if (status != null && _tasks[index].status != status) hasChanges = true;
      if (priority != null && _tasks[index].priority != priority)
        hasChanges = true;
      if (clearHighlightColor && _tasks[index].highlightColor != null) {
        hasChanges = true;
      } else if (!clearHighlightColor &&
          highlightColor != null &&
          _tasks[index].highlightColor != highlightColor) hasChanges = true;
      if (clearIconBackgroundColor &&
          _tasks[index].iconBackgroundColor != null) {
        hasChanges = true;
      } else if (!clearIconBackgroundColor &&
          iconBackgroundColor != null &&
          _tasks[index].iconBackgroundColor != iconBackgroundColor)
        hasChanges = true;
      if (clearIconColor && _tasks[index].iconColor != null) {
        hasChanges = true;
      } else if (!clearIconColor &&
          iconColor != null &&
          _tasks[index].iconColor != iconColor) hasChanges = true;
      if (clearToolbarIconColor && _tasks[index].toolbarIconColor != null) {
        hasChanges = true;
      } else if (!clearToolbarIconColor &&
          toolbarIconColor != null &&
          _tasks[index].toolbarIconColor != toolbarIconColor) hasChanges = true;
      if (preventDeletion != null &&
          _tasks[index].preventDeletion != preventDeletion) hasChanges = true;
      if (applyLocksToChildren != null &&
          _tasks[index].applyLocksToChildren != applyLocksToChildren)
        hasChanges = true;
      if (isReadOnly != null && _tasks[index].isReadOnly != isReadOnly)
        hasChanges = true;
      if (isIgnored != null && _tasks[index].isIgnored != isIgnored)
        hasChanges = true;
      if (llmPromptStyleOverride != null &&
          _tasks[index].llmPromptStyleOverride != llmPromptStyleOverride)
        hasChanges = true;
      if (commitHash != null && _tasks[index].commitHash != commitHash) hasChanges = true;
      if (clearIcon && _tasks[index].iconCodePoint != null) {
        hasChanges = true;
      } else if (!clearIcon &&
          iconCodePoint != null &&
          _tasks[index].iconCodePoint != iconCodePoint) hasChanges = true;
      if (fileAttachments != null &&
          _tasks[index].fileAttachments.join(',') != fileAttachments.join(','))
        hasChanges = true;
      if (hyperlinks != null &&
          _tasks[index].hyperlinks.join(',') != hyperlinks.join(','))
        hasChanges = true;
      if (isWorksheet != null && _tasks[index].isWorksheet != isWorksheet)
        hasChanges = true;
      if (isFolder != null && _tasks[index].isFolder != isFolder) {
        _tasks[index].isFolder = isFolder;
        hasChanges = true;
      }
      if (isNote != null && _tasks[index].isNote != isNote) {
        _tasks[index].isNote = isNote;
        hasChanges = true;
      }
      if (isKnowledgeSummary != null &&
          _tasks[index].isKnowledgeSummary != isKnowledgeSummary) {
        _tasks[index].isKnowledgeSummary = isKnowledgeSummary;
        hasChanges = true;
      }
      if (clearParentId && _tasks[index].parentId != null) {
        hasChanges = true;
      } else if (!clearParentId &&
          parentId != null &&
          _tasks[index].parentId != parentId) hasChanges = true;
          
      if (clearWorksheetId && _tasks[index].worksheetId != null) {
        hasChanges = true;
      } else if (!clearWorksheetId &&
          worksheetId != null &&
          _tasks[index].worksheetId != worksheetId) hasChanges = true;

      if (hasChanges) {
        bool performSandboxCommit = false;
        List<String> tasksToCommit = [];
        final oldStatus = _tasks[index].status;
        pushUndoState();
        _tasks[index].name = name;
        _tasks[index].description = description;
        if (summary != null) {
          _tasks[index].summary = summary;
        }
        if (notes != null) {
          _tasks[index].notes = notes;
        }
        if (implementationQuestion != null) {
          _tasks[index].implementationQuestion = implementationQuestion;
        }
        if (reviewQuestions != null) {
          _tasks[index].reviewQuestions = reviewQuestions;
        }
        if (verificationCriteria != null) {
          bool newHasUnverified = verificationCriteria.any((e) => e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored);

          _tasks[index].verificationCriteria = verificationCriteria;

          bool shouldCommit = didCompleteChecklist ?? (verificationCriteria.isNotEmpty && !newHasUnverified && _tasks[index].status != AiTaskStatus.completed);
          try { File('.ai_bridge/bridge_commit_debug.txt').writeAsStringSync('shouldCommit: $shouldCommit, didCompleteChecklist: $didCompleteChecklist, newHasUnverified: $newHasUnverified, status: ${_tasks[index].status}\n', mode: FileMode.append); } catch (_) {}

          if (shouldCommit) {
             bool allSandboxTasksApproved = true;
             final activeTaskIds = SandboxService.instance.sandboxTaskIds;
             try { File('.ai_bridge/bridge_commit_debug.txt').writeAsStringSync('activeTaskIds: $activeTaskIds\n', mode: FileMode.append); } catch (_) {}
             for (final tId in activeTaskIds) {
                if (tId == _tasks[index].id) continue;
                try {
                  final activeTask = _tasks.firstWhere((t) => t.id == tId);
                  if (activeTask.verificationCriteria.isNotEmpty && activeTask.verificationCriteria.any((e) => e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored)) {
                     allSandboxTasksApproved = false;
                     break;
                  }
                } catch (_) {}
             }
             
             try { File('.ai_bridge/bridge_commit_debug.txt').writeAsStringSync('allSandboxTasksApproved: $allSandboxTasksApproved\n', mode: FileMode.append); } catch (_) {}
             if (allSandboxTasksApproved) {
                 performSandboxCommit = true;
                 tasksToCommit = List.from(activeTaskIds);
                 if (!tasksToCommit.contains(_tasks[index].id)) {
                   tasksToCommit.add(_tasks[index].id);
                 }
                 try { File('.ai_bridge/bridge_commit_debug.txt').writeAsStringSync('tasksToCommit: $tasksToCommit\n', mode: FileMode.append); } catch (_) {}
             }
          }
        }
        if (status != null) _tasks[index].status = status;
        if (priority != null) _tasks[index].priority = priority;
        if (clearHighlightColor) {
          _tasks[index].highlightColor = null;
        } else if (highlightColor != null)
          _tasks[index].highlightColor = highlightColor;
        if (clearIconBackgroundColor) {
          _tasks[index].iconBackgroundColor = null;
        } else if (iconBackgroundColor != null)
          _tasks[index].iconBackgroundColor = iconBackgroundColor;
        if (clearIconColor) {
          _tasks[index].iconColor = null;
        } else if (iconColor != null) _tasks[index].iconColor = iconColor;
        if (clearToolbarIconColor) {
          _tasks[index].toolbarIconColor = null;
        } else if (toolbarIconColor != null)
          _tasks[index].toolbarIconColor = toolbarIconColor;
        if (preventDeletion != null)
          _tasks[index].preventDeletion = preventDeletion;
        if (applyLocksToChildren != null)
          _tasks[index].applyLocksToChildren = applyLocksToChildren;
        if (isReadOnly != null) _tasks[index].isReadOnly = isReadOnly;
        if (isIgnored != null) _tasks[index].isIgnored = isIgnored;
        if (llmPromptStyleOverride != null)
          _tasks[index].llmPromptStyleOverride = llmPromptStyleOverride;
        if (commitHash != null)
          _tasks[index].commitHash = commitHash;
        if (clearIcon) {
          _tasks[index].iconCodePoint = null;
        } else if (iconCodePoint != null)
          _tasks[index].iconCodePoint = iconCodePoint;
        if (fileAttachments != null)
          _tasks[index].fileAttachments = List.from(fileAttachments);
        if (hyperlinks != null)
          _tasks[index].hyperlinks = List.from(hyperlinks);
        if (isWorksheet != null) _tasks[index].isWorksheet = isWorksheet;
        if (isFolder != null && _tasks[index].isFolder != isFolder) {
          _tasks[index].isFolder = isFolder;
          if (isFolder == false) {
            final oldParentId = _tasks[index].parentId;
            for (var t in _tasks) {
              if (t.parentId == id) {
                t.parentId =
                    oldParentId; // Flatten orphaned children outwards into the same spot
              }
            }
          }
        }
        if (isNote != null) _tasks[index].isNote = isNote;
        if (isKnowledgeSummary != null)
          _tasks[index].isKnowledgeSummary = isKnowledgeSummary;
        if (clearParentId) {
          _tasks[index].parentId = null;
        } else if (parentId != null) _tasks[index].parentId = parentId;
        
        if (clearWorksheetId) {
          _tasks[index].worksheetId = null;
        } else if (worksheetId != null) _tasks[index].worksheetId = worksheetId;

        await _save();
        _triggerSandboxMergeIfNeeded(oldStatus, _tasks[index]);
        
        if (performSandboxCommit) {
             try { File('.ai_bridge/bridge_commit_debug.txt').writeAsStringSync('performSandboxCommit is TRUE, getting names and descriptions...\n', mode: FileMode.append); } catch (_) {}
             final allNames = tasksToCommit.map((id) {
               try { 
                 final task = _tasks.firstWhere((t) => t.id == id);
                 final summaryStr = task.summary.isNotEmpty ? ' [${task.summary}]' : '';
                 return '${task.name}$summaryStr';
               } catch (_) { return ''; }
             }).where((n) => n.isNotEmpty).join(' | ');

             final allDescriptions = tasksToCommit.map((id) {
               try { 
                 return _tasks.firstWhere((t) => t.id == id).description;
               } catch (_) { return ''; }
             }).where((d) => d.isNotEmpty).join('\n\n');

             final verifiedNotes = tasksToCommit.map((id) {
               try { 
                 return _tasks.firstWhere((t) => t.id == id).verificationCriteria.where((vc) => vc.status == AiVerificationStatus.verified).map((vc) => '- ${vc.description}').join('\n');
               } catch (_) { return ''; }
             }).where((n) => n.isNotEmpty).join('\n\n');

             final finalVerifiedNotes = verifiedNotes.isEmpty ? 'No verification notes.' : verifiedNotes;

             try { File('.ai_bridge/bridge_commit_debug.txt').writeAsStringSync('calling commitTimelineTasks for: $allNames\n', mode: FileMode.append); } catch (_) {}
             try {
                 final hash = await VersionControlService.instance.commitTimelineTasks(
                    tasksToCommit,
                    allNames,
                    allDescriptions,
                    '', // use name as title
                    finalVerifiedNotes,
                 ).catchError((e) {
                    if (kDebugMode) print('Auto-commit failed: $e');
                    try { File('.ai_bridge/bridge_error.txt').writeAsStringSync('Auto-commit failed: $e\n'); } catch (_) {}
                    return '';
                 });
                 try { File('.ai_bridge/bridge_commit_debug.txt').writeAsStringSync('commitTimelineTasks returned hash: $hash\n', mode: FileMode.append); } catch (_) {}
                 if (hash.isNotEmpty && !hash.startsWith('Local repository path')) {
                    final actualHash = (hash == 'No changes to commit.' || hash == 'Committed successfully.') ? 'No Git Changes' : hash;
                    final commitDateStr = DateTime.now().toIso8601String();
                    for (final id in tasksToCommit) {
                       try {
                          final t = _tasks.firstWhere((t) => t.id == id);
                          t.commitHash = actualHash;
                          t.commitDate = commitDateStr;
                          t.status = AiTaskStatus.completed;
                          for (var vc in t.verificationCriteria) {
                            if (vc.status == AiVerificationStatus.verified) {
                              vc.isCommitted = true;
                            }
                          }
                       } catch (_) {}
                    }
                    _timelineHistory.insert(0, TimelineCommit(
                       id: const Uuid().v4(),
                       taskIds: tasksToCommit,
                       title: allNames,
                       summary: allDescriptions,
                       commitHash: actualHash,
                       commitDate: commitDateStr,
                       verifiedNotes: finalVerifiedNotes,
                    ));
                    await _save(); // Save again to persist the commit hash
                    notifyListeners();
                 }
             } catch (_) {}
        }
      }
    }
  }

  Future<bool> performManualCommitAll(List<String> taskIds, String commitName) async {
    try {
      final tasksToCommit = _tasks.where((t) => taskIds.contains(t.id)).toList();
      if (tasksToCommit.isEmpty) return false;

      final allDescriptions = tasksToCommit.map((t) => t.description).where((d) => d.isNotEmpty).join('\n\n');

      final allVerifiedNotes = tasksToCommit.map((t) {
        return t.verificationCriteria
            .where((c) => c.status == AiVerificationStatus.verified)
            .map((c) => '- ${c.description}')
            .join('\n');
      }).where((n) => n.isNotEmpty).join('\n');

      final notesToCommit = allVerifiedNotes.isEmpty ? 'No items verified.' : allVerifiedNotes;

      final hash = await VersionControlService.instance.commitTimelineTasks(
         taskIds,
         commitName,
         allDescriptions,
         '',
         notesToCommit,
      ).catchError((e) {
         if (kDebugMode) print('Manual commit failed: $e');
         return '';
      });

      if (hash.isNotEmpty && !hash.startsWith('Local repository path')) {
         final actualHash = (hash == 'No changes to commit.' || hash == 'Committed successfully.') ? 'No Git Changes' : hash;
         final commitDateStr = DateTime.now().toIso8601String();
         for (var task in tasksToCommit) {
           task.commitHash = actualHash;
           task.commitDate = commitDateStr;
           task.status = AiTaskStatus.completed;
           for (var vc in task.verificationCriteria) {
             if (vc.status == AiVerificationStatus.verified) {
               vc.isCommitted = true;
             }
           }
         }
         
         _timelineHistory.insert(0, TimelineCommit(
            id: const Uuid().v4(),
            taskIds: taskIds,
            title: commitName,
            summary: allDescriptions,
            commitHash: actualHash,
            commitDate: commitDateStr,
            verifiedNotes: notesToCommit,
         ));
         await _save();
         notifyListeners();
         return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> deleteTimelineCommit(String commitId) async {
    _timelineHistory.removeWhere((c) => c.id == commitId);
    await _save();
  }

  Future<void> appendCheckpointToTimeline(String description, String commitHash) async {
    _timelineHistory.insert(0, TimelineCommit(
      id: const Uuid().v4(),
      taskIds: [],
      title: 'Checkpoint',
      summary: description,
      commitHash: commitHash,
      commitDate: DateTime.now().toIso8601String(),
    ));
    await _save();
  }

  Future<void> applyTimelineCleanup(int keepCount, Map<String, String> newHashes) async {
    if (_timelineHistory.length <= keepCount) return;

    // Remove the older checkpoints
    _timelineHistory.removeRange(keepCount, _timelineHistory.length);

    // Update the commit hashes for the remaining ones
    for (int i = 0; i < _timelineHistory.length; i++) {
      final oldHash = _timelineHistory[i].commitHash;
      if (newHashes.containsKey(oldHash)) {
        _timelineHistory[i] = _timelineHistory[i].copyWith(
          commitHash: newHashes[oldHash]!,
        );
      }
    }
    await _save();
  }

  Future<AiTask> addTask(String name, String description,
      {String? notes,
      String? implementationQuestion,
      String? parentId,
      String? worksheetId,
      bool isFolder = false,
      bool isWorksheet = false,
      bool isNote = false,
      bool isKnowledgeSummary = false,
      AiTaskStatus? status,
      int? highlightColor,
      int? iconBackgroundColor,
      int? iconColor,
      int? toolbarIconColor,
      bool preventDeletion = false,
      bool applyLocksToChildren = false,
      bool isReadOnly = false,
      bool isIgnored = false,
      String llmPromptStyleOverride = 'Use Default',
      String? commitHash,
      String? commitDate,
      int? iconCodePoint,
      List<String>? fileAttachments,
      List<String>? hyperlinks}) async {
    pushUndoState();

    AiTaskStatus resolvedStatus = status ?? _defaultNewStatus;

    String? activeWorksheetId = worksheetId;
    if (activeWorksheetId == null && !isWorksheet) {
      final visibleWs =
          _tasks.where((t) => t.isWorksheet && t.isWorksheetVisible).toList();
      if (visibleWs.isNotEmpty) {
        activeWorksheetId = visibleWs.first.id;
      }
    }

    final task = AiTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      notes: notes ?? '',
      implementationQuestion: implementationQuestion ?? '',
      status: isFolder ? AiTaskStatus.open : resolvedStatus,
      isFolder: isFolder,
      isWorksheet: isWorksheet,
      isNote: isNote,
      isKnowledgeSummary: isKnowledgeSummary,
      parentId: parentId,
      worksheetId: activeWorksheetId,
      highlightColor: highlightColor,
      iconBackgroundColor: iconBackgroundColor,
      iconColor: iconColor,
      toolbarIconColor: toolbarIconColor,
      preventDeletion: preventDeletion,
      applyLocksToChildren: applyLocksToChildren,
      isReadOnly: isReadOnly,
      isIgnored: isIgnored,
      llmPromptStyleOverride: llmPromptStyleOverride,
      commitHash: commitHash,
      commitDate: commitDate,
      iconCodePoint: iconCodePoint,
      fileAttachments: fileAttachments ?? [],
      hyperlinks: hyperlinks ?? [],
    );
    _tasks.add(task);
    await _save();
    return task;
  }

  Future<void> reorderBefore(String draggedId, String targetId) async {
    pushUndoState();
    final oldIndex = _tasks.indexWhere((t) => t.id == draggedId);
    if (oldIndex == -1) return;

    // Check if dropping onto itself
    if (draggedId == targetId) return;

    final targetParams = _tasks.firstWhere((t) => t.id == targetId);

    final moved = _tasks.removeAt(oldIndex);

    // Adopt target's parentId
    moved.parentId = targetParams.parentId;

    final newIndex = _tasks.indexWhere((t) => t.id == targetId);
    if (newIndex != -1) {
      _tasks.insert(newIndex, moved);
    } else {
      _tasks.add(moved);
    }
    await _save();
  }

  Future<void> reorderAfter(String draggedId, String targetId) async {
    pushUndoState();
    final oldIndex = _tasks.indexWhere((t) => t.id == draggedId);
    if (oldIndex == -1) return;

    // Check if dropping onto itself
    if (draggedId == targetId) return;

    final targetParams = _tasks.firstWhere((t) => t.id == targetId);

    final moved = _tasks.removeAt(oldIndex);
    moved.parentId = targetParams.parentId;

    final newIndex = _tasks.indexWhere((t) => t.id == targetId);
    if (newIndex != -1) {
      _tasks.insert(newIndex + 1, moved);
    } else {
      _tasks.add(moved);
    }
    await _save();
  }

  Future<void> moveTask(String taskId, String? newParentId, {String? newWorksheetId, bool clearWorksheetId = false}) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      if (newParentId != null && taskId == newParentId)
        return; // Prevent circular parenting
        
      String? resolvedWorksheetId = newWorksheetId;
      if (newParentId != null) {
        final parent = _tasks.firstWhere((t) => t.id == newParentId, orElse: () => _tasks[index]);
        if (parent.id == newParentId) {
          resolvedWorksheetId = parent.worksheetId ?? resolvedWorksheetId;
        }
      }

      if (_tasks[index].parentId == newParentId && 
         (clearWorksheetId ? _tasks[index].worksheetId == null : (resolvedWorksheetId == null || _tasks[index].worksheetId == resolvedWorksheetId)))
        return; // Prevent unnecessary drop-to-bottom glitches

      pushUndoState();
      final moved = _tasks.removeAt(index);
      moved.parentId = newParentId;

      if (clearWorksheetId) {
         void updateWorksheetRecursive(AiTask t, String? newWsId) {
            t.worksheetId = newWsId;
            final children = _tasks.where((child) => child.parentId == t.id).toList();
            for (var child in children) {
               updateWorksheetRecursive(child, newWsId);
            }
         }
         updateWorksheetRecursive(moved, null);
      } else if (resolvedWorksheetId != null && moved.worksheetId != resolvedWorksheetId) {
         void updateWorksheetRecursive(AiTask t, String? newWsId) {
            t.worksheetId = newWsId;
            final children = _tasks.where((child) => child.parentId == t.id).toList();
            for (var child in children) {
               updateWorksheetRecursive(child, newWsId);
            }
         }
         updateWorksheetRecursive(moved, resolvedWorksheetId);
      }

      _tasks.add(moved); // Move to bottom of target root
      await _save();
    }
  }

  void _triggerSandboxMergeIfNeeded(AiTaskStatus oldStatus, AiTask newTask) {
    // Single Timeline Workflow: We no longer auto-commit on status change.
    // Commits only happen when a checklist is fully verified.
  }

  Future<void> updateTaskStatus(String id, AiTaskStatus newStatus) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final oldStatus = _tasks[index].status;
      pushUndoState();
      _tasks[index].status = newStatus;
      await _save();
      _triggerSandboxMergeIfNeeded(oldStatus, _tasks[index]);
    }
  }

  Future<void> updateTaskPriority(String id, AiTaskPriority newPriority) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      pushUndoState();
      _tasks[index].priority = newPriority;
      await _save();
    }
  }

  Future<void> updateTaskNotes(String id, String notes) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      if (_tasks[index].notes != notes) {
        pushUndoState();
        _tasks[index].notes = notes;
        _tasks[index].isRead = false; // reset when notes genuinely change
        await _save();
      }
    }
  }

  Future<void> acceptProposedChanges(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1 && _tasks[index].proposedChanges != null) {
      pushUndoState();
      final proposals = _tasks[index].proposedChanges!;
      _tasks[index].name = proposals.name;
      _tasks[index].description = proposals.description;
      _tasks[index].notes = proposals.notes;
      _tasks[index].status = proposals.status;
      _tasks[index].proposedChanges = null;
      _tasks[index].isRead = false;
      await _save();
    }
  }

  Future<void> rejectProposedChanges(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1 && _tasks[index].proposedChanges != null) {
      pushUndoState();
      _tasks[index].proposedChanges = null;
      await _save();
    }
  }

  Future<void> updateTaskRead(String id, bool isRead) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      pushUndoState();
      _tasks[index].isRead = isRead;
      await _save();
    }
  }

  Future<void> markAllRead() async {
    bool hasChanges = false;
    for (var task in _tasks) {
      if (!task.isFolder &&
          task.status != AiTaskStatus.completed &&
          task.notes.isNotEmpty &&
          !task.isRead) {
        hasChanges = true;
        break;
      }
    }
    if (hasChanges) {
      pushUndoState();
      for (var task in _tasks) {
        task.isRead = true;
      }
      await _save();
    }
  }

  final Map<String, DateTime> _unlockedTasks = {};

  bool isTaskReadOnly(String taskId) {
    if (_unlockedTasks.containsKey(taskId)) {
      if (DateTime.now().isBefore(_unlockedTasks[taskId]!)) {
        return false;
      } else {
        _unlockedTasks.remove(taskId);
      }
    }
    if (_tasks.isEmpty) return false;
    final task =
        _tasks.firstWhere((t) => t.id == taskId, orElse: () => _tasks.first);
    if (task.id != taskId) return false;

    if (task.isReadOnly) return true;

    AiTask? current = task;
    Set<String> visited = {task.id};
    while (current != null && current.parentId != null) {
      if (visited.contains(current.parentId!)) break;
      visited.add(current.parentId!);
      final parent = _tasks.firstWhere((t) => t.id == current!.parentId,
          orElse: () => current!);
      if (parent.id == current.id) break;
      if (parent.applyLocksToChildren && parent.isReadOnly) return true;
      current = parent;
    }
    return false;
  }

  void unlockTask(String taskId) {
    _unlockedTasks[taskId] = DateTime.now().add(const Duration(minutes: 5));
    notifyListeners();
  }

  bool isTaskDeletionPrevented(String taskId) {
    final task =
        _tasks.firstWhere((t) => t.id == taskId, orElse: () => _tasks.first);
    if (task.id != taskId) return false;

    if (task.preventDeletion) return true;

    AiTask? current = task;
    Set<String> visited = {task.id};
    while (current != null && current.parentId != null) {
      if (visited.contains(current.parentId!)) break;
      visited.add(current.parentId!);
      final parent = _tasks.firstWhere((t) => t.id == current!.parentId,
          orElse: () => current!);
      if (parent.id == current.id) break;
      if (parent.applyLocksToChildren && parent.preventDeletion) return true;
      current = parent;
    }

    final Set<String> descendants = {taskId};
    bool added = true;
    while (added) {
      added = false;
      for (var t in _tasks) {
        if (t.parentId != null &&
            descendants.contains(t.parentId) &&
            !descendants.contains(t.id)) {
          descendants.add(t.id);
          added = true;
        }
      }
    }
    for (var dId in descendants) {
      if (dId == taskId) continue;
      final d = _tasks.firstWhere((t) => t.id == dId);
      if (d.preventDeletion) return true;
    }
    return false;
  }

  Future<void> deleteTask(String id) async {
    if (isTaskDeletionPrevented(id)) return;
    pushUndoState();
    final Set<String> toDelete = {id};
    bool added = true;
    while (added) {
      added = false;
      for (var t in _tasks) {
        if (t.parentId != null &&
            toDelete.contains(t.parentId) &&
            !toDelete.contains(t.id)) {
          toDelete.add(t.id);
          added = true;
        }
      }
    }
    _tasks.removeWhere((t) => toDelete.contains(t.id));
    await _save();
  }

  Future<void> clearAllCompleted() async {
    pushUndoState();
    _tasks.removeWhere((t) => t.status == AiTaskStatus.completed);
    await _save();
  }
}
