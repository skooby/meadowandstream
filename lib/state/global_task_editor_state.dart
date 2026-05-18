import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_bridge_service.dart';

class TaskEditorRequest {
  final AiTask? existingTask;
  final String? preselectedParentId;
  final bool forceFolderCreation;
  final bool forceNoteCreation;
  final int timestamp; // Ensure we always trigger an update when requesting

  TaskEditorRequest({
    this.existingTask,
    this.preselectedParentId,
    this.forceFolderCreation = false,
    this.forceNoteCreation = false,
  }) : timestamp = DateTime.now().millisecondsSinceEpoch;
}

class GlobalTaskEditorState {
  static final GlobalTaskEditorState instance = GlobalTaskEditorState._internal();
  
  bool hasUnsavedEdits = false;
  
  GlobalTaskEditorState._internal();

  final ValueNotifier<TaskEditorRequest?> activeRequest = ValueNotifier(null);

  void requestEdit({
    AiTask? existingTask,
    String? preselectedParentId,
    bool forceFolderCreation = false,
    bool forceNoteCreation = false,
  }) {
    if (existingTask != null) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('ai_last_edited_task_id', existingTask.id);
      });
    }
    
    activeRequest.value = TaskEditorRequest(
      existingTask: existingTask,
      preselectedParentId: preselectedParentId,
      forceFolderCreation: forceFolderCreation,
      forceNoteCreation: forceNoteCreation,
    );
  }
}
