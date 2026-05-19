import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants.dart';
import 'ai_bridge_service.dart';

class SandboxService extends ChangeNotifier {
  static final SandboxService instance = SandboxService._internal();

  SandboxService._internal();

  List<String> _sandboxTaskIds = [];

  List<String> get sandboxTaskIds => List.unmodifiable(_sandboxTaskIds);

  Future<void> init() async {
    await reload();
  }

  Future<void> reload() async {
    try {
      final sandboxFile = File('.ai_bridge/sandbox.json');
      if (await sandboxFile.exists()) {
        final content = await sandboxFile.readAsString();
        if (content.trim().isNotEmpty) {
          try {
            final List<dynamic> jsonList = jsonDecode(content);
            if (jsonList.isNotEmpty && jsonList.first is Map) {
              _sandboxTaskIds = jsonList.map((e) => e['id'].toString()).toList();
            } else {
              _sandboxTaskIds = jsonList.map((e) => e.toString()).toList();
            }
          } catch (e) {
            debugPrint('Sandbox JSON decode failed (might be truncated during write): $e');
            // Retain existing sandboxTaskIds if parse fails.
          }
        }
      }

      final timelineFile = File('.ai_bridge/timeline_history.json');
      if (await timelineFile.exists()) {
        // Timeline history is now loaded by AiBridgeService into TimelineCommit objects.
        // We no longer track task IDs here.
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading sandbox/timeline state: $e');
    }
  }

  Future<void> _save() async {
    notifyListeners();
    // AiBridgeService will handle the actual file writes to ensure full task objects
    // are serialized into sandbox.json and timeline_history.json, not just IDs.
    AiBridgeService.instance.saveTasks();
  }

  Future<void> addToSandbox(List<String> taskIds) async {
    bool changed = false;
    for (final id in taskIds) {
      if (!_sandboxTaskIds.contains(id)) {
        _sandboxTaskIds.add(id);
        changed = true;
      }
    }
    if (changed) {
      await _save();
    }
  }

  Future<void> removeFromSandbox(String taskId) async {
    if (_sandboxTaskIds.contains(taskId)) {
      _sandboxTaskIds.remove(taskId);
      await _save();
    }
  }

  Future<void> commitTaskToTimeline(String taskId) async {
    _sandboxTaskIds.remove(taskId);
    await _save();
  }
}
