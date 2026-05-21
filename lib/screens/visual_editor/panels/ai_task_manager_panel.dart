import '../../../state/global_task_editor_state.dart';
import 'package:antigravity_sdk/antigravity_sdk.dart';
import 'global_task_editor_window.dart';
import 'global_icon_picker_window.dart';
import 'package:flutter/material.dart';
import '../../../state/global_picker_state.dart';
import 'package:flutter/scheduler.dart';
import '../visual_editor_screen.dart';
import '../../../app/app.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/auto_backup_service.dart';
import 'package:path/path.dart' as p;
import '../../../services/backup_service.dart';
import 'backup_manager_panel.dart';
import '../../../services/version_control_service.dart';

import '../../../services/ai_bridge_service.dart';
import '../../../services/sandbox_service.dart';
import '../../../widgets/draggable_alert_dialog.dart';
import '../../../services/macro_service.dart';
import '../../../constants.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'global_icon_picker_window.dart';
import 'global_color_picker_window.dart';
import '../../../widgets/resizable_draggable_window.dart';
import 'attachment_viewer_window.dart';

final GlobalKey<AiTaskManagerPanelState> globalTaskManagerKey = GlobalKey<AiTaskManagerPanelState>();

final ValueNotifier<bool> showGlobalTaskPanelNotifier = () {
  final notifier = ValueNotifier<bool>(false);
  SharedPreferences.getInstance().then((prefs) {
    if (prefs.getBool('ve_showGlobalTaskPanel') == true) {
      notifier.value = true;
    }
  });
  return notifier;
}();

void toggleGlobalTaskPanel() async {
  showGlobalTaskPanelNotifier.value = !showGlobalTaskPanelNotifier.value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(
      've_showGlobalTaskPanel', showGlobalTaskPanelNotifier.value);
}

class AiTaskManagerPanel extends StatefulWidget {
  final bool isDocked;
  final void Function(DragUpdateDetails)? onPanUpdate;
  final VoidCallback? onFocus;
  final VoidCallback? onClose;

  const AiTaskManagerPanel({
    super.key,
    this.isDocked = true,
    this.onPanUpdate,
    this.onFocus,
    this.onClose,
  });

  @override
  State<AiTaskManagerPanel> createState() => AiTaskManagerPanelState();
}

class AiTaskManagerPanelState extends State<AiTaskManagerPanel> {
  final AiTask _unassignedWs = AiTask(
    id: 'unassigned_ws',
    name: 'Unassigned',
    isWorksheet: true,
    description: '',
    iconCodePoint: 0xe156, // Icons.inbox
  );

  void _syncUnassignedState() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('ai_tasks_unassigned_name', _unassignedWs.name);
      if (_unassignedWs.iconCodePoint != null) {
        prefs.setInt('ai_tasks_unassigned_icon', _unassignedWs.iconCodePoint!);
      } else {
        prefs.remove('ai_tasks_unassigned_icon');
      }
      if (_unassignedWs.highlightColor != null) {
        prefs.setInt('ai_tasks_unassigned_color', _unassignedWs.highlightColor!);
      } else {
        prefs.remove('ai_tasks_unassigned_color');
      }
      if (_unassignedWs.iconBackgroundColor != null) {
        prefs.setInt('ai_tasks_unassigned_icon_bg_color', _unassignedWs.iconBackgroundColor!);
      } else {
        prefs.remove('ai_tasks_unassigned_icon_bg_color');
      }
      if (_unassignedWs.iconColor != null) {
        prefs.setInt('ai_tasks_unassigned_text_color', _unassignedWs.iconColor!);
      } else {
        prefs.remove('ai_tasks_unassigned_text_color');
      }
      if (_unassignedWs.toolbarIconColor != null) {
        prefs.setInt('ai_tasks_unassigned_toolbar_icon_color', _unassignedWs.toolbarIconColor!);
      } else {
        prefs.remove('ai_tasks_unassigned_toolbar_icon_color');
      }
    });
  }

  Color _getThemeAwareColor(int customColorValue) {
    if (customColorValue == 0xFFFFFFFF) return AppColors.panelTextPrimary;
    if (customColorValue == 0x8AFFFFFF) return AppColors.panelTextSecondary;
    return Color(customColorValue);
  }

  bool _showCompleted = false;
  bool _showAiQueue = true;
  double _activeRatio = 0.6;
  Set<String> _collapsedActiveFolders = {};
  Set<String> _collapsedCompletedFolders = {};

  double _dialogWidth = 600;
  double _dialogHeight = 500;
  double _dialogLeftRatio = 0.5;


  Set<AiTaskStatus> _configExportStatuses = {
    AiTaskStatus.inProgress,
    AiTaskStatus.bug,
    AiTaskStatus.open
  };
  AiTaskStatus _configNewTaskStatus = AiTaskStatus.open;
  int _activePromptMode = 0; // 0: Do Work, 1: Review, 2: Brainstorm
  final GlobalKey<PopupMenuButtonState<int>> _promptMenuKey = GlobalKey();

  final ScrollController _activeScrollController = ScrollController();
  final ScrollController _completedScrollController = ScrollController();
  final ScrollController _queueScrollController = ScrollController();
  final TextEditingController _primaryDirectivesController = TextEditingController();
  final TextEditingController _instController = TextEditingController();
  final TextEditingController _quickInstController = TextEditingController();
  final TextEditingController _previewModeInstController = TextEditingController();
  final TextEditingController _previewApprovedInstController = TextEditingController();
  final TextEditingController _previewRejectedInstController = TextEditingController();
  final TextEditingController _systemHooksInstController = TextEditingController();
  final TextEditingController _missingFilesInstController = TextEditingController();

  bool _blockOnCopy = false;
  bool _blockOnReview = false;
  bool _blockOnBrainstorm = false;
  bool _blockOnQuick = false;
  bool _blockOnQuestion = false;
  bool _blockOnReference = false;

  final TextEditingController _tsController = TextEditingController();
  final TextEditingController _fsController = TextEditingController();
  final TextEditingController _dsController = TextEditingController();
  final TextEditingController _nsController = TextEditingController();
  final TextEditingController _flsController = TextEditingController();
  final TextEditingController _tlsController = TextEditingController();
  final TextEditingController _dlsController = TextEditingController();
  final TextEditingController _nlsController = TextEditingController();
  final TextEditingController _qlsController = TextEditingController();
  final TextEditingController _qsController = TextEditingController();

  bool _showDescription = true;
  bool _showNotes = true;
  bool _showImplementationQuestion = true;
  bool _foldersUppercase = false;
  bool _tasksBold = false;
  bool _foldersBold = false;
  bool _descriptionBold = false;
  bool _notesBold = false;
  bool _questionBold = false;
  int _foldersMaxLines = 0;
  int _tasksMaxLines = 0;
  int _descMaxLines = 2;
  int _notesMaxLines = 0;
  int _questionMaxLines = 2;

  double _fontSizeDescription = 9.5;
  double _fontSizeNotes = 8.5;
  double _fontSizeQuestion = 8.5;
  double _fontSizeTaskName = 11.0;
  double _fontSizeFolderName = 11.0;

  bool _uppercaseDescription = false;
  bool _uppercaseNotes = false;
  bool _uppercaseQuestion = false;
  bool _tasksUppercase = false;

  int _colorTaskName = 0xFFFFFFFF;
  int _colorFolderName = 0xFFFFFFFF;
  int _colorDescription = 0x8AFFFFFF;
  int _colorNotes = 0xB269F0AE;
  int _colorQuestion = 0xB2E040FB;
  double _toolWindowOpacity = 0.4;



  @override
  void initState() {
    super.initState();
    _loadState();
    _primaryDirectivesController.text = AiBridgeService.instance.primaryDirectives;
    _instController.text = AiBridgeService.instance.instructions;
    _quickInstController.text = AiBridgeService.instance.quickInstructions;
    _previewModeInstController.text = AiBridgeService.instance.previewModeInstructions;
    _previewApprovedInstController.text = AiBridgeService.instance.previewApprovedInstructions;
    _previewRejectedInstController.text = AiBridgeService.instance.previewRejectedInstructions;
    _systemHooksInstController.text = AiBridgeService.instance.systemHooksInstructions;
    _missingFilesInstController.text = AiBridgeService.instance.missingFilesInstructions;
    AiBridgeService.instance.addListener(_syncInstructions);
    AiBridgeService.instance.addListener(_syncUnassignedState);
    AiBridgeService.instance.addListener(_checkRestoreActiveTask);
    AiBridgeService.instance.addListener(_handleTaskSandboxTransition);
    GlobalTaskEditorState.instance.activeRequest.addListener(_onActiveTaskChanged);

    _checkRestoreActiveTask();
  }

  bool _hasRestoredActiveTask = false;

  void _checkRestoreActiveTask() {
    if (_hasRestoredActiveTask || AiBridgeService.instance.tasks.isEmpty) return;

    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final lastId = prefs.getString('ai_last_edited_task_id');
      if (lastId != null && GlobalTaskEditorState.instance.activeRequest.value == null) {
        final matches = AiBridgeService.instance.tasks.where((t) => t.id == lastId);
        if (matches.isNotEmpty) {
          GlobalTaskEditorState.instance.requestEdit(existingTask: matches.first);
        }
      }
      _hasRestoredActiveTask = true;
    });
  }

  void _onActiveTaskChanged() {
    if (mounted) setState(() {});
    _handleTaskSandboxTransition();
  }

  String? _lastSandboxTaskId;

  Future<void> _handleTaskSandboxTransition() async {
    final activeReq = GlobalTaskEditorState.instance.activeRequest.value;
    final targetTaskId = activeReq?.existingTask?.id;
    final taskStatus = activeReq?.existingTask?.status;
    final isCompleted = taskStatus == AiTaskStatus.completed || 
                        taskStatus == AiTaskStatus.inTesting || 
                        taskStatus == AiTaskStatus.inReview;
    
    final stateKey = targetTaskId != null ? '${targetTaskId}_$isCompleted' : null;
    
    if (stateKey == _lastSandboxTaskId) return;
    _lastSandboxTaskId = stateKey;

    try {
      // Single Timeline Workflow: No longer creating isolated sandbox branches or stashing.
      // All work happens on the main timeline and gets committed when a task checklist is complete.
      AiBridgeService.instance.notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Sandbox Transition Error: $e');
      }
    }
  }

  void _syncInstructions() {
    if (_primaryDirectivesController.text != AiBridgeService.instance.primaryDirectives) {
      if (!_primaryDirectivesController.value.selection.isValid ||
          _primaryDirectivesController.text.isEmpty) {
        _primaryDirectivesController.text = AiBridgeService.instance.primaryDirectives;
      }
    }
    if (_instController.text != AiBridgeService.instance.instructions) {
      if (!_instController.value.selection.isValid ||
          _instController.text.isEmpty) {
        _instController.text = AiBridgeService.instance.instructions;
      }
    }
    if (_quickInstController.text !=
        AiBridgeService.instance.quickInstructions) {
      if (!_quickInstController.value.selection.isValid ||
          _quickInstController.text.isEmpty) {
        _quickInstController.text = AiBridgeService.instance.quickInstructions;
      }
    }
    if (_previewModeInstController.text !=
        AiBridgeService.instance.previewModeInstructions) {
      if (!_previewModeInstController.value.selection.isValid ||
          _previewModeInstController.text.isEmpty) {
        _previewModeInstController.text = AiBridgeService.instance.previewModeInstructions;
      }
    }
    if (_previewApprovedInstController.text !=
        AiBridgeService.instance.previewApprovedInstructions) {
      if (!_previewApprovedInstController.value.selection.isValid ||
          _previewApprovedInstController.text.isEmpty) {
        _previewApprovedInstController.text = AiBridgeService.instance.previewApprovedInstructions;
      }
    }
    if (_previewRejectedInstController.text !=
        AiBridgeService.instance.previewRejectedInstructions) {
      if (!_previewRejectedInstController.value.selection.isValid ||
          _previewRejectedInstController.text.isEmpty) {
        _previewRejectedInstController.text = AiBridgeService.instance.previewRejectedInstructions;
      }
    }
    if (_systemHooksInstController.text !=
        AiBridgeService.instance.systemHooksInstructions) {
      if (!_systemHooksInstController.value.selection.isValid ||
          _systemHooksInstController.text.isEmpty) {
        _systemHooksInstController.text = AiBridgeService.instance.systemHooksInstructions;
    _missingFilesInstController.text = AiBridgeService.instance.missingFilesInstructions;
      }
    }
  }

  @override
  void dispose() {
    AiBridgeService.instance.removeListener(_checkRestoreActiveTask);
    AiBridgeService.instance.removeListener(_handleTaskSandboxTransition);
    AiBridgeService.instance.removeListener(_syncInstructions);
    AiBridgeService.instance.removeListener(_syncUnassignedState);
    GlobalTaskEditorState.instance.activeRequest.removeListener(_onActiveTaskChanged);
    _primaryDirectivesController.dispose();
    _instController.dispose();
    _quickInstController.dispose();
    _previewModeInstController.dispose();
    _previewApprovedInstController.dispose();
    _previewRejectedInstController.dispose();
    _systemHooksInstController.dispose();
    _tsController.dispose();
    _fsController.dispose();
    _dsController.dispose();
    _nsController.dispose();
    _flsController.dispose();
    _tlsController.dispose();
    _dlsController.dispose();
    _nlsController.dispose();
    _qlsController.dispose();
    _qsController.dispose();
    _activeScrollController.dispose();
    _completedScrollController.dispose();
    _queueScrollController.dispose();
    super.dispose();
  }

  String getLlmPromptStyleOverride(String? pId) {
    if (pId == null) return '';
    try {
      final parent = AiBridgeService.instance.tasks.firstWhere((t) => t.id == pId);
      if (parent.llmPromptStyleOverride != 'Use Default') {
        return parent.llmPromptStyleOverride;
      }
      return getLlmPromptStyleOverride(parent.parentId);
    } catch (_) {
      return '';
    }
  }



  String getAreaPath(String? pId) {
    if (pId == null) return '';
    try {
      final parent = AiBridgeService.instance.tasks.firstWhere((t) => t.id == pId);
      final parentPath = getAreaPath(parent.parentId);
      return parentPath.isNotEmpty ? '$parentPath > ${parent.name}' : parent.name;
    } catch (_) {
      return '';
    }
  }


  

  


  


  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showCompleted = prefs.getBool('ai_tasks_show_completed') ?? false;
        _activeRatio = prefs.getDouble('ai_tasks_active_ratio') ?? 0.6;
        _dialogWidth = prefs.getDouble('ai_tasks_dialog_w') ?? 600;
        _dialogHeight = prefs.getDouble('ai_tasks_dialog_h') ?? 500;
        _dialogLeftRatio = prefs.getDouble('ai_tasks_dialog_r') ?? 0.5;
        _collapsedActiveFolders =
            (prefs.getStringList('ai_tasks_collapsed_active') ?? []).toSet();
        _collapsedCompletedFolders =
            (prefs.getStringList('ai_tasks_collapsed_completed') ?? []).toSet();

        final savedStatuses = prefs.getStringList('ai_tasks_export_statuses');
        if (savedStatuses != null && savedStatuses.isNotEmpty) {
          _configExportStatuses = savedStatuses
              .map((s) => AiTaskStatus.values.firstWhere((e) => e.name == s,
                  orElse: () => AiTaskStatus.inProgress))
              .toSet();
        }
        final savedNewTarget = prefs.getString('ai_tasks_new_status');
        if (savedNewTarget != null) {
          _configNewTaskStatus = AiTaskStatus.values.firstWhere(
              (e) => e.name == savedNewTarget,
              orElse: () => AiTaskStatus.open);
        }
        _activePromptMode = prefs.getInt('ai_tasks_prompt_mode') ?? 0;

        _blockOnCopy = prefs.getBool('ai_tasks_block_copy') ?? false;
        _blockOnReview = prefs.getBool('ai_tasks_block_review') ?? false;
        _blockOnBrainstorm =
            prefs.getBool('ai_tasks_block_brainstorm') ?? false;
        _blockOnQuick = prefs.getBool('ai_tasks_block_quick') ?? false;
        _blockOnQuestion = prefs.getBool('ai_tasks_block_question') ?? false;
        _blockOnReference = prefs.getBool('ai_tasks_block_reference') ?? false;

        _showDescription = prefs.getBool('ai_tasks_show_desc') ?? true;
        _showNotes = prefs.getBool('ai_tasks_show_notes') ?? true;
        _showImplementationQuestion =
            prefs.getBool('ai_tasks_show_question') ?? true;
        _foldersUppercase =
            prefs.getBool('ai_tasks_show_folder_upper') ?? false;
        _tasksBold = prefs.getBool('ai_tasks_show_task_bold') ?? false;
        _foldersBold = prefs.getBool('ai_tasks_show_folder_bold') ?? true;
        _descriptionBold = prefs.getBool('ai_tasks_show_desc_bold') ?? false;
        _notesBold = prefs.getBool('ai_tasks_show_notes_bold') ?? false;
        _questionBold = prefs.getBool('ai_tasks_show_question_bold') ?? false;

        _fontSizeDescription = prefs.getDouble('ai_tasks_font_desc') ?? 11.0;
        _fontSizeNotes = prefs.getDouble('ai_tasks_font_notes') ?? 10.0;
        _fontSizeQuestion = prefs.getDouble('ai_tasks_font_question') ?? 10.0;
        _fontSizeTaskName = prefs.getDouble('ai_tasks_font_task_name') ?? 13.0;
        _fontSizeFolderName =
            prefs.getDouble('ai_tasks_font_folder_name') ?? 13.0;

        _foldersMaxLines = prefs.getInt('ai_tasks_max_lines_folders') ?? 0;
        _tasksMaxLines = prefs.getInt('ai_tasks_max_lines_tasks') ?? 0;
        _descMaxLines = prefs.getInt('ai_tasks_max_lines_desc') ?? 2;
        _notesMaxLines = prefs.getInt('ai_tasks_max_lines_notes') ?? 0;
        _questionMaxLines = prefs.getInt('ai_tasks_max_lines_question') ?? 2;

        _tsController.text = _fontSizeTaskName.toStringAsFixed(1);
        _fsController.text = _fontSizeFolderName.toStringAsFixed(1);
        _dsController.text = _fontSizeDescription.toStringAsFixed(1);
        _nsController.text = _fontSizeNotes.toStringAsFixed(1);
        _qsController.text = _fontSizeQuestion.toStringAsFixed(1);

        _flsController.text = _foldersMaxLines.toString();
        _tlsController.text = _tasksMaxLines.toString();
        _dlsController.text = _descMaxLines.toString();
        _nlsController.text = _notesMaxLines.toString();
        _qlsController.text = _questionMaxLines.toString();

        _uppercaseDescription = prefs.getBool('ai_tasks_upper_desc') ?? false;
        _uppercaseNotes = prefs.getBool('ai_tasks_upper_notes') ?? false;
        _uppercaseQuestion = prefs.getBool('ai_tasks_upper_question') ?? false;
        _tasksUppercase = prefs.getBool('ai_tasks_upper_task') ?? false;

        _toolWindowOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.4;

        _colorTaskName = prefs.getInt('ai_tasks_color_task') ?? 0xFFFFFFFF;
        _colorFolderName = prefs.getInt('ai_tasks_color_folder') ?? 0xFFFFFFFF;
        _colorDescription = prefs.getInt('ai_tasks_color_desc') ?? 0x8AFFFFFF;
        _colorNotes = prefs.getInt('ai_tasks_color_notes') ?? 0xB269F0AE;
        _colorQuestion = prefs.getInt('ai_tasks_color_question') ?? 0xB2E040FB;

        _unassignedWs.name = prefs.getString('ai_tasks_unassigned_name') ?? 'Unassigned';
        _unassignedWs.iconCodePoint = prefs.getInt('ai_tasks_unassigned_icon') ?? 0xe156;
        _unassignedWs.highlightColor = prefs.getInt('ai_tasks_unassigned_color');
        _unassignedWs.iconBackgroundColor = prefs.getInt('ai_tasks_unassigned_icon_bg_color');
        _unassignedWs.iconColor = prefs.getInt('ai_tasks_unassigned_text_color');
        _unassignedWs.toolbarIconColor = prefs.getInt('ai_tasks_unassigned_toolbar_icon_color');
        
        final savedFilter = prefs.getString('ai_tasks_filter_priority');
        if (savedFilter != null && savedFilter != 'all') {
          AiBridgeService.instance.setFilterPriority(AiTaskPriority.values.firstWhere(
              (e) => e.name == savedFilter,
              orElse: () => AiTaskPriority.none));
        } else {
          AiBridgeService.instance.setFilterPriority(AiTaskPriority.none);
        }
      });
    }
  }

  Future<void> _toggleFolder(String id, bool isCompletedSection) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final targetSet = isCompletedSection
          ? _collapsedCompletedFolders
          : _collapsedActiveFolders;
      if (targetSet.contains(id)) {
        targetSet.remove(id);
      } else {
        targetSet.add(id);
      }
    });
    await prefs.setStringList(
        isCompletedSection
            ? 'ai_tasks_collapsed_completed'
            : 'ai_tasks_collapsed_active',
        (isCompletedSection
                ? _collapsedCompletedFolders
                : _collapsedActiveFolders)
            .toList());
  }

  Future<void> _saveRatio(double val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ai_tasks_active_ratio', val);
    if (mounted) {
      setState(() => _activeRatio = val);
    }
  }

  Future<void> _toggleCompleted(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_tasks_show_completed', val);
    setState(() {
      _showCompleted = val;
    });
  }

  Map<AiTaskStatus, int> _getTaskStatusCounts(String folderId) {
    Map<AiTaskStatus, int> counts = {
      AiTaskStatus.open: 0,
      AiTaskStatus.inProgress: 0,
      AiTaskStatus.inReview: 0,
      AiTaskStatus.inTesting: 0,
      AiTaskStatus.bug: 0,
      AiTaskStatus.completed: 0,
    };
    final tasks = AiBridgeService.instance.tasks;
    final children = tasks.where((t) => t.parentId == folderId).toList();
    for (var child in children) {
      if (!child.isFolder) {
        bool hasTasksToPerform = child.verificationCriteria.any((e) => (e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored));
        if (!hasTasksToPerform) continue;

        if (counts.containsKey(child.status)) {
          counts[child.status] = counts[child.status]! + 1;
        } else {
          counts[child.status] = 1;
        }
      } else {
        final childCounts = _getTaskStatusCounts(child.id);
        for (var key in childCounts.keys) {
          counts[key] = (counts[key] ?? 0) + childCounts[key]!;
        }
      }
    }
    return counts;
  }

  Map<AiTaskPriority, int> _getTaskPriorityCounts(String folderId) {
    Map<AiTaskPriority, int> counts = {
      for (var p in AiTaskPriority.values) p: 0
    };
    final tasks = AiBridgeService.instance.tasks;
    final children = tasks.where((t) => t.parentId == folderId).toList();
    for (var child in children) {
      if (!child.isFolder) {
        bool hasTasksToPerform = child.verificationCriteria.any((e) => (e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored));
        if (!hasTasksToPerform) continue;

        if (child.status != AiTaskStatus.completed) {
          if (counts.containsKey(child.priority)) {
            counts[child.priority] = counts[child.priority]! + 1;
          } else {
            counts[child.priority] = 1;
          }
        }
      } else {
        final childCounts = _getTaskPriorityCounts(child.id);
        for (var key in childCounts.keys) {
          counts[key] = (counts[key] ?? 0) + childCounts[key]!;
        }
      }
    }
    return counts;
  }

  int _getUnreadCount(String folderId) {
    int count = 0;
    final tasks = AiBridgeService.instance.tasks;
    final children = tasks.where((t) => t.parentId == folderId).toList();
    for (var child in children) {
      if (!child.isFolder) {
        if (child.status != AiTaskStatus.completed &&
            child.notes.isNotEmpty &&
            !child.isRead) {
          count++;
        }
      } else {
        count += _getUnreadCount(child.id);
      }
    }
    return count;
  }

  int _getOpenChecklistCount(AiTask task) {
    int count = task.verificationCriteria.where((c) => c.status == AiVerificationStatus.none && !c.isPreview).length;
    final tasks = AiBridgeService.instance.tasks;
    final children = tasks.where((t) => t.parentId == task.id).toList();
    for (var child in children) {
      count += _getOpenChecklistCount(child);
    }
    return count;
  }

  int _getReviewChecklistCount(AiTask task) {
    int count = task.verificationCriteria.where((c) => c.status == AiVerificationStatus.pendingReview && !c.isPreview).length;
    final tasks = AiBridgeService.instance.tasks;
    final children = tasks.where((t) => t.parentId == task.id).toList();
    for (var child in children) {
      count += _getReviewChecklistCount(child);
    }
    return count;
  }


  

  void _showReviewDialog(BuildContext context, AiTask task) {
    if (task.proposedChanges == null) return;

    Widget buildPropBlock(String title, String oldText, String newText) {
      if (oldText == newText) return const SizedBox();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  color: AppColors.panelTextPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: AppUIConfig.rootFontSize)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    border: Border.all(color: Colors.red.withOpacity(0.3))),
                child: Text(oldText,
                    style:
                        TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    border: Border.all(color: Colors.green.withOpacity(0.3))),
                child: Text(newText,
                    style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize)),
              )),
            ],
          )
        ]),
      );
    }

    showDialog(
        context: globalAppNavigatorKey.currentContext ?? context,
        barrierColor: Colors.black45,
        builder: (ctx) => DraggableAlertDialog(
                backgroundColor: AppColors.windowBackground.withOpacity(0.85),
                title: Text('Review Proposed Changes', style: TextStyle(color: AppColors.panelTextPrimary)),
                content: SizedBox(
                    width: 800,
                    child: SingleChildScrollView(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        buildPropBlock(
                            'Name', task.name, task.proposedChanges!.name),
                        buildPropBlock('Description', task.description,
                            task.proposedChanges!.description),
                        buildPropBlock(
                            'Notes', task.notes, task.proposedChanges!.notes),
                      ],
                    ))),
                actions: [
                  TextButton(
                    onPressed: () {
                      AiBridgeService.instance.rejectProposedChanges(task.id);
                      Navigator.pop(ctx);
                    },
                    child: Text('Reject', style: TextStyle(color: AppColors.error)),
                  ),
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {
                      AiBridgeService.instance.acceptProposedChanges(task.id);
                      Navigator.pop(ctx);
                    },
                    child: Text('Accept Changes', style: TextStyle(color: AppColors.panelTextPrimary)),
                  )
                ]));
  }

  Widget _buildTaskRootDropZone(bool isHovering) {
    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8, top: 8),
      decoration: BoxDecoration(
        color: isHovering ? AppColors.accent.withOpacity(0.15) : AppColors.panelBackground.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isHovering ? AppColors.accent : AppColors.accent.withOpacity(0.1))
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers, size: 14, color: isHovering ? AppColors.accent : AppColors.textMuted),
            const SizedBox(width: 8),
            Text('Drag here to make Root Level', style: TextStyle(color: isHovering ? AppColors.accent : AppColors.textMuted, fontSize: AppUIConfig.smallFontSize)),
          ]
        )
      )
    );
  }

  Widget _buildTaskItem(AiTask task, int depth,
      {bool isDraggable = true,
      bool isCompletedSection = false,
      bool isEven = false}) {
    final isCompleted = task.status == AiTaskStatus.completed;

    int? getEffectiveFolderColor(AiTask t) {
      if (t.highlightColor != null) return t.highlightColor;
      String? pId = t.parentId;
      Set<String> visited = {t.id};
      AiTask? topParent;
      while (pId != null) {
        if (visited.contains(pId)) break;
        visited.add(pId);
        final pList =
            AiBridgeService.instance.tasks.where((parent) => parent.id == pId);
        if (pList.isEmpty) break;
        final parent = pList.first;
        topParent = parent;
        if (parent.highlightColor != null) return parent.highlightColor;
        pId = parent.parentId;
      }
      if (topParent != null && topParent.isWorksheet) return null;
      return _unassignedWs.highlightColor;
    }

    final int? effectiveColor = getEffectiveFolderColor(task);

    int? getEffectiveIconBackgroundColor(AiTask t) {
      if (t.iconBackgroundColor != null) return t.iconBackgroundColor;
      String? pId = t.parentId;
      Set<String> visited = {t.id};
      AiTask? topParent;
      while (pId != null) {
        if (visited.contains(pId)) break;
        visited.add(pId);
        final pList =
            AiBridgeService.instance.tasks.where((parent) => parent.id == pId);
        if (pList.isEmpty) break;
        final parent = pList.first;
        topParent = parent;
        if (parent.iconBackgroundColor != null) return parent.iconBackgroundColor;
        pId = parent.parentId;
      }
      if (topParent != null && topParent.isWorksheet) return null;
      return _unassignedWs.iconBackgroundColor;
    }

    int? getEffectiveIconColor(AiTask t) {
      if (t.iconColor != null) return t.iconColor;
      String? pId = t.parentId;
      Set<String> visited = {t.id};
      AiTask? topParent;
      while (pId != null) {
        if (visited.contains(pId)) break;
        visited.add(pId);
        final pList =
            AiBridgeService.instance.tasks.where((parent) => parent.id == pId);
        if (pList.isEmpty) break;
        final parent = pList.first;
        topParent = parent;
        if (parent.iconColor != null) return parent.iconColor;
        pId = parent.parentId;
      }
      if (topParent != null && topParent.isWorksheet) return null;
      return _unassignedWs.iconColor;
    }

    final int? effectiveIconBgColor = getEffectiveIconBackgroundColor(task);
    final int? effectiveIconColor = getEffectiveIconColor(task);

    bool isTaskQueued = false;
    final bridge = AiBridgeService.instance;
    if (bridge.activePrompt?.taskIds?.contains(task.id) == true) {
      isTaskQueued = true;
    } else {
      for (var p in bridge.pendingPrompts) {
        if (p.taskIds?.contains(task.id) == true) {
          isTaskQueued = true;
          break;
        }
      }
    }

    bool isTaskOrParentIgnored(AiTask t) {
      if (t.isIgnored) return true;
      String? pId = t.parentId;
      Set<String> visited = {t.id};
      while (pId != null) {
        if (visited.contains(pId)) break;
        visited.add(pId);
        final pList = AiBridgeService.instance.tasks.where((parent) => parent.id == pId);
        if (pList.isEmpty) break;
        final parent = pList.first;
        if (parent.isIgnored) return true;
        pId = parent.parentId;
      }
      return false;
    }

    final bool isIgnored = isTaskOrParentIgnored(task);
    final bool isActive = SandboxService.instance.sandboxTaskIds.contains(task.id);

    Color bgColor = Colors.transparent;
    if (isIgnored) {
      bgColor = Colors.white;
    } else if (isActive) {
      bgColor = AppColors.activeTaskHighlight.withValues(alpha: 0.25);
    } else if (effectiveColor != null) {
      bgColor = _getThemeAwareColor(effectiveColor).withValues(alpha: isEven ? 0.08 : 0.03);
    } else if (isEven) {
      bgColor = AppColors.panelTextPrimary.withValues(alpha: 0.02);
    }

    final bool isActiveEditorTask = GlobalTaskEditorState.instance.activeRequest.value?.existingTask?.id == task.id;

    Widget content = Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: isActiveEditorTask ? Border.all(color: Colors.white, width: 1.0) : null,
      ),
      padding: EdgeInsets.only(
          left: depth * 16.0 + 8.0, top: 1.5, bottom: 1.5, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.isFolder)
            InkWell(
                onTap: () => _toggleFolder(task.id, isCompletedSection),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0, top: 4.0),
                  child: task.iconCodePoint == 0
                      ? const SizedBox.shrink()
                      : task.iconCodePoint != null
                      ? Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                              color: effectiveIconBgColor != null
                                  ? Color(effectiveIconBgColor)
                                  : AppColors.folder,
                              borderRadius: BorderRadius.circular(4)),
                          child: Icon(
                              IconData(task.iconCodePoint!,
                                  fontFamily: 'MaterialIcons'),
                              size: 16,
                              color: isIgnored ? Colors.black : (effectiveIconColor != null ? _getThemeAwareColor(effectiveIconColor) : Colors.white)),
                        )
                      : Icon(
                          (isCompletedSection
                                      ? _collapsedCompletedFolders
                                      : _collapsedActiveFolders)
                                  .contains(task.id)
                              ? Icons.folder
                              : Icons.folder_open,
                          size: 18,
                          color: isIgnored ? Colors.black : (effectiveIconColor != null ? _getThemeAwareColor(effectiveIconColor) : AppColors.folder)),
                ))
          else
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (!task.isKnowledgeSummary)
                SizedBox(
                  height: 20,
                  child: Checkbox(
                    value: isCompleted,
                    activeColor: Colors.green,
                    fillColor: WidgetStateProperty.resolveWith((s) =>
                        s.contains(WidgetState.selected)
                            ? Colors.green
                            : Colors.transparent),
                    side: BorderSide(color: AppColors.panelTextSecondary, width: 1.5),
                    hoverColor: Colors.transparent,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onChanged: (val) {
                      if (val == true) {
                        AiBridgeService.instance
                            .updateTaskStatus(task.id, AiTaskStatus.completed);
                      } else {
                        AiBridgeService.instance
                            .updateTaskStatus(task.id, AiTaskStatus.inTesting);
                      }
                    },
                  ),
                ),
              if (task.isNote)
                Padding(
                    padding: const EdgeInsets.only(right: 8.0, top: 2.0),
                    child: (task.iconCodePoint == null || task.iconCodePoint == 0)
                        ? const SizedBox.shrink()
                        : Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                                color: effectiveIconBgColor != null
                                    ? Color(effectiveIconBgColor)
                                    : AppColors.summary,
                                borderRadius: BorderRadius.circular(4)),
                            child: Icon(IconData(task.iconCodePoint!, fontFamily: 'MaterialIcons'),
                                size: 16, color: isIgnored ? Colors.black : (effectiveIconColor != null ? _getThemeAwareColor(effectiveIconColor) : Colors.white)))
                )
              else if (task.isKnowledgeSummary)
                Padding(
                    padding: const EdgeInsets.only(right: 8.0, top: 2.0),
                    child: (task.iconCodePoint == null || task.iconCodePoint == 0)
                        ? const SizedBox.shrink()
                        : Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                                color: effectiveIconBgColor != null
                                    ? Color(effectiveIconBgColor)
                                    : Colors.deepPurpleAccent,
                                borderRadius: BorderRadius.circular(4)),
                            child:
                                Icon(IconData(task.iconCodePoint!, fontFamily: 'MaterialIcons'),
                                    size: 14, color: isIgnored ? Colors.black : (effectiveIconColor != null ? _getThemeAwareColor(effectiveIconColor) : Colors.white)))
                )
              else
                Padding(
                    padding: const EdgeInsets.only(right: 8.0, top: 2.0),
                    child: (task.iconCodePoint == null || task.iconCodePoint == 0)
                        ? const SizedBox.shrink()
                        : Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(color: effectiveIconBgColor != null ? Color(effectiveIconBgColor) : AppColors.borderSubtle, borderRadius: BorderRadius.circular(4)),
                            child: Icon(IconData(task.iconCodePoint!, fontFamily: 'MaterialIcons'), size: 14, color: isIgnored ? Colors.black : (effectiveIconColor != null ? _getThemeAwareColor(effectiveIconColor) : Colors.white)))
                )
            ]),
          Expanded(
              child: InkWell(
            onTap: task.isFolder
                ? () => _toggleFolder(task.id, isCompletedSection)
                : () { GlobalTaskEditorState.instance.requestEdit(existingTask: task); showTaskEditorWindow(context); },
            onLongPress:
                task.isFolder ? () { GlobalTaskEditorState.instance.requestEdit(existingTask: task); showTaskEditorWindow(context); } : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Expanded(
                    child: Text(
                              task.isFolder
                                  ? (_foldersUppercase
                                      ? task.name.toUpperCase()
                                      : task.name)
                                  : (_tasksUppercase
                                      ? task.name.toUpperCase()
                                      : task.name),
                              maxLines: task.isFolder
                                  ? (_foldersMaxLines > 0
                                      ? _foldersMaxLines
                                      : null)
                                  : (_tasksMaxLines > 0
                                      ? _tasksMaxLines
                                      : null),
                              style: TextStyle(
                                color: isIgnored
                                    ? Colors.black
                                    : isCompleted
                                    ? AppColors.panelTextSecondary
                                    : AppColors.panelTextPrimary,
                                fontSize: task.isFolder
                                    ? _fontSizeFolderName
                                    : _fontSizeTaskName,
                                fontWeight: task.isFolder
                                    ? (_foldersBold
                                        ? FontWeight.bold
                                        : FontWeight.normal)
                                    : (_tasksBold
                                        ? FontWeight.bold
                                        : FontWeight.normal),
                                height: 1.2,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: Colors.white,
                                decorationThickness: 2.0,
                              ),
                            ),

                  ),
                  if (task.fileAttachments.isNotEmpty)
                    ...task.fileAttachments.map((attachPath) {
                      final fileName = p.basename(attachPath);
                      final ext = p.extension(attachPath).toLowerCase();
                      final isImg = ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp', '.ico', '.tiff'].contains(ext);
                      return Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Tooltip(
                            message: fileName,
                            child: InkWell(
                              onTap: () {
                                GlobalPickerState.instance.requestAttachmentViewer(
                                  contextLabel: task.name,
                                  onLink: (linkedPath) {
                                    if (!task.fileAttachments.contains(linkedPath)) {
                                      task.fileAttachments.add(linkedPath);
                                      AiBridgeService.instance.saveTasks();
                                    }
                                  },
                                );
                                showAttachmentViewerWindow(context);
                              },
                              child: isImg
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: Image.file(
                                      File(attachPath),
                                      width: 18,
                                      height: 18,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(Icons.attach_file,
                                          size: 14, color: isIgnored ? Colors.black : AppColors.panelTextPrimary),
                                    ),
                                  )
                                : Icon(Icons.attach_file,
                                    size: 14, color: isIgnored ? Colors.black : AppColors.panelTextPrimary),
                            ),
                          ),
                        );
                    }),
                  if (task.hyperlinks.isNotEmpty)
                    ...task.hyperlinks.map((linkUrl) => Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Tooltip(
                            message: 'Open URL: $linkUrl',
                            child: InkWell(
                              onTap: () {
                                String launchUrl = linkUrl;
                                if (!launchUrl.startsWith('http://') &&
                                    !launchUrl.startsWith('https://')) {
                                  launchUrl = 'https://$launchUrl';
                                }
                                Process.start(
                                    'cmd', ['/c', 'start', '', launchUrl]);
                              },
                              child: Icon(Icons.link,
                                  size: 14, color: isIgnored ? Colors.blue : Colors.lightBlueAccent),
                            ),
                          ),
                        )),
                  if (!isCompletedSection)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, right: 4.0),
                      child: Builder(builder: (ctx) {
                        Map<AiTaskStatus, int> statusCounts =
                            _getTaskStatusCounts(task.id);
                        int openCount = statusCounts[AiTaskStatus.open] ?? 0;
                        int progCount =
                            statusCounts[AiTaskStatus.inProgress] ?? 0;
                        int testCount =
                            statusCounts[AiTaskStatus.inTesting] ?? 0;
                        int bugCount = statusCounts[AiTaskStatus.bug] ?? 0;
                        int unreadCount = _getUnreadCount(task.id);
                        int openChecklistCount = _getOpenChecklistCount(task);
                        int reviewChecklistCount = _getReviewChecklistCount(task);

                        Map<AiTaskPriority, int> prioCounts =
                            _getTaskPriorityCounts(task.id);
                        int countUrg = prioCounts[AiTaskPriority.urgent] ?? 0;
                        int countHi = prioCounts[AiTaskPriority.high] ?? 0;
                        int countMed = prioCounts[AiTaskPriority.medium] ?? 0;
                        int countLow = prioCounts[AiTaskPriority.low] ?? 0;

                        Widget buildNum(int count, Color color, Color bgColor) {
                          if (count == 0) return const SizedBox();
                          return Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: color.withOpacity(0.5))),
                                  child: Text('$count',
                                      style: TextStyle(
                                          color: isIgnored ? Colors.black : color,
                                          fontSize: AppUIConfig.smallFontSize,
                                          fontWeight: FontWeight.bold))));
                        }

                        Widget buildPrio(
                            int count, Color color, Color bgColor) {
                          if (count == 0) return const SizedBox();
                          return Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: color.withOpacity(0.5))),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.flag, size: 9, color: isIgnored ? Colors.black : color),
                                        const SizedBox(width: 2),
                                        Text('$count',
                                            style: TextStyle(
                                                color: isIgnored ? Colors.black : color,
                                                fontSize: AppUIConfig.smallFontSize,
                                                fontWeight: FontWeight.bold))
                                      ])));
                        }



                        return Row(mainAxisSize: MainAxisSize.min, children: [

                          if (task.isFolder)
                            buildNum(openCount, AppColors.panelTextPrimary, Colors.black26),
                          if (task.isFolder)
                            buildNum(progCount, Colors.lightBlueAccent,
                                Colors.blue.withOpacity(0.2)),
                          if (task.isFolder)
                            buildNum(testCount, Colors.orangeAccent,
                                Colors.orange.withOpacity(0.2)),
                          if (task.isFolder)
                            buildNum(bugCount, AppColors.error,
                                Colors.red.withOpacity(0.2)),
                          buildNum(openChecklistCount, Colors.tealAccent, Colors.teal.withOpacity(0.2)),
                          buildNum(reviewChecklistCount, Colors.yellowAccent, Colors.yellow.withOpacity(0.2)),
                          ]);
                      }),
                    ),
                ]),
                if (task.proposedChanges != null) ...[
                  Padding(
                      padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                      child: ElevatedButton.icon(
                        onPressed: () => _showReviewDialog(context, task),
                        icon: Icon(Icons.rate_review,
                            size: 12, color: AppColors.accent),
                        label: Text('Review Changes', style: TextStyle(
                                color: AppColors.accent, fontSize: AppUIConfig.rootFontSize)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 0),
                          minimumSize: const Size(0, 24),
                        ),
                      ))
                ] else if (!task.isFolder ||
                    !(isCompletedSection
                            ? _collapsedCompletedFolders
                            : _collapsedActiveFolders)
                        .contains(task.id)) ...[
                  if (_showDescription && task.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        _uppercaseDescription
                            ? task.description.toUpperCase()
                            : task.description,
                        maxLines: _descMaxLines > 0 ? _descMaxLines : null,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: isIgnored
                                ? Colors.black
                                : isCompleted
                                ? AppColors.borderSubtle
                                : AppColors.panelTextSecondary,
                            fontSize: _fontSizeDescription,
                            fontWeight: _descriptionBold
                                ? FontWeight.bold
                                : FontWeight.normal),
                      ),
                    ),
                  if (_showNotes && task.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        _uppercaseNotes ? task.notes.toUpperCase() : task.notes,
                        maxLines: _notesMaxLines > 0 ? _notesMaxLines : null,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isIgnored
                              ? Colors.black
                              : isCompleted ? AppColors.borderSubtle : AppColors.panelTextSecondary,
                          fontSize: _fontSizeNotes,
                          fontFamily: 'monospace',
                          fontWeight:
                              _notesBold ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  if (_showImplementationQuestion &&
                      task.implementationQuestion.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        _uppercaseQuestion
                            ? task.implementationQuestion.toUpperCase()
                            : task.implementationQuestion,
                        maxLines:
                            _questionMaxLines > 0 ? _questionMaxLines : null,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: isIgnored
                                ? Colors.black
                                : isCompleted
                                ? AppColors.borderSubtle
                                : AppColors.panelTextSecondary,
                            fontSize: _fontSizeQuestion,
                            fontFamily: 'monospace',
                            fontWeight: _questionBold
                                ? FontWeight.bold
                                : FontWeight.normal),
                      ),
                    ),
                ]
              ],
            ),
          )),
          if (!task.isFolder && !isCompletedSection && task.verificationCriteria.any((e) => (e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored))) ...[
            RawGestureDetector(
              gestures: {
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        LongPressGestureRecognizer>(
                  () => LongPressGestureRecognizer(
                      duration: const Duration(milliseconds: 200)),
                  (LongPressGestureRecognizer instance) {
                    instance.onLongPress = () {
                      showDialog(
                          context:
                              globalAppNavigatorKey.currentContext ?? context,
                          barrierColor: Colors.black45,
                          builder: (ctx) => DialogDragWrapper(
                                  child: SimpleDialog(
                                backgroundColor: AppColors.panelBackground.withOpacity(0.87),
                                title: Text('Change Status', style: TextStyle(color: AppColors.panelTextPrimary)),
                                children: AiTaskStatus.values
                                    .where((s) => s != AiTaskStatus.completed)
                                    .map((s) {
                                  return SimpleDialogOption(
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        AiBridgeService.instance
                                            .updateTaskStatus(task.id, s);
                                        Navigator.pop(ctx);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        color: s == AiTaskStatus.inReview
                                            ? Colors.purple.withOpacity(0.2)
                                            : s == AiTaskStatus.inTesting
                                                ? Colors.orange.withOpacity(0.2)
                                                : s == AiTaskStatus.inProgress
                                                    ? Colors.blue
                                                        .withOpacity(0.2)
                                                    : s == AiTaskStatus.bug
                                                        ? Colors.red
                                                            .withOpacity(0.2)
                                                        : AppColors.overlaySubtle,
                                        child: Text(
                                              _formatStatusName(s),
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: s ==
                                                        AiTaskStatus.inReview
                                                    ? Colors.purpleAccent
                                                    : s ==
                                                            AiTaskStatus
                                                                .inTesting
                                                        ? Colors.orangeAccent
                                                        : s ==
                                                                AiTaskStatus
                                                                    .inProgress
                                                            ? Colors
                                                                .lightBlueAccent
                                                            : s ==
                                                                    AiTaskStatus
                                                                        .bug
                                                                ? Colors
                                                                    .redAccent
                                                                : AppColors.panelTextPrimary)),
                                      ));
                                }).toList(),
                              )));
                    };
                  },
                ),
                TapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                  (TapGestureRecognizer instance) {
                    instance.onTap = () {
                      AiTaskStatus nextStatus;
                      switch (task.status) {
                        case AiTaskStatus.open:
                          nextStatus = task.verificationCriteria.isEmpty ? AiTaskStatus.inReview : AiTaskStatus.inProgress;
                          break;
                        case AiTaskStatus.inProgress:
                          nextStatus = AiTaskStatus.inReview;
                          break;
                        case AiTaskStatus.inReview:
                          nextStatus = AiTaskStatus.inTesting;
                          break;
                        case AiTaskStatus.inTesting:
                        case AiTaskStatus.bug:
                        default:
                          nextStatus = AiTaskStatus.open;
                      }
                      AiBridgeService.instance
                          .updateTaskStatus(task.id, nextStatus);
                    };
                    instance.onSecondaryTap = () {
                      AiTaskStatus prevStatus;
                      switch (task.status) {
                        case AiTaskStatus.open:
                          prevStatus = AiTaskStatus.inTesting;
                          break;
                        case AiTaskStatus.inTesting:
                          prevStatus = AiTaskStatus.inReview;
                          break;
                        case AiTaskStatus.inReview:
                          prevStatus = task.verificationCriteria.isEmpty ? AiTaskStatus.open : AiTaskStatus.inProgress;
                          break;
                        case AiTaskStatus.inProgress:
                          prevStatus = AiTaskStatus.open;
                          break;
                        case AiTaskStatus.bug:
                        default:
                          prevStatus = AiTaskStatus.open;
                      }
                      AiBridgeService.instance
                          .updateTaskStatus(task.id, prevStatus);
                    };
                  },
                ),
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (AiBridgeService.instance.activeTaskIds.contains(task.id))
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: _FlashingIcon(icon: Icons.autorenew, color: Colors.cyanAccent, size: 16),
                    ),
                  Container(
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isIgnored ? Colors.white : (isTaskQueued
                      ? Colors.cyan.withOpacity(0.2)
                      : task.status == AiTaskStatus.inReview
                      ? Colors.purple.withOpacity(0.2)
                      : task.status == AiTaskStatus.inTesting
                          ? Colors.orange.withOpacity(0.2)
                          : task.status == AiTaskStatus.inProgress
                              ? Colors.blue.withOpacity(0.2)
                              : task.status == AiTaskStatus.bug
                                  ? Colors.red.withOpacity(0.2)
                                  : AppColors.overlaySubtle),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: isIgnored ? Colors.black : (isTaskQueued
                          ? Colors.cyanAccent.withOpacity(0.5)
                          : task.status == AiTaskStatus.inReview
                          ? Colors.purpleAccent.withOpacity(0.5)
                          : task.status == AiTaskStatus.inTesting
                              ? Colors.orangeAccent.withOpacity(0.5)
                              : task.status == AiTaskStatus.inProgress
                                  ? Colors.lightBlueAccent.withOpacity(0.5)
                                  : task.status == AiTaskStatus.bug
                                      ? AppColors.error.withOpacity(0.5)
                                      : AppColors.overlaySubtle)),
                ),
                alignment: Alignment.center,
                child: Text(
                  isTaskQueued
                      ? 'QUEUED'
                      : task.status == AiTaskStatus.inReview
                      ? 'IN REVIEW'
                      : task.status == AiTaskStatus.inTesting
                          ? 'IN TESTING'
                          : task.status == AiTaskStatus.inProgress
                              ? 'IN PROGRESS'
                              : task.status == AiTaskStatus.bug
                                  ? 'BUG'
                                  : 'OPEN',
                  style: TextStyle(
                      fontSize: AppUIConfig.smallFontSize,
                      fontWeight: FontWeight.bold,
                      color: isIgnored ? Colors.black : (isTaskQueued
                          ? Colors.cyanAccent
                          : task.status == AiTaskStatus.inReview
                          ? Colors.purpleAccent
                          : task.status == AiTaskStatus.inTesting
                              ? Colors.orangeAccent
                              : task.status == AiTaskStatus.inProgress
                                  ? Colors.lightBlueAccent
                                  : task.status == AiTaskStatus.bug
                                      ? AppColors.error
                                      : AppColors.panelTextPrimary)),
                ),
              ),
              ],
            ),
            ),
            const SizedBox(width: 8),
          ],
          if (task.isFolder && !isCompletedSection) ...[
            const SizedBox(width: 12),
            InkWell(
              onTap: () { GlobalTaskEditorState.instance.requestEdit(preselectedParentId: task.id, forceFolderCreation: true); showTaskEditorWindow(context); },
              child: Tooltip(message: 'Add Child Folder', child: Icon(Icons.create_new_folder, size: 18, color: AppColors.folder)),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () { GlobalTaskEditorState.instance.requestEdit(preselectedParentId: task.id); showTaskEditorWindow(context); },
              child: Tooltip(message: 'Add Child Task', child: Icon(Icons.add, size: 20, color: AppColors.accent)),
            ),
          ],
          if (!task.isFolder && !task.isNote && !isCompletedSection) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _executeSingleTaskPrompt(task, 0),
              child: Tooltip(
                message: 'Quick Action',
                child: Icon(Icons.bolt, size: 16, color: AppColors.folder),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _executeSingleTaskPrompt(task, 0, false, true),
              child: Tooltip(
                message: 'Copy AI Prompt to Clipboard',
                child: Icon(Icons.copy, size: 14, color: AppColors.panelTextSecondary),
              ),
            ),
          ],

          const SizedBox(width: 8),
          InkWell(
            onTap: () { GlobalTaskEditorState.instance.requestEdit(existingTask: task); showTaskEditorWindow(context); },
            child: task.notes.isNotEmpty &&
                    !task.isRead &&
                    task.status != AiTaskStatus.completed
                ? Badge(
                    smallSize: 8,
                    backgroundColor: AppColors.error,
                    child:
                        Icon(Icons.edit, size: 14, color: AppColors.folder),
                  )
                : Icon(Icons.edit, size: 14, color: AppColors.panelTextSecondary),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: AiBridgeService.instance.isTaskDeletionPrevented(task.id)
                ? null
                : () => AiBridgeService.instance.deleteTask(task.id),
            child: Icon(Icons.delete,
                size: 14,
                color: AiBridgeService.instance.isTaskDeletionPrevented(task.id)
                    ? AppColors.error
                    : AppColors.panelTextSecondary),
          ),
        ],
      ),
    );

    if (!isDraggable) return content;

    Widget finalContent = task.isFolder
        ? DragTarget<String>(
            onWillAcceptWithDetails: (d) => d.data != task.id,
            onAcceptWithDetails: (d) =>
                AiBridgeService.instance.moveTask(d.data, task.id),
            builder: (ctx, cand, _) => Container(
              decoration: BoxDecoration(
                border: cand.isNotEmpty
                    ? Border.all(color: AppColors.folder, width: 2.0)
                    : null,
                color: cand.isNotEmpty
                    ? Colors.amber.withOpacity(0.2)
                    : Colors.transparent,
              ),
              child: content,
            ),
          )
        : content;

    return LongPressDraggable<String>(
      delay: const Duration(milliseconds: 250),
      data: task.id,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 400,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.panelBackground.withOpacity(0.95),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.accent.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(2, 4))
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (task.iconCodePoint == 0)
                const SizedBox.shrink()
              else if (task.iconCodePoint != null)
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                      color: task.iconBackgroundColor != null
                          ? _getThemeAwareColor(task.iconBackgroundColor!)
                          : AppColors.folder,
                      borderRadius: BorderRadius.circular(4)),
                  child: Icon(
                      IconData(task.iconCodePoint!,
                          fontFamily: 'MaterialIcons'),
                      size: 12,
                      color: effectiveIconColor != null ? _getThemeAwareColor(effectiveIconColor) : AppColors.panelTextPrimary),
                )
              else if (task.isFolder)
                Icon(Icons.folder,
                    size: 16,
                    color: effectiveIconColor != null ? _getThemeAwareColor(effectiveIconColor) : AppColors.folder),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppColors.panelTextPrimary,
                      fontSize: AppUIConfig.rootFontSize,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none),
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: finalContent),
      child: Stack(children: [
        DragTarget<String>(
          onWillAcceptWithDetails: (d) => d.data == task.id,
          onAcceptWithDetails: (d) {
            /* Intentionally swallow drop to prevent falling through to background */
          },
          builder: (ctx, cand, _) => finalContent,
        ),
        Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 8,
            child: DragTarget<String>(
                onWillAcceptWithDetails: (d) => d.data != task.id,
                onAcceptWithDetails: (d) =>
                    AiBridgeService.instance.reorderBefore(d.data, task.id),
                builder: (ctx, cand, _) => Container(
                    color: cand.isNotEmpty
                        ? AppColors.accent.withOpacity(0.8)
                        : Colors.transparent))),
        Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 8,
            child: DragTarget<String>(
                onWillAcceptWithDetails: (d) => d.data != task.id,
                onAcceptWithDetails: (d) =>
                    AiBridgeService.instance.reorderAfter(d.data, task.id),
                builder: (ctx, cand, _) => Container(
                    color: cand.isNotEmpty
                        ? AppColors.accent.withOpacity(0.8)
                        : Colors.transparent))),
      ]),
    );
  }

  String _formatStatusName(AiTaskStatus status) {
    switch (status) {
      case AiTaskStatus.inProgress:
        return 'IN PROGRESS';
      case AiTaskStatus.inReview:
        return 'IN REVIEW';
      case AiTaskStatus.inTesting:
        return 'IN TESTING';
      case AiTaskStatus.completed:
        return 'COMPLETED';
      case AiTaskStatus.bug:
        return 'BUG';
      case AiTaskStatus.open:
        return 'OPEN';
    }
  }

  
  Color _getStatusColor(AiTaskStatus? status) {
    return _getThemeAwareColor(_getRawStatusColor(status).value);
  }

    Color _getRawStatusColor(AiTaskStatus? status) {
    if (status == null) return AppColors.panelTextSecondary;
    switch (status) {
      case AiTaskStatus.inReview:
        return Colors.purpleAccent;
      case AiTaskStatus.inTesting:
        return Colors.orangeAccent;
      case AiTaskStatus.inProgress:
        return Colors.lightBlueAccent;
      case AiTaskStatus.bug:
        return AppColors.error;
      case AiTaskStatus.completed:
        return Colors.green;
      case AiTaskStatus.open:
      default:
        return AppColors.panelTextSecondary;
    }
  }

  Future<void> _showConfigDialog(BuildContext context) async {
    Set<AiTaskStatus> selectedStatuses = Set.from(_configExportStatuses);
    AiTaskStatus newTargetStatus = _configNewTaskStatus;

    final prefs = await SharedPreferences.getInstance();
    final afterEditStr =
        prefs.getString('ai_tasks_bridge_edit_status') ?? 'inTesting';
    final afterCompleteStr =
        prefs.getString('ai_tasks_bridge_complete_status') ?? 'inTesting';
    final voiceStr = prefs.getString('ai_tasks_bridge_voice') ?? 'Default';
    String selectedVoice = voiceStr;
    final complexityStr =
        prefs.getString('ai_tasks_bridge_complexity') ?? 'Default';
    String selectedComplexity = complexityStr;
    final delayVal = prefs.get('ai_tasks_delay_seconds');
    double delaySeconds = 5.0;
    if (delayVal != null && delayVal is num) {
      delaySeconds = delayVal.toDouble().clamp(0.0, 5.0);
    }

    AiTaskStatus? afterEditStatus = afterEditStr == 'dontChange'
        ? null
        : AiTaskStatus.values.firstWhere((e) => e.name == afterEditStr,
            orElse: () => AiTaskStatus.inTesting);
    AiTaskStatus? afterCompleteStatus = afterCompleteStr == 'dontChange'
        ? null
        : AiTaskStatus.values.firstWhere((e) => e.name == afterCompleteStr,
            orElse: () => AiTaskStatus.inTesting);

    if (!context.mounted) return;
    showDialog(
        context: globalAppNavigatorKey.currentContext ?? context,
        barrierColor: Colors.black45,
        builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
              Future<void> saveSettings() async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setStringList('ai_tasks_export_statuses',
                    selectedStatuses.map((e) => e.name).toList());
                await prefs.setString(
                    'ai_tasks_new_status', newTargetStatus.name);
                await prefs.setString('ai_tasks_bridge_edit_status',
                    afterEditStatus?.name ?? 'dontChange');
                await prefs.setString('ai_tasks_bridge_complete_status',
                    afterCompleteStatus?.name ?? 'dontChange');
                await prefs.setString('ai_tasks_bridge_voice', selectedVoice);
                await prefs.setString(
                    'ai_tasks_bridge_complexity', selectedComplexity);
                await prefs.setDouble('ai_tasks_delay_seconds', delaySeconds);
                await prefs.setBool('ai_tasks_block_copy', _blockOnCopy);
                await prefs.setBool('ai_tasks_block_review', _blockOnReview);
                await prefs.setBool(
                    'ai_tasks_block_brainstorm', _blockOnBrainstorm);
                await prefs.setBool('ai_tasks_block_quick', _blockOnQuick);
                await prefs.setBool(
                    'ai_tasks_block_question', _blockOnQuestion);
                await prefs.setBool(
                    'ai_tasks_block_reference', _blockOnReference);

                await prefs.setBool('ai_tasks_show_desc', _showDescription);
                await prefs.setBool('ai_tasks_show_notes', _showNotes);
                await prefs.setBool(
                    'ai_tasks_show_question', _showImplementationQuestion);
                await prefs.setBool(
                    'ai_tasks_show_folder_upper', _foldersUppercase);
                await prefs.setBool('ai_tasks_show_task_bold', _tasksBold);
                await prefs.setBool('ai_tasks_show_folder_bold', _foldersBold);
                await prefs.setBool(
                    'ai_tasks_show_desc_bold', _descriptionBold);
                await prefs.setBool('ai_tasks_show_notes_bold', _notesBold);
                await prefs.setBool(
                    'ai_tasks_show_question_bold', _questionBold);

                await prefs.setDouble(
                    'ai_tasks_font_desc', _fontSizeDescription);
                await prefs.setDouble('ai_tasks_font_notes', _fontSizeNotes);
                await prefs.setInt(
                    'ai_tasks_max_lines_folders', _foldersMaxLines);
                await prefs.setInt('ai_tasks_max_lines_tasks', _tasksMaxLines);
                await prefs.setInt('ai_tasks_max_lines_desc', _descMaxLines);
                await prefs.setInt('ai_tasks_max_lines_notes', _notesMaxLines);
                await prefs.setInt(
                    'ai_tasks_max_lines_question', _questionMaxLines);
                await prefs.setDouble(
                    'ai_tasks_font_question', _fontSizeQuestion);
                await prefs.setDouble(
                    'ai_tasks_font_task_name', _fontSizeTaskName);
                await prefs.setDouble(
                    'ai_tasks_font_folder_name', _fontSizeFolderName);

                await prefs.setBool(
                    'ai_tasks_upper_desc', _uppercaseDescription);
                await prefs.setBool('ai_tasks_upper_notes', _uppercaseNotes);
                await prefs.setBool(
                    'ai_tasks_upper_question', _uppercaseQuestion);
                await prefs.setBool('ai_tasks_upper_task', _tasksUppercase);

                await prefs.setInt('ai_tasks_color_task', _colorTaskName);
                await prefs.setInt('ai_tasks_color_folder', _colorFolderName);
                await prefs.setInt('ai_tasks_color_desc', _colorDescription);
                await prefs.setInt('ai_tasks_color_notes', _colorNotes);
                await prefs.setInt('ai_tasks_color_question', _colorQuestion);

                await AiBridgeService.instance.syncPreferences();
                if (mounted) {
                  setState(() {
                    _configExportStatuses = selectedStatuses;
                    _configNewTaskStatus = newTargetStatus;
                  });
                }
              }

               TableRow buildConfigHeader() {
                Widget th(String text) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(text.toUpperCase(),
                          style: TextStyle(
                              color: AppColors.accent,
                              fontSize: AppUIConfig.rootFontSize,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    );
                return TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('TYPE:',
                        style: TextStyle(
                            color: AppColors.accent,
                            fontSize: AppUIConfig.rootFontSize,
                            fontWeight: FontWeight.bold)),
                  ),
                  th('Show'),
                  th('Uppercase'),
                  th('Bold'),
                  th('Size'),
                  th('Color'),
                  th('Lines'),
                ]);
              }

              TableRow buildConfigTableRow(
                StateSetter ss,
                VoidCallback save,
                String title,
                bool? showVal,
                Function(bool)? onShow,
                bool? upperVal,
                Function(bool)? onUpper,
                bool? boldVal,
                Function(bool)? onBold,
                TextEditingController sizeCtrl,
                Function(double)? onSize,
                int colorVal,
                Function(int)? onColor,
                TextEditingController? linesCtrl,
                Function(int)? onLines,
              ) {
                Widget buildCb(bool? val, Function(bool)? onChanged) {
                  if (val == null || onChanged == null) return const SizedBox();
                  return Align(
                      alignment: Alignment.center,
                      child: Checkbox(
                          value: val,
                          visualDensity: VisualDensity.compact,
                          activeColor: AppColors.accent,
                          onChanged: (v) {
                            if (v != null) {
                              ss(() => onChanged(v));
                              save();
                            }
                          }));
                }

                final formattedTitle = title.toUpperCase().trim().endsWith(':')
                    ? title.toUpperCase().trim()
                    : '${title.toUpperCase().trim()}:';

                return TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(formattedTitle,
                        style: TextStyle(
                            color: AppColors.accent,
                            fontSize: AppUIConfig.rootFontSize,
                            fontWeight: FontWeight.bold)),
                  ),
                  buildCb(showVal, onShow),
                  buildCb(upperVal, onUpper),
                  buildCb(boldVal, onBold),
                  Padding(
                      padding:
                          const EdgeInsets.only(top: 6, bottom: 6, right: 16),
                      child: Row(children: [
                        MouseRegion(
                            cursor: SystemMouseCursors.resizeLeftRight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanUpdate: (details) {
                                if (onSize == null) return;
                                final dx = details.delta.dx;
                                SchedulerBinding.instance
                                    .addPostFrameCallback((_) {
                                  double newValue =
                                      (double.tryParse(sizeCtrl.text) ?? 12.0) +
                                          (dx * 0.1);
                                  if (newValue < 2.0) newValue = 2.0;
                                  if (newValue > 100.0) newValue = 100.0;
                                  sizeCtrl.text = newValue.toStringAsFixed(1);
                                  ss(() => onSize(newValue));
                                  save();
                                });
                              },
                              child: Icon(Icons.compare_arrows,
                                  size: 14, color: AppColors.panelTextSecondary),
                            )),
                        const SizedBox(width: 4),
                        Expanded(
                            child: SizedBox(
                                height: 24,
                                child: TextFormField(
                                  controller: sizeCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  style: TextStyle(
                                      color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                      contentPadding: EdgeInsets.zero,
                                      filled: true,
                                      fillColor: AppColors.overlaySubtle,
                                      border: OutlineInputBorder(
                                          borderSide: BorderSide.none)),
                                  onChanged: (val) {
                                    final parsed = double.tryParse(val);
                                    if (parsed != null && onSize != null) {
                                      ss(() => onSize(parsed));
                                      save();
                                    }
                                  },
                                )))
                      ])),
                  Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 6),
                      child: SizedBox(
                          height: 24,
                          child: InkWell(
                                onTap: () {
                                  GlobalPickerState.instance.requestColor(
                                    initialColor: colorVal != null ? Color(colorVal) : Colors.white,
                                    onColorSelected: (c) {
                                      if (onColor != null && c != null) {
                                        ss(() => onColor(c.value));
                                        save();
                                      }
                                    },
                                  );
                                  showColorPickerWindow(context);
                                },
                                child: Container(
                                  width: 24,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Color(colorVal),
                                    border: Border.all(color: AppColors.borderSubtle, width: 1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.palette,
                                      size: 12,
                                      color: Color(colorVal).computeLuminance() > 0.5 ? Colors.black87 : Colors.white70,
                                    ),
                                  ),
                                )
                              ))),
                  if (linesCtrl != null && onLines != null)
                    Padding(
                        padding:
                            const EdgeInsets.only(top: 6, bottom: 6, left: 12),
                        child: SizedBox(
                            height: 24,
                            child: TextFormField(
                              controller: linesCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                  color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                  contentPadding: EdgeInsets.zero,
                                  filled: true,
                                  fillColor: AppColors.overlaySubtle,
                                  border: OutlineInputBorder(
                                      borderSide: BorderSide.none)),
                              onChanged: (val) {
                                final parsed = int.tryParse(val);
                                if (parsed != null) {
                                  ss(() => onLines(parsed));
                                  save();
                                }
                              },
                            ))),
                  if (linesCtrl == null) const SizedBox(),
                ]);
              }

              Widget buildDropdownSettingRow({
                required String labelText,
                required Widget dropdown,
              }) {
                final formattedLabel = labelText.toUpperCase().trim().endsWith(':')
                    ? labelText.toUpperCase().trim()
                    : '${labelText.toUpperCase().trim()}:';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedLabel,
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: AppUIConfig.rootFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.overlaySubtle,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.borderSubtle, width: 1),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: dropdown,
                        ),
                      ),
                    ],
                  ),
                );
              }

              Widget buildSliderSettingRow({
                required String labelText,
                required Widget slider,
                required Widget valueText,
              }) {
                final formattedLabel = labelText.toUpperCase().trim().endsWith(':')
                    ? labelText.toUpperCase().trim()
                    : '${labelText.toUpperCase().trim()}:';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedLabel,
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: AppUIConfig.rootFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.overlaySubtle,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.borderSubtle, width: 1),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: slider),
                            const SizedBox(width: 8),
                            valueText,
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              Widget buildChipsSettingRow({
                required String labelText,
                required Widget chips,
              }) {
                final formattedLabel = labelText.toUpperCase().trim().endsWith(':')
                    ? labelText.toUpperCase().trim()
                    : '${labelText.toUpperCase().trim()}:';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedLabel,
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: AppUIConfig.rootFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.overlaySubtle,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.borderSubtle, width: 1),
                        ),
                        child: chips,
                      ),
                    ],
                  ),
                );
              }

              return Theme(
                data: Theme.of(context).copyWith(
                  textSelectionTheme: TextSelectionThemeData(
                    cursorColor: AppColors.folder,
                    selectionColor: AppColors.accent.withOpacity(0.4),
                    selectionHandleColor: AppColors.accent,
                  ),
                ),
                child: DefaultTabController(
                  length: 3,
                  child: DraggableAlertDialog(
                    backgroundColor: AppColors.windowBackground.withOpacity(prefs.getDouble('ve_toolWindowOpacity') ?? 0.8),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Prompt Helper Settings',
                            style: TextStyle(color: AppColors.panelTextPrimary)),
                        SizedBox(height: 12),
                        TabBar(
                          tabs: [
                            Tab(text: 'Workflow'),
                            Tab(text: 'Prompts & Rules'),
                            Tab(text: 'UI Options'),
                          ],
                          indicatorColor: AppColors.accent,
                          labelColor: AppColors.accent,
                          unselectedLabelColor: AppColors.panelTextSecondary,
                        ),
                      ],
                    ),
                    content: SizedBox(
                        width: 800,
                        height: 600,
                        child: TabBarView(
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              // TAB 1: WORKFLOW
                              SingleChildScrollView(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        buildChipsSettingRow(
                                          labelText: 'Statuses To Process',
                                          chips: Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: AiTaskStatus.values.map((s) {
                                              final isSelected = selectedStatuses.contains(s);
                                              return FilterChip(
                                                label: Text(
                                                    _formatStatusName(s).toUpperCase(),
                                                    style: TextStyle(
                                                        fontSize: AppUIConfig.smallFontSize,
                                                        color: isSelected
                                                            ? Colors.white
                                                            : AppColors.panelTextSecondary,
                                                        fontWeight: isSelected
                                                            ? FontWeight.bold
                                                            : FontWeight.normal)),
                                                selected: isSelected,
                                                showCheckmark: false,
                                                onSelected: (val) {
                                                  setStateBuilder(() {
                                                    if (val) {
                                                      selectedStatuses.add(s);
                                                    } else {
                                                      selectedStatuses.remove(s);
                                                    }
                                                  });
                                                  saveSettings();
                                                },
                                                backgroundColor: AppColors.panelBackground,
                                                selectedColor: AppColors.accent,
                                                side: BorderSide(
                                                    color: AppColors.borderSubtle),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: buildDropdownSettingRow(
                                                labelText: 'Default Status For New Tasks',
                                                dropdown: DropdownButton<AiTaskStatus>(
                                                  value: newTargetStatus,
                                                  isExpanded: true,
                                                  dropdownColor: AppColors.panelBackground,
                                                  style: TextStyle(color: AppColors.panelTextPrimary),
                                                  items: AiTaskStatus.values
                                                      .map((s) => DropdownMenuItem(
                                                          value: s,
                                                          child: Text(_formatStatusName(s).toUpperCase())))
                                                      .toList(),
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      setStateBuilder(() => newTargetStatus = val);
                                                      saveSettings();
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: buildDropdownSettingRow(
                                                labelText: 'Change Status After Bridge Edit',
                                                dropdown: DropdownButton<AiTaskStatus?>(
                                                  value: afterEditStatus,
                                                  isExpanded: true,
                                                  dropdownColor: AppColors.panelBackground,
                                                  style: TextStyle(color: AppColors.panelTextPrimary),
                                                  items: [
                                                    const DropdownMenuItem(
                                                        value: null,
                                                        child: Text('DON\'T CHANGE')),
                                                    ...AiTaskStatus.values.map((s) => DropdownMenuItem(
                                                        value: s,
                                                        child: Text(_formatStatusName(s).toUpperCase())))
                                                  ],
                                                  onChanged: (val) {
                                                    setStateBuilder(() => afterEditStatus = val);
                                                    saveSettings();
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: buildDropdownSettingRow(
                                                labelText: 'Change Status After Bridge Completed',
                                                dropdown: DropdownButton<AiTaskStatus?>(
                                                  value: afterCompleteStatus,
                                                  isExpanded: true,
                                                  dropdownColor: AppColors.panelBackground,
                                                  style: TextStyle(color: AppColors.panelTextPrimary),
                                                  items: [
                                                    const DropdownMenuItem(
                                                        value: null,
                                                        child: Text('DON\'T CHANGE')),
                                                    ...AiTaskStatus.values.map((s) => DropdownMenuItem(
                                                        value: s,
                                                        child: Text(_formatStatusName(s).toUpperCase())))
                                                  ],
                                                  onChanged: (val) {
                                                    setStateBuilder(() => afterCompleteStatus = val);
                                                    saveSettings();
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: buildDropdownSettingRow(
                                                labelText: 'LLM Voice Profile',
                                                dropdown: DropdownButton<String>(
                                                  value: selectedVoice,
                                                  isExpanded: true,
                                                  dropdownColor: AppColors.panelBackground,
                                                  style: TextStyle(color: AppColors.panelTextPrimary),
                                                  items: [
                                                    'Default',
                                                    'Conversational',
                                                    'Technical / Code Heavy',
                                                    'Direct / Robotic'
                                                  ]
                                                      .map((s) => DropdownMenuItem(
                                                          value: s,
                                                          child: Text(s.toUpperCase())))
                                                      .toList(),
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      setStateBuilder(() => selectedVoice = val);
                                                      saveSettings();
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: buildDropdownSettingRow(
                                                labelText: 'LLM Conceptual Complexity',
                                                dropdown: DropdownButton<String>(
                                                  value: selectedComplexity,
                                                  isExpanded: true,
                                                  dropdownColor: AppColors.panelBackground,
                                                  style: TextStyle(color: AppColors.panelTextPrimary),
                                                  items: [
                                                    'Default',
                                                    'Concise',
                                                    'Verbose',
                                                    'Step-by-Step'
                                                  ]
                                                      .map((s) => DropdownMenuItem(
                                                          value: s,
                                                          child: Text(s.toUpperCase())))
                                                      .toList(),
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      setStateBuilder(() => selectedComplexity = val);
                                                      saveSettings();
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: buildSliderSettingRow(
                                                labelText: 'AI Bridge Dispatch Delay (Seconds)',
                                                slider: Slider(
                                                  value: delaySeconds,
                                                  min: 0,
                                                  max: 5,
                                                  divisions: 10,
                                                  label: '${delaySeconds.toStringAsFixed(1)} s',
                                                  activeColor: AppColors.accent,
                                                  inactiveColor: AppColors.overlaySubtle,
                                                  onChanged: (val) {
                                                    setStateBuilder(() {
                                                      delaySeconds = val;
                                                    });
                                                  },
                                                  onChangeEnd: (val) {
                                                    saveSettings();
                                                  },
                                                ),
                                                valueText: Text(
                                                  '${delaySeconds.toStringAsFixed(1)} s',
                                                  style: TextStyle(
                                                    color: AppColors.panelTextPrimary,
                                                    fontSize: AppUIConfig.rootFontSize,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ])),
                              // TAB 2: PROMPTS & RULES
                              SingleChildScrollView(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Builder(builder: (ctx) {
                                          Widget buildRule(
                                              String title,
                                              TextEditingController controller,
                                              String hintText,
                                              Function(String) onChanged,
                                              Color activeColor) {
                                            final formattedTitle = title.toUpperCase().trim().endsWith(':')
                                                ? title.toUpperCase().trim()
                                                : '${title.toUpperCase().trim()}:';
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8.0),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: AppColors.overlaySubtle,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: AppColors.borderSubtle, width: 1),
                                                ),
                                                child: Theme(
                                                  data: Theme.of(ctx).copyWith(
                                                      dividerColor:
                                                          Colors.transparent),
                                                  child: ExpansionTile(
                                                    title: Text(formattedTitle,
                                                        style: TextStyle(
                                                            color: AppColors.accent,
                                                            fontSize: AppUIConfig.rootFontSize,
                                                            fontWeight:
                                                                FontWeight.bold)),
                                                    iconColor: AppColors.accent,
                                                    collapsedIconColor:
                                                        AppColors.accent,
                                                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                                                    childrenPadding:
                                                        const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 12.0),
                                                    children: [
                                                      TextField(
                                                        controller: controller,
                                                        style: TextStyle(
                                                            color: AppColors.panelTextPrimary,
                                                            fontSize: AppUIConfig.rootFontSize,
                                                            fontFamily:
                                                                'monospace'),
                                                        maxLines: null,
                                                        minLines: 2,
                                                        keyboardType:
                                                            TextInputType
                                                                .multiline,
                                                        decoration:
                                                            InputDecoration(
                                                          hintText: hintText,
                                                          hintStyle:
                                                              TextStyle(
                                                                  color: AppColors.panelTextSecondary.withOpacity(0.5)),
                                                          filled: true,
                                                          fillColor:
                                                              AppColors.panelBackground,
                                                          border: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                              borderSide:
                                                                  BorderSide(
                                                                      color: AppColors.borderSubtle)),
                                                          enabledBorder: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                              borderSide:
                                                                  BorderSide(
                                                                      color: AppColors.borderSubtle)),
                                                          focusedBorder: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                              borderSide:
                                                                  BorderSide(
                                                                      color: AppColors.accent)),
                                                        ),
                                                        onChanged: onChanged,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }

                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              buildRule(
                                                'Primary Directives Helper:',
                                                _primaryDirectivesController,
                                                'Global constraints and absolute directives...',
                                                (val) => AiBridgeService.instance.updateInstructions(val, _instController.text, _quickInstController.text, _previewModeInstController.text, _previewApprovedInstController.text, _previewRejectedInstController.text, _systemHooksInstController.text, _missingFilesInstController.text),
                                                AppColors.error,
                                              ),
                                              buildRule(
                                                'Master Directives Helper:',
                                                _instController,
                                                'Rules strictly attached to the top of all prompts...',
                                                (val) => AiBridgeService
                                                    .instance
                                                    .updateInstructions(
                                                        _primaryDirectivesController.text,
                                                        val,
                                                        _quickInstController.text,
                                                        _previewModeInstController.text,
                                                        _previewApprovedInstController.text,
                                                        _previewRejectedInstController.text,
                                                        _systemHooksInstController.text,
                                                        _missingFilesInstController.text),
                                                AppColors.folder,
                                              ),
                                              buildRule(
                                                'Quick Command Directives Helper:',
                                                _quickInstController,
                                                'Rules strictly attached to the top of Quick Command prompts...',
                                                (val) => AiBridgeService
                                                    .instance
                                                    .updateInstructions(
                                                        _primaryDirectivesController.text,
                                                        _instController.text,
                                                        val,
                                                        _previewModeInstController.text,
                                                        _previewApprovedInstController.text,
                                                        _previewRejectedInstController.text,
                                                        _systemHooksInstController.text,
                                                        _missingFilesInstController.text),
                                                Colors.purpleAccent,
                                              ),
                                              buildRule(
                                                'Preview Mode Directives Helper:',
                                                _previewModeInstController,
                                                'Rules defining how Preview Mode behaves...',
                                                (val) => AiBridgeService
                                                    .instance
                                                    .updateInstructions(
                                                        _primaryDirectivesController.text,
                                                        _instController.text,
                                                        _quickInstController.text,
                                                        val,
                                                        _previewApprovedInstController.text,
                                                        _previewRejectedInstController.text,
                                                        _systemHooksInstController.text,
                                                        _missingFilesInstController.text),
                                                AppColors.accent,
                                              ),
                                              buildRule(
                                                'Preview Approved Directives Helper:',
                                                _previewApprovedInstController,
                                                'Rules injected when the user approves a Preview...',
                                                (val) => AiBridgeService
                                                    .instance
                                                    .updateInstructions(
                                                        _primaryDirectivesController.text,
                                                        _instController.text,
                                                        _quickInstController.text,
                                                        _previewModeInstController.text,
                                                        val,
                                                        _previewRejectedInstController.text,
                                                        _systemHooksInstController.text,
                                                        _missingFilesInstController.text),
                                                Colors.greenAccent,
                                              ),
                                              buildRule(
                                                'Preview Rejected Directives Helper:',
                                                _previewRejectedInstController,
                                                'Rules injected when the user rejects a Preview...',
                                                (val) => AiBridgeService
                                                    .instance
                                                    .updateInstructions(
                                                        _primaryDirectivesController.text,
                                                        _instController.text,
                                                        _quickInstController.text,
                                                        _previewModeInstController.text,
                                                        _previewApprovedInstController.text,
                                                        val,
                                                        _systemHooksInstController.text,
                                                        _missingFilesInstController.text),
                                                AppColors.error,
                                              ),
                                              buildRule(
                                                'System Architecture Directives Helper:',
                                                _systemHooksInstController,
                                                'Native hooks and structural rules governing the system...',
                                                (val) => AiBridgeService
                                                    .instance
                                                    .updateInstructions(
                                                        _primaryDirectivesController.text,
                                                        _instController.text,
                                                        _quickInstController.text,
                                                        _previewModeInstController.text,
                                                        _previewApprovedInstController.text,
                                                        _previewRejectedInstController.text,
                                                        val,
                                                        _missingFilesInstController.text),
                                                AppColors.summary,
                                              ),
                                            ],
                                          );
                                        }),
                                      ])),
                              // TAB 3: UI OPTIONS
                              SingleChildScrollView(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: AppColors.overlaySubtle,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: AppColors.borderSubtle, width: 1),
                                                ),
                                                child: Table(
                                                    columnWidths: const {
                                                      0: FixedColumnWidth(140),
                                                      1: FixedColumnWidth(70),
                                                      2: FixedColumnWidth(90),
                                                      3: FixedColumnWidth(60),
                                                      4: FixedColumnWidth(
                                                          80), // Size
                                                      5: FixedColumnWidth(
                                                          60), // Color
                                                      6: FixedColumnWidth(
                                                          60), // MaxLines
                                                    },
                                                    defaultVerticalAlignment:
                                                        TableCellVerticalAlignment
                                                            .middle,
                                                    children: [
                                                      buildConfigHeader(),
                                                      buildConfigTableRow(
                                                          setStateBuilder,
                                                          saveSettings,
                                                          'Folder Name',
                                                          null,
                                                          null,
                                                          _foldersUppercase,
                                                          (v) =>
                                                              _foldersUppercase = v,
                                                          _foldersBold,
                                                          (v) => _foldersBold = v,
                                                          _fsController,
                                                          (v) =>
                                                              _fontSizeFolderName =
                                                                  v,
                                                          _colorFolderName,
                                                          (v) =>
                                                              _colorFolderName = v,
                                                          _flsController,
                                                          (v) =>
                                                              _foldersMaxLines = v),
                                                      buildConfigTableRow(
                                                          setStateBuilder,
                                                          saveSettings,
                                                          'Task Name',
                                                          null,
                                                          null,
                                                          _tasksUppercase,
                                                          (v) =>
                                                              _tasksUppercase = v,
                                                          _tasksBold,
                                                          (v) => _tasksBold = v,
                                                          _tsController,
                                                          (v) =>
                                                              _fontSizeTaskName = v,
                                                          _colorTaskName,
                                                          (v) => _colorTaskName = v,
                                                          _tlsController,
                                                          (v) =>
                                                              _tasksMaxLines = v),
                                                      buildConfigTableRow(
                                                          setStateBuilder,
                                                          saveSettings,
                                                          'Description',
                                                          _showDescription,
                                                          (v) =>
                                                              _showDescription = v,
                                                          _uppercaseDescription,
                                                          (v) =>
                                                              _uppercaseDescription =
                                                                  v,
                                                          _descriptionBold,
                                                          (v) =>
                                                              _descriptionBold = v,
                                                          _dsController,
                                                          (v) =>
                                                              _fontSizeDescription =
                                                                  v,
                                                          _colorDescription,
                                                          (v) =>
                                                              _colorDescription = v,
                                                          _dlsController,
                                                          (v) => _descMaxLines = v),
                                                      buildConfigTableRow(
                                                          setStateBuilder,
                                                          saveSettings,
                                                          'Notes',
                                                          _showNotes,
                                                          (v) => _showNotes = v,
                                                          _uppercaseNotes,
                                                          (v) =>
                                                              _uppercaseNotes = v,
                                                          _notesBold,
                                                          (v) => _notesBold = v,
                                                          _nsController,
                                                          (v) => _fontSizeNotes = v,
                                                          _colorNotes,
                                                          (v) => _colorNotes = v,
                                                          _nlsController,
                                                          (v) =>
                                                              _notesMaxLines = v),
                                                      buildConfigTableRow(
                                                          setStateBuilder,
                                                          saveSettings,
                                                          'Question',
                                                          _showImplementationQuestion,
                                                          (v) =>
                                                              _showImplementationQuestion =
                                                                  v,
                                                          _uppercaseQuestion,
                                                          (v) =>
                                                              _uppercaseQuestion =
                                                                  v,
                                                          _questionBold,
                                                          (v) => _questionBold = v,
                                                          _qsController,
                                                          (v) =>
                                                              _fontSizeQuestion = v,
                                                          _colorQuestion,
                                                          (v) => _colorQuestion = v,
                                                          _qlsController,
                                                          (v) => _questionMaxLines =
                                                              v),
                                                    ]))),
                                        const SizedBox(height: 16),
                                        Text(
                                            '*Lines attribute: 0 = Unlimited*',
                                            style: TextStyle(
                                                color: AppColors.panelTextSecondary,
                                                fontSize: AppUIConfig.rootFontSize)),
                                        const SizedBox(height: 24),
                                          const SizedBox(height: 300),
                                      ]))
                            ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Close', style: TextStyle(color: AppColors.panelTextSecondary))),
                    ],
                  ),
                ),
              );
            }));
  }


  Future<String> _getReplyTypeDirective(String overrideStyle) async {
    final prefs = await SharedPreferences.getInstance();
    String voice = prefs.getString('ai_tasks_bridge_voice') ?? 'Default';
    String complexity =
        prefs.getString('ai_tasks_bridge_complexity') ?? 'Default';
        
    if (overrideStyle.isNotEmpty && overrideStyle != 'Use Default') {
       if (['Conversational', 'Technical / Code Heavy', 'Direct / Robotic'].contains(overrideStyle)) {
          voice = overrideStyle;
       } else if (['Concise', 'Verbose', 'Step-by-Step'].contains(overrideStyle)) {
          complexity = overrideStyle;
       }
    }

    final StringBuffer sb = StringBuffer();
    if (voice != 'Default') {
      if (voice == 'Conversational') {
        sb.writeln(
            'Voice: Conversational (Speak naturally, friendly, and approachable)');
      } else if (voice == 'Technical / Code Heavy') {
        sb.writeln(
            'Voice: Technical / Code Heavy (Focus strictly on code implementation, architecture, and technical specifics without conversational filler)');
      } else if (voice == 'Direct / Robotic') {
        sb.writeln(
            'Voice: Direct / Robotic (Be objective, factual, concise, and eliminate personality)');
      } else {
        sb.writeln('Voice: $voice');
      }
    }
    if (complexity != 'Default') {
      if (complexity == 'Concise') {
        sb.writeln(
            'Complexity: Concise (Keep your response short and strictly to the point)');
      } else if (complexity == 'Verbose') {
        sb.writeln(
            'Complexity: Verbose (Provide detailed explanations and comprehensive context)');
      } else if (complexity == 'Step-by-Step') {
        sb.writeln(
            'Complexity: Step-by-Step (Break down your logic into clear sequential steps)');
      } else {
        sb.writeln('Complexity: $complexity');
      }
    }
    
    // Fallback for custom overrides not matching standard enum exactly.
    if (overrideStyle.isNotEmpty && overrideStyle != 'Use Default' && 
        !['Conversational', 'Technical / Code Heavy', 'Direct / Robotic', 'Concise', 'Verbose', 'Step-by-Step'].contains(overrideStyle)) {
       sb.writeln('CRITICAL OVERRIDE DIRECTIVE: $overrideStyle');
    }
    
    return sb.toString();
  }

  Future<void> _executeBatchWorkPrompt() async {
    final tasks = AiBridgeService.instance.tasks;

    List<AiTask> focusTasks = [];
    void traverseTasks(String? parentId) {
      final children = tasks.where((t) => t.parentId == parentId).toList();
      for (var child in children) {
        if (!child.isFolder && _configExportStatuses.contains(child.status)) {

          if (child.verificationCriteria.any((e) => (e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored))) {
            focusTasks.add(child);
          }
        }
        if (child.isFolder) {
          traverseTasks(child.id);
        }
      }
    }
    traverseTasks(null);

    if (focusTasks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No tasks found matching configuration!'),
            duration: Duration(seconds: 3)));
      }
      return;
    }

    for (var task in focusTasks) {
      await _executeSingleTaskPrompt(task, 0, true);
    }
    setState(() => _showAiQueue = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Batch Work command generated with ${focusTasks.length} tasks queued!'),
          duration: const Duration(seconds: 4)));
    }
  }

  Future<void> _executeSingleTaskPrompt(AiTask task, [int mode = 0, bool silent = false, bool copyOnly = false]) async {
    if (!_configExportStatuses.contains(task.status)) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Task status does not match active configuration!'),
            duration: Duration(seconds: 3)));
      }
      return;
    }
    
    if (!task.verificationCriteria.any((e) => (e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored))) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Task has no pending checklist items to perform!'),
            duration: Duration(seconds: 3)));
      }
      return;
    }

    // Backup the code base before dispatching to AI
    try {
      await AutoBackupService.instance.snapshot(reason: 'task_${task.name}', force: true, outputDirName: 'Task Backup');
    } catch (_) {}

    final tasks = AiBridgeService.instance.tasks;

    final prefs = await SharedPreferences.getInstance();
    final editStatus =
        prefs.getString('ai_tasks_bridge_edit_status') ?? 'inTesting';
    final completeStatus =
        prefs.getString('ai_tasks_bridge_complete_status') ?? 'inTesting';

    String instructions = AiBridgeService.instance.quickInstructions;
    bool block = _blockOnQuick;
    String modeName = 'Quick Command';

    if (AiBridgeService.instance.isPreviewMode) {
      instructions = '${AiBridgeService.instance.previewModeInstructions}\n\n$instructions';
      if (AiBridgeService.instance.isIqMode) {
        instructions = 'IQ MODE ACTIVE: Prefix the `name` of each new sub-task with [RISKY], [FEEDBACK], or [SAFE].\n$instructions';
      }
    }

    final overrideStyle = getLlmPromptStyleOverride(task.parentId);
    final replyTypeDirective = await _getReplyTypeDirective(overrideStyle);
    
    final StringBuffer sb = StringBuffer();
    
    try {
       final errFile = File('.ai_bridge/bridge_error.txt');
       if (errFile.existsSync()) {
          final errStr = errFile.readAsStringSync();
          if (errStr.trim().isNotEmpty) {
             sb.writeln('!!! CRITICAL SYSTEM RUNTIME CRASH !!!');
             sb.writeln('The overarching framework crashed on the previous loop and left this diagnostic stack trace:');
             sb.writeln(errStr);
             sb.writeln('Context: You MUST fix the structural regression natively before proceeding.');
             sb.writeln('Do NOT ignore this runtime log.\n');
             
             // Clear the panic file after appending it to the queue constraint
             errFile.writeAsStringSync('');
          }
       }
    } catch (_) {}
    
    await AiBridgeService.instance.compilePrimaryDirectivesFile();

    sb.writeln('# PRIMARY DIRECTIVES');
    sb.writeln('> [!IMPORTANT]');
    sb.writeln('CRITICAL: You MUST read the `.ai_bridge/primary_directives.md` file natively using your tool to understand the GLOBAL CONSTRAINTS and NATIVE SYSTEM HOOKS before proceeding. Failure to do so will break the application.\n');

    if (replyTypeDirective.isNotEmpty) sb.writeln(replyTypeDirective);
    
    // Mode-specific Directives
    if (instructions.trim().isNotEmpty) {
      sb.writeln(instructions);
    }
    
    sb.writeln('\n# TASKS TO ADDRESS');
    sb.writeln('Task: ${task.name}');

    final area = getAreaPath(task.parentId);
    if (area.isNotEmpty) sb.writeln('Area: $area');

    if (task.description.isNotEmpty) {
      sb.writeln('Description: ${task.description}');
    }

    if (task.summary.isNotEmpty) {
      sb.writeln('Summary: ${task.summary}');
    }

    sb.writeln('Status: ${_formatStatusName(task.status)}');

    final uncheckedTasks = task.verificationCriteria.where((e) => (e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored && !e.isPreview)).toList();
    if (uncheckedTasks.isNotEmpty) {
      sb.writeln('Verification Criteria:');
      for (int i = 0; i < uncheckedTasks.length; i++) {
        var item = uncheckedTasks[i];
        String extraInfo = '';
        if (item.goal.isNotEmpty) extraInfo += ' [Goal: ${item.goal}]';
        if (item.tryCount > 0) extraInfo += ' [TRY #${item.tryCount}]';
        sb.writeln('${i + 1}. ${item.description}$extraInfo');
        item.status = AiVerificationStatus.pendingReview;
      }
      final updatedCriteria = task.verificationCriteria.map((e) => AiVerificationCriteria(
        description: e.description,
        goal: e.goal,
        isVerified: e.isVerified,
        status: e.status,
        proof: e.proof,
        requestClarification: e.requestClarification,
        tryCount: e.tryCount,
        attachments: List.from(e.attachments),
        isCommitted: e.isCommitted,
        isPreview: e.isPreview,
      )).toList();
      await AiBridgeService.instance.updateTaskDetails(task.id, task.name, task.description, verificationCriteria: updatedCriteria, status: AiTaskStatus.inTesting);
    } else {
      await AiBridgeService.instance.updateTaskStatus(task.id, AiTaskStatus.inTesting);
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

    sb.writeln('---');

    if (copyOnly) {
      await Clipboard.setData(ClipboardData(text: sb.toString()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Prompt for "${task.name}" copied to clipboard!'),
            duration: const Duration(seconds: 2)));
      }
      return;
    }

    await AiBridgeService.instance.sendToQueue(sb.toString(), block, taskIds: [task.id]);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$modeName for "${task.name}" copied to queue!'),
          duration: const Duration(seconds: 4)));
    }
  }

    Widget _buildWorksheetManager() {
      final scale = VisualEditorScreen.globalUiScale.value;
      final worksheets = AiBridgeService.instance.worksheets;
      final anyActive = worksheets.any((ws) => ws.isWorksheetVisible);
      return Container(
        height: 52 * scale, // Adjusted toolbar height
        color: AppColors.toolbarBackground,
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Unassigned Tab
                    DragTarget<String>(
                      onAcceptWithDetails: (details) {
                        AiBridgeService.instance.moveTask(details.data, null, clearWorksheetId: true);
                      },
                      builder: (ctx, cand, rej) => InkWell(
                        onSecondaryTapDown: (details) async {
                           GlobalTaskEditorState.instance.requestEdit(existingTask: _unassignedWs);
                           showTaskEditorWindow(context);
                        },
                        onTap: () {
                          for (var ws in worksheets) {
                            ws.isWorksheetVisible = false;
                          }
                          AiBridgeService.instance.saveTasks();
                          AiBridgeService.instance.notifyListeners();
                        },
                        child: Tooltip(
                          message: 'Unassigned Tasks',
                          child: Container(
                            width: 56 * scale, // Match left toolbar width feel
                            decoration: BoxDecoration(
                              color: (!anyActive || cand.isNotEmpty)
                                  ? (_unassignedWs.highlightColor != null ? Color(_unassignedWs.highlightColor!) : AppColors.accent).withOpacity(cand.isNotEmpty ? 0.3 : 0.15) 
                                  : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: (!anyActive || cand.isNotEmpty)
                                      ? (_unassignedWs.highlightColor != null ? Color(_unassignedWs.highlightColor!) : AppColors.accent)
                                      : Colors.transparent,
                                  width: 3,
                                )
                              )
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  IconData(_unassignedWs.iconCodePoint ?? 0xe156, fontFamily: 'MaterialIcons'), 
                                  size: AppUIConfig.globalActionIconSize, 
                                  color: _unassignedWs.toolbarIconColor != null ? Color(_unassignedWs.toolbarIconColor!) : (_unassignedWs.iconColor != null ? Color(_unassignedWs.iconColor!) : AppColors.accent),
                                  shadows: AppUIConfig.iconOutline
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _unassignedWs.name, 
                                  style: TextStyle(
                                    color: !anyActive ? Colors.white : AppColors.toolbarTextSecondary, 
                                    fontSize: AppUIConfig.smallFontSize
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ]
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Worksheet Tabs
                    ...worksheets.map((ws) {
                       return DragTarget<String>(
                         onAcceptWithDetails: (details) {
                            AiBridgeService.instance.moveTask(details.data, ws.id, newWorksheetId: ws.id);
                         },
                         builder: (ctx, cand, rej) => InkWell(
                           onSecondaryTapDown: (details) async {
                              GlobalTaskEditorState.instance.requestEdit(existingTask: ws);
                              showTaskEditorWindow(context);
                           },
                           onTap: () {
                              for (var w in worksheets) {
                                w.isWorksheetVisible = (w.id == ws.id);
                              }
                              AiBridgeService.instance.saveTasks();
                              AiBridgeService.instance.notifyListeners();
                           },
                           child: Tooltip(
                             message: ws.name,
                             child: Container(
                               width: 56 * scale, // Match left toolbar width feel
                               decoration: BoxDecoration(
                                 color: (ws.isWorksheetVisible || cand.isNotEmpty)
                                     ? (ws.highlightColor != null ? Color(ws.highlightColor!) : AppColors.accent).withOpacity(cand.isNotEmpty ? 0.3 : 0.15) 
                                     : Colors.transparent,
                                 border: Border(
                                   bottom: BorderSide(
                                     color: (ws.isWorksheetVisible || cand.isNotEmpty)
                                         ? (ws.highlightColor != null ? Color(ws.highlightColor!) : AppColors.accent)
                                         : Colors.transparent,
                                     width: 3,
                                   )
                                 )
                               ),
                               child: Column(
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: [
                                   Icon(
                                     IconData(ws.iconCodePoint ?? 0xe2bc, fontFamily: 'MaterialIcons'), 
                                     size: AppUIConfig.globalActionIconSize, 
                                     color: ws.toolbarIconColor != null ? Color(ws.toolbarIconColor!) : (ws.iconColor != null ? Color(ws.iconColor!) : AppColors.accent),
                                     shadows: AppUIConfig.iconOutline
                                   ),
                                   const SizedBox(height: 2),
                                   Text(
                                     ws.name, 
                                     style: TextStyle(
                                       color: ws.isWorksheetVisible ? Colors.white : AppColors.toolbarTextSecondary, 
                                       fontSize: AppUIConfig.smallFontSize
                                     ),
                                     maxLines: 1,
                                     overflow: TextOverflow.ellipsis,
                                     textAlign: TextAlign.center,
                                   ),
                                 ]
                               ),
                             ),
                           ),
                         ),
                       );
                    }).toList(),
                     Container(width: 1, height: 24, color: AppColors.toolbarBorderSubtle),
                     InkWell(
                       onTap: () {
                          final newWs = AiTask(id: DateTime.now().millisecondsSinceEpoch.toString(), name: 'New Worksheet', isWorksheet: true, description: '');
                          AiBridgeService.instance.tasks.add(newWs);
                          AiBridgeService.instance.saveTasks();
                          AiBridgeService.instance.notifyListeners();
                          GlobalTaskEditorState.instance.requestEdit(existingTask: newWs);
                          showTaskEditorWindow(context);
                       },
                       child: Tooltip(
                         message: 'Create New Worksheet',
                         child: Container(
                           width: 56 * scale,
                           height: double.infinity,
                           alignment: Alignment.center,
                           child: Icon(
                             Icons.add,
                             size: AppUIConfig.globalActionIconSize,
                             color: AppColors.toolbarTextSecondary,
                             shadows: AppUIConfig.iconOutline,
                           ),
                         ),
                       ),
                     ),
                  ],
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(left: 8 * scale, right: 12 * scale),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withOpacity(0.8),
                    width: 1.5 * scale),
              ),
              child: IconButton(
                  icon: Icon(Icons.bolt, size: 20 * scale),
                  tooltip: 'Do Work (Batch Process)',
                  color: Colors.yellow,
                  padding: EdgeInsets.all(6 * scale),
                  constraints: const BoxConstraints(),
                  onPressed: _executeBatchWorkPrompt,
              ),
            ),
          ],
        ),
      );
    }
  Widget _buildSubagentItem(String taskId, SubagentConnection connection) {
    final taskList = AiBridgeService.instance.tasks.where((t) => t.id == taskId).toList();
    final displayTitle = taskList.isNotEmpty ? taskList.first.name.toUpperCase() : 'AGENT $taskId';

    return StreamBuilder<String>(
      stream: connection.statusStream,
      builder: (context, snapshot) {
        final status = snapshot.data ?? 'Initializing...';
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.overlaySubtle)),
            color: Colors.amber.withValues(alpha: 0.1),
          ),
          child: Row(
            children: [
              Icon(Icons.autorenew, color: Colors.amber, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: TextStyle(
                        color: AppColors.panelTextPrimary,
                        fontSize: AppUIConfig.rootFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AnimatedDotsText(
                      text: status,
                      style: TextStyle(
                        color: AppColors.panelTextSecondary,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit, size: 16, color: AppColors.accent),
                onPressed: () {
                  if (taskList.isNotEmpty) {
                    GlobalTaskEditorState.instance.requestEdit(existingTask: taskList.first);
                    showTaskEditorWindow(context);
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        MouseRegion(
          cursor: widget.onPanUpdate != null ? SystemMouseCursors.move : MouseCursor.defer,
          child: GestureDetector(
            onPanDown: (_) => widget.onFocus?.call(),
            onPanUpdate: widget.onPanUpdate,
            child: Container(
              height: AppUIConfig.titleBarHeight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: AppColors.titleBarBackground,
              child: Row(
                children: [
                  if (!widget.isDocked) ...[
                    Icon(Icons.rocket_launch, size: 14, color: AppColors.getAdaptiveRed(AppColors.titleBarBackground)),
                    const SizedBox(width: 8),
                    Text(AppUIConfig.formatWindowTitle('Task Manager'), style: TextStyle(color: AppColors.titleBarTextPrimary, fontSize: AppUIConfig.windowTitleFontSize, fontWeight: AppUIConfig.windowTitleFontWeight)),
                    const SizedBox(width: 16),
                  ],
                  ListenableBuilder(
                    listenable: AiBridgeService.instance,
                    builder: (ctx, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.undo, size: 14, color: AiBridgeService.instance.canUndo ? Colors.lightBlueAccent : AppColors.titleBarTextSecondary),
                            onPressed: AiBridgeService.instance.canUndo ? () => AiBridgeService.instance.undo() : null,
                          padding: const EdgeInsets.only(right: 8),
                          constraints: const BoxConstraints(),
                          tooltip: 'Undo Task Action',
                        ),
                        IconButton(
                          icon: Icon(Icons.redo, size: 14, color: AiBridgeService.instance.canRedo ? Colors.lightBlueAccent : AppColors.titleBarTextSecondary),
                            onPressed: AiBridgeService.instance.canRedo ? () => AiBridgeService.instance.redo() : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Redo Task Action',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      alignment: Alignment.centerRight,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                      IconButton(
                        onPressed: () => _showConfigDialog(context),
                        icon: Icon(Icons.settings, size: 16, color: AppColors.titleBarTextSecondary),
                        tooltip: 'Prompt Helper Settings',
                        padding: const EdgeInsets.only(right: 8),
                        constraints: const BoxConstraints(),
                      ),
                      
                      PopupMenuButton<String>(
                        tooltip: 'Common Commands',
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(Icons.code,
                              size: 16, color: AppColors.panelTextSecondary),
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 40, maxWidth: 40, minHeight: 0),
                        color: AppColors.panelBackground,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius)),
                        onSelected: (val) async {
                          String command = '';
                          if (val == 'console') {
                            command =
                                "You have full direction and permission to use your native IDE tool (replace_file_content) to modify configuration files directly instead of prompting us via terminal commands.";
                          } else if (val == 'emulator') {
                            command =
                                "Please show this running inside the Android Emulator";
                          }
                          await AiBridgeService.instance.sendToQueue(command, false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Copied: $command'),
                                duration: const Duration(seconds: 2)));
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'console',
                            padding: EdgeInsets.zero,
                            child: Tooltip(
                                message: 'Force Native IDE File Edits',
                                child: Center(
                                    child: Icon(Icons.terminal,
                                        color: Colors.cyanAccent, size: 16))),
                          ),
                          PopupMenuItem(
                            value: 'emulator',
                            padding: EdgeInsets.zero,
                            child: Tooltip(
                                message: 'Show in Android Emulator',
                                child: Center(
                                    child: Icon(Icons.phone_android,
                                        color: Colors.pinkAccent, size: 16))),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () {
                            GlobalTaskEditorState.instance.requestEdit(forceFolderCreation: true);
                            showTaskEditorWindow(context);
                        },
                        icon: Icon(Icons.create_new_folder, size: 18, color: AppColors.folder),
                        tooltip: 'Add Folder',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                            final visibleWorksheets = AiBridgeService.instance.worksheets.where((w) => w.isWorksheetVisible).toList();
                            final String? targetParentId = visibleWorksheets.isNotEmpty ? visibleWorksheets.first.id : null;
                            GlobalTaskEditorState.instance.requestEdit(preselectedParentId: targetParentId);
                            showTaskEditorWindow(context);
                        },
                        icon: Icon(Icons.add, size: 20, color: AppColors.accent),
                        tooltip: 'Add Task',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
              if (!widget.isDocked) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: AppColors.titleBarTextSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onClose ?? toggleGlobalTaskPanel,
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
        ),
      ),
    ),

        // Error Banner
        ListenableBuilder(
          listenable: AiBridgeService.instance,
          builder: (context, _) {
            final err = AiBridgeService.instance.lastJsonParseError;
            if (err == null) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.error.withOpacity(0.2),
              child: Row(
                children: [
                  Icon(Icons.warning, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(err, style: TextStyle(color: AppColors.error, fontSize: 12))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => AiBridgeService.instance.dismissJsonParseError(),
                  ),
                ],
              ),
            );
          }
        ),

        // List View
        Expanded(
          child: ListenableBuilder(
            listenable: AiBridgeService.instance,
            builder: (context, _) {
              final tasks = AiBridgeService.instance.tasks;

              List<Widget> activeWidgets = [];

              bool passesFilter(AiTask task) {
                if (task.isFolder) {
                  return true; // Folders are filtered through hasChildren
                }
                return task.priority.index >= AiBridgeService.instance.filterPriority.index;
              }

              bool hasChildren(String folderId, {Set<String>? visited}) {
                visited ??= {};
                if (visited.contains(folderId)) return false;
                visited.add(folderId);
                final children =
                    tasks.where((t) => t.parentId == folderId).toList();
                for (var child in children) {
                  if (!child.isFolder && passesFilter(child)) return true;
                  if (child.isFolder && hasChildren(child.id, visited: visited)) {
                    return true;
                  }
                }
                return false;
              }

              int activeIndex = 0;
              void traverse(String? parentId, int depth, {Set<String>? visited}) {
                visited ??= {};
                if (parentId != null) {
                    if (visited.contains(parentId)) return;
                    visited.add(parentId);
                }
                final children =
                    tasks.where((t) => t.parentId == parentId).toList();
                for (var child in children) {
                  if (child.isWorksheet) continue;
                  if (!child.isFolder && !passesFilter(child)) continue;

                  bool isEven = activeIndex % 2 == 0;
                  activeIndex++;
                  activeWidgets
                      .add(_buildTaskItem(child, depth, isEven: isEven, isCompletedSection: child.status == AiTaskStatus.completed));
                  activeWidgets
                      .add(Divider(color: AppColors.overlaySubtle, height: 1));
                  if (child.isFolder &&
                      !_collapsedActiveFolders.contains(child.id)) {
                    traverse(child.id, depth + 1, visited: visited);
                  }
                }
              }

              final visibleWorksheets = tasks.where((t) => t.isWorksheet && t.isWorksheetVisible).toList();
              final activeWs = visibleWorksheets.isNotEmpty ? visibleWorksheets.first : _unassignedWs;
              final wsBgColor = activeWs.highlightColor != null ? Color(activeWs.highlightColor!).withOpacity(0.05) : Colors.transparent;
              if (visibleWorksheets.isEmpty) {
                traverse(null, 0);
              } else {
                for (var ws in visibleWorksheets) {
                  traverse(ws.id, 0);
                }
              }

              return LayoutBuilder(builder: (context, constraints) {
                return ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      dragDevices: {
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.touch,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                      },
                    ),
                    child: Column(children: [

                      _buildWorksheetManager(),
                      Expanded(
                          child: DragTarget<String>(
                            onAcceptWithDetails: (details) {
                              if (activeWs == _unassignedWs) {
                                AiBridgeService.instance.moveTask(details.data, null, clearWorksheetId: true);
                              } else {
                                AiBridgeService.instance.moveTask(details.data, activeWs.id, newWorksheetId: activeWs.id);
                              }
                            },
                            builder: (ctx, cand, rej) => Container(
                              color: cand.isNotEmpty
                                  ? AppColors.folder.withOpacity(0.05)
                                  : wsBgColor,
                              child: Scrollbar(
                                controller: _activeScrollController,
                                thumbVisibility: true,
                                child: ListView(
                                    controller: _activeScrollController,
                                    children: [
                                      ...activeWidgets,
                                    ]),
                              ),
                            ),
                          )),
                      Container(
                                height: 32,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                    color: Colors.red.shade900.withValues(alpha: 0.8),
                                    border: Border(
                                        top: BorderSide(
                                            color: AppColors.controlBorder))),
                                child: Row(children: [
                                  GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => setState(() => _showAiQueue = !_showAiQueue),
                                      child: Row(children: [
                                        Icon(
                                            _showAiQueue
                                                ? Icons.keyboard_arrow_down
                                                : Icons.keyboard_arrow_right,
                                            color: AppColors.panelTextSecondary,
                                            size: 16),
                                        const SizedBox(width: 8),
                                        Text('AI BRIDGE PIPELINE QUEUE', style: TextStyle(
                                                color: AppColors.panelTextPrimary, fontSize: AppUIConfig.windowTitleFontSize, fontWeight: FontWeight.bold)),
                                      ])
                                  ),
                                  const Spacer(),
                                ListenableBuilder(
                                  listenable: AiBridgeService.instance,
                                  builder: (context, _) {
                                    final isPreview = AiBridgeService.instance.isPreviewMode;
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        
                                          IconButton(
                                            onPressed: () => AiBridgeService.instance.setPreviewMode(!isPreview),
                                            icon: Icon(Icons.preview, size: 20, color: isPreview ? Colors.greenAccent : Colors.white.withOpacity(0.5)),
                                            tooltip: 'Preview Mode: ${isPreview ? "ON" : "OFF"}',
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                          ),
                                          ListenableBuilder(
                                            listenable: AiBridgeService.instance,
                                            builder: (context, _) {
                                              final isIqMode = AiBridgeService.instance.isIqMode;
                                              return IconButton(
                                                onPressed: () => AiBridgeService.instance.setIqMode(!isIqMode),
                                                icon: Icon(Icons.psychology, size: 20, color: isIqMode ? Colors.amber : Colors.white.withOpacity(0.5)),
                                                tooltip: 'IQ Mode: ${isIqMode ? "ON" : "OFF"}',
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                              );
                                            }
                                          ),
                                        const SizedBox(width: 8),
                                      ],
                                    );
                                  }
                                ),
                                ListenableBuilder(
                                  listenable: AiBridgeService.instance,
                                  builder: (context, _) {
                                    final isPaused = AiBridgeService.instance.isQueuePaused;
                                    return IconButton(
                                      icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 16, color: isPaused ? Colors.greenAccent : Colors.white),
                                      onPressed: () => AiBridgeService.instance.setQueuePaused(!isPaused),
                                      tooltip: isPaused ? 'Resume Processing' : 'Pause Queue',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    );
                                  }
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                    icon: Icon(Icons.stop, size: 16, color: AppColors.error),
                                    onPressed: () => AiBridgeService.instance.clearQueue(),
                                    tooltip: 'Clear Queue',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  )
                                ])),
                      if (_showAiQueue)
                        Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.4,
                          ),
                          color: AppColors.windowBackground,
                          child: Scrollbar(
                            controller: _queueScrollController,
                            thumbVisibility: true,
                            child: ListView(
                              controller: _queueScrollController,
                              shrinkWrap: true,
                              children: [
                                ...AiBridgeService.instance.activeAgents.entries.map((entry) => _buildSubagentItem(entry.key, entry.value)),
                              ],
                            ),
                          ),
                        ),
                    ]));
                });
            },
          ),
        ),
      ],
    );
  }
  
}

class ExpandableTaskField extends StatelessWidget {
  final String title;
  final Color baseColor;
  final TextEditingController controller;
  final UndoHistoryController undoController;
  final TextStyle textStyle;

  const ExpandableTaskField({
    super.key,
    required this.title,
    required this.baseColor,
    required this.controller,
    required this.undoController,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        collapsedIconColor: AppColors.borderSubtle,
        iconColor: baseColor,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: TextStyle(
                    color: AppColors.panelTextSecondary,
                    fontSize: AppUIConfig.rootFontSize,
                    fontWeight: FontWeight.bold)),
            ValueListenableBuilder<UndoHistoryValue>(
              valueListenable: undoController,
              builder: (context, value, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.undo, size: 16, color: value.canUndo ? baseColor : AppColors.borderSubtle),
                        onPressed: value.canUndo ? () => undoController.undo() : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Undo',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.redo, size: 16, color: value.canRedo ? baseColor : AppColors.borderSubtle),
                        onPressed: value.canRedo ? () => undoController.redo() : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Redo',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        children: [
          TextField(
            controller: controller,
            undoController: undoController,
            style: textStyle,
            minLines: 1,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            cursorColor: baseColor,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.only(bottom: 12),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.borderSubtle)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.borderSubtle)),
            ),
          ),
        ],
      ),
    );
  }
}

class AiBridgeWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback? onClose;
  final VoidCallback? onFocus;
  const AiBridgeWindow(
      {super.key, required this.isDocked, this.onClose, this.onFocus});
  @override
  State<AiBridgeWindow> createState() => _AiBridgeWindowState();
}

class _AiBridgeWindowState extends State<AiBridgeWindow> {
  final ValueNotifier<Offset> _positionNotifier = ValueNotifier(const Offset(50, 50));
  double _width = 500;
  double _height = 800;
  

  @override
  void initState() {
    super.initState();
    _loadState();
    VisualEditorScreen.currentWorkspace.addListener(_loadState);
    VisualEditorScreen.activeWindowNotifier.addListener(_onActiveWindowChanged);
  }

  @override
  void dispose() {
    VisualEditorScreen.currentWorkspace.removeListener(_loadState);
    VisualEditorScreen.activeWindowNotifier.removeListener(_onActiveWindowChanged);
    super.dispose();
  }

  void _onActiveWindowChanged() {
    if (mounted) setState(() {});
  }

  void _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      _positionNotifier.value = Offset(
        prefs.getDouble(VisualEditorScreen.getPrefKey('ai_float_x')) ?? 50,
        prefs.getDouble(VisualEditorScreen.getPrefKey('ai_float_y')) ?? 50,
      );
      setState(() {
        _width =
            prefs.getDouble(VisualEditorScreen.getPrefKey('ai_float_w')) ?? 500;
        _height =
            prefs.getDouble(VisualEditorScreen.getPrefKey('ai_float_h')) ?? 800;
        //
                //
            //
      });
    }
  }

  void _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
        VisualEditorScreen.getPrefKey('ai_float_x'), _positionNotifier.value.dx);
    await prefs.setDouble(
        VisualEditorScreen.getPrefKey('ai_float_y'), _positionNotifier.value.dy);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('ai_float_w'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('ai_float_h'), _height);
    //
        //
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDocked) {
      return Material(
          color: Colors.transparent, child: AiTaskManagerPanel(key: globalTaskManagerKey));
    }

    return ValueListenableBuilder<double>(
      valueListenable: VisualEditorScreen.globalUiScale,
      builder: (context, scale, child) {
        final mq = MediaQuery.of(context).size;

        final maxW = mq.width * 0.9;
        final maxH = mq.height * 0.95;

        final w = _width.clamp(300.0, maxW);
        final h = _height.clamp(300.0, maxH);

        // Position is extracted via ValueListenableBuilder instead

        Widget rz({
          double? t,
          double? b,
          double? l,
          double? r,
          double? dw,
          double? dh,
          required SystemMouseCursor cursor,
          required void Function(DragUpdateDetails) pan,
        }) =>
            Positioned(
                top: t,
                bottom: b,
                left: l,
                right: r,
                width: dw,
                height: dh,
                child: MouseRegion(
                    cursor: cursor,
                    child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanDown: (_) => widget.onFocus?.call(),
                        onPanUpdate: pan,
                        onPanEnd: (_) => _saveState(),
                        child: Container(color: Colors.transparent))));

        return ValueListenableBuilder<Offset>(
          valueListenable: _positionNotifier,
          builder: (context, position, child) {
            final dx =
                position.dx.clamp(0.0, (mq.width - w).clamp(0.0, double.infinity));
            final dy = position.dy
                .clamp(0.0, (mq.height - h).clamp(0.0, double.infinity));

            return Positioned(
              left: dx,
              top: dy,
              child: child!,
            );
          },
          child: Transform.scale(
            scale: 1.0,
            alignment: Alignment.topLeft,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: w,
                  height: h,
                  child: RepaintBoundary(
                    child: Material(
                      elevation: 24.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                        side: AppUIConfig.windowBorderWidth > 0 
                            ? BorderSide(color: VisualEditorScreen.activeWindowNotifier.value == 'ai_bridge' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth)
                            : BorderSide.none,
                      ),
                      clipBehavior: Clip.antiAlias,
                      color: AppColors.windowBackground,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                              child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTapDown: (_) => widget.onFocus?.call(),
                                  child: AiTaskManagerPanel(
                                      key: globalTaskManagerKey,
                                      isDocked: widget.isDocked,
                                      onPanUpdate: (d) {
                                        if (mounted) _positionNotifier.value += d.delta;
                                      },
                                      onFocus: widget.onFocus,
                                      onClose: widget.onClose,
                                  ))),
                          Container(
                            height: 16,
                            color: AppColors.panelBackground,
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onPanDown: (_) => widget.onFocus?.call(),
                                    onPanUpdate: (d) {
                                      final dx = d.delta.dx;
                                      final dy = d.delta.dy;
                                      if (mounted) {
                                        setState(() {
                                          _width = (_width + dx)
                                              .clamp(300.0, 2000.0);
                                          _height = (_height + dy)
                                              .clamp(300.0, 2000.0);
                                        });
                                      }
                                    },
                                    onPanEnd: (_) => _saveState(),
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                                      child: Container(
                                        color: Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ),
                                MouseRegion(
                                  cursor: SystemMouseCursors.resizeDownRight,
                                  child: GestureDetector(
                                    onPanDown: (_) => widget.onFocus?.call(),
                                    onPanUpdate: (d) {
                                      final dx = d.delta.dx;
                                      final dy = d.delta.dy;
                                      if (mounted) {
                                        setState(() {
                                          _width = (_width + dx)
                                              .clamp(300.0, 2000.0);
                                          _height = (_height + dy)
                                              .clamp(300.0, 2000.0);
                                        });
                                      }
                                    },
                                    onPanEnd: (_) => _saveState(),
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      color: Colors.transparent,
                                      child: Icon(Icons.drag_handle, size: 14, color: AppColors.panelTextSecondary),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                 ...[
                  rz(
                      t: 0,
                      l: 12,
                      r: 12,
                      dh: 12,
                      cursor: SystemMouseCursors.resizeUpDown,
                      pan: (d) => setState(() {
                            double nH = _height - d.delta.dy;
                            if (nH >= 300) {
                              _height = nH;
                              _positionNotifier.value += Offset(0, d.delta.dy);
                            }
                          })),
                  rz(
                      b: 0,
                      l: 12,
                      r: 12,
                      dh: 12,
                      cursor: SystemMouseCursors.resizeUpDown,
                      pan: (d) => setState(() {
                            double nH = _height + d.delta.dy;
                            if (nH >= 300) {
                              _height = nH;
                            }
                          })),
                  rz(
                      l: 0,
                      t: 12,
                      b: 12,
                      dw: 12,
                      cursor: SystemMouseCursors.resizeLeftRight,
                      pan: (d) => setState(() {
                            double nW = _width - d.delta.dx;
                            if (nW >= 300) {
                              _width = nW;
                              _positionNotifier.value += Offset(d.delta.dx, 0);
                            }
                          })),
                  rz(
                      r: 0,
                      t: 12,
                      b: 12,
                      dw: 12,
                      cursor: SystemMouseCursors.resizeLeftRight,
                      pan: (d) => setState(() {
                            double nW = _width + d.delta.dx;
                            if (nW >= 300) {
                              _width = nW;
                            }
                          })),
                  rz(
                      t: 0,
                      l: 0,
                      dw: 16,
                      dh: 16,
                      cursor: SystemMouseCursors.resizeUpLeftDownRight,
                      pan: (d) => setState(() {
                            double nW = _width - d.delta.dx;
                            double nH = _height - d.delta.dy;
                            if (nW >= 300) {
                              _width = nW;
                              _positionNotifier.value += Offset(d.delta.dx, 0);
                            }
                            if (nH >= 300) {
                              _height = nH;
                              _positionNotifier.value += Offset(0, d.delta.dy);
                            }
                          })),
                  rz(
                      t: 0,
                      r: 0,
                      dw: 16,
                      dh: 16,
                      cursor: SystemMouseCursors.resizeUpRightDownLeft,
                      pan: (d) => setState(() {
                            double nW = _width + d.delta.dx;
                            double nH = _height - d.delta.dy;
                            if (nW >= 300) {
                              _width = nW;
                            }
                            if (nH >= 300) {
                              _height = nH;
                              _positionNotifier.value += Offset(0, d.delta.dy);
                            }
                          })),
                  rz(
                      b: 0,
                      l: 0,
                      dw: 16,
                      dh: 16,
                      cursor: SystemMouseCursors.resizeUpRightDownLeft,
                      pan: (d) => setState(() {
                            double nW = _width - d.delta.dx;
                            double nH = _height + d.delta.dy;
                            if (nW >= 300) {
                              _width = nW;
                              _positionNotifier.value += Offset(d.delta.dx, 0);
                            }
                            if (nH >= 300) {
                              _height = nH;
                            }
                          })),
                  rz(
                      b: 0,
                      r: 0,
                      dw: 16,
                      dh: 16,
                      cursor: SystemMouseCursors.resizeUpLeftDownRight,
                      pan: (d) => setState(() {
                            double nW = _width + d.delta.dx;
                            double nH = _height + d.delta.dy;
                            if (nW >= 300) {
                              _width = nW;
                            }
                            if (nH >= 300) {
                              _height = nH;
                            }
                          })),
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FlashingBackground extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color flashColor;
  final BoxBorder? border;
  const _FlashingBackground({required this.child, required this.baseColor, required this.flashColor, this.border});
  @override
  State<_FlashingBackground> createState() => _FlashingBackgroundState();
}

class _FlashingBackgroundState extends State<_FlashingBackground> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _colorAnim = ColorTween(begin: widget.baseColor, end: widget.flashColor).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnim,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: _colorAnim.value,
            border: widget.border,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _FlashingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _FlashingIcon({required this.icon, required this.color, this.size = 14});
  @override
  State<_FlashingIcon> createState() => _FlashingIconState();
}

class _FlashingIconState extends State<_FlashingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _ctrl, child: Icon(widget.icon, color: widget.color, size: widget.size));
  }
}

