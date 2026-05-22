import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to monitor the status of the Antigravity CLI daemon.
/// Handles checking both the local LSP HTTP/WebSocket bridge and native OS processes.
class AntigravityStatusService {
  static final AntigravityStatusService instance = AntigravityStatusService._();
  
  AntigravityStatusService._();

  /// Path to the agent status file, configurable for testing.
  @visibleForTesting
  String statusFilePath = '.ai_bridge/agent_status.txt';

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
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
    try {
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
              final fileContent = statusFile.readAsStringSync().trim();
              if (fileContent == 'BUSY') {
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
    } on DioException catch (e) {
      final isTimeout = e.type == DioExceptionType.connectionTimeout ||
                        e.type == DioExceptionType.receiveTimeout ||
                        e.type == DioExceptionType.sendTimeout;
      final status = isTimeout ? 'offline (timeout)' : 'offline';
      debugPrint('[AntigravityStatusService] HTTP bridge status check: $status');
      return null;
    } catch (e) {
      debugPrint('[AntigravityStatusService] HTTP bridge status check: offline');
      return null;
    }
  }

  /// Queries the HTTP status map to check if the CLI is busy.
  /// Returns true if the daemon has active jobs or is in a WORKING/PROCESSING state.
  Future<bool> checkHttpBridgeBusy() async {
    try {
      final data = await getHttpBridgeStatus();
      if (data != null) {
        final activeJobs = data['active_jobs'] ?? 0;
        final globalState = (data['status'] ?? 'IDLE').toString().toUpperCase();
        final isBusy = activeJobs > 0 || globalState == 'WORKING' || globalState == 'PROCESSING';
        debugPrint('[AntigravityStatusService] HTTP bridge check: state=$globalState, activeJobs=$activeJobs, isBusy=$isBusy');
        return isBusy;
      }
      return false;
    } catch (e) {
      debugPrint('[AntigravityStatusService] HTTP bridge check: offline');
      return false;
    }
  }

  /// Scans running OS processes to see if the Antigravity daemon is currently active.
  Future<bool> isProcessRunning() async {
    if (kIsWeb) return false;
    try {
      final result = await Process.run(
        Platform.isWindows ? 'tasklist' : 'ps',
        Platform.isWindows ? [] : ['-ax'],
      );
      final output = result.stdout.toString().toLowerCase();
      final isRunning = output.contains('antigravity-server') || 
                        output.contains('language_server.exe') || 
                        output.contains('language_server') ||
                        output.contains('kiro');
      debugPrint('[AntigravityStatusService] Process running check: $isRunning');
      return isRunning;
    } catch (e) {
      debugPrint('[AntigravityStatusService] Process check: offline');
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
        final content = statusFile.readAsStringSync().trim();
        if (content == 'BUSY') {
          final isRunning = await isProcessRunning();
          if (!isRunning) {
            debugPrint('[AntigravityStatusService] agent_status.txt is BUSY, but HTTP bridge is offline and process is not running. Auto-recovering status to IDLE.');
            try {
              statusFile.writeAsStringSync('IDLE');
            } catch (_) {}
            return false;
          }
          debugPrint('[AntigravityStatusService] $statusFilePath is explicitly BUSY');
          return true;
        }
      }
    } catch (_) {}

    // 3. Fallback: if process is running but bridge did not respond (possibly due to network/port issue)
    // or if the process itself is active and we want to prevent simultaneous updates.
    // However, if the process is running but the HTTP bridge returns IDLE (handled in step 1),
    // we do NOT treat it as busy. But if the HTTP bridge is completely offline/unreachable AND
    // the process is running, let's treat it as potentially busy if agent_status.txt is BUSY,
    // which is already covered. If the bridge is offline and agent_status.txt is IDLE,
    // we assume it is not busy.
    return false;
  }
}
