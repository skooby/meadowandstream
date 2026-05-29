import 'dart:io';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LogCategory { GENERAL, ERROR, NETWORK, DB, SYSTEM, AI, MACRO, VC, CLI, SYNC }

enum ErrorCategory { layout, runtime, test, dependency }

class DetectedError {
  final String message;
  final ErrorCategory category;
  final DateTime timestamp;

  DetectedError(this.message, this.category) : timestamp = DateTime.now();
}

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogCategory category;

  LogEntry(this.message, {this.category = LogCategory.GENERAL}) : timestamp = DateTime.now();
}

class LogTypeConfig {
  final LogCategory category;
  bool system;
  bool console;

  LogTypeConfig({required this.category, this.system = true, this.console = true});

  Map<String, dynamic> toJson() => {
    'category': category.name,
    'system': system,
    'console': console,
  };

  factory LogTypeConfig.fromJson(Map<String, dynamic> json) {
    final cat = LogCategory.values.firstWhere(
      (e) => e.name == json['category'],
      orElse: () => LogCategory.GENERAL,
    );
    return LogTypeConfig(
      category: cat,
      system: json['system'] ?? true,
      console: json['console'] ?? true,
    );
  }
}

class SystemLogsService extends ChangeNotifier {
  static final SystemLogsService instance = SystemLogsService._internal();
  SystemLogsService._internal();

  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);
  
  File? _logFile;
  List<LogTypeConfig> _categoryConfigs = [];
  List<LogTypeConfig> get categoryConfigs => _categoryConfigs;

  Future<void> init() async {
    await loadConfigs();
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/sandbox_session_logs.txt');
      if (!await _logFile!.exists()) {
        await _logFile!.create();
      }
      // Add initial marker
      await _logFile!.writeAsString("=== NEW SESSION STARTED: ${DateTime.now()} ===\n", mode: FileMode.append);
    } catch (_) {}
  }

  Future<void> loadConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('system_log_types_config');
      if (jsonStr != null) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _categoryConfigs = list.map((e) => LogTypeConfig.fromJson(e)).toList();
      } else {
        _setDefaultConfigs();
      }
    } catch (_) {
      _setDefaultConfigs();
    }
    // Ensure all categories are present
    for (final cat in LogCategory.values) {
      if (!_categoryConfigs.any((e) => e.category == cat)) {
        _categoryConfigs.add(LogTypeConfig(category: cat));
      }
    }
  }

  void _setDefaultConfigs() {
    _categoryConfigs = LogCategory.values
        .map((cat) => LogTypeConfig(category: cat, system: true, console: true))
        .toList();
  }

  Future<void> saveConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_categoryConfigs.map((e) => e.toJson()).toList());
      await prefs.setString('system_log_types_config', jsonStr);
    } catch (_) {}
    notifyListeners();
  }

  void reorderConfigs(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _categoryConfigs.removeAt(oldIndex);
    _categoryConfigs.insert(newIndex, item);
    saveConfigs();
  }

  void addLog(String message, {LogCategory category = LogCategory.GENERAL}) {
    if (message.toLowerCase().contains('[aibridge]') ||
        message.toLowerCase().contains('[ai bridge]') ||
        message.contains('[AntigravityStatusService]')) {
      category = LogCategory.SYNC;
    }
    // Ensure configs are loaded
    if (_categoryConfigs.isEmpty) {
      _setDefaultConfigs();
    }
    final config = _categoryConfigs.firstWhere(
      (e) => e.category == category,
      orElse: () => LogTypeConfig(category: category),
    );

    // Always print AI logs to console so they're visible regardless of saved config.
    if (category == LogCategory.AI) {
      debugPrint('[AI] $message');
    } else if (message.toLowerCase().contains('[aibridge]') ||
        message.toLowerCase().contains('[ai bridge]') ||
        message.contains('[AntigravityStatusService]')) {
      debugPrint('[LogCategory.DIRECT] $message');
    } else if (config.console && category != LogCategory.GENERAL) {
      debugPrint('[$category] $message');
    }

    // AI logs always go to the system log panel regardless of saved config.
    if (!config.system && category != LogCategory.AI) {
      return;
    }

    final entry = LogEntry(message, category: category);
    _logs.add(entry);
    // Keep max to avoid OOM
    if (_logs.length > 500) {
      _logs.removeAt(0);
    }
    
    if (_logFile != null) {
        String formattedTime = "${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}";
        _logFile!.writeAsString("[$formattedTime] [${entry.category.name}] ${entry.message}\n", mode: FileMode.append).catchError((_) => _logFile!);
    }

    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  void clearLogs() {
    _logs.clear();
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }
}
