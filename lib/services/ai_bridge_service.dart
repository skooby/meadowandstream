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
import 'error_scanner.dart';
import 'antigravity_status_service.dart';
import 'ai_bridge_state_machine.dart';
import 'local_ai_service.dart';
import '../db/app_database.dart';

enum UpdateCoverType { hotReload, hotRestart, rebuild }

enum AntigravityBridgeMode { sdk, desktop, cli, handsfree }

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


enum AiVerificationStatus { none, submitted, pendingReview, verified, ignored }

class AiVerificationCriteria {
  String description;
  String goal;
  bool isVerified;
  AiVerificationStatus status;
  String? proof;
  String notes;
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
    this.notes = '',
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
        'notes': notes,
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
      notes: json['notes'] ?? '',
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
  bool isLocked;
  String llmPromptStyleOverride;
  AiTask? proposedChanges;
  List<String> fileAttachments;
  List<String> hyperlinks;
  String? commitHash;
  String? commitDate;
  String? previewState;

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
    this.isLocked = false,
    this.llmPromptStyleOverride = 'Use Default',
    this.proposedChanges,
    this.commitHash,
    this.commitDate,
    this.previewState,
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
      'isLocked': isLocked,
      'llmPromptStyleOverride': llmPromptStyleOverride,
      'fileAttachments': fileAttachments,
      'hyperlinks': hyperlinks,
      'commitHash': commitHash,
      'commitDate': commitDate,
      'previewState': previewState,
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
      isLocked: json['isLocked'] ?? false,
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
      previewState: json['previewState'] as String?,
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
  final String? targetCriteriaDescription;
  DateTime? completedAt;

  QueuedPrompt(
    this.text,
    this.block,
    this.taskIds, {
    this.targetCriteriaDescription,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'block': block,
        'taskIds': taskIds,
        'targetCriteriaDescription': targetCriteriaDescription,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory QueuedPrompt.fromJson(Map<String, dynamic> json) {
    final taskIdsData = json['taskIds'] as List<dynamic>?;
    return QueuedPrompt(
      json['text'] as String,
      json['block'] == true,
      taskIdsData?.map((e) => e.toString()).toList(),
      targetCriteriaDescription: json['targetCriteriaDescription'] as String?,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
    );
  }
}

class SimulatedAction {
  final String type; // 'PROMPT', 'VBS_SCRIPT', 'MACRO', 'API_CALL', 'FILE_WRITE', 'QUEUE', 'METADATA', 'STATE', 'STATUS_WRITE'
  final String title;
  final String detail;
  final DateTime timestamp;

  SimulatedAction({
    required this.type,
    required this.title,
    required this.detail,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'detail': detail,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SimulatedAction.fromJson(Map<String, dynamic> json) {
    return SimulatedAction(
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      detail: json['detail'] ?? '',
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
    );
  }
}

/// Represents a document review request written by the AI agent to
/// `.ai_bridge/pending_review.json`. When this file is present, the bridge
/// suspends the pipeline and surfaces a review UI for the user.
///
/// Agent schema:
/// ```json
/// {
///   "filePath": "/abs/path/to/document.md",
///   "fileName": "document.md",
///   "summary": "AI-generated summary of the document contents...",
///   "reason": "Why this document needs user review before proceeding.",
///   "createdAt": "2026-05-28T05:00:00.000Z"
/// }
/// ```
class PendingReviewRequest {
  final String filePath;
  final String fileName;
  final String summary;
  final String reason;
  final DateTime createdAt;

  const PendingReviewRequest({
    required this.filePath,
    required this.fileName,
    required this.summary,
    required this.reason,
    required this.createdAt,
  });

  factory PendingReviewRequest.fromJson(Map<String, dynamic> json) {
    return PendingReviewRequest(
      filePath: json['filePath'] as String? ?? '',
      fileName: json['fileName'] as String? ?? json['filePath']?.split('/').last ?? 'document',
      summary: json['summary'] as String? ?? '',
      reason: json['reason'] as String? ?? 'Document requires your review.',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'filePath': filePath,
    'fileName': fileName,
    'summary': summary,
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
  };

  PendingReviewRequest copyWith({String? summary}) {
    return PendingReviewRequest(
      filePath: filePath,
      fileName: fileName,
      summary: summary ?? this.summary,
      reason: reason,
      createdAt: createdAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Document Summary Service
// Delegates to LocalAiService — the same AI assistant used by the Task Editor.
// Tries Ollama first (with auto-start), falls back to OpenAI if unavailable.
// ---------------------------------------------------------------------------

class OllamaDocumentSummaryService {
  static const int _maxDocumentChars = 8000; // Truncation limit

  /// Reads [filePath], truncates if needed, and asks the AI assistant to
  /// summarize it. Returns an empty string on any failure.
  static Future<String> generateSummary(String filePath) async {
    // 1. Read file content
    String content;
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('[DocSummary] File not found: $filePath');
        return '';
      }
      content = file.readAsStringSync();
      if (content.length > _maxDocumentChars) {
        content = '${content.substring(0, _maxDocumentChars)}\n...[truncated]';
      }
    } catch (e) {
      debugPrint('[DocSummary] File read error: $e');
      return '';
    }

    // 2. Delegate to LocalAiService — same assistant as the Task Editor.
    //    It uses the user's configured model, auto-starts Ollama if needed,
    //    and falls back to OpenAI (gpt-4o-mini) if Ollama is unavailable.
    try {
      final prompt =
          'You are a technical document summarizer. Please provide a concise '
          '2-4 sentence summary of the following document. Focus on the key '
          'purpose, main changes or findings, and any action required by the '
          'reader. Do not use bullet points — respond with plain prose only.\n\n'
          'Document:\n$content';

      final result = await LocalAiService.instance.generateText(prompt);
      final summary = (result ?? '').trim();
      debugPrint('[DocSummary] Summary generated (${summary.length} chars)');
      return summary;
    } catch (e) {
      debugPrint('[DocSummary] Generate error: $e');
      return '';
    }
  }
}

class AiBridgeService extends ChangeNotifier with WindowListener {
  static final AiBridgeService instance = AiBridgeService._internal();

  final AiBridgeStateMachine stateMachine = AiBridgeStateMachine();

  bool _isDryRunMode = false;
  bool get isDryRunMode => _isDryRunMode;

  final List<SimulatedAction> _simulatedActions = [];
  List<SimulatedAction> get simulatedActions => _simulatedActions;

  void setDryRunMode(bool enabled) {
    _isDryRunMode = enabled;
    clearSimulatedActions();
    _getPrefs().then((prefs) => prefs.setBool('ai_bridge_dry_run_mode', enabled));
  }

  void logSimulatedAction(String type, String title, String detail) {
    _simulatedActions.add(SimulatedAction(type: type, title: title, detail: detail));
    _saveSimulatedActions();
    notifyListeners();
  }

  void clearSimulatedActions() {
    _simulatedActions.clear();
    _saveSimulatedActions();
    notifyListeners();
  }

  Future<void> _saveSimulatedActions() async {
    try {
      final prefs = await _getPrefs();
      final List<String> encoded =
          _simulatedActions.map((a) => jsonEncode(a.toJson())).toList();
      await prefs.setStringList('ai_bridge_simulated_actions', encoded);
    } catch (e) {
      debugPrint('Failed to save simulated actions: $e');
    }
  }

  late AntigravityClient antigravityClient;
  AppDatabase? _db;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null && !Platform.environment.containsKey('FLUTTER_TEST')) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  AiBridgeService._internal() {
    _initClient();
    AntigravityStatusService.instance.statusFilePath = '$_dirPath/agent_status.txt';
    stateMachine.start();
  }

  void initialize(AppDatabase db) {
    _db = db;
    AntigravityStatusService.instance.statusFilePath = '$_dirPath/agent_status.txt';
    syncDatabaseDump();
    syncConversationHistory();
    init();
  }

  Future<List<File>> _getBrainFiles(Directory brainDir) async {
    try {
      final exists = await brainDir.exists().timeout(const Duration(milliseconds: 500), onTimeout: () => false);
      if (!exists) return const [];
    } catch (_) {
      return const [];
    }

    final List<File> files = [];

    // Check root folder (for unit test compatibility or direct files)
    final rootTranscript = File('${brainDir.path}/transcript.jsonl');
    final rootOverview = File('${brainDir.path}/overview.txt');

    try {
      final rootChecks = await Future.wait([
        rootTranscript.exists().timeout(const Duration(milliseconds: 300), onTimeout: () => false),
        rootOverview.exists().timeout(const Duration(milliseconds: 300), onTimeout: () => false),
      ]);
      if (rootChecks[0]) files.add(rootTranscript);
      if (rootChecks[1]) files.add(rootOverview);

      final List<FileSystemEntity> entities = await brainDir
          .list(recursive: false)
          .toList()
          .timeout(const Duration(milliseconds: 1000), onTimeout: () => []);
          
      final subdirs = entities.whereType<Directory>().toList();
      final Map<Directory, DateTime> subdirTimes = {};
      await Future.wait(subdirs.map((dir) async {
        try {
          final stat = await dir.stat().timeout(const Duration(milliseconds: 300));
          subdirTimes[dir] = stat.modified;
        } catch (_) {
          subdirTimes[dir] = DateTime.fromMillisecondsSinceEpoch(0);
        }
      }));
      subdirs.sort((a, b) => (subdirTimes[b] ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(subdirTimes[a] ?? DateTime.fromMillisecondsSinceEpoch(0)));

      final List<Future<void>> subdirChecks = [];
      for (final subdir in subdirs.take(3)) {
        subdirChecks.add(() async {
          final transcript = File('${subdir.path}/.system_generated/logs/transcript.jsonl');
          final overview = File('${subdir.path}/overview.txt');
          final overviewSys = File('${subdir.path}/.system_generated/overview.txt');
          
          final checks = await Future.wait([
            transcript.exists().timeout(const Duration(milliseconds: 300), onTimeout: () => false),
            overview.exists().timeout(const Duration(milliseconds: 300), onTimeout: () => false),
            overviewSys.exists().timeout(const Duration(milliseconds: 300), onTimeout: () => false),
          ]);
          
          if (checks[0]) files.add(transcript);
          if (checks[1]) files.add(overview);
          if (checks[2]) files.add(overviewSys);
        }());
      }
      
      await Future.wait(subdirChecks).timeout(const Duration(milliseconds: 1500), onTimeout: () => []);
    } catch (e) {
      debugPrint('[AiBridgeService] Error getting brain files: $e');
    }
    return files;
  }

  Future<void> syncDatabaseDump() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      debugPrint('[AiBridgeService] Skipping database dump sync in unit test environment.');
      return;
    }
    final db = _db;
    if (db == null) return;
    try {
      final assetsList = await db.select(db.assets).get().timeout(const Duration(milliseconds: 800));
      final stringsList = await db.select(db.strings).get().timeout(const Duration(milliseconds: 800));
      final translationsList = await db.select(db.translations).get().timeout(const Duration(milliseconds: 800));
      final assetTagsList = await db.select(db.assetTags).get().timeout(const Duration(milliseconds: 800));

      final dump = {
        'assets': assetsList.map((e) => e.toJson()).toList(),
        'strings': stringsList.map((e) => e.toJson()).toList(),
        'translations': translationsList.map((e) => e.toJson()).toList(),
        'assetTags': assetTagsList.map((e) => e.toJson()).toList(),
      };

      final dumpDir = Directory('.ai_bridge');
      if (!await dumpDir.exists()) {
        await dumpDir.create(recursive: true);
      }
      final dumpFile = File('.ai_bridge/db_dump.json');
      final newContent = const JsonEncoder.withIndent('  ').convert(dump);
      if (await dumpFile.exists()) {
        final currentContent = await dumpFile.readAsString();
        if (currentContent == newContent) {
          return;
        }
      }
      await dumpFile.writeAsString(newContent, flush: true);
      debugPrint('[AiBridgeService] Synced database dump to .ai_bridge/db_dump.json');
    } catch (e) {
      debugPrint('[AiBridgeService] Error syncing database dump: $e');
    }
  }

  Future<List<String>> _readAsLinesWithRetry(File file, {int maxRetries = 3, Duration delay = const Duration(milliseconds: 100)}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await file.readAsLines().timeout(
          const Duration(milliseconds: 1000),
          onTimeout: () => const [],
        );
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          rethrow;
        }
        await Future.delayed(delay);
      }
    }
    return const [];
  }

  @visibleForTesting
  Future<List<String>> readAsLinesWithRetryForTesting(File file, {int maxRetries = 3, Duration delay = const Duration(milliseconds: 100)}) {
    return _readAsLinesWithRetry(file, maxRetries: maxRetries, delay: delay);
  }

  Future<void> syncConversationHistory([File? file]) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    try {
      File? targetFile = file;
      if (targetFile == null) {
        final String userProfile = Platform.environment['USERPROFILE'] ?? '';
        if (userProfile.isEmpty) return;
        final brainDir = Directory('$userProfile\\.gemini\\antigravity\\brain');
        if (!await brainDir.exists()) return;
        final files = await _getBrainFiles(brainDir);
        final transcripts = files.where((f) => f.path.endsWith('transcript.jsonl')).toList();
        if (transcripts.isEmpty) return;
        // Sort by last modified to find the active one
        transcripts.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        targetFile = transcripts.first;
      }

      if (!targetFile.existsSync()) return;

      final lines = await _readAsLinesWithRetry(targetFile);

      // Check if we need to reset the logged steps index (e.g. new session or file was cleared/shrunk)
      bool hasReset = false;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('{')) continue;
        try {
          final map = jsonDecode(trimmed) as Map<String, dynamic>;
          final stepIndex = map['step_index'] as int?;
          if (stepIndex != null && stepIndex < _lastLoggedStepIndex) {
            hasReset = true;
            break;
          }
        } catch (_) {}
      }
      if (hasReset) {
        _lastLoggedStepIndex = -1;
      }

      if (_lastLoggedStepIndex == -1 && file == null) {
        // Startup run: set index to max to avoid dumping old session logs
        int maxIndex = -1;
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || !trimmed.startsWith('{')) continue;
          try {
            final map = jsonDecode(trimmed) as Map<String, dynamic>;
            final stepIndex = map['step_index'] as int?;
            if (stepIndex != null && stepIndex > maxIndex) {
              maxIndex = stepIndex;
            }
          } catch (_) {}
        }
        _lastLoggedStepIndex = maxIndex;
      }

      final sb = StringBuffer();
      sb.writeln('# Conversation History (Realtime Logs)');
      sb.writeln('Source file: `${targetFile.path}`');
      sb.writeln('Last Synced: ${DateTime.now().toLocal().toString().split('.').first}');
      sb.writeln('\n---\n');

      int maxStepIndex = _lastLoggedStepIndex;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('{')) continue;
        try {
          final map = jsonDecode(trimmed) as Map<String, dynamic>;
          final stepIndex = map['step_index'] as int?;
          final type = map['type'] as String?;
          final source = map['source'] as String?;
          final content = map['content'] as String? ?? '';
          final toolCalls = map['tool_calls'] as List?;

          // Format for markdown document
          if (source == 'USER_EXPLICIT' || type == 'USER_INPUT') {
            sb.writeln('## 👤 USER');
            sb.writeln(content);
            sb.writeln('\n');
          } else if (source == 'MODEL') {
            sb.writeln('## 🤖 AGENT');
            if (content.isNotEmpty) {
              sb.writeln(content);
              sb.writeln('\n');
            }
            if (toolCalls != null && toolCalls.isNotEmpty) {
              sb.writeln('**Tool Calls**:');
              for (final call in toolCalls) {
                final name = call['name'] ?? call['method'] ?? 'unknown_tool';
                final args = call['args'] ?? call['arguments'] ?? {};
                sb.writeln('- Tool: `$name`');
                sb.writeln('  Arguments: `${jsonEncode(args)}`');
              }
              sb.writeln('\n');
            }
          } else if (source == 'SYSTEM') {
            if (type == 'TOOL_RESPONSE' || content.isNotEmpty) {
              sb.writeln('> **System/Tool Result**:');
              sb.writeln('> ${content.replaceAll('\n', '\n> ')}');
              sb.writeln('\n');
            }
          }

          // Output to SystemLogsService for real-time viewing if it hasn't been logged yet
          if (stepIndex != null && stepIndex > _lastLoggedStepIndex) {
            if (stepIndex > maxStepIndex) {
              maxStepIndex = stepIndex;
            }

            final String prefix;
            switch (_bridgeMode) {
              case AntigravityBridgeMode.sdk:
                prefix = '[SDK]';
                break;
              case AntigravityBridgeMode.desktop:
                prefix = '[Desktop]';
                break;
              case AntigravityBridgeMode.cli:
                prefix = '[CLI]';
                break;
              case AntigravityBridgeMode.handsfree:
                prefix = '[Handsfree]';
                break;
            }
            if (source == 'USER_EXPLICIT' || type == 'USER_INPUT') {
              final cleanContent = content.trim().replaceAll('\n', ' ');
              SystemLogsService.instance.addLog('$prefix USER: "$cleanContent"', category: LogCategory.CLI);
            } else if (source == 'MODEL' && type == 'PLANNER_RESPONSE') {
              if (content.isNotEmpty) {
                // Strip XML tags and markdown blocks, extract first line or short summary of thoughts
                final clean = content.replaceAll(RegExp(r'<[^>]*>'), '').trim().replaceAll('\n', ' ');
                final disp = clean.length > 120 ? '${clean.substring(0, 120)}...' : clean;
                if (disp.isNotEmpty) {
                  SystemLogsService.instance.addLog('$prefix AGENT: $disp', category: LogCategory.CLI);
                }
              }
              if (toolCalls != null && toolCalls.isNotEmpty) {
                for (final call in toolCalls) {
                  final name = call['name'] ?? call['method'] ?? 'tool';
                  final args = call['args'] ?? call['arguments'] ?? {};
                  
                  // Extract key details based on tool name
                  String details = '';
                  if (name == 'view_file' || name == 'write_to_file' || name == 'replace_file_content' || name == 'multi_replace_file_content') {
                    final path = args['AbsolutePath'] ?? args['TargetFile'] ?? '';
                    final filename = path.toString().split('/').last.split('\\').last;
                    details = 'File: $filename';
                  } else if (name == 'grep_search') {
                    details = 'Query: "${args['Query']}"';
                  } else if (name == 'run_command') {
                    details = 'Cmd: "${args['CommandLine']}"';
                  } else if (name == 'list_dir') {
                    final path = args['DirectoryPath'] ?? '';
                    final dirName = path.toString().split('/').last.split('\\').last;
                    details = 'Dir: $dirName';
                  } else {
                    details = args.keys.take(2).map((k) => '$k: ${args[k]}').join(', ');
                  }
                  
                  SystemLogsService.instance.addLog('$prefix AGENT: Calling tool `$name` ($details)', category: LogCategory.CLI);
                }
              }
            } else if (source == 'SYSTEM') {
              if (content.isNotEmpty) {
                final isErr = content.toLowerCase().contains('error') || content.toLowerCase().contains('failed') || content.toLowerCase().contains('exception');
                if (isErr) {
                  final cleanErr = content.trim().replaceAll('\n', ' ');
                  final dispErr = cleanErr.length > 150 ? '${cleanErr.substring(0, 150)}...' : cleanErr;
                  SystemLogsService.instance.addLog('$prefix TOOL ERROR: $dispErr', category: LogCategory.CLI);
                } else {
                  SystemLogsService.instance.addLog('$prefix TOOL RESULT: Completed successfully (${content.length} bytes returned)', category: LogCategory.CLI);
                }
              }
            }
          }
        } catch (_) {}
      }

      _lastLoggedStepIndex = maxStepIndex;

      // Disabled writing to conversation_history.md and logging per user request: "lets stop processing this for now..."
      /*
      final destFile = File('.ai_bridge/conversation_history.md');
      if (!destFile.parent.existsSync()) {
        destFile.parent.createSync(recursive: true);
      }
      await destFile.writeAsString(sb.toString(), flush: true);
      debugPrint('[AiBridgeService] Synced conversation history to .ai_bridge/conversation_history.md');
      */
    } catch (e) {
      debugPrint('[AiBridgeService] Error syncing conversation history: $e');
    }
  }

  Future<void> _ensureBackendRunning() async {
    if (_sendViaClipboard) {
      debugPrint('[AiBridgeService] Skipping background HTTP daemon startup because Send via clipboard paste to the CLI is enabled.');
      return;
    }
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
    try {
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

      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        try {
          antigravityClient;
        } catch (_) {
          antigravityClient = AntigravityClient.custom(
            config: const AntigravityConfig(
              binaryPath: '',
              lsAddress: '127.0.0.1:8080',
              csrfToken: '',
              projectId: '',
              targetModel: 'gemini-2.0-flash',
              apiKey: '',
            ),
          );
          AntigravityClient.instance = antigravityClient;
        }
      } else {
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
      }

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
    } catch (e) {
      debugPrint('[AiBridgeService] Error initializing client: $e');
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        try {
          antigravityClient;
        } catch (_) {
          antigravityClient = AntigravityClient.custom(
            config: const AntigravityConfig(
              binaryPath: '',
              lsAddress: '127.0.0.1:8080',
              csrfToken: '',
              projectId: '',
              targetModel: 'gemini-2.0-flash',
              apiKey: '',
            ),
          );
          AntigravityClient.instance = antigravityClient;
        }
      } else {
        antigravityClient = AntigravityClient.custom(
          config: const AntigravityConfig(
            binaryPath: '',
            lsAddress: '127.0.0.1:8080',
            csrfToken: '',
            projectId: '',
            targetModel: 'gemini-2.0-flash',
            apiKey: '',
          ),
        );
        AntigravityClient.instance = antigravityClient;
      }
    }
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
                notes: (match.notes.isNotEmpty) ? match.notes : ext.notes,
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

  Future<void> _chooseModelTier() async {
    final prefs = await SharedPreferences.getInstance();
    final useHi = prefs.getBool('antigravity_use_hi_model') ?? false;
    final loModel = prefs.getString('antigravity_lo_model') ?? 'gemini-2.0-flash-lite';
    final hiModel = prefs.getString('antigravity_hi_model') ?? 'gemini-2.0-flash';
    final modelToUse = useHi ? hiModel : loModel;

    await prefs.setString('antigravity_model', modelToUse);
    await updateAntigravityConfig();

    // Write the chosen model directly into ~/.gemini/antigravity-cli/settings.json
    // so the Antigravity CLI loads it natively on its next session init.
    try {
      final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
      final settingsFile = File('$userProfile\\.gemini\\antigravity-cli\\settings.json');
      Map<String, dynamic> settingsJson = {};
      if (await settingsFile.exists()) {
        final raw = await settingsFile.readAsString();
        settingsJson = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
      settingsJson['model'] = modelToUse;
      await settingsFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(settingsJson),
        flush: true,
      );
      debugPrint('[AiBridgeService] Wrote model "$modelToUse" to antigravity-cli settings.json');
    } catch (e) {
      debugPrint('[AiBridgeService] Failed to write model to antigravity-cli settings.json: $e');
    }
  }

  String _dirPath = '.ai_bridge';
  String _filePath = '.ai_bridge/tasks.json';
  String get bridgeDirPath => _dirPath;

  @visibleForTesting
  Directory? testBrainDir;

  @visibleForTesting
  set testDirPath(String path) {
    _dirPath = path;
    AntigravityStatusService.instance.statusFilePath = '$path/agent_status.txt';
  }

  @visibleForTesting
  String get testDirPath => _dirPath;

  @visibleForTesting
  set testFilePath(String path) {
    _filePath = path;
  }

  @visibleForTesting
  String get filePath => _filePath;

  @visibleForTesting
  void initializeForTesting() {
    _startWatching();
    _startWatchingAntigravity();
  }

  bool forceDiskSaveInTests = false;

  Future<void> loadFromFileForTesting() async {
    final wasSaving = _isSavingLocally;
    _isSavingLocally = false;
    try {
      await _loadFromFile();
    } finally {
      _isSavingLocally = wasSaving;
    }
  }


  StreamSubscription<FileSystemEvent>? _watchSubscription;
  StreamSubscription<FileSystemEvent>? _libWatchSubscription;
  StreamSubscription<FileSystemEvent>? _rootWatchSubscription;
  bool _isSavingLocally = false;
  int _lastProcessedLogIndex = 0;
  int _lastLoggedStepIndex = -1;
  Timer? _errorDebounceTimer;
  Timer? _dryRunTimer;
  final List<DetectedError> _errorBuffer = [];
  bool _isLogListenerRegistered = false;

  @override
  void dispose() {
    windowManager.removeListener(this);
    SystemLogsService.instance.removeListener(_handleSystemLogsChanged);
    _isLogListenerRegistered = false;
    _errorDebounceTimer?.cancel();
    _dryRunTimer?.cancel();
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
  UpdateCoverType? get pendingUpdateType => _pendingUpdateType;
  bool _isTriggeringUpdate = false;

  bool _isQueuePaused = false;
  bool get isQueuePaused => _isQueuePaused;
  bool _isProcessingQueue = false;

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

  String _rulesDirPath = '.agent/rules';

  @visibleForTesting
  set testRulesDirPath(String path) {
    _rulesDirPath = path;
  }

  bool _useHiModel = false;
  bool get useHiModel => _useHiModel;

  void setUseHiModel(bool value) async {
    _useHiModel = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('antigravity_use_hi_model', value);
  }

  void setBridgeMode(AntigravityBridgeMode mode) async {
    _bridgeMode = mode;
    _writeActiveModeFile(mode.name);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('antigravity_bridge_mode', mode.name);
  }

  void _writeActiveModeFile(String modeName) {
    try {
      final file = File('$_dirPath/active_mode.txt');
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync(modeName);
    } catch (e) {
      debugPrint('Failed to write active_mode.txt: $e');
    }
  }

  bool _sendViaClipboard = true;
  bool get sendViaClipboard => _sendViaClipboard;

  void setSendViaClipboard(bool value) async {
    _sendViaClipboard = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('antigravity_send_via_clipboard', value);
  }

  final List<QueuedPrompt> _pendingPrompts = [];
  final List<QueuedPrompt> _completedPrompts = [];
  QueuedPrompt? _activePrompt;
  bool _isPromptDispatched = false;

  @visibleForTesting
  set isPromptDispatched(bool value) => _isPromptDispatched = value;

  List<QueuedPrompt> get pendingPrompts => _pendingPrompts;
  List<QueuedPrompt> get completedPrompts => _completedPrompts;
  QueuedPrompt? get activePrompt => _activePrompt;

  String _queueStatus = 'IDLE';
  String get queueStatus => _queueStatus;

  // Rolling log of recent pipeline phase messages (newest first).
  // Used by the Bridge Monitor to explain why the pipeline completed early
  // or what internal state transitions occurred during processing.
  final List<String> _pipelinePhaseLog = [];
  List<String> get pipelinePhaseLog => List.unmodifiable(_pipelinePhaseLog);

  void _logPhase(String message) {
    final ts = DateTime.now().toLocal().toString().split('.').first;
    final entry = '[$ts] $message';
    _pipelinePhaseLog.insert(0, entry);
    if (_pipelinePhaseLog.length > 50) {
      _pipelinePhaseLog.removeLast();
    }
    print('[AiBridge][Phase] $message');
    notifyListeners();
  }


  void _writeQueueStatus(String status) {
    if (_queueStatus == status) return;
    _queueStatus = status;
    logSimulatedAction('FILE_WRITE', 'Write queue_status.txt', status);
    try {
      final qFile = File('$_dirPath/queue_status.txt');
      if (!qFile.parent.existsSync()) {
        qFile.parent.createSync(recursive: true);
      }
      qFile.writeAsStringSync(status);
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        try {
          File('queue_status.txt').writeAsStringSync(status);
        } catch (_) {}
      }
      print('[AiBridge] Wrote $status to queue_status.txt');
    } catch (e) {
      print('[AiBridge] Failed to write queue_status.txt: $e');
    }
    notifyListeners();
  }

  String? _activeProcessingTaskId;
  DateTime? _activeProcessingTaskAssignedAt;

  String? get activeProcessingTaskId => _activeProcessingTaskId;
  DateTime? get activeProcessingTaskAssignedAt => _activeProcessingTaskAssignedAt;
  int _compileErrorLoopCount = 0;
  bool _isHandlingAgentStatus = false;
  DateTime? _statusHandlingLockAcquiredAt;
  bool get isHandlingAgentStatus => _isHandlingAgentStatus;
  DateTime? get statusHandlingLockAcquiredAt => _statusHandlingLockAcquiredAt;
  // Incremented by clearQueue() / forceResetIdle() so that in-flight async
  // methods can detect they've been superseded and abort gracefully.
  int _interruptionToken = 0;

  final Map<String, SubagentConnection> _activeAgents = {};
  Map<String, SubagentConnection> get activeAgents => Map.unmodifiable(_activeAgents);

  List<String> get activeTaskIds => _activeAgents.keys.toList();
  List<String> get pipelineTaskIds => [];
  List<String> get completedTaskIds => [];

  // --- Pending Document Review ---
  PendingReviewRequest? _pendingReview;
  PendingReviewRequest? get pendingReview => _pendingReview;
  bool get hasPendingDocumentReview => _pendingReview != null;

  bool _isSummarizingReview = false;
  bool get isSummarizingReview => _isSummarizingReview;

  /// Accept the pending document review. Writes a `review_result.json` signal
  /// file and deletes `pending_review.json` so the agent can continue.
  Future<void> acceptPendingReview() async {
    try {
      final signalFile = File('$_dirPath/review_result.json');
      signalFile.writeAsStringSync(jsonEncode({
        'result': 'accepted',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      final reviewFile = File('$_dirPath/pending_review.json');
      if (reviewFile.existsSync()) reviewFile.deleteSync();
    } catch (e) {
      debugPrint('[AiBridge] acceptPendingReview error: $e');
    }
    _pendingReview = null;
    _isSummarizingReview = false; // Cancel any in-progress summarization
    notifyListeners();
    print('[AiBridge] User ACCEPTED pending document review.');
  }

  /// Reject the pending document review with optional feedback text.
  Future<void> rejectPendingReview({String feedback = ''}) async {
    try {
      final signalFile = File('$_dirPath/review_result.json');
      signalFile.writeAsStringSync(jsonEncode({
        'result': 'rejected',
        'feedback': feedback,
        'timestamp': DateTime.now().toIso8601String(),
      }));
      final reviewFile = File('$_dirPath/pending_review.json');
      if (reviewFile.existsSync()) reviewFile.deleteSync();
    } catch (e) {
      debugPrint('[AiBridge] rejectPendingReview error: $e');
    }
    _pendingReview = null;
    _isSummarizingReview = false; // Cancel any in-progress summarization
    notifyListeners();
    print('[AiBridge] User REJECTED pending document review. Feedback: ${feedback.isEmpty ? "(none)" : feedback}');
  }

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

  void _writeCurrentTaskFile(String taskId, {String? targetCriteriaDescription}) {
    if (Platform.environment.containsKey('FLUTTER_TEST') && !forceDiskSaveInTests) {
      return;
    }
    try {
      final taskIdx = _tasks.indexWhere((t) => t.id == taskId);
      if (taskIdx == -1) return;
      final task = _tasks[taskIdx];
      final json = task.toJson();
      json['name'] = _buildTaskPathName(task);
      // targetCriteriaIndex is the canonical index into the FULL verificationCriteria
      // list that the agent must echo back in latest_verification.json so the bridge
      // can match the returned proof unambiguously without relying on string matching.
      int? targetCriteriaIndex;
      if (json['verificationCriteria'] != null) {
        if (targetCriteriaDescription != null) {
          final idx = task.verificationCriteria.indexWhere(
            (e) => e.description.trim().toLowerCase() == targetCriteriaDescription.trim().toLowerCase(),
          );
          final resolvedIdx = idx != -1 ? idx : 0;
          targetCriteriaIndex = resolvedIdx;
          json['verificationCriteria'] = [task.verificationCriteria[resolvedIdx].toJson()];
        } else {
          final uncheckedTasks = task.verificationCriteria
              .where((e) =>
                  e.status != AiVerificationStatus.verified &&
                  e.status != AiVerificationStatus.ignored &&
                  e.status != AiVerificationStatus.pendingReview &&
                  !e.isPreview)
              .toList();
          if (uncheckedTasks.isNotEmpty) {
            final firstUnchecked = uncheckedTasks.first;
            final globalIdx = task.verificationCriteria.indexOf(firstUnchecked);
            targetCriteriaIndex = globalIdx >= 0 ? globalIdx : 0;
            json['verificationCriteria'] = [firstUnchecked.toJson()];
          } else {
            json['verificationCriteria'] = [];
          }
        }
      }
      // Embed the index so the agent can echo it back verbatim.
      if (targetCriteriaIndex != null) {
        json['targetCriteriaIndex'] = targetCriteriaIndex;
      }
      if (_isDryRunMode) {
        logSimulatedAction('FILE_WRITE', 'Write current_task.json', jsonEncode(json));
      }
      File('$_dirPath/current_task.json')
          .writeAsString(jsonEncode(json), flush: true)
          .catchError((e) {
        debugPrint('Failed to write current_task.json: $e');
      });
    } catch (e) {
      debugPrint('Failed to initiate current_task.json write: $e');
    }
  }

  Future<void> sendToQueue(String text, bool blockScreen,
      {List<String>? taskIds, bool insertFirst = false, String? targetCriteriaDescription}) async {
    final summaryLink = Uri.file(File('$_dirPath/project_summary.md').absolute.path).toString();
    final processedText = text.replaceAll('{SUMMARY}', summaryLink);

    clearSimulatedActions();
    _lastLoggedStepIndex = -1;

    // Check for custom macro rules (Slash Command Override)
    final rules = await loadCustomRules(_rulesDirPath);
    CustomRule? triggeredRule;
    final trimmedText = processedText.trim();
    for (final rule in rules) {
      if (trimmedText == rule.trigger) {
        triggeredRule = rule;
        break;
      }
    }

    if (triggeredRule != null) {
      if (triggeredRule.action == 'route-harness') {
        final model = extractModelFromRuleBody(triggeredRule.body);
        if (model != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('antigravity_model', model);
          await updateAntigravityConfig();
          
          final logMsg = 'Routed harness to model: $model based on rule trigger: ${triggeredRule.trigger}';
          debugPrint('[AiBridgeService] $logMsg');
          SystemLogsService.instance.addLog('[AiBridgeService] $logMsg', category: LogCategory.AI);
          
          if (_isDryRunMode) {
            logSimulatedAction('RULE_TRIGGERED', triggeredRule.trigger, logMsg);
          }
          notifyListeners();
          return; // Intercept prompt/command, do not queue
        }
      }
    }

    if (_isDryRunMode) {
      logSimulatedAction('QUEUE', 'Add Prompt to Queue', processedText);
      if (taskIds != null && taskIds.isNotEmpty) {
        logSimulatedAction('METADATA', 'Associated Task IDs', taskIds.join(', '));
      }
    }

    if (insertFirst) {
      _pendingPrompts.insert(0, QueuedPrompt(processedText, blockScreen, taskIds, targetCriteriaDescription: targetCriteriaDescription));
    } else {
      _pendingPrompts.add(QueuedPrompt(processedText, blockScreen, taskIds, targetCriteriaDescription: targetCriteriaDescription));
    }

    if (taskIds != null && taskIds.isNotEmpty) {
      if (!_isDryRunMode) {
        await SandboxService.instance.addToSandbox(taskIds);
      }
    }

    await _saveQueueState();
    notifyListeners();

    if (_activeProcessingTaskId == null && _activePrompt == null) {
      _pendingUpdateType = null;
      await _processQueue();
    }
  }

  Future<void> executeTask(AiTask task) async {
    if (isTaskOrAncestorIgnored(task)) {
      print('[AiBridge] Aborting execution of ignored task: ${task.name}');
      return;
    }
    _lastLoggedStepIndex = -1;
    await _ensureBackendRunning();
    await syncDatabaseDump();
    await _updateDispatchState();
    await _chooseModelTier();
    final json = task.toJson();
    json['name'] = _buildTaskPathName(task);
    json['endingInstructions'] = _endingInstructions;
    final connection = await antigravityClient.invokeSubagent(json);
    _activeAgents[task.id] = connection;
    _isAntigravityBusy = true;
    stateMachine.enterBusy();
    _updateStateMachineInputs();
    notifyListeners();

    connection.statusStream.listen((status) async {
      if (status == "Completed") {
        _activeAgents.remove(task.id);
        _isAntigravityBusy = false;
        _antigravityLastChangeObservedAt = null;
        _updateStateMachineInputs();
        
        String statusName = 'IDLE';
        try {
          final statusFile = File('$_dirPath/agent_status.txt');
          if (statusFile.existsSync()) {
            final content = statusFile.readAsStringSync().trim().toUpperCase();
            if (content.startsWith('PR')) {
              statusName = 'PREVIEW';
            }
          }
        } catch (_) {}

        if (!_isHandlingAgentStatus) {
          await _processStatusChange(statusName);
        }
      }
      notifyListeners();
    });
  }

  Future<void> _sendToAiAgent(String text) async {
    await _chooseModelTier();
    stateMachine.enterDispatching();
    await _updateDispatchState();
    _isPromptDispatched = true;
    _isAntigravityBusy = true;
    notifyListeners(); // Immediately notify UI that agent is busy — the 1500ms poller is too slow for fast queue items.

    // 1. Log Dispatch
    logSimulatedAction('STATE', 'Dispatch Prompt', 'Dispatching prompt to agent.');
    logSimulatedAction('PROMPT', 'Prompt Text', text);

    // Log the full prompt to System Logs so the user can see exactly what was sent
    SystemLogsService.instance.addLog(
      '[PROMPT SENT — ${text.length} chars]\n$text',
      category: LogCategory.AI,
    );

    // 2. Write current_task.json
    if (_activeProcessingTaskId != null) {
      logSimulatedAction('FILE_WRITE', 'Write current_task.json', 'Writing task ID: $_activeProcessingTaskId');
      _writeCurrentTaskFile(_activeProcessingTaskId!, targetCriteriaDescription: _activePrompt?.targetCriteriaDescription);
    } else {
      final json = {
        "id": "free_prompt",
        "name": "Free-form Request",
        "description": text,
        "verificationCriteria": []
      };
      logSimulatedAction('FILE_WRITE', 'Write current_task.json (Free-form)', jsonEncode(json));
      try {
        File('$_dirPath/current_task.json').writeAsStringSync(jsonEncode(json), flush: true);
      } catch (e) {
        debugPrint('Failed to write current_task.json: $e');
      }
    }

    if (Platform.environment.containsKey('FLUTTER_TEST') && !_isDryRunMode) {
      await antigravityClient.sendPrompt(text);
      return;
    }

    // Model for Desktop/CLI/Handsfree is applied by _chooseModelTier() writing
    // directly to ~/.gemini/antigravity-cli/settings.json before this point.
    // No clipboard prepend needed.
    if (!_isDryRunMode) {
      await Clipboard.setData(ClipboardData(text: text));
    }

    // 3. Prepare VBScript content and Log Macro / VBScript Actions
    if (_bridgeMode == AntigravityBridgeMode.cli || _bridgeMode == AntigravityBridgeMode.desktop) {
      logSimulatedAction('MACRO', 'Execute Macro Trigger', 'BridgeConnect');
      
      final String targetTitle = _bridgeMode == AntigravityBridgeMode.cli
          ? 'Antigravity CLI'
          : 'Antigravity - Agentic Desktop';
      final int myPid = pid;

      final script = _bridgeMode == AntigravityBridgeMode.cli
          ? '''
Set wshShell = CreateObject("WScript.Shell")
wshShell.AppActivate "$targetTitle"
WScript.Sleep 500
wshShell.SendKeys "^v"
WScript.Sleep 200
wshShell.SendKeys "~"
WScript.Sleep 300
wshShell.AppActivate $myPid
'''
          : '''
Set wshShell = CreateObject("WScript.Shell")
success = wshShell.AppActivate("AI Bridge")
If Not success Then
  success = wshShell.AppActivate("Antigravity - Agentic Desktop")
End If
If Not success Then
  wshShell.AppActivate("Antigravity")
End If
WScript.Sleep 500
wshShell.SendKeys "^v"
WScript.Sleep 200
wshShell.SendKeys "~"
WScript.Sleep 300
wshShell.AppActivate $myPid
''';

      final String modeSuffix = _bridgeMode == AntigravityBridgeMode.cli ? '(CLI)' : '(Desktop)';
      logSimulatedAction('VBS_SCRIPT', 'Write paste.vbs $modeSuffix', script);
      logSimulatedAction('VBS_SCRIPT', 'Run paste.vbs script', 'Executing wscript paste.vbs');

      if (!_isDryRunMode) {
        if (_bridgeMode == AntigravityBridgeMode.cli && _sendViaClipboard) {
          final isRunning = await AntigravityStatusService.instance.isProcessRunning();
          if (!isRunning) {
            logSimulatedAction('STATE', 'CLI Process Offline', 'Launching terminal window...');
            debugPrint('[AiBridgeService] CLI terminal process is offline. Launching terminal window...');
            await AntigravityStatusService.instance.ensureTerminalDaemonRunning();
            await Future.delayed(const Duration(milliseconds: 2000));
          }
        }

        try {
          await MacroService.instance.executeTrigger('BridgeConnect');
        } catch (e) {
          debugPrint('[AiBridgeService] Error executing BridgeConnect macro: $e');
        }

        final vbsFile = File('$_dirPath/paste.vbs');
        if (!vbsFile.parent.existsSync()) {
          vbsFile.parent.createSync(recursive: true);
        }
        await vbsFile.writeAsString(script);
        await Process.run('wscript', [vbsFile.path]).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('[AiBridgeService] wscript paste.vbs execution timed out after 5 seconds.');
            return ProcessResult(0, -1, '', 'wscript execution timeout');
          },
        );
      }
    } else if (_bridgeMode == AntigravityBridgeMode.handsfree) {
      logSimulatedAction('STATE', 'Handsfree mode transition', 'Writing task context to current_task.json.');
      if (!_isDryRunMode) {
        debugPrint('[AiBridgeService] Handsfree mode: context written to current_task.json.');
      }
    }

    // 4. Set Status File agent_status.txt
    final statusFile = File('$_dirPath/agent_status.txt');
    logSimulatedAction('STATUS_WRITE', 'Set Status File (agent_status.txt)', 'BUSY');
    try {
      if (!statusFile.parent.existsSync()) {
        statusFile.parent.createSync(recursive: true);
      }
      statusFile.writeAsStringSync('BUSY');
    } catch (_) {}

    stateMachine.enterBusy();
    _updateStateMachineInputs();

    // 5. If dry run, simulate the agent completing: write output files then trigger IDLE.
    //    This is the ONLY dry-run-specific block — everything after _processStatusChange('IDLE')
    //    is shared code that runs identically in both modes.
    if (_isDryRunMode) {
      _dryRunTimer = Timer(const Duration(seconds: 1), () async {
        if (_activePrompt != null) {
          // Simulate agent writing its output files (latest_notes.json / latest_verification.json).
          // In live mode the real LLM writes these; here we produce placeholder content so
          // _processStatusChange can ingest them through the exact same path.
          try {
            final notesFile = File('$_dirPath/latest_notes.json');
            if (!notesFile.parent.existsSync()) {
              notesFile.parent.createSync(recursive: true);
            }

            // Resolve the exact criteria item the agent was given — same logic as _writeCurrentTaskFile.
            AiVerificationCriteria? targetCriteria;
            AiTask? targetTask;
            final List<dynamic> verifList = [];

            if (_activeProcessingTaskId != null) {
              try {
                targetTask = _tasks.firstWhere((t) => t.id == _activeProcessingTaskId);
                final targetDesc = _activePrompt?.targetCriteriaDescription;
                if (targetDesc != null) {
                  // Exact match (case-insensitive), fallback to first — mirrors _writeCurrentTaskFile.
                  targetCriteria = targetTask.verificationCriteria.firstWhere(
                    (vc) => vc.description.trim().toLowerCase() == targetDesc.trim().toLowerCase(),
                    orElse: () => targetTask!.verificationCriteria.first,
                  );
                } else {
                  // No specific item targeted: pick the first unchecked one — mirrors _writeCurrentTaskFile.
                  final unchecked = targetTask.verificationCriteria.where((vc) =>
                      vc.status != AiVerificationStatus.verified &&
                      vc.status != AiVerificationStatus.ignored &&
                      vc.status != AiVerificationStatus.pendingReview &&
                      !vc.isPreview).toList();
                  if (unchecked.isNotEmpty) {
                    targetCriteria = unchecked.first;
                  } else if (targetTask.verificationCriteria.isNotEmpty) {
                    targetCriteria = targetTask.verificationCriteria.first;
                  }
                }
              } catch (_) {}
            }

            if (targetCriteria != null) {
              verifList.add({
                "description": targetCriteria.description,
                "isVerified": true,
                "proof": "Verified in simulator.",
                "notes": "All checks completed.",
              });
            }

            // Build notes using the actual task name + criteria description.
            final criteriaLabel = targetCriteria?.description ?? _activePrompt?.targetCriteriaDescription;
            final taskLabel = targetTask?.name;
            final notesSummary = (taskLabel != null && criteriaLabel != null)
                ? 'Completed: $taskLabel — $criteriaLabel'
                : (criteriaLabel != null ? 'Completed: $criteriaLabel' : 'Processed');
            final notesDetail = criteriaLabel != null
                ? 'Successfully processed: $criteriaLabel'
                : 'Processed';
            final notesJson = jsonEncode({"summary": notesSummary, "notes": notesDetail});
            logSimulatedAction('FILE_WRITE', 'Agent Output: latest_notes.json', notesJson);
            notesFile.writeAsStringSync(notesJson);

            final verifFile = File('$_dirPath/latest_verification.json');
            final verifJson = jsonEncode(verifList);
            logSimulatedAction('FILE_WRITE', 'Agent Output: latest_verification.json', verifJson);
            verifFile.writeAsStringSync(verifJson);
          } catch (_) {}

          // Mark busy as false so _processStatusChange's busy-wait passes immediately,
          // then simulate agent writing IDLE — triggering the same completion path as live mode.
          _isAntigravityBusy = false;
          _antigravityLastChangeObservedAt = null;
          logSimulatedAction('STATUS_WRITE', 'Agent Output: agent_status.txt', 'IDLE');
          try {
            final statusFile = File('$_dirPath/agent_status.txt');
            if (!statusFile.parent.existsSync()) {
              statusFile.parent.createSync(recursive: true);
            }
            statusFile.writeAsStringSync('IDLE');
          } catch (_) {}

          // Hand off to the shared completion path — identical to live mode from here.
          await _processStatusChange('IDLE');
        }
      });
    }
  }

  String? _lastJsonParseError;
  String? get lastJsonParseError => _lastJsonParseError;

  void dismissJsonParseError() {
    _lastJsonParseError = null;
    notifyListeners();
  }

  Future<void> forceNextQueueItem() async {
    _activeProcessingTaskId = null;
    _activeProcessingTaskAssignedAt = null;
    _activePrompt = null;
    await _saveQueueState();
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

    if (_activePrompt != null) {
      await prefs.setString('ai_bridge_active_prompt', jsonEncode(_activePrompt!.toJson()));
    } else {
      await prefs.remove('ai_bridge_active_prompt');
    }

    if (_activeProcessingTaskId != null) {
      await prefs.setString('ai_bridge_active_processing_task_id', _activeProcessingTaskId!);
    } else {
      await prefs.remove('ai_bridge_active_processing_task_id');
    }

    if (_activeProcessingTaskAssignedAt != null) {
      await prefs.setString('ai_bridge_active_processing_task_assigned_at', _activeProcessingTaskAssignedAt!.toIso8601String());
    } else {
      await prefs.remove('ai_bridge_active_processing_task_assigned_at');
    }

    await prefs.setBool('ai_bridge_is_prompt_dispatched', _isPromptDispatched);
  }

  Future<void> _processQueue() async {
    if (_isQueuePaused || _isProcessingQueue) return;

    if (_pendingPrompts.isEmpty && _activePrompt == null && _activeProcessingTaskId == null) {
      _writeQueueStatus('IDLE');
    }

    _isProcessingQueue = true;
    try {
      if (_pendingUpdateType != null) {
        await triggerPendingUpdate(force: true);
      }

      if (_activeProcessingTaskId != null ||
          _activePrompt != null ||
          _isAntigravityBusy ||
          _isTriggeringUpdate) {
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
                 await appendCheckpointToTimeline(desc, hash, taskIds: [task.id]);
               }
            }
          } catch (_) {}
        } else {
          _activeProcessingTaskId = null;
          _activeProcessingTaskAssignedAt = null;
        }

        _activePrompt = nextPrompt;
        _isPromptDispatched = false;
        _pendingPrompts.removeAt(0);
        await _saveQueueState();
        notifyListeners();

        // Natively wait configured seconds before dispatch to IDE to guarantee the queue settles perfectly and hot reloads reset focus securely
        final prefs = await SharedPreferences.getInstance();
        final delayVal = prefs.get('ai_tasks_delay_seconds');
        double delaySeconds = _isDryRunMode ? 0.05 : 5.0;
        if (!_isDryRunMode && delayVal != null && delayVal is num) {
          delaySeconds = delayVal.toDouble().clamp(0.0, 5.0);
        }
        await Future.delayed(Duration(milliseconds: (delaySeconds * 1000).round()));
        if (_activePrompt == null) {
          print('[AiBridge] Queue was cleared during initial delay. Aborting.');
          return;
        }

        await syncDatabaseDump();
        if (_activePrompt == null) {
          print('[AiBridge] Queue was cleared during database sync. Aborting.');
          return;
        }

        String promptText = nextPrompt.text;
        if (nextPrompt.taskIds != null && nextPrompt.taskIds!.isNotEmpty) {
          final isStandardTaskPrompt = nextPrompt.text.contains('# PRIMARY DIRECTIVES') ||
              nextPrompt.text.contains('# TASKS TO ADDRESS');
          if (isStandardTaskPrompt) {
            final taskId = nextPrompt.taskIds!.first;
            final taskIdx = _tasks.indexWhere((t) => t.id == taskId);
            if (taskIdx != -1) {
              final task = _tasks[taskIdx];
              AiVerificationCriteria? targetItem;
              if (nextPrompt.targetCriteriaDescription != null) {
                final itemIdx = task.verificationCriteria.indexWhere((vc) =>
                    vc.description.trim().toLowerCase() ==
                    nextPrompt.targetCriteriaDescription!.trim().toLowerCase());
                if (itemIdx != -1) {
                  targetItem = task.verificationCriteria[itemIdx];
                }
              }

              // Extract replyTypeDirective lines
              String? replyTypeDirective;
              final List<String> voiceLines = [];
              final List<String> lines = nextPrompt.text.split('\n');
              for (final line in lines) {
                if (line.startsWith('Voice:') || line.startsWith('Complexity:') || line.startsWith('CRITICAL OVERRIDE DIRECTIVE:')) {
                  voiceLines.add(line);
                }
              }
              if (voiceLines.isNotEmpty) {
                replyTypeDirective = voiceLines.join('\n');
              }

              // Extract extraSuffix
              String? extraSuffix;
              final endMarkerIndex = nextPrompt.text.indexOf('\n---');
              if (endMarkerIndex != -1) {
                final remaining = nextPrompt.text.substring(endMarkerIndex + 4).trim();
                if (remaining.isNotEmpty) {
                  var cleanSuffix = remaining;
                  if (_endingInstructions.isNotEmpty && cleanSuffix.contains(_endingInstructions)) {
                    cleanSuffix = cleanSuffix.replaceAll(_endingInstructions, '').trim();
                  }
                  if (cleanSuffix.endsWith('---')) {
                    cleanSuffix = cleanSuffix.substring(0, cleanSuffix.length - 3).trim();
                  }
                  if (cleanSuffix.trim().isNotEmpty) {
                    extraSuffix = cleanSuffix.trim();
                  }
                }
              }

              final dynamicPrompt = await buildTaskPrompt(
                task,
                targetCriteria: targetItem,
                replyTypeDirective: replyTypeDirective,
                extraSuffix: extraSuffix,
              );

              final directivesIndex = nextPrompt.text.indexOf('# PRIMARY DIRECTIVES');
              if (directivesIndex > 0) {
                final prefix = nextPrompt.text.substring(0, directivesIndex);
                promptText = '$prefix$dynamicPrompt';
              } else {
                promptText = dynamicPrompt;
              }
            }
          }
        }

        if (_activePrompt == null) {
          print('[AiBridge] Queue was cleared during prompt build. Aborting.');
          return;
        }

        _activePrompt = QueuedPrompt(
          promptText,
          nextPrompt.block,
          nextPrompt.taskIds,
          targetCriteriaDescription: nextPrompt.targetCriteriaDescription,
          completedAt: nextPrompt.completedAt,
        );
        _writeQueueStatus('BUSY');
        if (_bridgeMode != AntigravityBridgeMode.sdk) {
          await _sendToAiAgent(promptText);
        } else {
          _isAntigravityBusy = true;
          stateMachine.enterBusy();
          _updateStateMachineInputs();
          notifyListeners();

          try {
            final statusFile = File('$_dirPath/agent_status.txt');
            if (!statusFile.parent.existsSync()) {
              statusFile.parent.createSync(recursive: true);
            }
            statusFile.writeAsStringSync('BUSY');
          } catch (_) {}

          if (nextPrompt.taskIds != null && nextPrompt.taskIds!.isNotEmpty) {
            final taskId = nextPrompt.taskIds!.first;
            final taskIdx = _tasks.indexWhere((t) => t.id == taskId);
            if (taskIdx != -1) {
              await executeTask(_tasks[taskIdx]);
            }
          } else {
            await _ensureBackendRunning();
            await _chooseModelTier();
            await antigravityClient.sendPrompt(promptText);
          }
        }
        await _saveQueueState();
        setScreenBlockerEnabled(nextPrompt.block);
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  void _updateStateMachineInputs() {
    final controller = stateMachine.visualController;
    controller.updateInputValue('AgentBusy', _isAntigravityBusy);
    controller.updateInputValue('AgentThinking', isThinking);
    controller.updateInputValue('BridgeActive', _activePrompt != null || _activeAgents.isNotEmpty);
  }

  Future<void> clearQueue() async {
    _interruptionToken++; // Signal any in-flight _processStatusChange to abort.
    _writeQueueStatus('IDLE');
    try {
      final statusFile = File('$_dirPath/agent_status.txt');
      if (statusFile.parent.existsSync()) {
        statusFile.writeAsStringSync('IDLE');
      }
    } catch (_) {}
    _errorDebounceTimer?.cancel();
    _dryRunTimer?.cancel();
    _errorBuffer.clear();
    _pendingUpdateType = null;
    _isHandlingAgentStatus = false;
    _isProcessingQueue = false;
    _showUpdateCover = false;
    _updateStateMachineInputs();

    for (final connection in _activeAgents.values) {
      try {
        connection.close();
      } catch (e) {
        debugPrint('Error closing subagent connection: $e');
      }
    }
    _activeAgents.clear();
    _activeProcessingTaskId = null;
    _activePrompt = null;
    _isPromptDispatched = false;
    _pendingPrompts.clear();
    _completedPrompts.clear();
    _lastTaskMissingFiles.clear();
    _isAntigravityBusy = false;
    _antigravityLastChangeObservedAt = null;
    _isTriggeringUpdate = false;
    setScreenBlockerEnabled(false);

    try {
      final ctFile = File('$_dirPath/current_task.json');
      if (ctFile.existsSync()) {
        ctFile.deleteSync();
      }
    } catch (_) {}
    try {
      final notesFile = File('$_dirPath/latest_notes.json');
      if (notesFile.existsSync()) {
        notesFile.deleteSync();
      }
    } catch (_) {}
    try {
      final previewFile = File('$_dirPath/latest_preview.json');
      if (previewFile.existsSync()) {
        previewFile.deleteSync();
      }
    } catch (_) {}
    try {
      final verificationFile = File('$_dirPath/latest_verification.json');
      if (verificationFile.existsSync()) {
        verificationFile.deleteSync();
      }
    } catch (_) {}

    bool changed = false;
    for (int i = 0; i < _tasks.length; i++) {
      bool taskChanged = false;
      final criteriaList = _tasks[i].verificationCriteria;
      for (int j = 0; j < criteriaList.length; j++) {
        if (criteriaList[j].status == AiVerificationStatus.submitted) {
          criteriaList[j].status = AiVerificationStatus.none;
          taskChanged = true;
        }
      }
      if (taskChanged) {
        changed = true;
      }
    }
    if (changed) {
      await _save();
    }

    try {
      final statusFile = File('$_dirPath/agent_status.txt');
      if (!await statusFile.parent.exists()) {
        await statusFile.parent.create(recursive: true);
      }
      await statusFile.writeAsString('IDLE', flush: true);
    } catch (e) {
      debugPrint('Failed to write IDLE to agent_status.txt: $e');
    }

    await _saveQueueState();
    notifyListeners();
  }

  Future<void> forceResetIdle() async {
    _interruptionToken++; // Signal any in-flight _processStatusChange to abort.
    _dryRunTimer?.cancel();
    _isAntigravityBusy = false;
    _antigravityLastChangeObservedAt = null;
    _isTranscriptActive = false;   // Clear universal busy signal immediately
    _isProcessingQueue = false;     // Release queue lock in case it's stuck
    _isTriggeringUpdate = false;
    _isHandlingAgentStatus = false;
    _statusHandlingLockAcquiredAt = null;

    for (final connection in _activeAgents.values) {
      try {
        connection.close();
      } catch (e) {
        debugPrint('Error closing subagent connection: $e');
      }
    }
    _activeAgents.clear();

    if (_activePrompt != null) {
      _activePrompt!.completedAt = DateTime.now();
      _completedPrompts.add(_activePrompt!);
      _activePrompt = null;
    }
    _activeProcessingTaskId = null;
    _activeProcessingTaskAssignedAt = null;

    setScreenBlockerEnabled(false);

    try {
      final statusFile = File('$_dirPath/agent_status.txt');
      if (!await statusFile.parent.exists()) {
        await statusFile.parent.create(recursive: true);
      }
      await statusFile.writeAsString('IDLE', flush: true);
    } catch (e) {
      debugPrint('Failed to write IDLE to agent_status.txt: $e');
    }

    await _saveQueueState();
    _updateStateMachineInputs();
    notifyListeners();
    _processQueue();
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

  Future<void> forceDispatchSyncError() async {
    _isSyncErrorDetected = false;
    SystemLogsService.instance.addLog(
      '[AI Bridge Sync] Dispatched sync recovery prompt to force agent synchronization.',
      category: LogCategory.SYNC,
    );
    notifyListeners();
    
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        if (_bridgeMode != AntigravityBridgeMode.sdk) {
          await _sendToAiAgent(_syncErrorInstructions);
        } else {
          await antigravityClient.sendPrompt(_syncErrorInstructions);
        }
      } else {
        if (_bridgeMode != AntigravityBridgeMode.sdk) {
          await _sendToAiAgent(_syncErrorInstructions).timeout(const Duration(seconds: 10));
        } else {
          await antigravityClient.sendPrompt(_syncErrorInstructions).timeout(const Duration(seconds: 10));
        }
      }
    } catch (e) {
      SystemLogsService.instance.addLog(
        '[AI Bridge Sync] Error dispatching sync recovery prompt: $e',
        category: LogCategory.ERROR,
      );
    }
  }

  @visibleForTesting
  void handleSystemLogsChangedForTesting() {
    _handleSystemLogsChanged();
  }

  void _handleSystemLogsChanged() {
    final logs = SystemLogsService.instance.logs;
    if (logs.length < _lastProcessedLogIndex) {
      _lastProcessedLogIndex = 0;
    }
    if (logs.length <= _lastProcessedLogIndex) {
      _lastProcessedLogIndex = logs.length;
      return;
    }

    final newEntries = logs.sublist(_lastProcessedLogIndex);
    _lastProcessedLogIndex = logs.length;

    for (final entry in newEntries) {
      if (entry.category == LogCategory.CLI ||
          entry.category == LogCategory.SYNC) {
        continue;
      }
      final detected = ErrorScanner.scan(entry.message);
      if (detected != null) {
        _handleDetectedError(detected);
      }
    }
  }

  void _handleDetectedError(DetectedError error) {
    if (!isThinking) return;

    _errorBuffer.add(error);

    _errorDebounceTimer?.cancel();
    _errorDebounceTimer = Timer(const Duration(milliseconds: 1500), () {
      _dispatchBufferedErrors();
    });
  }

  Future<void> _dispatchBufferedErrors() async {
    if (!isThinking) {
      _errorBuffer.clear();
      return;
    }
    if (_errorBuffer.isEmpty) return;

    final errorsToDispatch = List<DetectedError>.from(_errorBuffer);
    _errorBuffer.clear();

    final sb = StringBuffer();
    sb.writeln('=== RUNTIME/LAYOUT ERRORS DETECTED ===');
    for (final err in errorsToDispatch) {
      sb.writeln('[${err.timestamp}] [${err.category.name.toUpperCase()}] ${err.message}');
    }

    await dispatchRuntimeError(sb.toString());
  }

  Future<void> dispatchRuntimeError(String errorLog) async {
    try {
      if (_activeProcessingTaskId != null) {
        await _absorbOrphanedFiles(_activeProcessingTaskId!);
      }

      _tasks.removeWhere((t) => t.name.toLowerCase() == 'fix runtime errors');

      final task = await addTask(
        'Fix runtime errors',
        'The application encountered runtime/layout/test/dependency errors during execution. Fix them immediately.',
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

      final promptText =
          '# PRIMARY DIRECTIVES\nVoice: Direct / Robotic\nComplexity: Concise\n\nCRITICAL RUNTIME ERROR DETECTED! The application encountered runtime/layout/test/dependency errors during execution.\nRead the error log inside .ai_bridge/bridge_error.txt immediately. Fix the issue dynamically and DO NOT push IDLE again until you have structurally verified your fix.';

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
            .writeAsStringSync('dispatchRuntimeError crashed:\n\n$e\n$st');
      } catch (_) {}
    }
  }

  Future<void> forceDispatchGitPushError(String errorLog) async {
    try {
      if (_activeProcessingTaskId != null) {
        await _absorbOrphanedFiles(_activeProcessingTaskId!);
      }

      _tasks.removeWhere((t) => t.name.toLowerCase() == 'fix git push errors');

      // Gather additional Git diagnostics to include all details needed to resolve the issue
      String diagnostics = '';
      try {
        final path = await VersionControlService.instance.getLocalRepositoryPath();
        if (path != null && path.isNotEmpty) {
          final statusRes = await Process.run('git', ['status'], workingDirectory: path, runInShell: true);
          final branchRes = await Process.run('git', ['branch', '-vv'], workingDirectory: path, runInShell: true);
          final diffRes = await Process.run('git', ['diff', '--name-only', '--diff-filter=U'], workingDirectory: path, runInShell: true);
          final logRes = await Process.run('git', ['log', '-n', '5', '--oneline'], workingDirectory: path, runInShell: true);
          
          diagnostics = '\n\n=== NATIVE GIT DIAGNOSTICS ===\n'
              'Working Directory: $path\n\n'
              'Branch Info:\n${branchRes.stdout}\n'
              'Git Status:\n${statusRes.stdout}\n'
              'Conflicting Files:\n${diffRes.stdout}\n'
              'Recent Commits:\n${logRes.stdout}\n';
        }
      } catch (diagError) {
        diagnostics = '\n\n[Diagnostics Error] Failed to gather Git diagnostics: $diagError\n';
      }

      final fullErrorLog = '$errorLog$diagnostics';

      final task = await addTask(
        'Fix git push errors',
        'The recent attempt to push committed changes to the remote repository failed. Resolve any git conflicts, push protection violations, or repository rule violations immediately.',
        notes: fullErrorLog,
        status: AiTaskStatus.inProgress,
      );

      if (_tasks.isNotEmpty && _tasks.first.id != task.id) {
        await reorderBefore(task.id, _tasks.first.id);
      }

      _isQueuePaused = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ai_queue_paused', false);

      try {
        File('$_dirPath/bridge_error.txt').writeAsStringSync(fullErrorLog);
      } catch (_) {}

      final promptText =
          '# PRIMARY DIRECTIVES\nVoice: Direct / Robotic\nComplexity: Concise\n\n'
          'CRITICAL GIT PUSH REJECTION! Your committed changes failed to push to the remote repository.\n'
          'Read the push failure log inside .ai_bridge/bridge_error.txt immediately. '
          'Resolve any conflicts, secrets scan blocks, or repository rule violations, commit and push your fixes, '
          'and do not mark this complete until the remote repository successfully accepts the changes.';

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
            .writeAsStringSync('forceDispatchGitPushError crashed:\n\n$e\n$st');
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
          final trimmed = content.trim();
          if (trimmed.isNotEmpty && trimmed.startsWith('{')) {
            final jsonMap = jsonDecode(trimmed);
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
          }
        } catch (_) {}
      }

      // Absorb Verification
      final verificationFile = File('$_dirPath/latest_verification.json');
      if (verificationFile.existsSync()) {
        try {
          final content = verificationFile.readAsStringSync();
          verificationFile.deleteSync();
          final trimmed = content.trim();
          if (trimmed.isNotEmpty && trimmed.startsWith('[')) {
            final List<dynamic> jsonList = jsonDecode(trimmed);
            final existing = _tasks[taskIdx].verificationCriteria;
            for (var item in jsonList) {
              final desc = item['description']?.toString().trim() ?? '';
              final proof = item['proof']?.toString().trim();
              final notes = item['notes']?.toString().trim();
              // Match by criteriaIndex first, then exact description, then prefix.
              int vcIdx = -1;
              final criteriaIndexRaw = item['criteriaIndex'];
              if (criteriaIndexRaw != null) {
                final idx = (criteriaIndexRaw as num?)?.toInt() ?? -1;
                if (idx >= 0 && idx < existing.length) {
                  vcIdx = idx;
                }
              }
              if (vcIdx == -1 && desc.isNotEmpty) {
                vcIdx = existing.indexWhere((vc) => vc.description.trim().toLowerCase() == desc.toLowerCase());
              }
              if (vcIdx == -1 && desc.isNotEmpty) {
                vcIdx = existing.indexWhere((vc) {
                  final e = vc.description.trim().toLowerCase();
                  final n = desc.toLowerCase();
                  return n.startsWith(e) || e.startsWith(n);
                });
              }
              if (vcIdx != -1) {
                existing[vcIdx].proof = proof;
                if (notes != null) existing[vcIdx].notes = notes;
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
          final trimmed = content.trim();
          if (trimmed.isNotEmpty && trimmed.startsWith('[')) {
            final List<dynamic> jsonList = jsonDecode(trimmed);
            final newItems = jsonList.map((e) => AiVerificationCriteria(
              description: e['description']?.toString() ?? 'Preview item',
              goal: e['goal']?.toString() ?? '',
              status: AiVerificationStatus.pendingReview,
              isVerified: false,
              isPreview: true,
            )).toList();
            _tasks[taskIdx].verificationCriteria.addAll(newItems);
            changed = true;
          }
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
  void onWindowFocus() async {
    isWindowFocused = true;
    if (_pendingUpdateType != null && !isThinking) {
      await triggerPendingUpdate();
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
  bool _isDaemonRunning = false;
  Map<String, DateTime> _antigravityLastModifiedTimes = {};
  DateTime? _antigravityLastChangeObservedAt;
  Timer? _antigravityPollTimer;
  Timer? _queueCleanupTimer;

  int? _stepIndexAtDispatch;
  DateTime? _promptDispatchedAt;

  int? get stepIndexAtDispatch => _stepIndexAtDispatch;
  set stepIndexAtDispatch(int? value) => _stepIndexAtDispatch = value;

  DateTime? get promptDispatchedAt => _promptDispatchedAt;
  set promptDispatchedAt(DateTime? value) => _promptDispatchedAt = value;

  bool get isAntigravityBusy => _isAntigravityBusy;
  bool get isDaemonRunning => _isDaemonRunning;
  DateTime? get antigravityLastChangeObservedAt => _antigravityLastChangeObservedAt;

  // Tracks the last time the brain-dir transcript file was written to on disk.
  // Updated every poller tick by directly stat-ing the file — this works for
  // BOTH AI Bridge prompts AND prompts typed directly into the CLI/Desktop.
  DateTime? _transcriptLastModifiedAt;
  bool _isTranscriptActive = false;
  bool get isTranscriptActive => _isTranscriptActive;

  @visibleForTesting
  set antigravityLastChangeObservedAtForTesting(DateTime? value) {
    _antigravityLastChangeObservedAt = value;
  }

  bool get isThinking =>
      _activeAgents.isNotEmpty ||
      _isAntigravityBusy ||
      _activePrompt != null ||
      _isPromptDispatched ||
      _isTranscriptActive ||
      (_antigravityLastChangeObservedAt != null &&
          DateTime.now().difference(_antigravityLastChangeObservedAt!).inSeconds < 90);

  bool _isTesting = false;
  bool get isTesting => _isTesting || _tasks.any((t) => t.status == AiTaskStatus.inTesting);
  set isTesting(bool value) {
    if (_isTesting != value) {
      _isTesting = value;
      notifyListeners();
    }
  }

  @visibleForTesting
  void setAntigravityBusyForTesting(bool busy) {
    _isAntigravityBusy = busy;
  }


  bool _isWatchingPoll = false;

  void _startWatchingAntigravity() {
    if (kIsWeb || (!Platform.isWindows && !Platform.isMacOS)) return;

    _antigravityPollTimer?.cancel();

    final String userProfile = Platform.environment['USERPROFILE'] ?? '';
    if (userProfile.isEmpty) return;
    final brainDir = testBrainDir ??
        Directory('$userProfile\\.gemini\\antigravity\\brain');

    _antigravityPollTimer =
        Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (_isWatchingPoll) return;
      _isWatchingPoll = true;
      try {
        if (await brainDir.exists()) {
          final entities = await _getBrainFiles(brainDir);
          for (final file in entities) {
            FileStat? stat;
            try {
              stat = await file.stat().timeout(const Duration(milliseconds: 500));
            } catch (_) {}
            if (stat == null) continue;
            final prev = _antigravityLastModifiedTimes[file.path];
            if (prev != stat.modified) {
              if (prev != null) {
                _antigravityLastChangeObservedAt = DateTime.now();
              }

              if (file.path.endsWith('transcript.jsonl')) {
                await syncConversationHistory(file);
                try {
                  final lines = await _readAsLinesWithRetry(file);
                  if (lines.isNotEmpty) {
                    Map<String, dynamic>? lastStep;
                    for (int i = lines.length - 1; i >= 0; i--) {
                      final line = lines[i].trim();
                      if (line.isNotEmpty && line.startsWith('{')) {
                        lastStep = jsonDecode(line) as Map<String, dynamic>;
                        break;
                      }
                    }
                    if (lastStep != null &&
                        lastStep['type'] == 'PLANNER_RESPONSE' &&
                        lastStep['status'] == 'DONE') {
                      // Guard against Claude extended-thinking steps: a thinking-only
                      // PLANNER_RESPONSE has no tool_calls and must NOT be treated as
                      // a completed agent turn — only a step with actual tool invocations
                      // (write_to_file for bridge files, etc.) counts as real work done.
                      final toolCalls = lastStep['tool_calls'];
                      final hasToolCalls = toolCalls is List && toolCalls.isNotEmpty;
                      if (!hasToolCalls) {
                        print('[AiBridge] Poller: skipping PLANNER_RESPONSE with no tool_calls — likely an extended-thinking block, not a completed turn.');
                      } else {
                        final String modelContent = lastStep['content'] ?? '';

                        // CRITICAL: Only treat this as a completion trigger if the agent
                        // has included a bridge completion marker in this response.
                        // Without this guard, EVERY intermediate agent step (view_file,
                        // grep_search, etc.) fires the completion pipeline because they
                        // all produce PLANNER_RESPONSE DONE with tool_calls — causing
                        // isThinking to flash briefly then reset mid-session.
                        final bool hasCompletionMarker =
                            modelContent.contains('<bridge_notes>') ||
                            modelContent.contains('<verification>') ||
                            modelContent.contains('<preview>') ||
                            modelContent.contains('please send the block screen message') ||
                            modelContent.toLowerCase().contains('agent_status.txt') && (
                              modelContent.contains('IDLE') || modelContent.contains('PREVIEW')
                            );

                        // Also check whether the tool_calls include a write of IDLE/PREVIEW
                        // to agent_status.txt — that is the authoritative completion signal.
                        bool hasStatusWrite = false;
                        for (final call in toolCalls as List) {
                            if (call is Map) {
                              final name = call['name'] ?? '';
                              final args = call['args'] ?? call['arguments'] ?? {};
                              if ((name == 'write_to_file' || name == 'replace_file_content') &&
                                  args is Map) {
                                final targetFile = (args['TargetFile'] ?? args['AbsolutePath'] ?? '').toString();
                                final content = (args['CodeContent'] ?? args['ReplacementContent'] ?? '').toString().trim().toUpperCase();
                                if (targetFile.contains('agent_status') &&
                                    (content == 'IDLE' || content == 'PREVIEW')) {
                                  hasStatusWrite = true;
                                  break;
                                }
                              }
                            }
                          }

                        if (!hasCompletionMarker && !hasStatusWrite) {
                          print('[AiBridge] Poller: skipping PLANNER_RESPONSE DONE — no completion marker or status write detected. Intermediate agent step.');
                        } else {
                          final String statusName = modelContent.contains('<preview>') ? 'PREVIEW' : 'IDLE';

                          final isAgentBusy = _activePrompt != null || _activeAgents.isNotEmpty;
                          // Transcript is ground truth — do NOT gate on !_isAntigravityBusy.
                          // The CLI process may still report busy momentarily after completion.
                          if (isAgentBusy && !_isHandlingAgentStatus && !_isDryRunMode) {
                            print('[AiBridge] Poller: transcript PLANNER_RESPONSE DONE → triggering $statusName (bypassing CLI busy state)');
                            _logPhase('TRIGGER: Transcript PLANNER_RESPONSE DONE detected with completion marker → signalling $statusName. (CLI busy state bypassed — transcript is ground truth)');
                            _isAntigravityBusy = false; // Clear the stale busy flag immediately
                            _antigravityLastChangeObservedAt = null;
                            await _processStatusChange(statusName);
                          }
                        }
                      }
                    }

                  }
                } catch (e) {
                  final errStr = e.toString();
                  if (!errStr.contains('Cannot open file') && !errStr.contains('Sharing violation')) {
                    print('[AiBridge] Poller error reading last line of transcript: $e');
                  }
                }
              }
            }
            _antigravityLastModifiedTimes[file.path] = stat.modified;
          }
        }

        // Use direct HTTP/process checks for busy status
        final foundBusy = await AntigravityStatusService.instance.isCliBusy();
        final procRunning = await AntigravityStatusService.instance.isProcessRunning();

        if (_isDaemonRunning != procRunning) {
          _isDaemonRunning = procRunning;
          notifyListeners();
        }

        if (foundBusy) {
          _antigravityLastChangeObservedAt = DateTime.now();
        }

        // ── Transcript-based busy detection ─────────────────────────────────
        // Detect agent activity regardless of whether the prompt came from AI
        // Bridge or was typed directly into the CLI/Desktop. The transcript file
        // is always written to while the agent is working, so its mod-time is
        // the universal busy signal for BOTH external and bridged prompts.
        try {
          final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
          final brainDir = Directory('$userProfile\\.gemini\\antigravity\\brain');
          if (await brainDir.exists()) {
            final transcriptFile = await _findLatestTranscript(brainDir);
            if (transcriptFile != null) {
              final mod = await transcriptFile.lastModified();
              _transcriptLastModifiedAt = mod;
              final transcriptAge = DateTime.now().difference(mod).inSeconds;
              // Check agent_status.txt — if it already says IDLE, the agent is done
              // even if the transcript is recent (race condition on final write).
              bool agentStatusIsIdle = false;
              try {
                final sf = File('$_dirPath/agent_status.txt');
                if (sf.existsSync()) {
                  final s = sf.readAsStringSync().trim().toUpperCase();
                  agentStatusIsIdle = s.startsWith('ID');
                }
              } catch (_) {}

              final newTranscriptActive = transcriptAge < 60 && !agentStatusIsIdle;
              if (_isTranscriptActive != newTranscriptActive) {
                _isTranscriptActive = newTranscriptActive;
                notifyListeners();
              }
            } else {
              if (_isTranscriptActive) {
                _isTranscriptActive = false;
                notifyListeners();
              }
            }
          }
        } catch (_) {}
        // ────────────────────────────────────────────────────────────────────


        if (_isAntigravityBusy != foundBusy) {
          // Only allow clearing to false when there is no active prompt.
          // If an active prompt exists, the agent is still working — the
          // process check can lag or transiently return false during
          // extended-thinking pauses and must not override the prompt state.
          final canClear = foundBusy || _activePrompt == null;
          if (canClear) {
            _isAntigravityBusy = foundBusy;
            notifyListeners();
            if (!foundBusy && _pendingUpdateType != null) {
              await triggerPendingUpdate();
            }
          }
        }

        // Unified status check — agent_status.txt is the authoritative signal.
        // ALWAYS unlock the queue immediately when IDLE/PREVIEW is seen, regardless
        // of _activePrompt state. This prevents the stuck-queue bug where the pipeline
        // was gated on _activePrompt != null and left queue_status.txt = BUSY forever.
        if (!_isDryRunMode) {
          try {
            final statusFile = File('$_dirPath/agent_status.txt');
            if (await statusFile.exists()) {
              final content = (await statusFile.readAsString()).trim();
              final norm = content.toUpperCase();
              if (norm.startsWith('ID') || norm.startsWith('PR')) {
                // ── Unconditional immediate unlock ───────────────────────────
                // These must ALWAYS run regardless of _activePrompt or lock state.
                _isAntigravityBusy = false;
                _isTranscriptActive = false;
                _antigravityLastChangeObservedAt = null;
                _isProcessingQueue = false;

                final isAgentBusy = _activePrompt != null || _activeAgents.isNotEmpty;
                final willFinalize = isAgentBusy &&
                    (_bridgeMode == AntigravityBridgeMode.sdk ||
                     _bridgeMode == AntigravityBridgeMode.desktop ||
                     _bridgeMode == AntigravityBridgeMode.cli ||
                     _bridgeMode == AntigravityBridgeMode.handsfree);

                if (!willFinalize) {
                  _writeQueueStatus('IDLE');
                }
                notifyListeners();

                // ── Prompt lifecycle finalization (optional) ─────────────────
                // Only enter _processStatusChange if there is an active prompt to
                // finalize (write notes, verification, advance queue, etc.)
                if (isAgentBusy) {
                  if (willFinalize) {
                    final statusName = norm.startsWith('PR') ? 'PREVIEW' : 'IDLE';
                    _logPhase('TRIGGER: agent_status.txt → "$content" detected. Queue unlocked. Entering lifecycle finalization for $statusName.');
                    _activeAgents.clear();
                    if (!_isHandlingAgentStatus) {
                      await _processStatusChange(statusName);
                    }
                  }
                } else {
                  _logPhase('TRIGGER: agent_status.txt → "$content" detected. Queue unlocked. No active prompt — skipping lifecycle finalization.');
                }
              }
            }
          } catch (e) {
            print('[AiBridge] Poller unified status check error: $e');
          }
        }

        _updateStateMachineInputs();
        // Detect AI Bridge Sync Error
        await checkForSyncError();

        // Detect pending document review written by the agent
        try {
          final reviewFile = File('$_dirPath/pending_review.json');
          if (reviewFile.existsSync()) {
            final raw = reviewFile.readAsStringSync().trim();
            if (raw.isNotEmpty) {
              final map = jsonDecode(raw) as Map<String, dynamic>;
              final incoming = PendingReviewRequest.fromJson(map);
              // Only update if the filePath changed (avoid spurious repaints)
              if (_pendingReview?.filePath != incoming.filePath) {
                _pendingReview = incoming;
                print('[AiBridge] Pending document review detected: ${incoming.fileName}');
                notifyListeners();

                // Trigger Ollama summarization if the agent didn't supply one
                if (incoming.summary.isEmpty && !_isSummarizingReview) {
                  _isSummarizingReview = true;
                  notifyListeners();
                  // Fire-and-forget: runs async without blocking poller
                  Future.microtask(() async {
                    try {
                      print('[AiBridge] Requesting Ollama summary for: ${incoming.fileName}');
                      final generatedSummary = await OllamaDocumentSummaryService
                          .generateSummary(incoming.filePath);
                      // Only apply if this review is still the active one
                      if (_pendingReview?.filePath == incoming.filePath) {
                        _pendingReview = _pendingReview!.copyWith(
                          summary: generatedSummary.isEmpty
                              ? 'AI assistant could not generate a summary. Check that your AI service is configured and running.'
                              : generatedSummary,
                        );
                        print('[AiBridge] AI summary applied (${generatedSummary.length} chars)');
                      }
                    } catch (e) {
                      debugPrint('[AiBridge] AI summary error: $e');

                    } finally {
                      _isSummarizingReview = false;
                      notifyListeners();
                    }
                  });
                }
              }
            }
          } else if (_pendingReview != null) {
            // File was deleted externally (e.g. agent cancelled)
            _pendingReview = null;
            _isSummarizingReview = false;
            notifyListeners();
          }
        } catch (e) {
          debugPrint('[AiBridge] Pending review detection error: $e');
        }

      } catch (_) {
      } finally {
        _isWatchingPoll = false;
      }
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
      '---\nNATIVE SYSTEM HOOKS (DO NOT IGNORE)\n'
      '1. SAFETY ABORT / CLARIFICATION: If the task is unclear, unsafe, massive, or contains questions, DO NOT execute code. You MUST require clarification by outputting a `<preview>` tag containing a JSON array of questions, and writing `PREVIEW` to `.ai_bridge/agent_status.txt`.\n'
      '2. DATA MUTATION: Your active task context is in `.ai_bridge/current_task.json`. Never edit `.ai_bridge/tasks.json` directly.\n'
      '3. PROGRESS NOTES: Write progress notes to `.ai_bridge/latest_notes.json` ({"summary":"...","notes":"..."}) and verification proofs to `.ai_bridge/latest_verification.json` on disk. Do NOT output XML tags. The verification file MUST be a JSON array where each item includes a `criteriaIndex` field copied verbatim from the `[criteriaIndex: N]` annotation in the prompt — this is how the bridge unambiguously matches your proof to the correct checklist item. Format: [{"criteriaIndex": N, "description": "...", "isVerified": true, "proof": "...", "notes": "..."}]\n'
      '4. QUEUE RELEASE: As your FINAL step, overwrite `.ai_bridge/agent_status.txt` with `IDLE` (or `PREVIEW` if requesting clarification or preview review).\n'
      '5. BLOCK SCREEN: At the very end of your response, explicitly request to send the block screen message by outputting: "please send the block screen message once."';
  String get systemHooksInstructions => _systemHooksInstructions;

  String _missingFilesInstructions = '# SYSTEM ALERT: MISSING REQUIRED RESPONSE TAGS\n\nYou ended your turn, but the following required XML response tags were NOT found in your chat output:\n{missingList}\n\nYou must output these tags directly in your chat response before ending your turn.\n\nPlease output the missing XML tags immediately, then write IDLE (or PREVIEW) to `.ai_bridge/agent_status.txt` again. Do not re-do any code work.';
  String get missingFilesInstructions => _missingFilesInstructions;

  String _syncErrorInstructions = 'AI Bridge Sync Error: The system detected you outputted conversational/status information directly in your response chat outside of the required XML tags. You must output your notes and verification proofs strictly inside the `<bridge_notes>`, `<verification>`, or `<preview>` XML tags, and eliminate all conversational text outside of these tags. Please output the XML tags immediately without any other chat.';
  String get syncErrorInstructions => _syncErrorInstructions;

  String _endingInstructions = '';
  String get endingInstructions => _endingInstructions;

  bool _isSyncErrorDetected = false;
  bool get isSyncErrorDetected => _isSyncErrorDetected;
  List<String> _lastTaskMissingFiles = [];

  void dismissSyncError() {
    _isSyncErrorDetected = false;
    _lastTaskMissingFiles.clear();
    stateMachine.enterIdle();
    SystemLogsService.instance.addLog(
      '[AI Bridge Sync] User manually dismissed/cleared the sync error status.',
      category: LogCategory.SYNC,
    );
    notifyListeners();
  }

  Future<File?> _findLatestTranscript(Directory brainDir) async {
    if (!await brainDir.exists()) return null;
    try {
      final brainFiles = await _getBrainFiles(brainDir);
      final files = brainFiles.where((f) => f.path.endsWith('transcript.jsonl')).toList();
      if (files.isEmpty) return null;
      final fileTimes = <File, DateTime>{};
      await Future.wait(files.map((file) async {
        try {
          fileTimes[file] = await file.lastModified();
        } catch (_) {
          fileTimes[file] = DateTime.fromMillisecondsSinceEpoch(0);
        }
      }));
      files.sort((a, b) => (fileTimes[b] ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(fileTimes[a] ?? DateTime.fromMillisecondsSinceEpoch(0)));
      return files.first;
    } catch (_) {
      return null;
    }
  }

  Future<int> _findMaxStepIndex(File transcriptFile) async {
    try {
      final lines = await transcriptFile.readAsLines().timeout(
        const Duration(milliseconds: 1000),
        onTimeout: () => const [],
      );
      int maxIndex = -1;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('{')) continue;
        try {
          final map = jsonDecode(trimmed) as Map<String, dynamic>;
          final stepIndex = map['step_index'] as int?;
          if (stepIndex != null && stepIndex > maxIndex) {
            maxIndex = stepIndex;
          }
        } catch (_) {}
      }
      return maxIndex;
    } catch (_) {
      return -1;
    }
  }

  Future<void> _updateDispatchState() async {
    _isSyncErrorDetected = false;
    _promptDispatchedAt = DateTime.now();
    _antigravityLastChangeObservedAt = DateTime.now();
    notifyListeners();
    try {
      final String userProfile = Platform.environment['USERPROFILE'] ?? '';
      final brainDir = testBrainDir ?? Directory('$userProfile\\.gemini\\antigravity\\brain');
      final transcriptFile = await _findLatestTranscript(brainDir);
      if (transcriptFile != null) {
        _stepIndexAtDispatch = await _findMaxStepIndex(transcriptFile);
      } else {
        _stepIndexAtDispatch = -1;
      }
    } catch (_) {
      _stepIndexAtDispatch = -1;
    }
  }

  @visibleForTesting
  Future<void> checkForSyncError({Directory? customBrainDir, DateTime? customNow}) async {
    return;
  }

  @visibleForTesting
  Future<void> processStatusChangeForTesting(String content) => _processStatusChange(content);

  @visibleForTesting
  set isSyncErrorDetected(bool value) {
    _isSyncErrorDetected = value;
    notifyListeners();
  }

  @visibleForTesting
  set activePrompt(QueuedPrompt? value) {
    _activePrompt = value;
    if (value != null) {
      _isPromptDispatched = true;
    } else {
      _isPromptDispatched = false;
    }
    notifyListeners();
  }

  @visibleForTesting
  set antigravityLastChangeObservedAt(DateTime? value) {
    _antigravityLastChangeObservedAt = value;
  }

  @visibleForTesting
  set activeProcessingTaskIdForTesting(String? value) {
    _activeProcessingTaskId = value;
  }

  @visibleForTesting
  set isAntigravityBusyForTesting(bool value) {
    _isAntigravityBusy = value;
  }

  @visibleForTesting
  set isHandlingAgentStatusForTesting(bool value) {
    _isHandlingAgentStatus = value;
  }

  @visibleForTesting
  Future<void> processQueueForTesting() => _processQueue();

  @visibleForTesting
  Future<void> saveQueueStateForTesting() => _saveQueueState();

  @visibleForTesting
  bool get isPromptDispatchedForTesting => _isPromptDispatched;

  /// Public getter for the Bridge Monitor UI to check dispatch state.
  bool get isPromptDispatched => _isPromptDispatched;


  Future<void> compilePrimaryDirectivesFile([AiTask? task]) async {
    if (Platform.environment.containsKey('FLUTTER_TEST') && !forceDiskSaveInTests) {
      return;
    }
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

      if (_isPreviewMode) {
        AiTask? activeTask = task;
        if (activeTask == null && _activeProcessingTaskId != null) {
          try {
            activeTask = _tasks.firstWhere((t) => t.id == _activeProcessingTaskId);
          } catch (_) {}
        }
        final state = activeTask?.previewState;
        if (state == 'approved') {
          if (_previewApprovedInstructions.isNotEmpty) {
            sb.writeln('# PREVIEW APPROVED DIRECTIVES');
            sb.writeln(_previewApprovedInstructions);
            sb.writeln('');
          }
        } else if (state == 'rejected') {
          if (_previewRejectedInstructions.isNotEmpty) {
            sb.writeln('# PREVIEW REJECTED DIRECTIVES');
            sb.writeln(_previewRejectedInstructions);
            sb.writeln('');
          }
        } else {
          if (_previewModeInstructions.isNotEmpty) {
            sb.writeln('# PREVIEW MODE DIRECTIVES');
            sb.writeln(_previewModeInstructions);
            sb.writeln('');
          }
        }
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

  Future<String> buildTaskPrompt(
    AiTask task, {
    AiVerificationCriteria? targetCriteria,
    String? replyTypeDirective,
    String? extraSuffix,
  }) async {
    final sb = StringBuffer();
    sb.writeln('# PRIMARY DIRECTIVES');
    sb.writeln('> [!IMPORTANT]');
    sb.writeln('CRITICAL: You MUST read the `.ai_bridge/primary_directives.md` file natively using your tool to understand the GLOBAL CONSTRAINTS and NATIVE SYSTEM HOOKS before proceeding. Failure to do so will break the application.');
    sb.writeln('To align context with the current workspace state, you must also read the recent conversation history in `.ai_bridge/conversation_history.md` and the database dump in `.ai_bridge/db_dump.json` using your file-reading tools.\n');
    
    if (replyTypeDirective != null && replyTypeDirective.isNotEmpty) {
      sb.writeln(replyTypeDirective.trim());
      sb.writeln('');
    }

    String modeInstructions = '';
    if (_isPreviewMode && _isIqMode) {
      modeInstructions = 'IQ MODE ACTIVE: Prefix the `name` of each new sub-task with [RISKY], [FEEDBACK], or [SAFE].';
    }
    if (modeInstructions.isNotEmpty) {
      sb.writeln(modeInstructions);
      sb.writeln('');
    }

    sb.writeln('# TASKS TO ADDRESS');
    sb.writeln('Task: ${task.name}');
    if (task.description.isNotEmpty) {
      sb.writeln('Description: ${task.description}');
    }
    sb.writeln('Status: ${task.status.name}');
    
    final uncheckedTasks = task.verificationCriteria
        .where((e) => e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored && e.status != AiVerificationStatus.pendingReview && !e.isPreview)
        .toList();
    final targetItem = targetCriteria ?? (uncheckedTasks.isNotEmpty ? uncheckedTasks.first : null);
    if (targetItem != null) {
      // Compute the global index of this item in the full criteria list so we
      // can embed it in the prompt — the agent must echo this number back in
      // latest_verification.json as `criteriaIndex` for unambiguous matching.
      final globalCriteriaIndex = task.verificationCriteria.indexOf(targetItem);
      sb.writeln('Verification Criteria:');
      String extraInfo = '';
      if (targetItem.goal.isNotEmpty) extraInfo += ' [Goal: ${targetItem.goal}]';
      if (targetItem.notes.isNotEmpty) extraInfo += ' [Notes: ${targetItem.notes}]';
      if (targetItem.tryCount > 0) extraInfo += ' [TRY #${targetItem.tryCount}]';
      if (globalCriteriaIndex >= 0) extraInfo += ' [criteriaIndex: $globalCriteriaIndex]';
      if (targetItem.requestClarification) {
        sb.writeln('1. [CLARIFY] ${targetItem.description}$extraInfo');
      } else {
        sb.writeln('1. ${targetItem.description}$extraInfo');
      }
      sb.writeln('\nCRITICAL FOCUS CONSTRAINT:');
      sb.writeln('Your ONLY objective for this run is to satisfy Checklist Item #1 above. Do not attempt to work on, address, or implement any other features, checklist items, or criteria. Focus entirely on completing this single item, verify it is working, and then output your notes and verification proofs as requested.');
    }
    
    if (task.fileAttachments.isNotEmpty) {
      sb.writeln('Attachments:');
      for (final attachment in task.fileAttachments) {
        sb.writeln('- $attachment');
      }
    }
    
    if (task.hyperlinks.isNotEmpty) {
      sb.writeln('Hyperlinks:');
      for (final link in task.hyperlinks) {
        sb.writeln('- $link');
      }
    }

    if (extraSuffix != null && extraSuffix.isNotEmpty) {
      sb.writeln('');
      sb.writeln(extraSuffix.trim());
    }
 
    if (_endingInstructions.isNotEmpty) {
      sb.writeln('');
      sb.writeln(_endingInstructions);
    }
    
    sb.writeln('---');
    return sb.toString();
  }

  bool isTaskOrAncestorIgnored(AiTask task) {
    if (task.isIgnored) return true;
    String? pId = task.parentId;
    final Set<String> visited = {task.id};
    while (pId != null) {
      if (visited.contains(pId)) break;
      visited.add(pId);
      final pList = _tasks.where((parent) => parent.id == pId);
      if (pList.isEmpty) break;
      final parent = pList.first;
      if (parent.isIgnored) return true;
      pId = parent.parentId;
    }
    if (task.worksheetId != null) {
      final wsList = _tasks.where((t) => t.id == task.worksheetId);
      if (wsList.isNotEmpty && wsList.first.isIgnored) {
        return true;
      }
    }
    return false;
  }

  Future<void> submitTaskChecklist(
    AiTask task, {
    bool blockScreen = true,
    String replyTypeDirective = '',
    String crashInfo = '',
  }) async {
    if (isTaskOrAncestorIgnored(task)) {
      print('[AiBridge] Skipping ignored task: ${task.name}');
      return;
    }
    await compilePrimaryDirectivesFile(task);

    final unchecked = task.verificationCriteria
        .where((e) => (e.status != AiVerificationStatus.verified &&
            e.status != AiVerificationStatus.ignored &&
            e.status != AiVerificationStatus.pendingReview &&
            !e.isPreview))
        .toList();

    if (unchecked.isNotEmpty) {
      for (final item in unchecked) {
        item.status = AiVerificationStatus.submitted;
      }
      final updatedCriteria = task.verificationCriteria
          .map((e) => AiVerificationCriteria(
                description: e.description,
                goal: e.goal,
                isVerified: e.isVerified,
                status: e.status,
                proof: e.proof,
                notes: e.notes,
                requestClarification: e.requestClarification,
                tryCount: e.tryCount,
                attachments: List.from(e.attachments),
                isCommitted: e.isCommitted,
                isPreview: e.isPreview,
              ))
          .toList();
      await updateTaskDetails(
        task.id,
        task.name,
        task.description,
        verificationCriteria: updatedCriteria,
        status: AiTaskStatus.inTesting,
      );
    } else {
      await updateTaskStatus(task.id, AiTaskStatus.inTesting);
    }

    final updatedTask = _tasks.firstWhere((t) => t.id == task.id, orElse: () => task);
    final finalUnchecked = updatedTask.verificationCriteria
        .where((e) => (e.status != AiVerificationStatus.verified &&
            e.status != AiVerificationStatus.ignored &&
            e.status != AiVerificationStatus.pendingReview &&
            !e.isPreview))
        .toList();

    if (finalUnchecked.isEmpty) {
      final basePrompt = await buildTaskPrompt(updatedTask, replyTypeDirective: replyTypeDirective);
      final fullPrompt = crashInfo.isEmpty ? basePrompt : '$crashInfo$basePrompt';
      await sendToQueue(fullPrompt, blockScreen, taskIds: [task.id]);
    } else {
      for (final item in finalUnchecked) {
        final basePrompt = await buildTaskPrompt(updatedTask, targetCriteria: item, replyTypeDirective: replyTypeDirective);
        final fullPrompt = crashInfo.isEmpty ? basePrompt : '$crashInfo$basePrompt';
        await sendToQueue(fullPrompt, blockScreen, taskIds: [task.id], targetCriteriaDescription: item.description);
      }
    }
  }

  Future<void> approvePreview(String taskId) async {
    final taskIdx = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIdx == -1) return;
    
    final task = _tasks[taskIdx];
    task.previewState = 'approved';
    
    for (final vc in task.verificationCriteria) {
      if (vc.isPreview) {
        vc.isPreview = false;
        vc.status = AiVerificationStatus.none;
      }
    }
    task.status = AiTaskStatus.inTesting;
    
    await _save();
    notifyListeners();
    
    await compilePrimaryDirectivesFile(task);
    
    final prompt = await buildTaskPrompt(task);
    await sendToQueue(prompt, true, taskIds: [task.id]);
  }

  Future<void> rejectPreview(String taskId, String feedback) async {
    final taskIdx = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIdx == -1) return;
    
    final task = _tasks[taskIdx];
    task.previewState = 'rejected';
    
    await _save();
    notifyListeners();
    
    await compilePrimaryDirectivesFile(task);
    
    final fullPrompt = await buildTaskPrompt(
      task,
      extraSuffix: 'User Rejection Feedback:\n$feedback',
    );
    await sendToQueue(fullPrompt, true, taskIds: [task.id]);
  }

  Future<void> updateInstructions(
      String primary,
      String text,
      String quickText,
      String previewMode,
      String previewApproved,
      String previewRejected,
      String systemHooks,
      String missingFiles,
      String syncError, [
      String ending = '',
  ]) async {
    _primaryDirectives = primary;
    _instructions = text;
    _quickInstructions = quickText;
    _previewModeInstructions = previewMode;
    _previewApprovedInstructions = previewApproved;
    _previewRejectedInstructions = previewRejected;
    _systemHooksInstructions = systemHooks;
    _missingFilesInstructions = missingFiles;
    _syncErrorInstructions = syncError;
    _endingInstructions = ending;
    notifyListeners();
    await _save();
    await compilePrimaryDirectivesFile();
  }

  Future<void> init() async {
    _writeQueueStatus('IDLE');
    try {
      _queueCleanupTimer?.cancel();
      _pendingPrompts.clear();
      _completedPrompts.clear();

      final prefs = await _getPrefs();
      _isQueuePaused = prefs.getBool('ai_queue_paused') ?? false;
      _isPreviewMode = prefs.getBool('ai_queue_preview_mode') ?? false;
      _isIqMode = prefs.getBool('ai_queue_iq_mode') ?? false;
      _isDryRunMode = prefs.getBool('ai_bridge_dry_run_mode') ?? false;
      _sendViaClipboard = prefs.getBool('antigravity_send_via_clipboard') ?? true;
      _useHiModel = prefs.getBool('antigravity_use_hi_model') ?? false;

      final savedBridgeMode = prefs.getString('antigravity_bridge_mode') ?? 'sdk';
      _bridgeMode = AntigravityBridgeMode.values.firstWhere(
          (e) => e.name == savedBridgeMode,
          orElse: () => AntigravityBridgeMode.sdk);
      _writeActiveModeFile(_bridgeMode.name);


      // ── Startup always starts clean ────────────────────────────────────────
      // Never restore in-flight state (pending queue, active prompt, dispatch
      // flags) from a previous session. The agent may have crashed, been
      // killed, or completed without writing IDLE — so stale queue state would
      // cause the pipeline to get stuck immediately on launch.
      // Completed-prompt history is kept for reference.
      _pendingPrompts.clear();
      _activePrompt = null;
      _activeProcessingTaskId = null;
      _activeProcessingTaskAssignedAt = null;
      _isPromptDispatched = false;
      _isAntigravityBusy = false;
      _isHandlingAgentStatus = false;
      _statusHandlingLockAcquiredAt = null;
      _isTranscriptActive = false;
      _antigravityLastChangeObservedAt = null;
      _activeAgents.clear();

      // Wipe the persisted in-flight keys so they don't come back on the next restart
      try {
        await prefs.remove('ai_bridge_queue');
        await prefs.remove('ai_bridge_active_prompt');
        await prefs.remove('ai_bridge_active_processing_task_id');
        await prefs.remove('ai_bridge_active_processing_task_assigned_at');
        await prefs.remove('ai_bridge_is_prompt_dispatched');
      } catch (_) {}

      // Restore completed history (display only — not re-dispatched)
      final savedCompletedQueue = prefs.getStringList('ai_bridge_completed_queue');
      if (savedCompletedQueue != null && savedCompletedQueue.isNotEmpty) {
        try {
          _completedPrompts.addAll(
              savedCompletedQueue.map((s) => QueuedPrompt.fromJson(jsonDecode(s))));
        } catch (e) {
          debugPrint('[AiBridge] Error decoding completed queue history: $e');
        }
      }

      // Restore dry-run simulated action log (cosmetic, not functional)
      final savedSimulated = prefs.getStringList('ai_bridge_simulated_actions');
      if (savedSimulated != null && savedSimulated.isNotEmpty) {
        try {
          _simulatedActions.clear();
          _simulatedActions.addAll(
              savedSimulated.map((s) => SimulatedAction.fromJson(jsonDecode(s))));
        } catch (e) {
          debugPrint('[AiBridge] Error decoding simulated actions: $e');
        }
      }

      final dir = Directory(_dirPath);
      if (!await dir.exists()) {
        if (!(Platform.environment.containsKey('FLUTTER_TEST') && !forceDiskSaveInTests)) {
          await dir.create(recursive: true);
        }
      } else {
        if (!(Platform.environment.containsKey('FLUTTER_TEST') && !forceDiskSaveInTests)) {
          _isSyncErrorDetected = false;
          _isAntigravityBusy = false;
          _antigravityLastChangeObservedAt = null;
          _promptDispatchedAt = DateTime.now();
          _stepIndexAtDispatch = -1;
          try {
            final String userProfile = Platform.environment['USERPROFILE'] ?? '';
            final brainDir = testBrainDir ?? Directory('$userProfile\\.gemini\\antigravity\\brain');
            final transcriptFile = await _findLatestTranscript(brainDir);
            if (transcriptFile != null) {
              _stepIndexAtDispatch = await _findMaxStepIndex(transcriptFile);
            }
          } catch (_) {}

          // ── Unconditional startup reset ────────────────────────────────────
          // Always force agent_status.txt to IDLE on restart — regardless of
          // what the previous session left behind. The queue was cleared above,
          // so there is no activePrompt to resume and the agent is not running.
          debugPrint('[AiBridge] Startup: forcing agent_status.txt → IDLE and clearing all pending bridge files.');
          final statusFile = File('$_dirPath/agent_status.txt');
          try {
            if (!statusFile.parent.existsSync()) statusFile.parent.createSync(recursive: true);
            statusFile.writeAsStringSync('IDLE');
          } catch (_) {}

          // Delete any leftover output/review files from the previous run
          for (final name in [
            'latest_notes.json',
            'latest_verification.json',
            'latest_preview.json',
            'pending_review.json',
          ]) {
            try {
              final f = File('$_dirPath/$name');
              if (f.existsSync()) f.deleteSync();
            } catch (_) {}
          }
        }
      }
      await _loadFromFile();
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        _startWatching();
        _startWatchingAntigravity();
        Future.delayed(const Duration(milliseconds: 600), () {
          if (_activePrompt == null) {
            _processQueue();
          }
        });
      }

      if (!_isLogListenerRegistered) {
        _lastProcessedLogIndex = SystemLogsService.instance.logs.length;
        SystemLogsService.instance.addListener(_handleSystemLogsChanged);
        _isLogListenerRegistered = true;
      }

      try {
        if (!kIsWeb &&
            (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
          windowManager.addListener(this);
        }
      } catch (_) {}

      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
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
      }
    } catch (e) {
      debugPrint('Error initializing AiBridgeService: $e');
    }
  }



  Future<void> _processStatusChange(String rawContent) async {
    final content = rawContent.trim().toUpperCase().startsWith('PR') ? 'PREVIEW' : 'IDLE';
    if (content == 'PREVIEW') {
      stateMachine.enterPreviewing();
    } else {
      stateMachine.enterCompiling();
    }
    _updateStateMachineInputs();
    if (_isHandlingAgentStatus) {
      if (_statusHandlingLockAcquiredAt != null &&
          DateTime.now().difference(_statusHandlingLockAcquiredAt!).inSeconds > 25) {
        print('[AiBridge] Status watcher lock has been held for >25 seconds. Forcing lock release.');
        _isHandlingAgentStatus = false;
      } else {
        print('[AiBridge] Status watcher is already handling an event. Ignoring duplicate event.');
        return;
      }
    }

    _isHandlingAgentStatus = true;
    _statusHandlingLockAcquiredAt = DateTime.now();
    // Capture the token at lock-acquisition time. If the user triggers
    // clearQueue() or forceResetIdle() while we await below, the token will
    // have been incremented and we bail out immediately.
    final int interruptToken = _interruptionToken;
    print('[AiBridge] Acquired status handling lock (_isHandlingAgentStatus = true)');
    _logPhase('LOCK ACQUIRED: _processStatusChange started for "$content". activePrompt=${_activePrompt != null}, isAntigravityBusy=$_isAntigravityBusy, activeAgents=${_activeAgents.length}');

    // Watchdog: the 25-second re-entry guard only fires on a *second* call, but
    // all callers are guarded by !_isHandlingAgentStatus, so re-entry never occurs.
    // This timer self-releases the lock after 12 minutes so the pipeline can recover
    // even if an inner await hangs indefinitely. The 12-minute ceiling accounts for
    // the 5-minute bounce-protection reminder wait + the 10-minute busy-wait +
    // dart analyze + file I/O overhead.
    final watchdogTimer = Timer(const Duration(minutes: 12), () {
      if (_isHandlingAgentStatus) {
        print('[AiBridge] WATCHDOG: _processStatusChange has been running > 12 minutes. Force-releasing lock and resetting pipeline.');
        _isHandlingAgentStatus = false;
        _statusHandlingLockAcquiredAt = null;
        _isAntigravityBusy = false;
        _antigravityLastChangeObservedAt = null;
        stateMachine.enterIdle();
        notifyListeners();
      }
    });

    try {
      try {
        File('$_dirPath/bridge_debug.txt').writeAsStringSync(
            'IDLE/PREVIEW detected! isAntigravityBusy: $_isAntigravityBusy');
      } catch (_) {}

      int waitCount = 0;
      print('[AiBridge] Waiting for _isAntigravityBusy to be false. Current: $_isAntigravityBusy');
      while (_isAntigravityBusy && waitCount < 1200) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (interruptToken != _interruptionToken) {
          print('[AiBridge] Interrupt detected during busy-wait. Aborting _processStatusChange.');
          return;
        }
        waitCount++;
      }
      if (_isAntigravityBusy) {
        print('[AiBridge] WARNING: Busy wait timed out after 10 minutes. Forcing busy status to false.');
        _isAntigravityBusy = false;
      }
      _antigravityLastChangeObservedAt = null;
      print('[AiBridge] Busy wait finished. Proceeding with status processing.');
      if (!_isDryRunMode) {
        await Future.delayed(const Duration(milliseconds: 800));
      }
      if (interruptToken != _interruptionToken) {
        print('[AiBridge] Interrupt detected after initial delay. Aborting _processStatusChange.');
        _logPhase('ABORTED: Interrupt token changed after initial delay — clearQueue/forceReset was called during busy-wait. Pipeline reset externally.');
        return;
      }

      String rawModelContent = '';
      try {
        final String userProfile = Platform.environment['USERPROFILE'] ?? '';
        final brainDir = testBrainDir ?? Directory('$userProfile\\.gemini\\antigravity\\brain');
        final hasBrainDir = await brainDir.exists().timeout(const Duration(milliseconds: 500), onTimeout: () => false);
        if (hasBrainDir) {
          final overviewFiles = await _getBrainFiles(brainDir);
          final files = overviewFiles.where((f) => f.path.endsWith('transcript.jsonl')).toList();
          if (files.isNotEmpty) {
            final fileTimes = <File, DateTime>{};
            await Future.wait(files.map((file) async {
              try {
                fileTimes[file] = await file.lastModified().timeout(
                  const Duration(milliseconds: 500),
                  onTimeout: () => DateTime.fromMillisecondsSinceEpoch(0),
                );
              } catch (_) {
                fileTimes[file] = DateTime.fromMillisecondsSinceEpoch(0);
              }
            }));
            files.sort((a, b) => (fileTimes[b] ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(fileTimes[a] ?? DateTime.fromMillisecondsSinceEpoch(0)));
            final latest = files.first;
            try {
              final lines = await latest.readAsLines().timeout(
                const Duration(milliseconds: 1500),
                onTimeout: () => const [],
              );
              for (int i = lines.length - 1; i >= 0; i--) {
                try {
                  final line = lines[i].trim();
                  if (line.isEmpty || !line.startsWith('{')) continue;
                  final map = jsonDecode(line);
                  if (map['type'] == 'PLANNER_RESPONSE') {
                    if (map['content'] != null) {
                      rawModelContent = map['content'];
                    }
                    break;
                  }
                } catch (_) {}
              }
            } catch (_) {}
          }
        }
      } catch (_) {}

      if (interruptToken != _interruptionToken) {
        print('[AiBridge] Interrupt detected after brain-file read. Aborting _processStatusChange.');
        _logPhase('ABORTED: Interrupt token changed after brain-file read. Pipeline reset externally.');
        return;
      }

      if (content == 'IDLE') {
        bool hasCompileError = false;
        if (Platform.environment.containsKey('FLUTTER_TEST')) {
          print('[AiBridgeService] Skipping dart analyze build check in unit test environment.');
          logSimulatedAction('STATE', 'Dart Analyze: Skipped', 'Skipping build check in test environment.');
          stateMachine.enterSynchronizing();
        } else {
          print('[AiBridge] Running dart analyze build check...');
          logSimulatedAction('STATE', 'Dart Analyze: Running', 'Running dart analyze to check for compile errors.');
          Process? process;
          try {
            process = await Process.start('dart', ['analyze'], runInShell: true);
            final stdoutBuffer = StringBuffer();
            final stderrBuffer = StringBuffer();

            final stdoutSub = process.stdout.transform(utf8.decoder).listen((data) {
              stdoutBuffer.write(data);
            });
            final stderrSub = process.stderr.transform(utf8.decoder).listen((data) {
              stderrBuffer.write(data);
            });

            await process.exitCode.timeout(const Duration(minutes: 5));
            await stdoutSub.cancel();
            await stderrSub.cancel();

            final output = stdoutBuffer.toString() + '\n' + stderrBuffer.toString();
            if (output.contains('error -') ||
                output.contains('error •') ||
                output.contains('error \u2022')) {
              hasCompileError = true;
              print('[AiBridge] Build check failed. Dispatching compile error...');
              logSimulatedAction('STATE', 'Dart Analyze: Failed', 'Compile errors detected. Dispatching auto-correction.');
              stateMachine.enterError('Dart compilation errors detected. Auto-correcting...');
              await forceDispatchCompileError(output);
            } else {
              print('[AiBridge] Build check passed.');
              logSimulatedAction('STATE', 'Dart Analyze: Passed', 'No compile errors. Proceeding with completion.');
              stateMachine.enterSynchronizing();
            }
          } on TimeoutException catch (e) {
            print('[AiBridge] Automated dart analyze check timed out: $e. Terminating process.');
            logSimulatedAction('STATE', 'Dart Analyze: Timeout', 'Build check timed out. Continuing.');
            if (process != null) {
              process.kill();
            }
            stateMachine.enterSynchronizing();
          } catch (e) {
            print('[AiBridge] Failed to run automated dart analyze check: $e');
            logSimulatedAction('STATE', 'Dart Analyze: Error', 'Build check failed: $e');
            stateMachine.enterSynchronizing();
          }
        }
        if (interruptToken != _interruptionToken) {
          print('[AiBridge] Interrupt detected after dart analyze. Aborting _processStatusChange.');
          _logPhase('ABORTED: Interrupt token changed after dart analyze. Pipeline reset externally.');
          return;
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
        logSimulatedAction('STATE', 'Status Ingestion', 'Agent returned $content. Ingesting output files.');
        try {
          final taskIdx = _tasks
              .indexWhere((t) => t.id == _activeProcessingTaskId);
          if (taskIdx != -1) {
            bool changed = false;

            String notesContent = '';
            String previewContent = '';
            String verificationContent = '';
            String aiOutput = '';

            Future<void> attemptIngestion() async {
              final notesFile = File('$_dirPath/latest_notes.json');
              if (notesFile.existsSync() && notesContent.isEmpty) {
                try {
                  notesContent = notesFile.readAsStringSync();
                } catch (_) {}
              }

              final previewFile = File('$_dirPath/latest_preview.json');
              if (previewFile.existsSync() && previewContent.isEmpty) {
                try {
                  previewContent = previewFile.readAsStringSync();
                } catch (_) {}
              }

              final verificationFile = File('$_dirPath/latest_verification.json');
              if (verificationFile.existsSync() && verificationContent.isEmpty) {
                try {
                  verificationContent = verificationFile.readAsStringSync();
                } catch (_) {}
              }

              if (notesContent.trim().isEmpty || 
                  (content == 'IDLE' && _tasks[taskIdx].verificationCriteria.isNotEmpty && verificationContent.trim().isEmpty) ||
                  (content == 'PREVIEW' && previewContent.trim().isEmpty)) {
                try {
                  final String userProfile = Platform.environment['USERPROFILE'] ?? '';
                  final brainDir = testBrainDir ?? Directory('$userProfile\\.gemini\\antigravity\\brain');
                  final hasBrainDir = await brainDir.exists().timeout(const Duration(milliseconds: 500), onTimeout: () => false);
                  if (hasBrainDir) {
                    final overviewFiles = await _getBrainFiles(brainDir);
                    final files = overviewFiles.where((f) => f.path.endsWith('transcript.jsonl')).toList();
                    if (files.isNotEmpty) {
                      final fileTimes = <File, DateTime>{};
                      await Future.wait(files.map((file) async {
                        try {
                          fileTimes[file] = await file.lastModified().timeout(
                            const Duration(milliseconds: 500),
                            onTimeout: () => DateTime.fromMillisecondsSinceEpoch(0),
                          );
                        } catch (_) {
                          fileTimes[file] = DateTime.fromMillisecondsSinceEpoch(0);
                        }
                      }));
                      files.sort((a, b) => (fileTimes[b] ?? DateTime.fromMillisecondsSinceEpoch(0))
                          .compareTo(fileTimes[a] ?? DateTime.fromMillisecondsSinceEpoch(0)));
                      final latest = files.first;
                      try {
                        final lines = await latest.readAsLines().timeout(
                          const Duration(milliseconds: 1500),
                          onTimeout: () => const [],
                        );
                        for (int i = lines.length - 1; i >= 0; i--) {
                          try {
                            final line = lines[i].trim();
                            if (line.isEmpty || !line.startsWith('{')) continue;
                            final map = jsonDecode(line);
                            if (map['source'] == 'MODEL') {
                              if (map['content'] != null) {
                                String mContent = map['content'];
                                if (mContent.contains('<bridge_notes>') || 
                                    mContent.contains('<preview>') || 
                                    mContent.contains('<verification>')) {
                                  aiOutput = mContent;
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

                if (aiOutput.isNotEmpty) {
                  if (notesContent.trim().isEmpty) {
                    final notesMatches = RegExp(
                            r'<bridge_notes>(.*?)</bridge_notes>',
                            dotAll: true)
                        .allMatches(aiOutput);
                    if (notesMatches.isNotEmpty) {
                      notesContent = notesMatches.last.group(1)!;
                    }
                  }
                  if (previewContent.trim().isEmpty) {
                    final previewMatches = RegExp(
                            r'<preview>(.*?)</preview>',
                            dotAll: true)
                        .allMatches(aiOutput);
                    if (previewMatches.isNotEmpty) {
                      previewContent = previewMatches.last.group(1)!;
                    }
                  }
                  if (verificationContent.trim().isEmpty) {
                    final verificationMatches = RegExp(
                            r'<verification>(.*?)</verification>',
                            dotAll: true)
                        .allMatches(aiOutput);
                    if (verificationMatches.isNotEmpty) {
                      verificationContent = verificationMatches.last.group(1)!;
                    }
                  }
                }
              }
            }

            // Wait for agent_status.txt to confirm IDLE/PREVIEW before ingesting
            // output files. The transcript poller can call _processStatusChange early
            // (before the agent finishes writing latest_notes.json etc.), so we must
            // not start polling for those files until the agent has actually written
            // its own status file — that is the authoritative signal that all bridge
            // output files have been flushed to disk.
            {
              int statusWaitCount = 0;
              const int maxStatusWaits = 40; // 40 × 500 ms = 20 s max
              while (statusWaitCount < maxStatusWaits) {
                try {
                  final statusFile = File('$_dirPath/agent_status.txt');
                  if (statusFile.existsSync()) {
                    final statusContent = statusFile.readAsStringSync().trim().toUpperCase();
                    if (statusContent.startsWith('ID') || statusContent.startsWith('PR')) {
                      break; // agent_status.txt is IDLE or PREVIEW — safe to ingest
                    }
                  }
                } catch (_) {}
                if (interruptToken != _interruptionToken) break;
                await Future.delayed(const Duration(milliseconds: 500));
                statusWaitCount++;
              }
              if (statusWaitCount > 0) {
                print('[AiBridge] Waited ${statusWaitCount * 500}ms for agent_status.txt to confirm IDLE before ingesting output files.');
              }
            }

            bool hasVerificationCriteria = _tasks[taskIdx].verificationCriteria.isNotEmpty;
            int attemptCount = 0;
            while (attemptCount < 25) {
              if (attemptCount > 0) {
                print('[AiBridge] Missing or incomplete files detected (attempt ${attemptCount + 1}/25). Waiting 500ms...');
                await Future.delayed(const Duration(milliseconds: 500));
              }
              await attemptIngestion();
              
              final bool notesMissing = notesContent.trim().isEmpty;
              final bool verificationMissing = hasVerificationCriteria && verificationContent.trim().isEmpty;
              final bool previewMissing = content == 'PREVIEW' && previewContent.trim().isEmpty;
              
              if (!notesMissing && !verificationMissing && !previewMissing) {
                break;
              }
              attemptCount++;
            }

            // --- Missing-file recovery: send a one-shot reminder to the agent ---
            // If the retry loop exhausted and files are still missing, the agent
            // finished processing but forgot to write its output files. Send it a
            // targeted reminder, wait for it to go IDLE again, then do a second
            // shorter retry pass. This fires at most once per task completion.
            {
              final bool notesMissingFinal = notesContent.trim().isEmpty;
              final bool verificationMissingFinal = hasVerificationCriteria && verificationContent.trim().isEmpty;
              final bool previewMissingFinal = content == 'PREVIEW' && previewContent.trim().isEmpty;

              if (notesMissingFinal || verificationMissingFinal || previewMissingFinal) {
                final missingList = <String>[];
                if (notesMissingFinal) missingList.add('`.ai_bridge/latest_notes.json`');
                if (verificationMissingFinal) missingList.add('`.ai_bridge/latest_verification.json`');
                if (previewMissingFinal) missingList.add('`.ai_bridge/latest_preview.json`');

                final missingFileReminder =
                    'AI Bridge Output Files Missing: You have finished processing but the following '
                    'required output file(s) were not written to disk: ${missingList.join(', ')}. '
                    'You MUST write these files now using your file-writing tool. '
                    'Refer to the PROGRESS NOTES and QUEUE RELEASE directives in `.ai_bridge/primary_directives.md`. '
                    'After writing the files, overwrite `.ai_bridge/agent_status.txt` with `IDLE` as your final step.';

                SystemLogsService.instance.addLog(
                  '[AI Bridge] Missing output files after ${attemptCount} retries: ${missingList.join(', ')}. Sending reminder to agent.',
                  category: LogCategory.SYNC,
                );
                print('[AiBridge] Missing output files after retries. Sending reminder prompt to agent: ${missingList.join(', ')}');
                _logPhase('MISSING FILES: After $attemptCount retries, output files still missing: ${missingList.join(', ')}. Dispatching reminder to agent. Bounce-protection will wait for BUSY then IDLE.');

                try {
                  if (Platform.environment.containsKey('FLUTTER_TEST')) {
                    if (_bridgeMode != AntigravityBridgeMode.sdk) {
                      await _sendToAiAgent(missingFileReminder);
                    } else {
                      await antigravityClient.sendPrompt(missingFileReminder);
                    }
                  } else {
                    if (_bridgeMode != AntigravityBridgeMode.sdk) {
                      await _sendToAiAgent(missingFileReminder).timeout(const Duration(seconds: 10));
                    } else {
                      await antigravityClient.sendPrompt(missingFileReminder).timeout(const Duration(seconds: 10));
                    }
                  }
                } catch (e) {
                  SystemLogsService.instance.addLog(
                    '[AI Bridge] Error dispatching missing-files reminder: $e',
                    category: LogCategory.ERROR,
                  );
                }

                // Bounce-protected wait after the missing-files reminder.
                //
                // Extended-thinking models (e.g. Claude Sonnet with thinking enabled)
                // have a multi-minute internal reasoning phase before they write any
                // files. Without this guard the 20-second timeout fires while the AI
                // is still thinking, causing a premature abort.
                //
                // Phase 1 — Bounce detection (up to 8s):
                //   Poll agent_status.txt to confirm the agent actually received the
                //   reminder and transitioned to BUSY. If BUSY is observed we know
                //   the AI is actively working and we must wait for it to finish.
                //
                // Phase 2 — Extended idle wait (up to 5 min):
                //   Now that BUSY was confirmed, wait patiently for IDLE/PREVIEW.
                //   This covers even the longest extended-thinking sessions.
                {
                  bool agentWentBusy = false;

                  // Phase 1: wait up to 8 s for agent_status.txt → BUSY
                  for (int bounce = 0; bounce < 16; bounce++) {
                    if (interruptToken != _interruptionToken) break;
                    await Future.delayed(const Duration(milliseconds: 500));
                    try {
                      final statusFile = File('$_dirPath/agent_status.txt');
                      if (statusFile.existsSync()) {
                        final statusStr = statusFile.readAsStringSync().trim().toUpperCase();
                        if (statusStr.startsWith('BU')) {
                          agentWentBusy = true;
                          print('[AiBridge] Bounce protection: agent_status.txt → BUSY detected after reminder. Waiting for IDLE (extended timeout).');
                          _logPhase('BOUNCE PHASE 1: BUSY confirmed — agent received reminder and is now thinking. Switching to extended wait (up to 5 min).');
                          break;
                        }
                        // If it's already IDLE/PREVIEW the agent responded instantly
                        if (statusStr.startsWith('ID') || statusStr.startsWith('PR')) {
                          print('[AiBridge] Bounce protection: agent_status.txt already IDLE/PREVIEW after reminder (no thinking phase).');
                          _logPhase('BOUNCE PHASE 1: agent_status.txt already IDLE/PREVIEW — agent responded instantly (no extended thinking). Proceeding to file ingestion.');
                          break;
                        }
                      }
                    } catch (_) {}
                  }

                  // Phase 2: if BUSY was observed, wait up to 5 min for IDLE/PREVIEW
                  if (agentWentBusy) {
                    int reminderStatusWait = 0;
                    const int maxReminderStatusWaits = 600; // 600 × 500ms = 5 min
                    while (reminderStatusWait < maxReminderStatusWaits) {
                      try {
                        final statusFile = File('$_dirPath/agent_status.txt');
                        if (statusFile.existsSync()) {
                          final statusStr = statusFile.readAsStringSync().trim().toUpperCase();
                          if (statusStr.startsWith('ID') || statusStr.startsWith('PR')) {
                            break;
                          }
                        }
                      } catch (_) {}
                      if (interruptToken != _interruptionToken) break;
                      await Future.delayed(const Duration(milliseconds: 500));
                      reminderStatusWait++;
                    }
                    if (reminderStatusWait > 0) {
                      print('[AiBridge] Bounce protection: waited ${reminderStatusWait * 500}ms for agent_status.txt to confirm IDLE after reminder (extended wait).');
                    }
                  } else {
                    // BUSY was never seen — fall back to original 20s wait
                    _logPhase('BOUNCE PHASE 1: BUSY never observed within 8s after reminder. Falling back to 20s wait (agent may not have received prompt yet).');
                    int reminderStatusWait = 0;
                    const int maxReminderStatusWaits = 40; // 40 × 500ms = 20s
                    while (reminderStatusWait < maxReminderStatusWaits) {
                      try {
                        final statusFile = File('$_dirPath/agent_status.txt');
                        if (statusFile.existsSync()) {
                          final statusStr = statusFile.readAsStringSync().trim().toUpperCase();
                          if (statusStr.startsWith('ID') || statusStr.startsWith('PR')) {
                            break;
                          }
                        }
                      } catch (_) {}
                      if (interruptToken != _interruptionToken) break;
                      await Future.delayed(const Duration(milliseconds: 500));
                      reminderStatusWait++;
                    }
                    if (reminderStatusWait > 0) {
                      print('[AiBridge] Reminder: waited ${reminderStatusWait * 500}ms for agent_status.txt to confirm IDLE after missing-files reminder (fallback wait).');
                    }
                  }
                }

                // Second shorter retry pass to pick up newly written files
                int reminderAttempt = 0;
                while (reminderAttempt < 10) {
                  if (reminderAttempt > 0) {
                    await Future.delayed(const Duration(milliseconds: 500));
                  }
                  await attemptIngestion();
                  final bool notesOk = notesContent.trim().isNotEmpty;
                  final bool verificationOk = !hasVerificationCriteria || verificationContent.trim().isNotEmpty;
                  final bool previewOk = content != 'PREVIEW' || previewContent.trim().isNotEmpty;
                  
                  if (reminderAttempt < 10) {
                    if (notesOk && verificationOk && previewOk) {
                      print('[AiBridge] Missing files recovered after reminder on attempt ${reminderAttempt + 1}.');
                      _logPhase('REMINDER RECOVERY: Missing files recovered on attempt ${reminderAttempt + 1} after reminder. Proceeding with ingestion.');
                      break;
                    }
                  } else {
                    _logPhase('REMINDER RECOVERY: Files still missing after $reminderAttempt retry attempts post-reminder. Proceeding anyway (may have incomplete data).');
                  }
                  reminderAttempt++;
                }
              }
            }

            try {
              final notesFile = File('$_dirPath/latest_notes.json');
              if (notesFile.existsSync()) notesFile.deleteSync();
            } catch (_) {}
            try {
              final previewFile = File('$_dirPath/latest_preview.json');
              if (previewFile.existsSync()) previewFile.deleteSync();
            } catch (_) {}
            try {
              final verificationFile = File('$_dirPath/latest_verification.json');
              if (verificationFile.existsSync()) verificationFile.deleteSync();
            } catch (_) {}

            // 1. Absorb Notes
            if (notesContent.trim().isNotEmpty) {
              logSimulatedAction('FILE_READ', 'Read latest_notes.json', notesContent);
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
                    final trimmed = content.trim();
                    if (trimmed.isNotEmpty && trimmed.startsWith('{')) {
                      final Map<String, dynamic> jsonMap =
                          jsonDecode(trimmed);
                      parsedSummary =
                          jsonMap['summary']?.toString().trim() ?? '';
                      parsedNotes =
                          jsonMap['notes']?.toString().trim() ?? '';
                    }
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
            bool generatedPreviewItems = false;
            if (previewContent.trim().isNotEmpty) {
              logSimulatedAction('FILE_READ', 'Read latest_preview.json', previewContent);
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
                  final trimmed = content.trim();
                  if (trimmed.isNotEmpty && trimmed.startsWith('[')) {
                    final List<dynamic> jsonList = jsonDecode(trimmed);
                    final newItems = jsonList
                        .map((e) => AiVerificationCriteria(
                              description: e['description']?.toString() ?? 'Preview item',
                              goal: e['goal']?.toString() ?? '',
                              status: AiVerificationStatus.pendingReview,
                              isVerified: false,
                              isPreview: true,
                            ))
                        .toList();
                    
                    _tasks[taskIdx].verificationCriteria.removeWhere((item) => item.isPreview);
                    _tasks[taskIdx].verificationCriteria.addAll(newItems);
                    changed = true;
                    if (newItems.isNotEmpty) {
                      generatedPreviewItems = true;
                    }
                  }
                }
              } catch (e) {
                _lastJsonParseError = 'Preview Parse Error: $e';
                debugPrint('Error parsing preview json: $e');
              }
            }

            // 3. Absorb Verification
            if (verificationContent.trim().isNotEmpty) {
              logSimulatedAction('FILE_READ', 'Read latest_verification.json', verificationContent);
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
                  final trimmed = content.trim();
                  if (trimmed.isNotEmpty && trimmed.startsWith('[')) {
                    final List<dynamic> jsonList = jsonDecode(trimmed);
                    final newItems = jsonList
                        .map((e) => AiVerificationCriteria.fromJson(e))
                        .toList();

                    final existing = _tasks[taskIdx].verificationCriteria;
                    for (int ni = 0; ni < newItems.length; ni++) {
                      final newItem = newItems[ni];
                      // Attempt 1: match by criteriaIndex (unambiguous — agent echoes
                      // the index written into current_task.json / the prompt).
                      final rawJson = jsonList[ni];
                      final criteriaIndexRaw = rawJson['criteriaIndex'];
                      int matchIdx = -1;
                      if (criteriaIndexRaw != null) {
                        final idx = (criteriaIndexRaw as num?)?.toInt() ?? -1;
                        if (idx >= 0 && idx < existing.length) {
                          matchIdx = idx;
                          print('[AiBridge] Verification matched by criteriaIndex=$idx → "${existing[idx].description.substring(0, existing[idx].description.length.clamp(0, 60))}"');
                        }
                      }
                      // Attempt 2: exact description match (case-insensitive)
                      if (matchIdx == -1) {
                        matchIdx = existing.indexWhere((e) {
                          final eDesc = e.description.trim().toLowerCase();
                          final nDesc = newItem.description.trim().toLowerCase();
                          return nDesc == eDesc;
                        });
                      }
                      // Attempt 3: bidirectional prefix match (last resort)
                      if (matchIdx == -1) {
                        matchIdx = existing.indexWhere((e) {
                          final eDesc = e.description.trim().toLowerCase();
                          final nDesc = newItem.description.trim().toLowerCase();
                          return nDesc.startsWith(eDesc) || eDesc.startsWith(nDesc);
                        });
                        if (matchIdx != -1) {
                          print('[AiBridge] Verification matched by prefix fallback → "${existing[matchIdx].description.substring(0, existing[matchIdx].description.length.clamp(0, 60))}"');
                        }
                      }
                      if (matchIdx != -1) {
                        existing[matchIdx].proof = newItem.proof;
                        existing[matchIdx].notes = newItem.notes;
                        if (existing[matchIdx].status == AiVerificationStatus.submitted) {
                          existing[matchIdx].status = AiVerificationStatus.pendingReview;
                        }
                      } else {
                        // No match via index, exact, or prefix — skip silently to
                        // avoid phantom checklist items causing infinite re-queue.
                        print('[AiBridge] Verification item "${newItem.description.substring(0, newItem.description.length.clamp(0, 80))}" had no matching criterion (no criteriaIndex, no exact/prefix match) — skipped.');
                      }
                    }
                    changed = true;
                  }
                }
              } catch (e) {
                _lastJsonParseError = 'Verification Parse Error: $e';
                debugPrint(
                    'Warning: Could not read latest_verification.json: $e');
              }
            }
             _lastTaskMissingFiles.clear();

            if (content == 'IDLE' && !generatedPreviewItems) {
              try {
                // Timeout guard: SharedPreferences can deadlock if the platform channel
                // is busy — cap this to 8 seconds so it cannot hang the whole pipeline.
                final prefs = await _getPrefs().timeout(const Duration(seconds: 8));
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
              } catch (e) {
                print('[AiBridge] Skipping post-complete status change (SharedPreferences timeout or error): $e');
              }
            } // end if (content == 'IDLE' && !generatedPreviewItems)
            if (content == 'PREVIEW') {
              if (_tasks[taskIdx].previewState != 'pending') {
                _tasks[taskIdx].previewState = 'pending';
                changed = true;
              }
            } else if (content == 'IDLE') {
              if (_tasks[taskIdx].previewState != null) {
                _tasks[taskIdx].previewState = null;
                changed = true;
              }
            }

            final String? targetDesc = _activePrompt?.targetCriteriaDescription;
            for (final item in _tasks[taskIdx].verificationCriteria) {
              if (item.status == AiVerificationStatus.submitted) {
                if (targetDesc == null || item.description.trim().toLowerCase() == targetDesc.trim().toLowerCase()) {
                  item.status = AiVerificationStatus.pendingReview;
                  changed = true;
                }
              }
            }
            if (changed) {
              try {
                // Timeout guard: _save() writes tasks.json to disk — if the OS has a
                // file lock (antivirus, etc.) it can block indefinitely without one.
                await _save().timeout(const Duration(seconds: 15));
              } catch (e) {
                print('[AiBridge] _save() timed out or failed during status ingestion: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('Failed auto-status transition: $e');
        }
      }

      if (content == 'IDLE' || content == 'PREVIEW') {
        _isAntigravityBusy = false;
        _antigravityLastChangeObservedAt = null;
        setScreenBlockerEnabled(false);
        print('[AiBridge] $content detected. Completing and archiving active prompt.');
        logSimulatedAction('STATE', '$content Detected', 'Agent returned $content. Archiving active prompt and clearing task state.');
        try {
          File('$_dirPath/agent_status.txt').writeAsStringSync(content);
          print('[AiBridge] Wrote $content to agent_status.txt');
          logSimulatedAction('FILE_WRITE', 'Write agent_status.txt', content);
        } catch (e) {
          print('[AiBridge] Failed to write status to agent_status.txt: $e');
        }
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
            logSimulatedAction('FILE_WRITE', 'Delete current_task.json', 'Removing active task context file.');
            ctFile.deleteSync();
          }
        } catch (e) {
          print('[AiBridge] Failed to delete current_task.json: $e');
        }
        if (content == 'IDLE') {
          stateMachine.enterIdle();
        } else {
          stateMachine.enterPreviewing();
        }
      }
      _saveQueueState();
      notifyListeners();

      if (_pendingPrompts.isEmpty) {
        _writeQueueStatus('IDLE');
        // Log the hot restart step in both modes — live mode executes it, dry-run skips the actual call.
        logSimulatedAction(
          'UPDATE_TRIGGER',
          'Hot Restart',
          _isDryRunMode
              ? 'Queue empty. Skipping actual hot restart in dry-run mode.'
              : 'Queue empty. Triggering hot restart.',
        );
        if (!_isDryRunMode) {
          _pendingUpdateType = UpdateCoverType.hotRestart;
          print('[AiBridge] Queue is empty. Triggering pending update. Type: $_pendingUpdateType');
          await triggerPendingUpdate(force: true);
        } else {
          print('[AiBridge] Queue is empty. Hot restart logged (skipped in dry-run).');
        }
      } else {
        print('[AiBridge] Queue still has ${_pendingPrompts.length} items. Deferring update/reload until end of queue.');
      }

      print('[AiBridge] Executing _processQueue() for any remaining prompts.');
      _processQueue();
    } finally {
      watchdogTimer.cancel(); // Always cancel — normal completion doesn't need the watchdog
      _isHandlingAgentStatus = false;
      print('[AiBridge] Released status handling lock (_isHandlingAgentStatus = false)');
    }
  }

  bool _isProcessingSuggestion = false;

  void _startWatching() {
    _watchSubscription?.cancel();
    _libWatchSubscription?.cancel();
    _rootWatchSubscription?.cancel();

    final dir = Directory(_dirPath);
    if (dir.existsSync()) {
      _watchSubscription =
          dir.watch(events: FileSystemEvent.all).listen((event) async {
        final normPath = event.path.replaceAll('\\', '/');

        if (normPath.toLowerCase().endsWith('agent_status.txt')) {
          try {
            final file = File(event.path);
            if (file.existsSync()) {
              final content = file.readAsStringSync().trim().toUpperCase();
              final foundBusy = content.startsWith('BU');
              if (_isAntigravityBusy != foundBusy) {
                _isAntigravityBusy = foundBusy;
                notifyListeners();
              }
            }
          } catch (_) {}
        }

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
      final backupFile = File('$_filePath.bak');

      bool shouldRestore = false;
      dynamic jsonTop;
      String? restoreErrorReason;

      if (await file.exists()) {
        try {
          String contents = '';
          for (int i = 0; i < 5; i++) {
            try {
              contents = await file.readAsString();
              if (contents.isNotEmpty) {
                break;
              }
            } catch (e) {
              if (i == 4) rethrow;
            }
            await Future.delayed(const Duration(milliseconds: 150));
          }

          if (contents.isEmpty) {
            shouldRestore = true;
            restoreErrorReason = 'File is empty';
          } else {
            try {
              jsonTop = jsonDecode(contents);
              if (jsonTop is Map) {
                if (!jsonTop.containsKey('tasks') && !jsonTop.containsKey('primaryDirectives')) {
                  shouldRestore = true;
                  restoreErrorReason = 'Invalid schema: missing tasks and primaryDirectives';
                }
              } else if (jsonTop is! List) {
                shouldRestore = true;
                restoreErrorReason = 'Invalid format: top level is neither Map nor List';
              }
            } catch (e) {
              shouldRestore = true;
              restoreErrorReason = 'JSON parse error: $e';
            }
          }
        } catch (e) {
          shouldRestore = true;
          restoreErrorReason = 'Read error: $e';
        }

        if (shouldRestore) {
          if (await backupFile.exists()) {
            try {
              final backupContent = await backupFile.readAsString();
              jsonTop = jsonDecode(backupContent);
              if (!(Platform.environment.containsKey('FLUTTER_TEST') && !forceDiskSaveInTests)) {
                await file.writeAsString(backupContent, mode: FileMode.write, flush: true);
              }
              _lastJsonParseError = 'restored from backup: $restoreErrorReason';
              debugPrint('[AiBridge] Main task file corrupted ($restoreErrorReason). Successfully restored from backup.');
            } catch (backupErr) {
              _lastJsonParseError = 'Failed to load and restore from backup: $backupErr';
              debugPrint('[AiBridge] Failed to restore from backup: $backupErr');
              rethrow;
            }
          } else {
            _lastJsonParseError = 'File corrupted and no backup file found: $restoreErrorReason';
            debugPrint('[AiBridge] File corrupted and no backup file found: $restoreErrorReason');
          }
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
            _syncErrorInstructions =
                jsonTop['syncErrorInstructions'] as String? ??
                    _syncErrorInstructions;
            _endingInstructions =
                jsonTop['endingInstructions'] as String? ??
                    _endingInstructions;
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
              final trimmed = content.trim();
              if (trimmed.isNotEmpty && trimmed.startsWith('[')) {
                final List<dynamic> sList = jsonDecode(trimmed);
                if (sList.isNotEmpty && sList.first is Map) {
                  jsonList.addAll(sList);
                }
              }
            }
          } catch (_) {}

          try {
            final timelineFile = File('$_dirPath/timeline_history.json');
            if (await timelineFile.exists()) {
              final content = await timelineFile.readAsString();
              final trimmed = content.trim();
              if (trimmed.isNotEmpty && trimmed.startsWith('[')) {
                final List<dynamic> tList = jsonDecode(trimmed);
                _timelineHistory = tList.map((e) => TimelineCommit.fromJson(e as Map<String, dynamic>)).toList();
              }
            }
          } catch (e) {
            debugPrint('[AiBridge] Error loading timeline_history.json: $e');
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
                      notes: (match.notes.isNotEmpty) ? match.notes : ext.notes,
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
            await triggerPendingUpdate();
          }

          if (requiresSave) {
            _save();
          } else {
            _processQueue();
          }
        } else {
          debugPrint('[AiBridge] Warning: jsonTop is null (empty or unreadable tasks.json file). Skipping reload to prevent corruption.');
          return;
        }
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('Error reloading tasks dynamically: $e');
      try {
        if (!(Platform.environment.containsKey('FLUTTER_TEST') && !forceDiskSaveInTests)) {
          File('$_dirPath/bridge_error.txt')
              .writeAsString('Bridge CRASH in file watcher:\n$e\n$st', flush: true)
              .catchError((_) => File('$_dirPath/bridge_error.txt'));
        }
      } catch (_) {}
    }
  }

  bool get hasPendingUpdate => _pendingUpdateType != null && !isThinking && !_isTriggeringUpdate;

  Future<void> Function(UpdateCoverType)? onAutoReloadTriggered;

  Future<void> triggerPendingUpdate({bool force = false}) async {
    if (_isTriggeringUpdate) return;
    if (_pendingPrompts.isNotEmpty || _activePrompt != null) {
      print('[AiBridge] Deferring update/reload since the queue is not empty (Pending: ${_pendingPrompts.length}, Active: ${_activePrompt != null}).');
      return;
    }
    if (_isDryRunMode) {
      if (_pendingUpdateType != null) {
        if (_pendingUpdateType != UpdateCoverType.hotRestart) {
          logSimulatedAction('UPDATE_TRIGGER', 'Trigger $_pendingUpdateType', 'Triggering simulated $_pendingUpdateType');
        }
        _pendingUpdateType = null;
      }
      return;
    }
    if ((force || !isThinking) && _pendingUpdateType != null) {
      _isTriggeringUpdate = true;
      try {
        try {
          SystemSound.play(SystemSoundType.alert);
        } catch (_) {}

        final type = _pendingUpdateType!;
        _pendingUpdateType = null; // Clear early to prevent leakage

        try {
          await MacroService.instance.executeTrigger('BeforeReload');
        } catch (e) {
          debugPrint('Error executing BeforeReload macro: $e');
        }

        if (onAutoReloadTriggered != null) {
          await onAutoReloadTriggered!(type);
        } else {
          showUpdateCoverFor(type);
        }
      } catch (e) {
        debugPrint('Error during triggerPendingUpdate execution: $e');
      } finally {
        _isTriggeringUpdate = false;
      }
    }
  }
  Future<void> _save() async {
    if (Platform.environment.containsKey('FLUTTER_TEST') && !forceDiskSaveInTests) {
      return;
    }
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
        'syncErrorInstructions': _syncErrorInstructions,
        'endingInstructions': _endingInstructions,
        'tasks': jsonTasksList
      };
      const encoder = JsonEncoder.withIndent('  ');
      final serializedPayload = encoder.convert(outPayload);
      await file.writeAsString(serializedPayload,
          mode: FileMode.write, flush: true);

      final backupFile = File('$_filePath.bak');
      await backupFile.writeAsString(serializedPayload,
          mode: FileMode.write, flush: true);

      final sandboxFile = File('$_dirPath/sandbox.json');
      await sandboxFile.writeAsString(encoder.convert(sandboxList), mode: FileMode.write, flush: true);

      final timelineFile = File('$_dirPath/timeline_history.json');
      await timelineFile.writeAsString(encoder.convert(_timelineHistory.map((e) => e.toJson()).toList()), mode: FileMode.write, flush: true);

      // Database dump sync is independent of task list save. Run with a safety timeout in background to prevent deadlock/hangs.
      syncDatabaseDump().timeout(const Duration(seconds: 1), onTimeout: () {
        debugPrint('[AiBridgeService] syncDatabaseDump timed out during task save.');
      }).catchError((e) {
        debugPrint('[AiBridgeService] syncDatabaseDump failed during task save: $e');
      });

      notifyListeners();
    } catch (e, st) {
      debugPrint('Error saving AI tasks: $e');
      try {
        if (!(Platform.environment.containsKey('FLUTTER_TEST') && !forceDiskSaveInTests)) {
          File('$_dirPath/bridge_error.txt')
              .writeAsString('Bridge CRASH at saveTasks():\n$e\n$st', flush: true)
              .catchError((_) => File('$_dirPath/bridge_error.txt'));
        }
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
      bool? isKnowledgeSummary,
      bool? isLocked}) async {
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
      if (isLocked != null && _tasks[index].isLocked != isLocked) {
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
          if (isLocked ?? _tasks[index].isLocked) {
            shouldCommit = false;
          }
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
        if (isLocked != null) _tasks[index].isLocked = isLocked;
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
             final tasksList = tasksToCommit.map((id) {
               try {
                 return _tasks.firstWhere((t) => t.id == id);
               } catch (_) {
                 return null;
               }
             }).whereType<AiTask>().toList();
             final allNames = generateCommitName(tasksList);

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
                    forceDispatchGitPushError(e.toString());
                    return '';
                 });
                 try { File('.ai_bridge/bridge_commit_debug.txt').writeAsStringSync('commitTimelineTasks returned hash: $hash\n', mode: FileMode.append); } catch (_) {}
                 if (hash.isNotEmpty && !hash.startsWith('Local repository path')) {
                    final actualHash = (hash == 'No changes to commit.' || hash == 'Committed successfully.') ? 'No Git Changes' : hash;
                    final commitDateStr = DateTime.now().toIso8601String();
                    for (final id in tasksToCommit) {
                       try {
                          final task = _tasks.firstWhere((t) => t.id == id);
                          task.commitHash = actualHash;
                          task.commitDate = commitDateStr;
                          task.status = AiTaskStatus.completed;
                          task.isLocked = false;
                          _prefs?.remove('task_custom_commit_note_$id');
                          for (var vc in task.verificationCriteria) {
                            if (vc.status == AiVerificationStatus.verified) {
                              vc.isCommitted = true;
                            }
                          }
                       } catch (_) {}
                    }
                    await reloadTimelineHistory();
                 }
             } catch (_) {}
        }
      }
    }
  }

  String generateCommitName(List<AiTask> tasks) {
    return tasks.map((task) {
      final summaryStr = task.summary.isNotEmpty ? ' [${task.summary}]' : '';
      
      final customNote = _prefs?.getString('task_custom_commit_note_${task.id}') ?? '';
      String notesClean = '';
      if (customNote.isNotEmpty) {
        notesClean = customNote.replaceAll(RegExp(r'\s+'), ' ').trim();
      } else {
        final rawNotes = task.notes;
        if (!rawNotes.contains('### Update -') && !rawNotes.contains('=== RUNTIME/LAYOUT')) {
          notesClean = rawNotes.replaceAll(RegExp(r'\s+'), ' ').trim();
        }
      }
      
      if (notesClean.length > 50) {
        notesClean = '${notesClean.substring(0, 47)}...';
      }
      final notesStr = notesClean.isNotEmpty ? ' (Note: $notesClean)' : '';
      return '${task.name}$summaryStr$notesStr';
    }).where((n) => n.isNotEmpty).join(' | ');
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
         try { File('.ai_bridge/bridge_error.txt').writeAsStringSync('Manual commit failed: $e\n'); } catch (_) {}
         forceDispatchGitPushError(e.toString());
         return '';
      });

      if (hash.isNotEmpty && !hash.startsWith('Local repository path')) {
         final actualHash = (hash == 'No changes to commit.' || hash == 'Committed successfully.') ? 'No Git Changes' : hash;
         final commitDateStr = DateTime.now().toIso8601String();
         for (var task in tasksToCommit) {
           task.commitHash = actualHash;
           task.commitDate = commitDateStr;
           task.status = AiTaskStatus.completed;
           task.isLocked = false;
           _prefs?.remove('task_custom_commit_note_${task.id}');
           for (var vc in task.verificationCriteria) {
             if (vc.status == AiVerificationStatus.verified) {
               vc.isCommitted = true;
             }
           }
         }
         
         await reloadTimelineHistory();
         return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> reloadTimelineHistory() async {
    try {
      final commits = await VersionControlService.instance.fetchTimelineHistory();
      _timelineHistory = commits;
      await _save();
    } catch (e) {
      debugPrint('[AiBridge] Error reloading timeline history: $e');
    }
  }

  Future<void> deleteTimelineCommit(String commitId) async {
    _timelineHistory.removeWhere((c) => c.id == commitId);
    await _save();
  }

  Future<void> appendCheckpointToTimeline(String description, String commitHash, {List<String>? taskIds}) async {
    await reloadTimelineHistory();
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
      List<String>? hyperlinks,
      List<AiVerificationCriteria>? verificationCriteria}) async {
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
      verificationCriteria: verificationCriteria,
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

// ---------------------------------------------------------------------------
// Custom Macro Rules (Slash Command Override) Data Model and Helpers
// ---------------------------------------------------------------------------

class CustomRule {
  final String trigger;
  final String action;
  final String body;

  CustomRule({
    required this.trigger,
    required this.action,
    required this.body,
  });
}

Future<List<CustomRule>> loadCustomRules(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) {
    return [];
  }
  final rules = <CustomRule>[];
  try {
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.md')) {
        final content = await entity.readAsString();
        final rule = parseCustomRule(content);
        if (rule != null) {
          rules.add(rule);
        }
      }
    }
  } catch (e) {
    debugPrint('Error loading custom rules: $e');
  }
  return rules;
}

CustomRule? parseCustomRule(String content) {
  final lines = content.split(RegExp(r'\r?\n'));
  if (lines.isEmpty || lines.first.trim() != '---') {
    return null;
  }
  int secondSeparator = -1;
  for (int i = 1; i < lines.length; i++) {
    if (lines[i].trim() == '---') {
      secondSeparator = i;
      break;
    }
  }
  if (secondSeparator == -1) {
    return null;
  }
  String trigger = '';
  String action = '';
  for (int i = 1; i < secondSeparator; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final colonIdx = line.indexOf(':');
    if (colonIdx != -1) {
      final key = line.substring(0, colonIdx).trim().toLowerCase();
      var val = line.substring(colonIdx + 1).trim();
      if (val.startsWith('"') && val.endsWith('"') && val.length >= 2) {
        val = val.substring(1, val.length - 1);
      } else if (val.startsWith("'") && val.endsWith("'") && val.length >= 2) {
        val = val.substring(1, val.length - 1);
      }
      if (key == 'trigger') {
        trigger = val;
      } else if (key == 'action') {
        action = val;
      }
    }
  }
  final body = lines.sublist(secondSeparator + 1).join('\n').trim();
  if (trigger.isNotEmpty && action.isNotEmpty) {
    return CustomRule(trigger: trigger, action: action, body: body);
  }
  return null;
}

String? extractModelFromRuleBody(String body) {
  final knownModels = [
    'gemini-3.5-flash',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.5-pro',
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
    'gemini-2.0-pro',
    'gemini-1.5-flash',
    'gemini-1.5-flash-8b',
    'gemini-1.5-pro',
    'claude-3-5-sonnet',
    'claude-3-5-haiku',
    'llama-3.1-8b',
    'llama-3.1-70b',
    'llama-3.1-405b',
  ];
  for (final model in knownModels) {
    if (body.contains(model)) {
      return model;
    }
  }
  final regex = RegExp(r'(gemini|claude|llama)-[a-zA-Z0-9.-]+');
  final match = regex.firstMatch(body);
  if (match != null) {
    return match.group(0);
  }
  return null;
}


