import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';

enum LogCategory { GENERAL, ERROR, NETWORK, DB, SYSTEM, AI, MACRO, VC }

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

class SystemLogsService extends ChangeNotifier {
  static final SystemLogsService instance = SystemLogsService._internal();
  SystemLogsService._internal();

  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);
  
  File? _logFile;

  Future<void> init() async {
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

  void addLog(String message, {LogCategory category = LogCategory.GENERAL}) {
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
