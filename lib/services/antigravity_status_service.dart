import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/constants.dart';

/// Service to monitor the status of the Antigravity CLI daemon.
/// Handles checking both the local LSP HTTP/WebSocket bridge and native OS processes.
class AntigravityStatusService {
  static final AntigravityStatusService instance = AntigravityStatusService._();
  
  AntigravityStatusService._();

  bool _isSpawning = false;

  /// Path to the agent status file, configurable for testing.
  String statusFilePath = '.ai_bridge/agent_status.txt';

  String? _lastGlobalState;
  int? _lastActiveJobs;
  bool? _lastIsBusy;
  bool? _lastIsOnline;
  String? _lastBridgeLog;
  bool _enableLogs = false;
  DateTime? _lastProcessCheckTime;
  bool _lastProcessCheckResult = false;

  @visibleForTesting
  void resetState() {
    _lastGlobalState = null;
    _lastActiveJobs = null;
    _lastIsBusy = null;
    _lastIsOnline = null;
    _lastBridgeLog = null;
    _lastProcessCheckTime = null;
    _lastProcessCheckResult = false;
  }

  Future<void> _updateLogSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enableLogs = prefs.getBool('antigravity_status_debug') ?? false;
    } catch (_) {
      _enableLogs = false;
    }
  }

  void _logBridge(String message) {
    if (AppDebugConfig.enableStatusBridgeLogs || _enableLogs) {
      if (_lastBridgeLog != message) {
        _lastBridgeLog = message;
        debugPrint(message);
      }
    }
  }

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 1),
    receiveTimeout: const Duration(seconds: 1),
  ));

  /// Resolves the loopback/host URL for the HTTP bridge dynamically from SharedPreferences.
  /// Handles Android emulator routing fallback (10.0.2.2) and desktop localhost (127.0.0.1).
  Future<String> getBridgeUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var baseUrl = prefs.getString('antigravity_base_url') ?? 'http://127.0.0.1:8080';
      if (baseUrl.startsWith('http://localhost') || baseUrl.startsWith('https://localhost')) {
        baseUrl = baseUrl.replaceFirst('localhost', '127.0.0.1');
      }
      if (!kIsWeb && Platform.isAndroid) {
        if (baseUrl.contains('127.0.0.1')) {
          baseUrl = baseUrl.replaceFirst('127.0.0.1', '10.0.2.2');
        } else if (baseUrl.contains('localhost')) {
          baseUrl = baseUrl.replaceFirst('localhost', '10.0.2.2');
        }
      }
      return baseUrl;
    } catch (_) {
      if (!kIsWeb && Platform.isAndroid) {
        return 'http://10.0.2.2:8080';
      }
      return 'http://127.0.0.1:8080';
    }
  }

  /// Queries the local HTTP root endpoint and checks if the served SPA is responsive.
  /// Returns a status JSON map if online (querying agent_status.txt for busy status), or null if offline.
  Future<Map<String, dynamic>?> getHttpBridgeStatus() async {
    await _updateLogSetting();
    try {
      final statusFile = File(statusFilePath);
      final bridgeDir = statusFile.parent.path;
      final activeModeFile = File('$bridgeDir/active_mode.txt');
      if (activeModeFile.existsSync()) {
        final mode = activeModeFile.readAsStringSync().trim().toLowerCase();
        if (mode != 'sdk') {
          return null;
        }
      }

      final url = await getBridgeUrl();
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final content = response.data.toString().toLowerCase();
        if (content.contains('antigravity')) {
          String status = 'IDLE';
          int activeJobs = 0;
          try {
            final statusFile = File(statusFilePath);
            if (statusFile.existsSync()) {
              final fileContent = statusFile.readAsStringSync().trim().toUpperCase();
              if (fileContent.startsWith('BU')) {
                status = 'WORKING';
                activeJobs = 1;
              }
            }
          } catch (_) {}

          return {
            'status': status,
            'active_jobs': activeJobs,
          };
        }
      }
      return null;
    } on DioException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Queries the HTTP status map to check if the CLI is busy.
  /// Returns true if the daemon has active jobs or is in a WORKING/PROCESSING state.
  Future<bool> checkHttpBridgeBusy() async {
    await _updateLogSetting();
    try {
      final data = await getHttpBridgeStatus();

      if (data != null) {
        final activeJobs = data['active_jobs'] ?? 0;
        final globalState = (data['status'] ?? 'IDLE').toString().toUpperCase();
        final isBusy = activeJobs > 0 || globalState == 'WORKING' || globalState == 'PROCESSING';
        
        final changed = _lastIsOnline != true ||
            _lastGlobalState != globalState ||
            _lastActiveJobs != activeJobs ||
            _lastIsBusy != isBusy;
        if (changed) {
          _lastIsOnline = true;
          _lastGlobalState = globalState;
          _lastActiveJobs = activeJobs;
          _lastIsBusy = isBusy;
          _logBridge('[SYNC] HTTP bridge check: state=$globalState, activeJobs=$activeJobs, isBusy=$isBusy');
        }
        return isBusy;
      }

      if (_lastIsOnline != false) {
        _lastIsOnline = false;
        _lastGlobalState = null;
        _lastActiveJobs = null;
        _lastIsBusy = null;
        _logBridge('[SYNC] HTTP bridge check: offline');
      }
      return false;
    } catch (e) {
      if (_lastIsOnline != false) {
        _lastIsOnline = false;
        _lastGlobalState = null;
        _lastActiveJobs = null;
        _lastIsBusy = null;
        _logBridge('[SYNC] HTTP bridge check: offline');
      }
      return false;
    }
  }

  /// Scans running OS processes to see if the Antigravity daemon is currently active.
  /// Caches results for 5 seconds to prevent performance bottlenecks from rapid process queries.
  Future<bool> isProcessRunning() async {
    if (kIsWeb) return false;
    final now = DateTime.now();
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest && _lastProcessCheckTime != null && now.difference(_lastProcessCheckTime!).inSeconds < 5) {
      return _lastProcessCheckResult;
    }
    try {
      final result = await Process.run(
        Platform.isWindows ? 'tasklist' : 'ps',
        Platform.isWindows ? ['/v'] : ['-ax'],
      );
      final output = result.stdout.toString().toLowerCase();
      final isRunning = Platform.isWindows 
          ? (output.contains('antigravity cli') || output.contains('agy.exe') || output.contains('antigravity.exe') || output.contains('antigravity'))
          : (output.contains('agy ') || output.contains('/agy') || output.contains('antigravity-server'));
      debugPrint('[SYNC] Process running check: $isRunning');
      _lastProcessCheckTime = now;
      _lastProcessCheckResult = isRunning;
      return isRunning;
    } catch (e) {
      debugPrint('[SYNC] Process check: offline');
      return false;
    }
  }

  /// Combined busy state check.
  /// Evaluates the HTTP bridge, local status files, and process lists to determine
  /// if the CLI is busy, stuck, or active.
  Future<bool> isCliBusy() async {
    // 1. Try checking the HTTP bridge first
    final isBridgeBusy = await checkHttpBridgeBusy();
    if (isBridgeBusy) return true;

    // 2. Check local agent_status.txt for explicit BUSY flag
    try {
      final statusFile = File(statusFilePath);
      if (statusFile.existsSync()) {
        final content = statusFile.readAsStringSync().trim().toUpperCase();
        if (content.startsWith('BU')) {
          // If the file was updated recently, assume active without scanning processes
          try {
            final stat = statusFile.statSync();
            final lastModified = stat.modified;
            final age = DateTime.now().difference(lastModified);
            if (age.inMinutes < 60) {
              debugPrint('[SYNC] $statusFilePath is BUSY and was updated recently (${age.inSeconds}s ago). Assuming active.');
              return true;
            }
          } catch (_) {}

          // Only scan processes if the file is older than 60 minutes to verify if the process is still running
          final isRunning = await isProcessRunning();
          if (!isRunning) {
            debugPrint('[SYNC] agent_status.txt is BUSY (starts with BU) and older than 60 minutes, HTTP bridge is offline and process is not running. Auto-recovering status to IDLE.');
            try {
              statusFile.writeAsStringSync('IDLE');
            } catch (_) {}
            return false;
          }
          debugPrint('[SYNC] $statusFilePath is explicitly BUSY and process is running');
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  /// Spawns the CLI terminal if it isn't running.
  Future<void> ensureTerminalDaemonRunning() async {
    if (kIsWeb) return;
    if (_isSpawning) {
      debugPrint('[SYNC] Spawning already in progress, skipping...');
      return;
    }
    
    // Acquire lock synchronously before yielding the thread
    _isSpawning = true;

    try {
      // Check if the agy process is running
      final isProcRunning = await isProcessRunning();
      
      if (!isProcRunning) {
        debugPrint('[SYNC] Terminal daemon not found. Spawning one...');
        try {
          if (Platform.isWindows) {
            try {
              // Try spawning using wt.exe (Windows Terminal)
              await Process.start(
                'wt.exe',
                [
                  '--title',
                  'Antigravity CLI',
                  'powershell.exe',
                  '-NoExit',
                  '-Command',
                  'cd c:\\Development\\Music\\Project; agy .'
                ],
              );
            } catch (_) {
              // Fallback to cmd.exe /c start with instant title setting to avoid race conditions
              await Process.start(
                'cmd.exe',
                [
                  '/c',
                  'start',
                  'Antigravity CLI',
                  'powershell.exe',
                  '-NoExit',
                  '-Command',
                  '\$Host.UI.RawUI.WindowTitle = \'Antigravity CLI\'; cd c:\\Development\\Music\\Project; agy .'
                ],
              );
            }
          } else {
            // Fallback for macOS/Linux terminal spawning if needed, though target OS is Windows
            await Process.start(
              'bash',
              ['-c', 'cd c:\\Development\\Music\\Project && agy .'],
              runInShell: true,
              mode: ProcessStartMode.detached,
            );
          }
          // Hold the lock for 5 seconds to let the OS process spin up and register in tasklist
          Future.delayed(const Duration(seconds: 5), () {
            _isSpawning = false;
          });
        } catch (spawnError) {
          _isSpawning = false;
          rethrow;
        }
      } else {
        // Process is already running, release lock immediately
        _isSpawning = false;
        debugPrint('[SYNC] Terminal daemon already running (isProcRunning: $isProcRunning)');
      }
    } catch (e) {
      _isSpawning = false;
      debugPrint('[SYNC] Error ensuring terminal daemon: $e');
    }
  }

  /// Brings the Antigravity terminal daemon window to the foreground on Windows.
  Future<void> focusDaemonWindow() async {
    if (kIsWeb) return;
    if (!Platform.isWindows) return;
    try {
      final vbsFile = File('.ai_bridge/focus_daemon.vbs');
      if (!vbsFile.parent.existsSync()) {
        vbsFile.parent.createSync(recursive: true);
      }
      await vbsFile.writeAsString('''
Set wshShell = CreateObject("WScript.Shell")
wshShell.AppActivate "Antigravity CLI"
''');
      await Process.run('wscript', [vbsFile.path]);
    } catch (e) {
      debugPrint('[SYNC] Error focusing daemon window: $e');
    }
  }
}
