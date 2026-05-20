import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'system_logs_service.dart';

class BackendProcessManager {
  static final BackendProcessManager _instance = BackendProcessManager._internal();
  factory BackendProcessManager() => _instance;
  BackendProcessManager._internal();

  Process? _activeProcess;
  bool _isStarting = false;

  Process? get activeProcess => _activeProcess;

  /// Resolves standard path and arguments if the command is empty, 'antigravity-server', or just the executable name.
  String getResolvedStartupCommand(String commandStr) {
    var cmd = commandStr.trim();
    if (cmd == 'antigravity-server' || cmd.isEmpty) {
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'] ?? '';
        final standardPath = '$userProfile\\AppData\\Local\\Programs\\Antigravity\\resources\\bin\\language_server.exe';
        if (File(standardPath).existsSync()) {
          return '"$standardPath" --standalone --override_ide_name antigravity --subclient_type hub --override_ide_version 2.0.0 --override_user_agent_name antigravity --https_server_port 0 --http_server_port 8080 --csrf_token 6c867a8e-96cc-483d-a132-178ab094abe3 --app_data_dir antigravity --api_server_url https://generativelanguage.googleapis.com --cloud_code_endpoint https://daily-cloudcode-pa.googleapis.com --enable_sidecars';
        }
      }
    } else if (Platform.isWindows && cmd.toLowerCase().endsWith('language_server.exe') && !cmd.contains('--standalone') && !cmd.contains('-standalone')) {
      return '$cmd --standalone --override_ide_name antigravity --subclient_type hub --override_ide_version 2.0.0 --override_user_agent_name antigravity --https_server_port 0 --http_server_port 8080 --csrf_token 6c867a8e-96cc-483d-a132-178ab094abe3 --app_data_dir antigravity --api_server_url https://generativelanguage.googleapis.com --cloud_code_endpoint https://daily-cloudcode-pa.googleapis.com --enable_sidecars';
    }
    return cmd;
  }

  /// Parses a command string into separate arguments, respecting double and single quotes.
  List<String> _parseCommand(String commandStr) {
    final List<String> parts = [];
    var current = StringBuffer();
    bool inDoubleQuotes = false;
    bool inSingleQuotes = false;
    
    for (int i = 0; i < commandStr.length; i++) {
      final char = commandStr[i];
      if (char == '"' && !inSingleQuotes) {
        inDoubleQuotes = !inDoubleQuotes;
      } else if (char == "'" && !inDoubleQuotes) {
        inSingleQuotes = !inSingleQuotes;
      } else if (char == ' ' && !inDoubleQuotes && !inSingleQuotes) {
        if (current.isNotEmpty) {
          parts.add(current.toString());
          current.clear();
        }
      } else {
        current.write(char);
      }
    }
    if (current.isNotEmpty) {
      parts.add(current.toString());
    }
    return parts;
  }

  /// Spawns the backend process if it's not already running.
  Future<void> spawnBackend(String commandStr) async {
    if (_activeProcess != null) {
      debugPrint('Backend process is already running.');
      return;
    }
    if (_isStarting) {
      debugPrint('Backend process is already starting.');
      return;
    }
    
    _isStarting = true;
    try {
      final resolvedCmd = getResolvedStartupCommand(commandStr);
      final parts = _parseCommand(resolvedCmd);
      if (parts.isEmpty) throw Exception('Startup command is empty.');

      final executable = parts.first;
      final arguments = parts.length > 1 ? parts.sublist(1) : <String>[];

      debugPrint('Spawning backend: $executable ${arguments.join(' ')}');

      _activeProcess = await Process.start(
        executable,
        arguments,
        mode: ProcessStartMode.normal,
        runInShell: true,
      );

      _activeProcess?.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _logLine(line, isStderr: false);
      });

      _activeProcess?.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _logLine(line, isStderr: true);
      });

      _activeProcess?.exitCode.then((code) {
        debugPrint('Antigravity backend exited with code: $code');
        _activeProcess = null;
      });

    } catch (e) {
      debugPrint('Failed to spawn backend process: $e');
      rethrow;
    } finally {
      _isStarting = false;
    }
  }

  void _logLine(String line, {required bool isStderr}) {
    if (line.trim().isEmpty) return;

    // Check for Go glog format: e.g. I0519 17:43:42...
    final glogRegex = RegExp(r'^([IWEF])\d{4}\s');
    final match = glogRegex.firstMatch(line);
    String prefix = '[Antigravity Backend]:';
    LogCategory logCat = LogCategory.AI;
    
    if (match != null) {
      final severity = match.group(1);
      if (severity == 'I') {
        prefix = '[Antigravity Backend INFO]:';
      } else if (severity == 'W') {
        prefix = '[Antigravity Backend WARNING]:';
      } else if (severity == 'E') {
        prefix = '[Antigravity Backend ERROR]:';
        logCat = LogCategory.ERROR;
      } else if (severity == 'F') {
        prefix = '[Antigravity Backend FATAL]:';
        logCat = LogCategory.ERROR;
      }
    } else {
      prefix = isStderr ? '[Antigravity Backend]:' : '[Antigravity Backend]:';
    }
    
    final formattedLog = '$prefix $line';
    debugPrint(formattedLog);
    SystemLogsService.instance.addLog(formattedLog, category: logCat);
  }

  /// Gracefully kills the backend process.
  void shutdown() {
    if (_activeProcess != null) {
      debugPrint('Killing Antigravity backend process...');
      _activeProcess!.kill(ProcessSignal.sigterm);
      _activeProcess = null;
    }
  }
}
