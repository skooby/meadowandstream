import 'package:path/path.dart' as p;
import '../../../services/auto_backup_service.dart';
import 'dart:io';
import 'dart:async';

import '../../../services/backup_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../widgets/markdown_code_block_builder.dart';
import 'package:flutter/material.dart';
import '../../../app/app.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../constants.dart';
import '../visual_editor_screen.dart';
import '../window_dock_manager.dart';
import '../../../state/global_task_editor_state.dart';

import '../../../services/ai_bridge_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../../widgets/draggable_alert_dialog.dart';
import 'global_color_picker_window.dart';
import 'global_icon_picker_window.dart';
import 'backup_manager_panel.dart';
import '../../../widgets/spell_check_text_editing_controller.dart';
import '../../../state/global_picker_state.dart';
import 'global_notes_editor_window.dart';
import 'attachment_viewer_window.dart';
import '../../../services/version_control_service.dart';
import 'version_control_window.dart';
import '../../../services/sandbox_service.dart';
import '../../../services/local_ai_service.dart';

final ValueNotifier<bool> showTaskEditorNotifier = ValueNotifier(false);

void showTaskEditorWindow(BuildContext context) {
  if (showTaskEditorNotifier.value) {
    try {
      WindowDockManager.instance.panels.firstWhere((p) => p.id == 'task_editor').onFocus?.call();
    } catch (_) {}
    return;
  }
  SharedPreferences.getInstance().then((prefs) =>
      prefs.setBool(VisualEditorScreen.getPrefKey('showTaskEditor'), true));
  showTaskEditorNotifier.value = true;
}

void hideTaskEditorWindow() {
  showTaskEditorNotifier.value = false;
  SharedPreferences.getInstance().then((prefs) =>
      prefs.setBool(VisualEditorScreen.getPrefKey('showTaskEditor'), false));
}

class ChecklistItemContainer extends StatefulWidget {
  final AiVerificationStatus status;
  final bool isPreview;
  final bool isLocked;
  final Widget child;
  const ChecklistItemContainer({Key? key, required this.status, required this.isPreview, this.isLocked = false, required this.child}) : super(key: key);
  @override
  State<ChecklistItemContainer> createState() => _ChecklistItemContainerState();
}

class _ChecklistItemContainerState extends State<ChecklistItemContainer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _colorAnim = ColorTween(begin: Colors.orange.withOpacity(0.3), end: Colors.orangeAccent).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPreview) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: widget.isLocked
                  ? Colors.orangeAccent
                  : widget.status == AiVerificationStatus.verified
                      ? Colors.green
                      : widget.status == AiVerificationStatus.pendingReview
                          ? Colors.orange
                          : widget.status == AiVerificationStatus.submitted
                              ? Colors.blueAccent
                              : widget.status == AiVerificationStatus.ignored
                                  ? Colors.grey.withOpacity(0.5)
                                  : AppColors.controlBorder,
              width: widget.isLocked ? 1.5 : 1.0),
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _colorAnim,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08), // orange background
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
            border: Border(
              left: const BorderSide(color: Colors.orange, width: 4),
              top: BorderSide(color: (_colorAnim.value ?? Colors.orange).withOpacity(0.3)),
              right: BorderSide(color: (_colorAnim.value ?? Colors.orange).withOpacity(0.3)),
              bottom: BorderSide(color: (_colorAnim.value ?? Colors.orange).withOpacity(0.3)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'PREVIEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

class GlobalTaskEditorWindow extends StatefulWidget {
  final VoidCallback onClose;
  final bool isDocked;
  final VoidCallback? onFocus;

  const GlobalTaskEditorWindow(
      {super.key, required this.onClose, this.onFocus, this.isDocked = false});

  @override
  State<GlobalTaskEditorWindow> createState() => _GlobalTaskEditorWindowState();
}

class _GlobalTaskEditorWindowState extends State<GlobalTaskEditorWindow> {
  bool _isLoaded = false;
  double _width = 800;
  double _height = 600;
  double _bgOpacity = 0.4;
  Offset _offset = const Offset(200, 100);

  AiTask? existingTask;
  AiTask? _shadowTask;
  String? preselectedParentId;
  bool forceFolderCreation = false;
  bool forceNoteCreation = false;

  late TextEditingController nameController;
  late TextEditingController descController;
  late TextEditingController summaryController;
  late TextEditingController notesController;
  late TextEditingController newSubTaskController;
  late FocusNode newSubTaskFocus;
  late UndoHistoryController descUndo;
  late UndoHistoryController summaryUndo;
  late UndoHistoryController notesUndo;

  List<AiReviewQuestion> reviewQuestionsList = [];
  bool isReviewQuestionsSectionExpanded = true;
  List<bool> reviewQuestionExpandedState = [];

  List<AiVerificationCriteria> verificationCriteriaList = [];
  List<TextEditingController> _verificationControllers = [];
  List<TextEditingController> _verificationGoalControllers = [];
  bool isVerificationCriteriaSectionExpanded = true;

  bool _isItemLocked(AiVerificationCriteria item) {
    final activePrompt = AiBridgeService.instance.activePrompt;
    if (activePrompt == null) return false;
    if (activePrompt.targetCriteriaDescription == null) return false;
    return activePrompt.targetCriteriaDescription!.trim().toLowerCase() ==
        item.description.trim().toLowerCase();
  }

  List<String> fileAttachments = [];
  List<String> hyperlinks = [];

  bool isFolder = false;
  bool isWorksheet = false;
  String? worksheetId;
  String? originalWorksheetId;
  String? activeParentId;
  bool isNote = false;
  bool isKnowledgeSummary = false;
  bool isPreviewingNotes = true;
  AiTaskStatus? originalStatus;
  AiTaskPriority? originalPriority;
  int? originalHighlightColor;
  int? originalIconBackgroundColor;
  int? originalIconColor;
  int? originalToolbarIconColor;
  int? originalIconCode;
  AiTaskStatus newTaskStatus = AiTaskStatus.inTesting;
  AiTaskPriority newPriority = AiTaskPriority.none;
  int? customHighlightColor;
  int? customIconBackgroundColor;
  int? customIconColor;
  int? customToolbarIconColor;
  int? customIconCode;
  bool preventDeletion = false;
  bool applyLocksToChildren = false;
  bool isReadOnly = false;
  bool isIgnored = false;
  bool isLocked = false;
  String llmPromptStyleOverride = 'Use Default';

  bool isCustomizationExpanded = false;
  bool isForceClosing = false;
  double _dialogLeftRatio = 0.5;
  Timer? _autoSaveTimer;
  int _selectedTabIndex = 0;

  bool isTaskReadOnly = false;

  // To avoid changing the giant UI code:
  void setStateBuilder(void Function() fn) {
    setState(fn);
    GlobalTaskEditorState.instance.hasUnsavedEdits = hasUnsavedEdits;
    GlobalTaskEditorState.instance.unsavedReason = unsavedReason ?? '';
    try {
      File('.ai_bridge/bridge_debug.txt').writeAsStringSync('unsavedReason: ${unsavedReason ?? 'null'}');
    } catch (_) {}
  }

  bool _isImageFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp', '.ico', '.tiff'].contains(ext);
  }


  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _descFocusNode = FocusNode();
  final FocusNode _summaryFocusNode = FocusNode();
  final FocusNode _notesFocusNode = FocusNode();

  void _onFocusChanged() {
    // When focus leaves a text field, immediately flush any pending debounced save.
    // This ensures _shadowTask is updated before the bridge cooldown expires and fires a reload.
    final anyFocused = _nameFocusNode.hasFocus || _descFocusNode.hasFocus ||
        _summaryFocusNode.hasFocus || _notesFocusNode.hasFocus || newSubTaskFocus.hasFocus;
    
    // Toggle spell check based on focus
    if (nameController is SpellCheckTextEditingController) {
      (nameController as SpellCheckTextEditingController).setEditing(_nameFocusNode.hasFocus);
    }
    if (descController is SpellCheckTextEditingController) {
      (descController as SpellCheckTextEditingController).setEditing(_descFocusNode.hasFocus);
    }
    if (summaryController is SpellCheckTextEditingController) {
      (summaryController as SpellCheckTextEditingController).setEditing(_summaryFocusNode.hasFocus);
    }
    if (notesController is SpellCheckTextEditingController) {
      (notesController as SpellCheckTextEditingController).setEditing(_notesFocusNode.hasFocus);
    }

    if (!anyFocused && hasUnsavedEdits) {
      _executeAutoSave(instant: true);
    }
  }

  @override
  void initState() {
    super.initState();
    nameController = SpellCheckTextEditingController();
    descController = SpellCheckTextEditingController();
    summaryController = SpellCheckTextEditingController();
    notesController = SpellCheckTextEditingController();
    newSubTaskController = SpellCheckTextEditingController();
    newSubTaskFocus = FocusNode();
    _nameFocusNode.addListener(_onFocusChanged);
    _descFocusNode.addListener(_onFocusChanged);
    _summaryFocusNode.addListener(_onFocusChanged);
    _notesFocusNode.addListener(_onFocusChanged);
    newSubTaskFocus.addListener(_onFocusChanged);

    // Update UI on text changed to reflect Save button state
    nameController.addListener(_executeAutoSave);
    descController.addListener(_executeAutoSave);
    summaryController.addListener(_executeAutoSave);
    notesController.addListener(_executeAutoSave);

    descUndo = UndoHistoryController();
    summaryUndo = UndoHistoryController();
    notesUndo = UndoHistoryController();

    _loadPreferences();
    VisualEditorScreen.currentWorkspace.addListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.addListener(_loadPreferences);
    VisualEditorScreen.activeWindowNotifier.addListener(_onActiveWindowChanged);
    GlobalTaskEditorState.instance.activeRequest.addListener(_onRequestChanged);

    if (GlobalTaskEditorState.instance.activeRequest.value != null) {
      _applyRequest(GlobalTaskEditorState.instance.activeRequest.value!);
    }

    AiBridgeService.instance.addListener(_onAiBridgeTasksChanged);
    // Register the flush callback so the reload pipeline can force-save before reloading
    GlobalTaskEditorState.instance.flushPendingSave = () => _executeAutoSave(instant: true);
  }

  @override
  void dispose() {
    GlobalTaskEditorState.instance.hasUnsavedEdits = false;
    GlobalTaskEditorState.instance.flushPendingSave = null;
    VisualEditorScreen.currentWorkspace.removeListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.removeListener(_loadPreferences);
    GlobalTaskEditorState.instance.activeRequest
        .removeListener(_onRequestChanged);

    _nameFocusNode.removeListener(_onFocusChanged);
    _descFocusNode.removeListener(_onFocusChanged);
    _summaryFocusNode.removeListener(_onFocusChanged);
    _notesFocusNode.removeListener(_onFocusChanged);
    newSubTaskFocus.removeListener(_onFocusChanged);

    nameController.removeListener(_executeAutoSave);
    descController.removeListener(_executeAutoSave);
    summaryController.removeListener(_executeAutoSave);
    notesController.removeListener(_executeAutoSave);

    _nameFocusNode.dispose();
    _descFocusNode.dispose();
    _notesFocusNode.dispose();
    nameController.dispose();
    descController.dispose();
    summaryController.dispose();
    notesController.dispose();
    newSubTaskController.dispose();
    newSubTaskFocus.dispose();
    descUndo.dispose();
    summaryUndo.dispose();
    notesUndo.dispose();
    _autoSaveTimer?.cancel();
    for (var c in _verificationControllers) {
      c.dispose();
    }
    for (var c in _verificationGoalControllers) {
      c.dispose();
    }
    AiBridgeService.instance.removeListener(_onAiBridgeTasksChanged);
    VisualEditorScreen.activeWindowNotifier.removeListener(_onActiveWindowChanged);
    super.dispose();
  }

  void _onActiveWindowChanged() {
    if (mounted) setState(() {});
  }

  void _insertMarkdown(String prefix) {
    final text = notesController.text;
    final selection = notesController.selection;
    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, prefix);
      notesController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + prefix.length),
      );
    } else {
      notesController.text += prefix;
    }
    _executeAutoSave();
  }

  void _performAutoSave({bool isClosing = false}) {
    // We don't auto-save anymore, but we do need to rebuild the UI
    // to dynamically update the Save button state based on hasUnsavedEdits.
    try {
      setStateBuilder(() {});
    } catch (_) {}
  }

  Future<void> _executeAutoSave(
      {bool isClosing = false, bool instant = false}) async {
    _autoSaveTimer?.cancel();
    if (isClosing || instant) {
      await _executeAutoSaveInternal(isClosing: isClosing);
    } else {
      _autoSaveTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) {
          _executeAutoSaveInternal(isClosing: false);
        }
      });
    }
  }

  String? get unsavedReason {
    if (existingTask == null || _shadowTask == null) {
      if (nameController.text.trim().isNotEmpty) return 'nameController';
      if (descController.text.trim().isNotEmpty) return 'descController';
      if (notesController.text.trim().isNotEmpty) return 'notesController';
      if (verificationCriteriaList.isNotEmpty) return 'verificationCriteriaList';
      return null;
    }

    if (reviewQuestionsList.length != _shadowTask!.reviewQuestions.length) return 'reviewQuestionsList length';
    for (int i = 0; i < reviewQuestionsList.length; i++) {
      if (reviewQuestionsList[i].selectedOption != _shadowTask!.reviewQuestions[i].selectedOption) return 'reviewQuestionsList[$i]';
    }

    if (verificationCriteriaList.length != _shadowTask!.verificationCriteria.length) return 'verificationCriteriaList length';
    for (int i = 0; i < verificationCriteriaList.length; i++) {
        if (verificationCriteriaList[i].description != _shadowTask!.verificationCriteria[i].description) return 'verificationCriteriaList[$i].description';
        if (verificationCriteriaList[i].goal != _shadowTask!.verificationCriteria[i].goal) return 'verificationCriteriaList[$i].goal';
        if (verificationCriteriaList[i].status != _shadowTask!.verificationCriteria[i].status) return 'verificationCriteriaList[$i].status';
        if (verificationCriteriaList[i].isVerified != _shadowTask!.verificationCriteria[i].isVerified) return 'verificationCriteriaList[$i].isVerified';
        if (verificationCriteriaList[i].proof != _shadowTask!.verificationCriteria[i].proof) return 'verificationCriteriaList[$i].proof';
        if (verificationCriteriaList[i].notes != _shadowTask!.verificationCriteria[i].notes) return 'verificationCriteriaList[$i].notes';
        if (verificationCriteriaList[i].requestClarification != _shadowTask!.verificationCriteria[i].requestClarification) return 'verificationCriteriaList[$i].requestClarification';
        if (verificationCriteriaList[i].tryCount != _shadowTask!.verificationCriteria[i].tryCount) return 'verificationCriteriaList[$i].tryCount';
    }

    if (nameController.text.replaceAll('\r', '').trim() != _shadowTask!.name.replaceAll('\r', '').trim()) return 'name';
    if (descController.text.replaceAll('\r', '').trim() != _shadowTask!.description.replaceAll('\r', '').trim()) return 'description';
    if (summaryController.text.replaceAll('\r', '').trim() != _shadowTask!.summary.replaceAll('\r', '').trim()) return 'summary';
    if (notesController.text.replaceAll('\r', '').trim() != _shadowTask!.notes.replaceAll('\r', '').trim()) return 'notes';
    if (isWorksheet != _shadowTask!.isWorksheet) return 'isWorksheet';
    if (isFolder != _shadowTask!.isFolder) return 'isFolder';
    if (isNote != _shadowTask!.isNote) return 'isNote';
    if (isKnowledgeSummary != _shadowTask!.isKnowledgeSummary) return 'isKnowledgeSummary';
    if (activeParentId != _shadowTask!.parentId) return 'parentId';
    if (worksheetId != _shadowTask!.worksheetId) return 'worksheetId';
    if (originalHighlightColor != customHighlightColor) return 'highlightColor';
    if (originalIconBackgroundColor != customIconBackgroundColor) return 'iconBackgroundColor';
    if (originalIconColor != customIconColor) return 'iconColor';
    if (originalToolbarIconColor != customToolbarIconColor) return 'toolbarIconColor';
    if (originalIconCode != customIconCode) return 'iconCodePoint';
    if (_shadowTask!.preventDeletion != preventDeletion) return 'preventDeletion';
    if (_shadowTask!.applyLocksToChildren != applyLocksToChildren) return 'applyLocksToChildren';
    if (_shadowTask!.isReadOnly != isReadOnly) return 'isReadOnly';
    if (_shadowTask!.isIgnored != isIgnored) return 'isIgnored';
    if (_shadowTask!.isLocked != isLocked) return 'isLocked';
    if (_shadowTask!.llmPromptStyleOverride != llmPromptStyleOverride) return 'llmPromptStyleOverride';
    if (originalStatus != _shadowTask!.status) return 'status';
    if (fileAttachments.join(',') != _shadowTask!.fileAttachments.join(',')) return 'fileAttachments';
    if (hyperlinks.join(',') != _shadowTask!.hyperlinks.join(',')) return 'hyperlinks';
    
    return null;
  }
  
  bool get hasUnsavedEdits => unsavedReason != null;

  Future<void> _executeAutoSaveInternal({bool isClosing = false}) async {
    try { File('.ai_bridge/bridge_debug.txt').writeAsStringSync('[SAVE-1] started. vcList=${verificationCriteriaList.length} shadow=${_shadowTask?.verificationCriteria.length ?? -1} reason=${unsavedReason ?? 'null'}'); } catch(_) {}
    if (existingTask == null) {
      if (!hasUnsavedEdits) return; // Don't create empty task
      if (isFolder || isWorksheet || isNote || isKnowledgeSummary) {
        existingTask = await AiBridgeService.instance.addTask(
            nameController.text.trim(), descController.text.trim(),
            notes: notesController.text.trim(),
            isFolder: isFolder,
            isWorksheet: isWorksheet,
            isNote: isNote,
            isKnowledgeSummary: isKnowledgeSummary,
            parentId: activeParentId,
            worksheetId: worksheetId,
            status: originalStatus,
            highlightColor: customHighlightColor,
            iconBackgroundColor: customIconBackgroundColor,
            iconColor: customIconColor,
            toolbarIconColor: customToolbarIconColor,
            iconCodePoint: customIconCode);
      } else {
        existingTask = await AiBridgeService.instance.addTask(
            nameController.text.trim(), descController.text.trim(),
            notes: notesController.text.trim(),
            isWorksheet: isWorksheet,
            worksheetId: worksheetId,
            status: originalStatus,
            highlightColor: customHighlightColor,
            iconBackgroundColor: customIconBackgroundColor,
            iconColor: customIconColor,
            toolbarIconColor: customToolbarIconColor,
            iconCodePoint: customIconCode,
            parentId: activeParentId);
      }
      _shadowTask = AiTask.fromJson(existingTask!.toJson());
      setStateBuilder(() {});
    }

    if (!hasUnsavedEdits) return;

    AiTaskStatus newStatus = existingTask!.status;
    if ((originalStatus == AiTaskStatus.inTesting || originalStatus == AiTaskStatus.completed) &&
        existingTask!.status == originalStatus) {
      final prefs = await SharedPreferences.getInstance();
      final afterEditStr =
          prefs.getString('ai_tasks_bridge_edit_status') ?? 'dontChange';
      if (afterEditStr != 'dontChange') {
        newStatus = AiTaskStatus.values.firstWhere(
            (e) => e.name == afterEditStr,
            orElse: () => AiTaskStatus.inTesting);

        if (newStatus == AiTaskStatus.inProgress) {
          bool hasTasksToPerform = verificationCriteriaList
              .any((e) => (e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored && !e.isPreview));
          if (!hasTasksToPerform) {
            newStatus = originalStatus!;
          }
        }
      }
    }

    // Update local state to match saved state BEFORE async network/file call
    // This prevents file watcher race conditions where notifyListeners() fires before we update _shadowTask!
    existingTask!.name = nameController.text.trim();
    existingTask!.description = descController.text.trim();
    existingTask!.summary = summaryController.text.trim();
    existingTask!.isWorksheet = isWorksheet;
    existingTask!.parentId = activeParentId;
    existingTask!.notes = notesController.text.trim();
    existingTask!.verificationCriteria = isFolder
        ? <AiVerificationCriteria>[]
        : verificationCriteriaList
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
                isPreview: e.isPreview))
            .toList();
    existingTask!.reviewQuestions = reviewQuestionsList
        .map((e) => AiReviewQuestion(
            question: e.question,
            options: List.from(e.options),
            selectedOption: e.selectedOption))
        .toList();
    existingTask!.status = newStatus;
    existingTask!.highlightColor = customHighlightColor;
    existingTask!.iconBackgroundColor = customIconBackgroundColor;
    existingTask!.iconColor = customIconColor;
    existingTask!.toolbarIconColor = customToolbarIconColor;
    existingTask!.iconCodePoint = customIconCode;
    existingTask!.preventDeletion = preventDeletion;
    existingTask!.applyLocksToChildren = applyLocksToChildren;
    existingTask!.isReadOnly = isReadOnly;
    existingTask!.isIgnored = isIgnored;
    existingTask!.isLocked = isLocked;
    existingTask!.llmPromptStyleOverride = llmPromptStyleOverride;

    // Compute didCompleteChecklist BEFORE rebuilding shadow so we compare
    // the OLD shadow state (pre-edit) against the NEW verificationCriteriaList.
    // Previously this ran after the shadow was rebuilt, making old == new always.
    bool? didCompleteChecklist;
    if (_shadowTask != null && verificationCriteriaList.isNotEmpty) {
      bool oldHasUnverified = _shadowTask!.verificationCriteria.any((e) => e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored);
      bool newHasUnverified = verificationCriteriaList.any((e) => e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored);
      if (oldHasUnverified && !newHasUnverified) {
        didCompleteChecklist = true;
      } else {
        didCompleteChecklist = false;
      }
    }

    // Rebuild shadow BEFORE the async call so _onAiBridgeTasksChanged sees a clean state
    _shadowTask = AiTask.fromJson(existingTask!.toJson());
    try { File('.ai_bridge/bridge_debug.txt').writeAsStringSync('[SAVE-2] shadow rebuilt early. vcList=${verificationCriteriaList.length} shadow=${_shadowTask?.verificationCriteria.length ?? -1} reason=${unsavedReason ?? 'null'}'); } catch(_) {}

    originalStatus = newStatus;
    originalHighlightColor = customHighlightColor;
    originalIconBackgroundColor = customIconBackgroundColor;
    originalIconColor = customIconColor;
    originalToolbarIconColor = customToolbarIconColor;
    originalIconCode = customIconCode;

    await AiBridgeService.instance.updateTaskDetails(existingTask!.id,
        nameController.text.trim(), descController.text.trim(),
        summary: summaryController.text.trim(),
        notes: notesController.text.trim(),
        isWorksheet: isWorksheet,
        didCompleteChecklist: didCompleteChecklist,
        verificationCriteria: verificationCriteriaList
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
                isPreview: e.isPreview))
            .toList(),
        reviewQuestions: reviewQuestionsList
            .map((e) => AiReviewQuestion(
                question: e.question,
                options: List.from(e.options),
                selectedOption: e.selectedOption))
            .toList(),
        status: newStatus,
        highlightColor: customHighlightColor,
        clearHighlightColor: customHighlightColor == null,
        iconBackgroundColor: customIconBackgroundColor,
        clearIconBackgroundColor: customIconBackgroundColor == null,
        iconColor: customIconColor,
        clearIconColor: customIconColor == null,
        toolbarIconColor: customToolbarIconColor,
        clearToolbarIconColor: customToolbarIconColor == null,
        preventDeletion: preventDeletion,
        applyLocksToChildren: applyLocksToChildren,
        isReadOnly: isReadOnly,
        isIgnored: isIgnored,
        isLocked: isLocked,
        llmPromptStyleOverride: llmPromptStyleOverride,
        iconCodePoint: customIconCode,
        clearIcon: customIconCode == null,
        parentId: activeParentId,
        clearParentId: activeParentId == null,
        worksheetId: worksheetId,
        clearWorksheetId: worksheetId == null,
        fileAttachments: List.from(fileAttachments),
        hyperlinks: List.from(hyperlinks),
        isFolder: isFolder,
        isNote: isNote,
        isKnowledgeSummary: isKnowledgeSummary);

    try { File('.ai_bridge/bridge_debug.txt').writeAsStringSync('[SAVE-3] after updateTaskDetails. vcList=${verificationCriteriaList.length} shadow=${_shadowTask?.verificationCriteria.length ?? -1} reason=${unsavedReason ?? 'null'}'); } catch(_) {}

    if (existingTask!.id == 'unassigned_ws' ||
        AiBridgeService.instance.tasks.any((t) => t.id == existingTask!.id)) {
      await AiBridgeService.instance.saveTasks();
    }

    _shadowTask = AiTask.fromJson(existingTask!.toJson());

    try { File('.ai_bridge/bridge_debug.txt').writeAsStringSync('[SAVE-4] shadow rebuilt post-save. vcList=${verificationCriteriaList.length} shadow=${_shadowTask?.verificationCriteria.length ?? -1} reason=${unsavedReason ?? 'null'}'); } catch(_) {}

    if (mounted) {
      try {
        // Force-clear dirty state after a successful save, regardless of any listener
        // re-entrancy that may have temporarily flipped unsavedReason back to non-null.
        GlobalTaskEditorState.instance.hasUnsavedEdits = false;
        GlobalTaskEditorState.instance.unsavedReason = '';
        setState(() {});
        try { File('.ai_bridge/bridge_debug.txt').writeAsStringSync('[SAVE-5] done. reason=${unsavedReason ?? 'null'} globalDirty=${GlobalTaskEditorState.instance.hasUnsavedEdits}'); } catch(_) {}
      } catch (_) {}
    }
  }


  void _onRequestChanged() {
    final req = GlobalTaskEditorState.instance.activeRequest.value;
    if (req != null) {
      if (existingTask != null && existingTask!.id != req.existingTask?.id) {
        if (newSubTaskController.text.trim().isNotEmpty) {
          verificationCriteriaList.add(AiVerificationCriteria(
              description: newSubTaskController.text.trim()));
          _verificationControllers.add(TextEditingController(
              text: newSubTaskController.text.trim()));
          _verificationGoalControllers.add(TextEditingController());
          newSubTaskController.clear();
        }
        if (hasUnsavedEdits) {
          _executeAutoSaveInternal(isClosing: true);
        }
      }
      _applyRequest(req);
    }
  }

  void _onAiBridgeTasksChanged() {
    if (existingTask != null && _shadowTask != null) {
      setStateBuilder(() {
        isTaskReadOnly = existingTask != null &&
            AiBridgeService.instance.isTaskReadOnly(existingTask!.id);
      });
      final matches =
          AiBridgeService.instance.tasks.where((t) => t.id == existingTask!.id);
      if (matches.isNotEmpty) {
        final updatedTask = matches.first;

        bool didGranularMerge = false;
        if (updatedTask.notes != _shadowTask!.notes) {
          String normalizedNew = updatedTask.notes.replaceAll('\r', '').trim();
          String normalizedOld = _shadowTask!.notes.replaceAll('\r', '').trim();
          
          if (normalizedNew == normalizedOld) {
            _shadowTask!.notes = updatedTask.notes;
            existingTask!.notes = updatedTask.notes;
          } else if (notesController.text.replaceAll('\r', '').trim() == normalizedOld) {
            // Update shadow BEFORE controller so listener fires against up-to-date shadow
            existingTask!.notes = updatedTask.notes;
            _shadowTask!.notes = updatedTask.notes;
            notesController.text = updatedTask.notes;
            didGranularMerge = true;
          } else {
            String oldNotes = _shadowTask!.notes.replaceAll('\r', '');
            String newNotes = updatedTask.notes.replaceAll('\r', '');
            // Update shadow BEFORE controller so listener fires against up-to-date shadow
            existingTask!.notes = updatedTask.notes;
            _shadowTask!.notes = updatedTask.notes;
            if (newNotes.startsWith(oldNotes)) {
              notesController.text = notesController.text + newNotes.substring(oldNotes.length);
            } else if (newNotes.endsWith(oldNotes)) {
              notesController.text =
                  newNotes.substring(0, newNotes.length - oldNotes.length) +
                      notesController.text;
            } else {
              notesController.text = newNotes + '\n\n' + notesController.text;
            }
            didGranularMerge = true;
          }
        }
        if (descController.text.replaceAll('\r', '').trim() ==
                _shadowTask!.description.replaceAll('\r', '').trim() &&
            updatedTask.description != _shadowTask!.description) {
          existingTask!.description = updatedTask.description;
          _shadowTask!.description = updatedTask.description;
          descController.removeListener(_executeAutoSave);
          descController.text = updatedTask.description;
          descController.addListener(_executeAutoSave);
          didGranularMerge = true;
        }
        if (summaryController.text.replaceAll('\r', '').trim() ==
                _shadowTask!.summary.replaceAll('\r', '').trim() &&
            updatedTask.summary != _shadowTask!.summary) {
          existingTask!.summary = updatedTask.summary;
          _shadowTask!.summary = updatedTask.summary;
          summaryController.removeListener(_executeAutoSave);
          summaryController.text = updatedTask.summary;
          summaryController.addListener(_executeAutoSave);
          didGranularMerge = true;
        }
        if (nameController.text.replaceAll('\r', '').trim() ==
                _shadowTask!.name.replaceAll('\r', '').trim() &&
            updatedTask.name != _shadowTask!.name) {
          existingTask!.name = updatedTask.name;
          _shadowTask!.name = updatedTask.name;
          nameController.removeListener(_executeAutoSave);
          nameController.text = updatedTask.name;
          nameController.addListener(_executeAutoSave);
          didGranularMerge = true;
        }
        if (existingTask!.status == originalStatus &&
            updatedTask.status != originalStatus) {
          originalStatus = updatedTask.status;
          newTaskStatus = updatedTask.status;
          existingTask!.status = updatedTask.status;
          _shadowTask!.status = updatedTask.status;
          didGranularMerge = true;
        }

        // Granular merge for verificationCriteria
        bool criteriaChanged = false;
        
        while (_shadowTask!.verificationCriteria.length > updatedTask.verificationCriteria.length) {
          _shadowTask!.verificationCriteria.removeLast();
          existingTask!.verificationCriteria.removeLast();
          criteriaChanged = true;
        }

        for (int i = 0; i < updatedTask.verificationCriteria.length; i++) {
          if (i >= _shadowTask!.verificationCriteria.length) {
            _shadowTask!.verificationCriteria.add(updatedTask.verificationCriteria[i]);
            existingTask!.verificationCriteria.add(updatedTask.verificationCriteria[i]);
            criteriaChanged = true;
          } else {
            if (updatedTask.verificationCriteria[i].description != _shadowTask!.verificationCriteria[i].description ||
                updatedTask.verificationCriteria[i].isVerified != _shadowTask!.verificationCriteria[i].isVerified ||
                updatedTask.verificationCriteria[i].status != _shadowTask!.verificationCriteria[i].status ||
                updatedTask.verificationCriteria[i].proof != _shadowTask!.verificationCriteria[i].proof ||
                updatedTask.verificationCriteria[i].notes != _shadowTask!.verificationCriteria[i].notes ||
                updatedTask.verificationCriteria[i].isCommitted != _shadowTask!.verificationCriteria[i].isCommitted ||
                updatedTask.verificationCriteria[i].isPreview != _shadowTask!.verificationCriteria[i].isPreview) {
              
              _shadowTask!.verificationCriteria[i].description = updatedTask.verificationCriteria[i].description;
              _shadowTask!.verificationCriteria[i].isVerified = updatedTask.verificationCriteria[i].isVerified;
              _shadowTask!.verificationCriteria[i].status = updatedTask.verificationCriteria[i].status;
              _shadowTask!.verificationCriteria[i].proof = updatedTask.verificationCriteria[i].proof;
              _shadowTask!.verificationCriteria[i].notes = updatedTask.verificationCriteria[i].notes;
              _shadowTask!.verificationCriteria[i].isCommitted = updatedTask.verificationCriteria[i].isCommitted;
              _shadowTask!.verificationCriteria[i].isPreview = updatedTask.verificationCriteria[i].isPreview;
              
              existingTask!.verificationCriteria[i].description = updatedTask.verificationCriteria[i].description;
              existingTask!.verificationCriteria[i].isVerified = updatedTask.verificationCriteria[i].isVerified;
              existingTask!.verificationCriteria[i].status = updatedTask.verificationCriteria[i].status;
              existingTask!.verificationCriteria[i].proof = updatedTask.verificationCriteria[i].proof;
              existingTask!.verificationCriteria[i].notes = updatedTask.verificationCriteria[i].notes;
              existingTask!.verificationCriteria[i].isCommitted = updatedTask.verificationCriteria[i].isCommitted;
              existingTask!.verificationCriteria[i].isPreview = updatedTask.verificationCriteria[i].isPreview;
              criteriaChanged = true;
            }
          }
        }
        
        if (criteriaChanged) {
           didGranularMerge = true;
           // also update UI state list directly
           verificationCriteriaList = _shadowTask!.verificationCriteria.map((e) => AiVerificationCriteria(
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
                isPreview: e.isPreview)).toList();
        
           while (_verificationControllers.length < verificationCriteriaList.length) {
             _verificationControllers.add(SpellCheckTextEditingController(text: verificationCriteriaList[_verificationControllers.length].description));
             _verificationGoalControllers.add(SpellCheckTextEditingController(text: verificationCriteriaList[_verificationGoalControllers.length].goal));
           }
           while (_verificationControllers.length > verificationCriteriaList.length) {
             _verificationControllers.removeLast().dispose();
             _verificationGoalControllers.removeLast().dispose();
           }
           
           for (int i = 0; i < verificationCriteriaList.length; i++) {
             if (_verificationControllers[i].text != verificationCriteriaList[i].description) {
               _verificationControllers[i].text = verificationCriteriaList[i].description;
             }
             if (_verificationGoalControllers[i].text != (verificationCriteriaList[i].goal ?? '')) {
               _verificationGoalControllers[i].text = verificationCriteriaList[i].goal ?? '';
             }
           }
        }

        if (didGranularMerge && mounted) {
          try {
            setStateBuilder(() {});
          } catch (_) {}
        }

        // Do not process full background syncs if we have pending un-saved edits.
        // This prevents the UI from overwriting the user's active work.
        if (hasUnsavedEdits) {
          try {
            String reason = '';
            if (nameController.text.replaceAll('\r', '').trim() !=
                (_shadowTask!.name.replaceAll('\r', '').trim()))
              reason += 'name; ';
            if (descController.text.replaceAll('\r', '').trim() !=
                (_shadowTask!.description.replaceAll('\r', '').trim()))
              reason += 'desc; ';
            if (notesController.text.replaceAll('\r', '').trim() !=
                (_shadowTask!.notes.replaceAll('\r', '').trim()))
              reason += 'notes; ';
            if (existingTask!.worksheetId != originalWorksheetId)
              reason += 'worksheetId; ';
            if (existingTask!.status != originalStatus) reason += 'status; ';
            if (existingTask!.priority != originalPriority)
              reason += 'priority; ';
            if (originalHighlightColor != customHighlightColor)
              reason += 'highlightColor; ';
            if (originalIconBackgroundColor != customIconBackgroundColor)
              reason += 'iconBackgroundColor; ';
            if (originalIconColor != customIconColor) reason += 'iconColor; ';
            if (originalToolbarIconColor != customToolbarIconColor)
              reason += 'toolbarIconColor; ';
            if (originalIconCode != customIconCode) reason += 'iconCode; ';
            if (existingTask!.preventDeletion != preventDeletion)
              reason += 'preventDeletion; ';
            if (existingTask!.isLocked != isLocked)
              reason += 'isLocked; ';

            File('.ai_bridge/bridge_debug.txt').writeAsStringSync(
                'hasUnsavedEdits is TRUE! Reason: $reason\n',
                mode: FileMode.append);
          } catch (e) {}
          return;
        }

        _applyRequest(TaskEditorRequest(existingTask: updatedTask));
      }
    }
  }

  void _applyRequest(TaskEditorRequest req) {
    setState(() {
      final oldShadowTask = _shadowTask;
      existingTask = req.existingTask;
      if (existingTask != null) {
        _shadowTask = AiTask.fromJson(existingTask!.toJson());
      }
      preselectedParentId = req.preselectedParentId;
      activeParentId = existingTask?.parentId ?? preselectedParentId;
      forceFolderCreation = req.forceFolderCreation;
      forceNoteCreation = req.forceNoteCreation;

      isTaskReadOnly = existingTask != null &&
          AiBridgeService.instance.isTaskReadOnly(existingTask!.id);
      if (existingTask != null && !existingTask!.isRead) {
        existingTask!.isRead = true;
        AiBridgeService.instance.updateTaskRead(existingTask!.id, true);
      }

      bool isNewTask = oldShadowTask?.id != existingTask?.id;

      if (isNewTask || existingTask?.name != oldShadowTask?.name) {
        nameController.text = (existingTask?.name) ?? '';
      }
      if (isNewTask ||
          existingTask?.description != oldShadowTask?.description) {
        descController.text = (existingTask?.description) ?? '';
      }
      if (isNewTask ||
          existingTask?.summary != oldShadowTask?.summary) {
        final rawSummary = (existingTask?.summary) ?? '';
        summaryController.text = rawSummary;
      }
      if (isNewTask || existingTask?.notes != oldShadowTask?.notes) {
        notesController.text = (existingTask?.notes) ?? '';
      }
      if (isNewTask) {
        newSubTaskController.clear();
      }

      reviewQuestionsList = (existingTask?.reviewQuestions)
              ?.map((e) => AiReviewQuestion(
                  question: e.question,
                  options: List.from(e.options),
                  selectedOption: e.selectedOption))
              .toList() ??
          [];

      isReviewQuestionsSectionExpanded = true;
      reviewQuestionExpandedState =
          List.filled(reviewQuestionsList.length, true);

      verificationCriteriaList = (existingTask?.verificationCriteria)
              ?.map((e) => AiVerificationCriteria(
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
                  isPreview: e.isPreview))
              .toList() ??
          [];

      for (int i = 0; i < verificationCriteriaList.length; i++) {
        if (i < _verificationControllers.length) {
          if (_verificationControllers[i].text !=
              verificationCriteriaList[i].description) {
            _verificationControllers[i].text =
                verificationCriteriaList[i].description;
          }
          if (_verificationGoalControllers[i].text !=
              verificationCriteriaList[i].goal) {
            _verificationGoalControllers[i].text =
                verificationCriteriaList[i].goal;
          }
        } else {
          _verificationControllers.add(SpellCheckTextEditingController(
              text: verificationCriteriaList[i].description));
          _verificationGoalControllers.add(SpellCheckTextEditingController(
              text: verificationCriteriaList[i].goal));
        }
      }
      while (
          _verificationControllers.length > verificationCriteriaList.length) {
        _verificationControllers.removeLast().dispose();
        _verificationGoalControllers.removeLast().dispose();
      }

      isVerificationCriteriaSectionExpanded = true;

      fileAttachments = List.from((existingTask?.fileAttachments) ?? []);
      hyperlinks = List.from((existingTask?.hyperlinks) ?? []);

      isFolder = (existingTask?.isFolder) ?? forceFolderCreation;
      isWorksheet = (existingTask?.isWorksheet) ?? false;
      _selectedTabIndex = (isFolder || isWorksheet) ? 1 : 0;
      isNote = (existingTask?.isNote) ?? forceNoteCreation;
      isKnowledgeSummary = (existingTask?.isKnowledgeSummary) ?? false;
      worksheetId = existingTask?.worksheetId;
      if (worksheetId == null && existingTask == null && !isWorksheet) {
        // If creating a child task, inherit the parent folder's worksheetId first
        if (preselectedParentId != null) {
          final parentTask = AiBridgeService.instance.tasks
              .where((t) => t.id == preselectedParentId)
              .firstOrNull;
          if (parentTask != null) {
            worksheetId = parentTask.isWorksheet ? parentTask.id : parentTask.worksheetId;
          }
        }
        // Fall back to the first visible worksheet if still null
        if (worksheetId == null) {
          final visibleWs = AiBridgeService.instance.worksheets.where((w) => w.isWorksheetVisible).toList();
          if (visibleWs.isNotEmpty) {
            worksheetId = visibleWs.first.id;
          }
        }
      }
      originalWorksheetId = existingTask?.worksheetId;
      originalStatus = (existingTask?.status);
      originalPriority = (existingTask?.priority);
      originalHighlightColor = (existingTask?.highlightColor);
      originalIconBackgroundColor = (existingTask?.iconBackgroundColor);
      originalIconColor = (existingTask?.iconColor);
      originalIconCode = (existingTask?.iconCodePoint);

      newTaskStatus = AiBridgeService.instance.defaultNewStatus;
      newPriority = AiTaskPriority.none;
      customHighlightColor = (existingTask?.highlightColor);
      customIconBackgroundColor = (existingTask?.iconBackgroundColor);
      customIconColor = (existingTask?.iconColor);
      customToolbarIconColor = (existingTask?.toolbarIconColor);
      customIconCode = (existingTask?.iconCodePoint);

      preventDeletion = (existingTask?.preventDeletion) ?? false;
      applyLocksToChildren = (existingTask?.applyLocksToChildren) ?? false;
      isReadOnly = (existingTask?.isReadOnly) ?? false;
      isIgnored = (existingTask?.isIgnored) ?? false;
      isLocked = (existingTask?.isLocked) ?? false;
      llmPromptStyleOverride =
          (existingTask?.llmPromptStyleOverride) ?? 'Use Default';

      isCustomizationExpanded = false;
      isForceClosing = false;
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isLoaded = true;
        _width = prefs.getDouble(
                VisualEditorScreen.getPrefKey('task_editor_width')) ??
            800;
        _height = prefs.getDouble(
                VisualEditorScreen.getPrefKey('task_editor_height')) ??
            600;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.4;
        double dx =
            prefs.getDouble(VisualEditorScreen.getPrefKey('task_editor_dx')) ??
                200;
        double dy =
            prefs.getDouble(VisualEditorScreen.getPrefKey('task_editor_dy')) ??
                100;
        _offset = Offset(dx, dy);
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
        VisualEditorScreen.getPrefKey('task_editor_width'), _width);
    await prefs.setDouble(
        VisualEditorScreen.getPrefKey('task_editor_height'), _height);
    await prefs.setDouble(
        VisualEditorScreen.getPrefKey('task_editor_dx'), _offset.dx);
    await prefs.setDouble(
        VisualEditorScreen.getPrefKey('task_editor_dy'), _offset.dy);
  }

  void _handleClose() {
    if (!isForceClosing) {
      if (newSubTaskController.text.trim().isNotEmpty) {
        verificationCriteriaList.add(AiVerificationCriteria(
            description: newSubTaskController.text.trim()));
        _verificationControllers.add(TextEditingController(
            text: newSubTaskController.text.trim()));
        _verificationGoalControllers.add(TextEditingController());
        newSubTaskController.clear();
      }
      if (hasUnsavedEdits) {
        _executeAutoSaveInternal(isClosing: true);
      }
    }
    widget.onClose();
  }

  Widget _buildTaskEditorPreviewActionBanner(BuildContext context) {
    if (existingTask == null) return const SizedBox.shrink();
    final t = existingTask!;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        border: Border.all(color: Colors.orange, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.rate_review, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Proposed Tasks Ready for Review',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppUIConfig.smallFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Review proposed checklist items. Approve to run them, or Reject to send feedback.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppUIConfig.smallFontSize * 0.9,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: () async {
                  await AiBridgeService.instance.approvePreview(t.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Preview approved. Starting tasks...'))
                    );
                  }
                },
                child: Text('Approve', style: TextStyle(fontSize: AppUIConfig.smallFontSize * 0.9, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: () => _showRejectFeedbackDialog(context, t.id),
                child: Text('Reject', style: TextStyle(fontSize: AppUIConfig.smallFontSize * 0.9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRejectFeedbackDialog(BuildContext context, String taskId) {
    final controller = TextEditingController();
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panelBackground,
        title: const Text('Provide Rejection Feedback', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tell the AI why these tasks are being rejected and what changes are needed:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Enter feedback here...',
                hintStyle: TextStyle(color: Colors.white30),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              final feedback = controller.text.trim();
              Navigator.pop(ctx);
              if (feedback.isNotEmpty) {
                await AiBridgeService.instance.rejectPreview(taskId, feedback);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Preview rejected. Feedback sent to AI.'))
                  );
                }
              }
            },
            child: const Text('Submit Rejection', style: TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    BuildContext ctx = context;
    if (!_isLoaded) return const SizedBox.shrink();

    // To prevent giant modifications, we assign to local _width/_height

    Widget rz({
      double? t,
      double? b,
      double? l,
      double? r,
      double? w,
      double? h,
      required SystemMouseCursor cursor,
      required void Function(DragUpdateDetails) pan,
    }) =>
        Positioned(
            top: t,
            bottom: b,
            left: l,
            right: r,
            width: w,
            height: h,
            child: MouseRegion(
                cursor: cursor,
                child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) {
                      pan(d);
                      setState(() {
                        _width = _width;
                        _height = _height;
                        _offset = _offset;
                      });
                    },
                    onPanEnd: (_) async {
                      await _savePreferences();
                    },
                    child: Container(color: Colors.transparent))));

    List<Widget> _buildTaskTypeAndStatus(BuildContext context) {
      return [
        if (!forceFolderCreation && !forceNoteCreation) ...[],
        if (!isFolder && !isWorksheet && !isNote)
          StatefulBuilder(
            builder: (context, setStatusOuter) {
              bool statusExpanded = false;
              return StatefulBuilder(
                builder: (context, setStatusInner) {
                  final currentStatus = existingTask != null
                      ? existingTask!.status
                      : newTaskStatus;
                  final allStatuses = AiTaskStatus.values
                      .where((s) =>
                          !isKnowledgeSummary || s != AiTaskStatus.completed)
                      .toList();
                  return TapRegion(
                    onTapOutside: (event) {
                      if (statusExpanded) {
                        setStatusInner(() => statusExpanded = false);
                      }
                    },
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: allStatuses
                          .where((s) => statusExpanded || s == currentStatus)
                          .map((s) {
                        final baseColor = s == AiTaskStatus.inReview
                            ? Colors.purpleAccent
                            : s == AiTaskStatus.inTesting
                                ? Colors.orange
                                : s == AiTaskStatus.inProgress
                                    ? Colors.lightBlue
                                    : s == AiTaskStatus.bug
                                        ? Colors.red
                                        : Colors.green;
                        final lbl = s == AiTaskStatus.inReview
                            ? 'IN REVIEW'
                            : s == AiTaskStatus.inTesting
                                ? 'IN TESTING'
                                : s == AiTaskStatus.inProgress
                                    ? 'IN PROGRESS'
                                    : s.name.toUpperCase();
                        return GestureDetector(
                          onTap: () {
                            if (!statusExpanded) {
                              setStatusInner(() => statusExpanded = true);
                            } else {
                              setStateBuilder(() {
                                if (existingTask != null) {
                                  if (s == AiTaskStatus.inProgress && existingTask!.status != AiTaskStatus.inProgress) {
                                  }
                                  existingTask!.status = s;
                                } else {
                                  newTaskStatus = s;
                                }
                                _executeAutoSave();
                              });
                              setStatusInner(() => statusExpanded = false);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: s == currentStatus
                                  ? baseColor.withOpacity(0.35)
                                  : baseColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: s == currentStatus
                                      ? baseColor
                                      : baseColor.withOpacity(0.3)),
                            ),
                            child: Text(lbl,
                                style: TextStyle(
                                    fontSize: AppUIConfig.smallFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.panelTextPrimary)),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              );
            },
          ),
      ];
    }

    Widget _buildVerificationCriteriaSection() {
      if (isFolder || isWorksheet) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              setStateBuilder(() => isVerificationCriteriaSectionExpanded =
                  !isVerificationCriteriaSectionExpanded);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TASK CHECKLIST',
                    style: TextStyle(
                        color: AppColors.accent,
                        fontSize: AppUIConfig.rootFontSize,
                        fontWeight: FontWeight.bold)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (verificationCriteriaList.isNotEmpty)
                      InkWell(
                        onTap: () {
                          setStateBuilder(() {
                            verificationCriteriaList.clear();
                            for (var c in _verificationControllers) {
                              c.dispose();
                            }
                            for (var c in _verificationGoalControllers) {
                              c.dispose();
                            }
                            _verificationControllers.clear();
                            _verificationGoalControllers.clear();
                            _executeAutoSave();
                          });
                        },
                        child: Icon(Icons.delete_sweep,
                            size: 16, color: AppColors.titleBarTextSecondary),
                      ),
                    if (verificationCriteriaList.isNotEmpty)
                      const SizedBox(width: 8),
                    Text(
                        '${verificationCriteriaList.where((e) => e.isVerified).length}/${verificationCriteriaList.where((e) => e.status != AiVerificationStatus.ignored).length}',
                        style: TextStyle(
                            color: AppColors.titleBarTextSecondary,
                            fontSize: AppUIConfig.rootFontSize)),
                    const SizedBox(width: 8),
                    Icon(
                        isVerificationCriteriaSectionExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 16,
                        color: AppColors.titleBarTextSecondary),
                  ],
                ),
              ],
            ),
          ),
          if (isVerificationCriteriaSectionExpanded) ...[
            const SizedBox(height: 16),
            if (verificationCriteriaList.isEmpty)
              Text('No tasks attached.',
                  style: TextStyle(
                      color: AppColors.titleBarTextSecondary,
                      fontSize: AppUIConfig.rootFontSize,
                      fontStyle: FontStyle.italic)),
            if (verificationCriteriaList.isNotEmpty)
              Flexible(
                child: ReorderableListView(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  onReorder: (int oldIndex, int newIndex) {
                setStateBuilder(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final item = verificationCriteriaList.removeAt(oldIndex);
                  verificationCriteriaList.insert(newIndex, item);
                  final controller =
                      _verificationControllers.removeAt(oldIndex);
                  _verificationControllers.insert(newIndex, controller);
                  final goalController =
                      _verificationGoalControllers.removeAt(oldIndex);
                  _verificationGoalControllers.insert(newIndex, goalController);
                  _executeAutoSave();
                });
              },
              children: [
                for (int i = 0; i < verificationCriteriaList.length; i++)
                  ChecklistItemContainer(
                    key: ValueKey(_verificationControllers[i]),
                    status: verificationCriteriaList[i].status,
                    isPreview: verificationCriteriaList[i].isPreview,
                    isLocked: _isItemLocked(verificationCriteriaList[i]),
                    child: Builder(
                      builder: (context) {
                        final isItemLocked = _isItemLocked(verificationCriteriaList[i]);
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: InkWell(
                                        onTap: isItemLocked
                                            ? null
                                            : () {
                                                setStateBuilder(() {
                                                  if (verificationCriteriaList[i].status ==
                                                      AiVerificationStatus.none) {
                                                    if (verificationCriteriaList[i]
                                                        .description
                                                        .trim()
                                                        .endsWith('?')) {
                                                      verificationCriteriaList[i].status =
                                                          AiVerificationStatus.pendingReview;
                                                      verificationCriteriaList[i].isVerified =
                                                          false;
                                                    } else {
                                                      verificationCriteriaList[i].status =
                                                          AiVerificationStatus.verified;
                                                      verificationCriteriaList[i].isVerified =
                                                          true;
                                                    }
                                                  } else if (verificationCriteriaList[i]
                                                          .status ==
                                                      AiVerificationStatus.pendingReview) {
                                                    verificationCriteriaList[i].status =
                                                        AiVerificationStatus.verified;
                                                    verificationCriteriaList[i].isVerified =
                                                        true;
                                                  } else {
                                                    verificationCriteriaList[i].status =
                                                        AiVerificationStatus.none;
                                                    verificationCriteriaList[i].isVerified =
                                                        false;
                                                    verificationCriteriaList[i].proof = null;
                                                    verificationCriteriaList[i].isCommitted = false;
                                                  }
                                                  _executeAutoSave();
                                                });
                                              },
                                        child: Icon(
                                          verificationCriteriaList[i].status ==
                                                  AiVerificationStatus.verified
                                              ? Icons.check_box
                                              : verificationCriteriaList[i].status ==
                                                      AiVerificationStatus.pendingReview
                                                  ? Icons.check_box
                                                  : verificationCriteriaList[i].status ==
                                                          AiVerificationStatus.submitted
                                                      ? Icons.hourglass_top
                                                      : Icons.check_box_outline_blank,
                                          size: 18,
                                          color: verificationCriteriaList[i].status ==
                                                  AiVerificationStatus.verified
                                              ? Colors.green
                                              : verificationCriteriaList[i].status ==
                                                      AiVerificationStatus.pendingReview
                                                  ? Colors.orange
                                                  : verificationCriteriaList[i].status ==
                                                          AiVerificationStatus.submitted
                                                      ? Colors.blueAccent
                                                      : verificationCriteriaList[i].status == AiVerificationStatus.ignored
                                                          ? Colors.grey.withOpacity(0.5)
                                                          : AppColors.controlBorder,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Focus(
                                            onFocusChange: (hasFocus) {
                                              if (_verificationControllers[i] is SpellCheckTextEditingController) {
                                                (_verificationControllers[i] as SpellCheckTextEditingController).setEditing(hasFocus);
                                              }
                                            },
                                            onKeyEvent: (FocusNode node, KeyEvent event) {
                                              if (event is KeyDownEvent &&
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey.enter &&
                                                  !HardwareKeyboard
                                                      .instance.isShiftPressed) {
                                                final val = _verificationControllers[i].text.trim();
                                                if (val.isNotEmpty) {
                                                  Future.microtask(() async {
                                                    final result = await LocalAiService.instance.checkClarity(val);
                                                    if (result != null) {
                                                      final (isUnclear, aiNotes) = result;
                                                      setStateBuilder(() {
                                                        verificationCriteriaList[i].requestClarification = isUnclear;
                                                        if (isUnclear && aiNotes != null && aiNotes.isNotEmpty) {
                                                          final existing = verificationCriteriaList[i].notes;
                                                          verificationCriteriaList[i].notes = existing.isNotEmpty
                                                              ? '⚠️ $aiNotes\n\n$existing'
                                                              : '⚠️ $aiNotes';
                                                        }
                                                      });
                                                      _executeAutoSave();
                                                    }
                                                  });
                                                }
                                                FocusScope.of(context).nextFocus();
                                                return KeyEventResult.handled;
                                              }
                                              return KeyEventResult.ignored;
                                            },
                                            child: TextFormField(
                                              key: ValueKey(
                                                  '${existingTask?.id}_verification_$i'),
                                              controller: _verificationControllers[i],
                                              contextMenuBuilder: SpellCheckTextEditingController.buildContextMenu,
                                              readOnly: isItemLocked,
                                              style: TextStyle(
                                                color: verificationCriteriaList[i].status == AiVerificationStatus.ignored ? Colors.white54 : Colors.white,
                                                fontSize: AppUIConfig.rootFontSize,
                                                decoration: verificationCriteriaList[i].status ==
                                                            AiVerificationStatus.verified
                                                        ? TextDecoration.lineThrough
                                                        : verificationCriteriaList[i].status == AiVerificationStatus.ignored ? TextDecoration.lineThrough : null,
                                                decorationColor: verificationCriteriaList[i].status == AiVerificationStatus.ignored ? Colors.white54 : Colors.white,
                                              ),
                                              maxLines: null,
                                              keyboardType: TextInputType.multiline,
                                              textInputAction: TextInputAction.newline,
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                contentPadding: EdgeInsets.zero,
                                                border: InputBorder.none,
                                              ),
                                              onChanged: (val) {
                                                verificationCriteriaList[i].description = val;
                                                if (verificationCriteriaList[i].status != AiVerificationStatus.none) {
                                                    verificationCriteriaList[i].status = AiVerificationStatus.none;
                                                    verificationCriteriaList[i].isVerified = false;
                                                    verificationCriteriaList[i].proof = null;
                                                    verificationCriteriaList[i].isCommitted = false;
                                                }
                                                _executeAutoSave();
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Tooltip(
                                                message: isItemLocked
                                                    ? 'Goal Not Met (Locked)'
                                                    : 'Goal Not Met (L-Click: Retry, R-Click: -1)',
                                                child: GestureDetector(
                                                  onTap: isItemLocked
                                                      ? null
                                                      : () {
                                                          setStateBuilder(() {
                                                            verificationCriteriaList[i].status = AiVerificationStatus.none;
                                                            verificationCriteriaList[i].isVerified = false;
                                                            verificationCriteriaList[i].proof = null;
                                                            verificationCriteriaList[i].isCommitted = false;
                                                            if (verificationCriteriaList[i].tryCount < 9) {
                                                              verificationCriteriaList[i].tryCount++;
                                                            }
                                                            _executeAutoSave();
                                                          });
                                                        },
                                                  onSecondaryTap: isItemLocked
                                                      ? null
                                                      : () {
                                                          setStateBuilder(() {
                                                            if (verificationCriteriaList[i].tryCount > 0) {
                                                              verificationCriteriaList[i].tryCount--;
                                                              _executeAutoSave();
                                                            }
                                                          });
                                                        },
                                                  child: Container(
                                                    margin: const EdgeInsets.only(right: 8.0, top: 2.0),
                                                    width: 16,
                                                    height: 16,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: isItemLocked
                                                            ? Colors.orangeAccent.withOpacity(0.5)
                                                            : (verificationCriteriaList[i].tryCount > 5 ? Colors.redAccent : Colors.white), 
                                                        width: 1.0
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets.only(bottom: 1.0),
                                                      child: Text(
                                                        '${verificationCriteriaList[i].tryCount}',
                                                        style: TextStyle(
                                                          color: isItemLocked
                                                              ? Colors.orangeAccent
                                                              : (verificationCriteriaList[i].tryCount > 5 ? Colors.redAccent : Colors.white),
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Focus(
                                                  onFocusChange: (hasFocus) {
                                                    if (_verificationGoalControllers[i] is SpellCheckTextEditingController) {
                                                      (_verificationGoalControllers[i] as SpellCheckTextEditingController).setEditing(hasFocus);
                                                    }
                                                  },
                                                  onKeyEvent: (FocusNode node, KeyEvent event) {
                                                    if (event is KeyDownEvent &&
                                                        event.logicalKey ==
                                                            LogicalKeyboardKey.enter &&
                                                        !HardwareKeyboard
                                                            .instance.isShiftPressed) {
                                                      if (i ==
                                                          verificationCriteriaList.length - 1) {
                                                        newSubTaskFocus.requestFocus();
                                                      } else {
                                                        FocusScope.of(context).nextFocus();
                                                      }
                                                      return KeyEventResult.handled;
                                                    }
                                                    return KeyEventResult.ignored;
                                                  },
                                                  child: TextFormField(
                                                    key: ValueKey(
                                                        '${existingTask?.id}_verification_goal_$i'),
                                                    controller: _verificationGoalControllers[i],
                                                    contextMenuBuilder: SpellCheckTextEditingController.buildContextMenu,
                                                    readOnly: isItemLocked,
                                                    style: TextStyle(
                                                      color: verificationCriteriaList[i].status == AiVerificationStatus.ignored ? Colors.white54 : Colors.white70,
                                                      fontSize: AppUIConfig.rootFontSize * 0.9,
                                                      decoration: verificationCriteriaList[i].status ==
                                                                  AiVerificationStatus.verified
                                                              ? TextDecoration.lineThrough
                                                              : verificationCriteriaList[i].status == AiVerificationStatus.ignored ? TextDecoration.lineThrough : null,
                                                      decorationColor: verificationCriteriaList[i].status == AiVerificationStatus.ignored ? Colors.white54 : Colors.white70,
                                                    ),
                                                    maxLines: null,
                                                    keyboardType: TextInputType.multiline,
                                                    textInputAction: TextInputAction.newline,
                                                    decoration: InputDecoration(
                                                      isDense: true,
                                                      hintText: 'Define the goal for this checklist item...',
                                                      hintStyle: TextStyle(
                                                          color: Colors.white.withOpacity(0.3),
                                                          fontSize: AppUIConfig.rootFontSize * 0.9,
                                                          fontStyle: FontStyle.italic),
                                                      contentPadding: EdgeInsets.zero,
                                                      border: InputBorder.none,
                                                    ),
                                                    onChanged: (val) {
                                                      verificationCriteriaList[i].goal = val;
                                                      if (verificationCriteriaList[i].status != AiVerificationStatus.none) {
                                                          verificationCriteriaList[i].status = AiVerificationStatus.none;
                                                          verificationCriteriaList[i].isVerified = false;
                                                          verificationCriteriaList[i].proof = null;
                                                          verificationCriteriaList[i].isCommitted = false;
                                                      }
                                                      _executeAutoSave();
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    isItemLocked
                                        ? const Padding(
                                            padding: EdgeInsets.only(right: 6.0),
                                            child: Icon(Icons.lock,
                                                size: 18, color: Colors.orangeAccent),
                                          )
                                        : ReorderableDragStartListener(
                                            index: i,
                                            child: const Padding(
                                              padding: EdgeInsets.only(right: 6.0),
                                              child: Icon(Icons.drag_indicator,
                                                  size: 18, color: Colors.white38),
                                            ),
                                          ),
                                    IconButton(
                                      icon: Icon(
                                          verificationCriteriaList[i]
                                                  .requestClarification
                                              ? Icons.lightbulb
                                              : Icons.lightbulb_outline,
                                          size: 18,
                                          color: isItemLocked
                                              ? Colors.grey.withOpacity(0.3)
                                              : (verificationCriteriaList[i]
                                                      .requestClarification
                                                  ? Colors.yellow
                                                  : Colors.yellow.withOpacity(0.5))),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: isItemLocked ? 'Locked' : 'Request AI Clarification',
                                      onPressed: isItemLocked
                                          ? null
                                          : () async {
                                              if (verificationCriteriaList[i].requestClarification) {
                                                final currentPrompt = _verificationControllers[i].text.trim();
                                                if (currentPrompt.isNotEmpty) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Retooling prompt with AI...')),
                                                  );
                                                  final rewriteTemplate = LocalAiService.instance.rewritePrompt;
                                                  final instruction = rewriteTemplate.contains('{PROMPT}')
                                                      ? rewriteTemplate.replaceAll('{PROMPT}', currentPrompt)
                                                      : '$rewriteTemplate $currentPrompt';
                                                  final retooled = await LocalAiService.instance.generateText(instruction);
                                                  if (retooled != null && retooled.trim().isNotEmpty && context.mounted) {
                                                    setStateBuilder(() {
                                                      _verificationControllers[i].text = retooled.trim();
                                                      verificationCriteriaList[i].description = retooled.trim();
                                                      verificationCriteriaList[i].requestClarification = false;
                                                    });
                                                    _executeAutoSave();
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Prompt retooled!')),
                                                    );
                                                  }
                                                }
                                              } else {
                                                setStateBuilder(() {
                                                  verificationCriteriaList[i]
                                                          .requestClarification =
                                                      !verificationCriteriaList[i]
                                                          .requestClarification;
                                                  _executeAutoSave();
                                                });
                                              }
                                            },
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: Icon(
                                          verificationCriteriaList[i].status == AiVerificationStatus.ignored
                                              ? Icons.do_not_disturb_on
                                              : Icons.do_not_disturb_alt,
                                          size: 18,
                                          color: isItemLocked
                                              ? Colors.grey.withOpacity(0.3)
                                              : (verificationCriteriaList[i].status == AiVerificationStatus.ignored
                                                  ? Colors.grey
                                                  : Colors.grey.withOpacity(0.5))),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: isItemLocked ? 'Locked' : 'Ignore Task',
                                      onPressed: isItemLocked
                                          ? null
                                          : () {
                                              setStateBuilder(() {
                                                if (verificationCriteriaList[i].status == AiVerificationStatus.ignored) {
                                                  verificationCriteriaList[i].status = AiVerificationStatus.none;
                                                } else {
                                                  verificationCriteriaList[i].status = AiVerificationStatus.ignored;
                                                  verificationCriteriaList[i].isVerified = false;
                                                  verificationCriteriaList[i].proof = null;
                                                  verificationCriteriaList[i].isCommitted = false;
                                                }
                                                _executeAutoSave();
                                              });
                                            },
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: Icon(Icons.attach_file,
                                          size: 18,
                                          color: isItemLocked
                                              ? Colors.grey.withOpacity(0.3)
                                              : AppColors.titleBarTextSecondary),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: isItemLocked ? 'Locked' : 'Attach file or image',
                                      onPressed: isItemLocked
                                          ? null
                                          : () {
                                              GlobalPickerState.instance.requestAttachmentViewer(
                                                contextLabel: verificationCriteriaList[i].description,
                                                onLink: (linkedPath) {
                                                  if (!verificationCriteriaList[i].attachments.contains(linkedPath)) {
                                                    setStateBuilder(() {
                                                      verificationCriteriaList[i].attachments.add(linkedPath);
                                                      _executeAutoSave();
                                                    });
                                                  }
                                                },
                                              );
                                              showAttachmentViewerWindow(context);
                                            },
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline,
                                          size: 18,
                                          color: isItemLocked
                                              ? Colors.grey.withOpacity(0.3)
                                              : Colors.redAccent.withOpacity(0.8)),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: isItemLocked
                                          ? null
                                          : () {
                                              setStateBuilder(() {
                                                verificationCriteriaList.removeAt(i);
                                                _verificationControllers[i].dispose();
                                                _verificationControllers.removeAt(i);
                                                _verificationGoalControllers[i].dispose();
                                                _verificationGoalControllers.removeAt(i);
                                                _executeAutoSave();
                                              });
                                            },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (verificationCriteriaList[i].notes.isNotEmpty) ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (verificationCriteriaList[i].notes.startsWith('⚠️')) ...[
                                            Icon(Icons.smart_toy_outlined, size: 12, color: Colors.orangeAccent.withOpacity(0.8)),
                                            const SizedBox(width: 4),
                                            Text('AI Notes', style: TextStyle(color: Colors.orangeAccent.withOpacity(0.8), fontSize: AppUIConfig.rootFontSize * 0.8, fontWeight: FontWeight.w600)),
                                          ] else ...[
                                            Text('Notes', style: TextStyle(color: Colors.white38, fontSize: AppUIConfig.rootFontSize * 0.8)),
                                          ],
                                        ],
                                      ),
                                      if (!isItemLocked)
                                        InkWell(
                                          onTap: () {
                                            setStateBuilder(() {
                                              verificationCriteriaList[i].notes = '';
                                              _executeAutoSave();
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(4),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.clear, size: 12, color: Colors.white38),
                                                const SizedBox(width: 3),
                                                Text('Clear', style: TextStyle(color: Colors.white38, fontSize: AppUIConfig.rootFontSize * 0.8)),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 120),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: verificationCriteriaList[i].notes.startsWith('⚠️') ? Colors.orangeAccent.withOpacity(0.3) : Colors.white10),
                                  ),
                                  child: TextFormField(
                                    key: ValueKey('${existingTask?.id}_verification_notes_${i}_${verificationCriteriaList[i].notes}'),
                                    initialValue: verificationCriteriaList[i].notes,
                                    readOnly: isItemLocked,
                                    style: TextStyle(
                                        color: verificationCriteriaList[i].notes.startsWith('⚠️') ? Colors.orangeAccent.withOpacity(0.85) : Colors.white70,
                                        fontSize: AppUIConfig.rootFontSize * 0.9),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: 'Add notes for this checklist item...',
                                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: AppUIConfig.rootFontSize * 0.9),
                                      border: InputBorder.none,
                                    ),
                                    maxLines: null,
                                    onChanged: (val) {
                                      verificationCriteriaList[i].notes = val;
                                      _executeAutoSave();
                                    },
                                  ),
                                ),

                                if (verificationCriteriaList[i].status == AiVerificationStatus.verified) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 120),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: TextFormField(
                                      key: ValueKey('${existingTask?.id}_verification_proof_${i}_${verificationCriteriaList[i].proof ?? ""}'),
                                      initialValue: verificationCriteriaList[i].proof ?? '',
                                      readOnly: isItemLocked,
                                      style: TextStyle(
                                          color: Colors.lightBlueAccent,
                                          fontSize: AppUIConfig.rootFontSize * 0.9,
                                          fontFamily: 'monospace'),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText: 'Add a completion note / proof...',
                                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                        border: InputBorder.none,
                                      ),
                                      maxLines: null,
                                      onChanged: (val) {
                                        verificationCriteriaList[i].proof = val;
                                        _executeAutoSave();
                                      },
                                    ),
                                  ),
                                ] else if (verificationCriteriaList[i].proof != null &&
                                    verificationCriteriaList[i].proof!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 70),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: SingleChildScrollView(
                                      child: SelectableText(
                                          'Proof: ${verificationCriteriaList[i].proof}',
                                          style: TextStyle(
                                              color: Colors.lightBlueAccent,
                                              fontSize: AppUIConfig.rootFontSize * 0.9,
                                              fontFamily: 'monospace')),
                                    ),
                                  ),
                                ],
                                // ── Attachment row ──────────────────────────────
                                if (verificationCriteriaList[i].attachments.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (int ai = 0; ai < verificationCriteriaList[i].attachments.length; ai++) ...[
                                            Builder(builder: (ctx) {
                                              final aPath = verificationCriteriaList[i].attachments[ai];
                                              final aName = p.basename(aPath);
                                              final aIsImg = _isImageFile(aPath);
                                              return Tooltip(
                                                message: aName,
                                                child: GestureDetector(
                                                  onTap: () {
                                                    GlobalPickerState.instance.requestAttachmentViewer(
                                                      contextLabel: verificationCriteriaList[i].description,
                                                      onLink: (linkedPath) {
                                                        if (!verificationCriteriaList[i].attachments.contains(linkedPath)) {
                                                          setStateBuilder(() {
                                                            verificationCriteriaList[i].attachments.add(linkedPath);
                                                            if (verificationCriteriaList[i].status != AiVerificationStatus.none) {
                                                              verificationCriteriaList[i].status = AiVerificationStatus.none;
                                                              verificationCriteriaList[i].isVerified = false;
                                                              verificationCriteriaList[i].proof = null;
                                                              verificationCriteriaList[i].isCommitted = false;
                                                            }
                                                            _executeAutoSave();
                                                          });
                                                        }
                                                      },
                                                    );
                                                    showAttachmentViewerWindow(context);
                                                  },
                                                  onSecondaryTap: isItemLocked
                                                      ? null
                                                      : () {
                                                          // Right-click removes
                                                          setStateBuilder(() {
                                                            verificationCriteriaList[i].attachments.removeAt(ai);
                                                            if (verificationCriteriaList[i].status != AiVerificationStatus.none) {
                                                              verificationCriteriaList[i].status = AiVerificationStatus.none;
                                                              verificationCriteriaList[i].isVerified = false;
                                                              verificationCriteriaList[i].proof = null;
                                                              verificationCriteriaList[i].isCommitted = false;
                                                            }
                                                            _executeAutoSave();
                                                          });
                                                        },
                                                  child: Container(
                                                    margin: const EdgeInsets.only(right: 4),
                                                    width: 28,
                                                    height: 28,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: AppColors.controlBorder),
                                                      color: Colors.black26,
                                                    ),
                                                    clipBehavior: Clip.antiAlias,
                                                    child: aIsImg
                                                        ? Image.file(
                                                            File(aPath),
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (_, __, ___) => Icon(
                                                                Icons.insert_drive_file,
                                                                size: 14,
                                                                color: AppColors.titleBarTextSecondary),
                                                          )
                                                        : Icon(Icons.insert_drive_file,
                                                            size: 14,
                                                            color: AppColors.titleBarTextSecondary),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (verificationCriteriaList[i].isCommitted)
                              Positioned(
                                bottom: -4,
                                right: -4,
                                child: IgnorePointer(
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0.0, end: 1.0),
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.elasticOut,
                                    builder: (context, val, child) {
                                      return Transform.scale(
                                        scale: val,
                                        child: child,
                                      );
                                    },
                                    child: Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.green.withOpacity(0.8),
                                      size: 48,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.5),
                                          blurRadius: 4,
                                          offset: const Offset(1, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (verificationCriteriaList[i].isPreview)
                              Positioned(
                                bottom: -12,
                                right: 8,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: isItemLocked
                                        ? null
                                        : () {
                                            setStateBuilder(() {
                                              final item = verificationCriteriaList[i];
                                              final newTask = AiTask(
                                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                                name: item.description.length > 40 ? '${item.description.substring(0, 40)}...' : item.description,
                                                description: item.description,
                                                notes: item.goal.isNotEmpty ? 'Goal: ${item.goal}' : '',
                                                parentId: existingTask!.id,
                                                status: AiTaskStatus.inProgress,
                                                priority: AiTaskPriority.none,
                                                reviewQuestions: [],
                                                verificationCriteria: [],
                                                fileAttachments: List.from(item.attachments),
                                                hyperlinks: [],
                                                isFolder: false,
                                                isWorksheet: false,
                                                isWorksheetVisible: true,
                                                isRead: false,
                                                isNote: false,
                                                isKnowledgeSummary: false,
                                                preventDeletion: false,
                                                applyLocksToChildren: false,
                                                isReadOnly: false,
                                                isIgnored: false,
                                                llmPromptStyleOverride: 'Use Default',
                                              );
                                              AiBridgeService.instance.tasks.add(newTask);
                                              AiBridgeService.instance.saveTasks();
                                              verificationCriteriaList.removeAt(i);
                                              _verificationControllers[i].dispose();
                                              _verificationControllers.removeAt(i);
                                              _verificationGoalControllers[i].dispose();
                                              _verificationGoalControllers.removeAt(i);
                                              _executeAutoSave();
                                            });
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isItemLocked ? Colors.grey : Colors.orangeAccent,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.black, width: 1.5),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.turn_right,
                                              color: isItemLocked ? Colors.white : Colors.black,
                                              size: 16),
                                          const SizedBox(width: 4),
                                          Text('TO TASK',
                                              style: TextStyle(
                                                  color: isItemLocked ? Colors.white : Colors.black,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Focus(
                    onFocusChange: (hasFocus) {
                      if (newSubTaskController is SpellCheckTextEditingController) {
                        (newSubTaskController as SpellCheckTextEditingController).setEditing(hasFocus);
                      }
                    },
                    onKeyEvent: (FocusNode node, KeyEvent event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        if (newSubTaskController.text.trim().isNotEmpty) {
                          final newText = newSubTaskController.text.trim();
                          setStateBuilder(() {
                            verificationCriteriaList.add(AiVerificationCriteria(
                                description: newText));
                            _verificationControllers.add(TextEditingController(
                                text: newText));
                            _verificationGoalControllers.add(TextEditingController());
                            newSubTaskController.clear();
                          });
                          _executeAutoSave(instant: true);
                          // Run AI clarity check on the new item
                          final newIdx = verificationCriteriaList.length - 1;
                          Future.microtask(() async {
                            final result = await LocalAiService.instance.checkClarity(newText);
                            if (result != null) {
                              final (isUnclear, aiNotes) = result;
                              setStateBuilder(() {
                                if (newIdx < verificationCriteriaList.length) {
                                  verificationCriteriaList[newIdx].requestClarification = isUnclear;
                                  if (isUnclear && aiNotes != null && aiNotes.isNotEmpty) {
                                    final existing = verificationCriteriaList[newIdx].notes;
                                    verificationCriteriaList[newIdx].notes = existing.isNotEmpty
                                        ? '⚠️ $aiNotes\n\n$existing'
                                        : '⚠️ $aiNotes';
                                  }
                                }
                              });
                              _executeAutoSave();
                            }
                          });
                        }
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller:
                          newSubTaskController, // Reusing existing controller to add criteria or create a new one
                      contextMenuBuilder: SpellCheckTextEditingController.buildContextMenu,
                      focusNode: newSubTaskFocus,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: AppUIConfig.rootFontSize),
                      decoration: InputDecoration(
                        hintText: 'Add new task...',
                        hintStyle:
                            TextStyle(color: AppColors.titleBarTextSecondary),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.controlBorder)),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.accent)),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  color: AppColors.accent,
                  onPressed: () {
                    if (newSubTaskController.text.trim().isNotEmpty) {
                      final newText = newSubTaskController.text.trim();
                      setStateBuilder(() {
                        verificationCriteriaList.add(AiVerificationCriteria(
                            description: newText));
                        _verificationControllers.add(TextEditingController(
                            text: newText));
                        _verificationGoalControllers.add(TextEditingController());
                        newSubTaskController.clear();
                      });
                      _executeAutoSave(instant: true);
                      // Run AI clarity check on the new item
                      final newIdx = verificationCriteriaList.length - 1;
                      Future.microtask(() async {
                        final result = await LocalAiService.instance.checkClarity(newText);
                        if (result != null) {
                          final (isUnclear, aiNotes) = result;
                          setStateBuilder(() {
                            if (newIdx < verificationCriteriaList.length) {
                              verificationCriteriaList[newIdx].requestClarification = isUnclear;
                              if (isUnclear && aiNotes != null && aiNotes.isNotEmpty) {
                                final existing = verificationCriteriaList[newIdx].notes;
                                verificationCriteriaList[newIdx].notes = existing.isNotEmpty
                                    ? '⚠️ $aiNotes\n\n$existing'
                                    : '⚠️ $aiNotes';
                              }
                            }
                          });
                          _executeAutoSave();
                        }
                      });
                    }
                  },
                ),
              ],
            ),
            if (verificationCriteriaList.any((e) => e.isPreview)) ...[
              const SizedBox(height: 12),
              _buildTaskEditorPreviewActionBanner(context),
            ],
          ],
        ],
      );
    }


    Widget _buildLabeledBtn(
        String label, IconData icon, int? colorValue, VoidCallback onTap) {
      return Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: colorValue != null
                  ? Color(colorValue).withOpacity(0.2)
                  : Colors.transparent,
              border: Border.all(
                  color: colorValue != null
                      ? Color(colorValue)
                      : AppColors.controlBorder),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon,
                size: 14,
                color: colorValue != null
                    ? Color(colorValue)
                    : AppColors.titleBarTextSecondary),
          ),
        ),
      );
    }

    List<Widget> _buildCustomizationButtons(BuildContext context) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: customIconBackgroundColor != null
                ? Color(customIconBackgroundColor!)
                : AppColors.panelBackground,
            border: Border.all(color: AppColors.controlBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (customIconCode != null)
                Icon(IconData(customIconCode!, fontFamily: 'MaterialIcons'),
                    size: 14,
                    color: customIconColor != null
                        ? Color(customIconColor!)
                        : AppColors.panelTextPrimary),
              if (customIconCode != null) const SizedBox(width: 4),
              Text('Aa',
                  style: TextStyle(
                      color: AppColors.panelTextPrimary,
                      fontSize: AppUIConfig.smallFontSize,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildLabeledBtn(
            'Highlight Color', Icons.highlight, customHighlightColor, () {
          GlobalPickerState.instance.requestColor(
              initialColor: customHighlightColor != null
                  ? Color(customHighlightColor!)
                  : AppColors.panelBackground,
              onColorSelected: (c) {
                setState(() => customHighlightColor = c?.value);
                if (existingTask != null) {
                  existingTask!.highlightColor = c?.value;
                }
                _executeAutoSave();
              });
          showColorPickerWindow(context);
        }),
        const SizedBox(width: 8),
        _buildLabeledBtn('Icon Background Color', Icons.format_color_fill,
            customIconBackgroundColor, () {
          GlobalPickerState.instance.requestColor(
              initialColor: customIconBackgroundColor != null
                  ? Color(customIconBackgroundColor!)
                  : AppColors.panelBackground,
              onColorSelected: (c) {
                setState(() => customIconBackgroundColor = c?.value);
                if (existingTask != null) {
                  existingTask!.iconBackgroundColor = c?.value;
                }
                _executeAutoSave();
              });
          showColorPickerWindow(context);
        }),
        const SizedBox(width: 8),
        _buildLabeledBtn('Icon Color', Icons.palette, customIconColor, () {
          GlobalPickerState.instance.requestColor(
              initialColor: customIconColor != null
                  ? Color(customIconColor!)
                  : AppColors.panelTextPrimary,
              onColorSelected: (c) {
                setState(() => customIconColor = c?.value);
                if (existingTask != null) {
                  existingTask!.iconColor = c?.value;
                }
                _executeAutoSave();
              });
          showColorPickerWindow(context);
        }),
        const SizedBox(width: 8),
        if (isWorksheet) ...[
          _buildLabeledBtn(
              'Toolbar Icon Color', Icons.tab, customToolbarIconColor, () {
            GlobalPickerState.instance.requestColor(
                initialColor: customToolbarIconColor != null
                    ? Color(customToolbarIconColor!)
                    : AppColors.panelTextPrimary,
                onColorSelected: (c) {
                  setState(() => customToolbarIconColor = c?.value);
                  if (existingTask != null) {
                    existingTask!.toolbarIconColor = c?.value;
                  }
                  _executeAutoSave();
                });
            showColorPickerWindow(context);
          }),
          const SizedBox(width: 8),
        ],
        _buildLabeledBtn(
            'Task Icon',
            customIconCode != null
                ? IconData(customIconCode!, fontFamily: 'MaterialIcons')
                : Icons.emoji_emotions,
            null, () {
          GlobalPickerState.instance.requestIcon(
              initialIcon: customIconCode != null
                  ? IconData(customIconCode!, fontFamily: 'MaterialIcons')
                  : null,
              onIconSelected: (i) {
                setState(() => customIconCode = i?.codePoint);
                if (existingTask != null) {
                  existingTask!.iconCodePoint = i?.codePoint;
                }
                _executeAutoSave();
              });
          showIconPickerWindow(context);
        }),
      ];
    }

    Widget contentWidget = PopScope(
      canPop: isForceClosing,
      onPopInvokedWithResult: (didPop, dynamic result) {
        if (didPop) return;
        setStateBuilder(() => isForceClosing = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) _handleClose();
        });
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: AppColors.folder,
            selectionColor: AppColors.accent.withOpacity(0.4),
            selectionHandleColor: AppColors.accent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      focusNode: _nameFocusNode,
                      controller: nameController,
                      contextMenuBuilder: SpellCheckTextEditingController.buildContextMenu,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(
                          color: AppColors.panelTextPrimary,
                          fontSize: AppUIConfig.rootFontSize * 1.5,
                          fontWeight: FontWeight.bold),
                      cursorColor: AppColors.folder,
                      minLines: 1,
                      maxLines: 1,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.singleLineFormatter,
                      ],
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: existingTask == null
                            ? (isWorksheet
                                ? "WORKSHEET"
                                : isFolder
                                    ? "FOLDER"
                                    : isKnowledgeSummary
                                        ? "SUMMARY"
                                        : isNote
                                            ? "NOTE"
                                            : "AI TASK")
                            : "Task name...",
                        hintStyle: TextStyle(
                            color: AppColors.borderSubtle,
                            fontSize: AppUIConfig.rootFontSize * 1.5,
                            fontWeight: FontWeight.bold),
                        border: InputBorder.none,
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: AppColors.folder.withOpacity(0.4))),
                        enabledBorder: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ..._buildTaskTypeAndStatus(context),
                                const SizedBox(width: 8),
                                if (AiBridgeService
                                        .instance.worksheets.isNotEmpty &&
                                    !isWorksheet)
                                  Container(
                                    height: 24,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.black38,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: AppColors.borderSubtle),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: AiBridgeService
                                                .instance.worksheets
                                                .any((ws) =>
                                                    ws.id == activeParentId)
                                            ? activeParentId
                                            : null,
                                        hint: Text('WORKSHEET',
                                            style: TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold)),
                                        icon: Icon(Icons.arrow_drop_down,
                                            color: AppColors.textMuted,
                                            size: 16),
                                        dropdownColor:
                                            AppColors.panelBackground,
                                        style: TextStyle(
                                            color: AppColors.panelTextSecondary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                        onChanged: (String? newValue) {
                                          setStateBuilder(() {
                                            activeParentId = newValue;
                                          });
                                          _executeAutoSave();
                                        },
                                        items: [
                                          DropdownMenuItem<String>(
                                            value: null,
                                            child: Text('NONE'),
                                          ),
                                          ...AiBridgeService.instance.worksheets
                                              .map<DropdownMenuItem<String>>(
                                                  (AiTask ws) {
                                            return DropdownMenuItem<String>(
                                              value: ws.id,
                                              child:
                                                  Text(ws.name.toUpperCase()),
                                            );
                                          }).toList()
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (existingTask != null && !isFolder && !isWorksheet)
                          ListenableBuilder(
                            listenable: SandboxService.instance,
                            builder: (context, _) {
                              final isActive = SandboxService.instance.sandboxTaskIds.contains(existingTask!.id);
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: isActive ? Colors.amber.withOpacity(0.5) : Colors.transparent,
                                          width: 1.5),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        isActive ? Icons.star : Icons.star_border,
                                        size: 20,
                                      ),
                                      tooltip: isActive ? 'Remove from Active Tasks' : 'Add to Active Tasks',
                                      color: isActive ? Colors.amber : AppColors.textMuted,
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        if (isActive) {
                                          SandboxService.instance.removeFromSandbox(existingTask!.id);
                                        } else {
                                          SandboxService.instance.addToSandbox([existingTask!.id]);
                                        }
                                      },
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: isLocked ? Colors.redAccent.withOpacity(0.5) : Colors.transparent,
                                          width: 1.5),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        isLocked ? Icons.lock : Icons.lock_open,
                                        size: 20,
                                      ),
                                      tooltip: isLocked ? "Locked (Won't commit to GitHub)" : "Unlocked (Can commit to GitHub)",
                                      color: isLocked ? Colors.redAccent : AppColors.textMuted,
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        setStateBuilder(() {
                                          isLocked = !isLocked;
                                        });
                                        _executeAutoSave();
                                      },
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(left: 8, right: 4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white.withOpacity(0.8),
                                          width: 1.5),
                                    ),
                                    child: IconButton(
                                        icon: const Icon(Icons.bolt, size: 20),
                                        tooltip: 'Send to AI Bridge',
                                        color: Colors.yellow,
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        onPressed: (isTaskReadOnly || AiBridgeService.instance.isThinking) ? null : () async {
                                          print('[AiBridge] Queuing Task: ${existingTask!.name}');
                                          final unchecked = existingTask!.verificationCriteria
                                              .where((e) => (e.status != AiVerificationStatus.verified &&
                                                  e.status != AiVerificationStatus.ignored &&
                                                  e.status != AiVerificationStatus.pendingReview &&
                                                  !e.isPreview))
                                              .toList();
                                          if (unchecked.isEmpty) {
                                            print('  - Queuing entire task prompt');
                                          } else {
                                            for (final criteria in unchecked) {
                                              print('  - Queuing Checklist Item: ${criteria.description}');
                                            }
                                          }
                                          await AiBridgeService.instance.submitTaskChecklist(
                                            existingTask!,
                                            blockScreen: true,
                                          );
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                            content:
                                                Text('Task sent to AI Bridge queue!'),
                                            duration: Duration(seconds: 2),
                                          ));
                                        }),
                                  ),
                                ],
                              );
                            }
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.all(16).copyWith(bottom: 0, right: 0),
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding:
                                const EdgeInsets.only(right: 16, bottom: 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                        // Status chips only (urgency + type in header)
                                        // Old Status chips removed
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('DESCRIPTION',
                                                style: TextStyle(
                                                    color: AppColors.accent,
                                                    fontSize: AppUIConfig
                                                        .rootFontSize,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            ValueListenableBuilder<
                                                UndoHistoryValue>(
                                              valueListenable: descUndo,
                                              builder: (context, value, child) {
                                                return Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    ListenableBuilder(
                                                      listenable: LocalAiService.instance,
                                                      builder: (context, _) {
                                                        final isProcessing = LocalAiService.instance.isProcessing;
                                                        return IconButton(
                                                          icon: isProcessing
                                                              ? const SizedBox(
                                                                  width: 16,
                                                                  height: 16,
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth: 2,
                                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                                                                  ),
                                                                )
                                                              : const Icon(Icons.auto_awesome, size: 16),
                                                          onPressed: isProcessing
                                                              ? null
                                                              : () async {
                                                                  if (descController.text.isEmpty) return;
                                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reviewing prompt...')));
                                                                  final result = await LocalAiService.instance.reviewPrompt(descController.text);
                                                                  if (result != null && context.mounted) {
                                                                    setStateBuilder(() {
                                                                      notesController.text = result + '\n\n' + notesController.text;
                                                                      _selectedTabIndex = 1;
                                                                    });
                                                                    _executeAutoSave();
                                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prompt Review added to Notes!')));
                                                                  } else if (context.mounted) {
                                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${LocalAiService.instance.lastError}')));
                                                                  }
                                                                },
                                                          color: Colors.amberAccent,
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                          tooltip: isProcessing ? 'Reviewing...' : 'Review Prompt with AI',
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(width: 8),
                                                    ListenableBuilder(
                                                      listenable: LocalAiService.instance,
                                                      builder: (context, _) {
                                                        final isProcessingGen = LocalAiService.instance.isProcessing;
                                                        return IconButton(
                                                          icon: isProcessingGen
                                                              ? const SizedBox(
                                                                  width: 16,
                                                                  height: 16,
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth: 2,
                                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                                                                  ),
                                                                )
                                                              : const Icon(Icons.auto_fix_high, size: 16),
                                                          onPressed: isProcessingGen
                                                              ? null
                                                              : () async {
                                                                  if (descController.text.isEmpty) return;
                                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating task...')));
                                                                  final generated = await LocalAiService.instance.generateTask(descController.text);
                                                                  if (generated == null) {
                                                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${LocalAiService.instance.lastError}')));
                                                                    return;
                                                                  }
                                                                  setStateBuilder(() {
                                                                    if (nameController.text.trim().isEmpty && generated.title.isNotEmpty) {
                                                                      nameController.text = generated.title;
                                                                    }
                                                                    for (final itemText in generated.checklistItems) {
                                                                      if (itemText.isEmpty) continue;
                                                                      verificationCriteriaList.add(AiVerificationCriteria(description: itemText));
                                                                      _verificationControllers.add(TextEditingController(text: itemText));
                                                                      _verificationGoalControllers.add(TextEditingController());
                                                                    }
                                                                  });
                                                                  _executeAutoSave(instant: true);
                                                                  final startIdx = verificationCriteriaList.length - generated.checklistItems.length;
                                                                  for (int gi = 0; gi < generated.checklistItems.length; gi++) {
                                                                    final idx = startIdx + gi;
                                                                    final itemText = generated.checklistItems[gi];
                                                                    Future.microtask(() async {
                                                                      final clarityResult = await LocalAiService.instance.checkClarity(itemText);
                                                                      if (clarityResult != null) {
                                                                        final (isUnclear, aiNotes) = clarityResult;
                                                                        setStateBuilder(() {
                                                                          if (idx < verificationCriteriaList.length) {
                                                                            verificationCriteriaList[idx].requestClarification = isUnclear;
                                                                            if (isUnclear && aiNotes != null && aiNotes.isNotEmpty) {
                                                                              verificationCriteriaList[idx].notes = '⚠️ $aiNotes';
                                                                            }
                                                                          }
                                                                        });
                                                                        _executeAutoSave();
                                                                      }
                                                                    });
                                                                  }
                                                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generated ${generated.checklistItems.length} checklist items!')));
                                                                },
                                                          color: Colors.greenAccent,
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                          tooltip: isProcessingGen ? 'Generating...' : 'Generate Task with AI',
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.undo,
                                                          size: 16),
                                                      onPressed: value.canUndo
                                                          ? () =>
                                                              descUndo.undo()
                                                          : null,
                                                      color: value.canUndo
                                                          ? Colors
                                                              .lightBlueAccent
                                                          : AppColors
                                                              .titleBarTextSecondary,
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(),
                                                      tooltip: 'Undo',
                                                    ),
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.redo,
                                                          size: 16),
                                                      onPressed: value.canRedo
                                                          ? () =>
                                                              descUndo.redo()
                                                          : null,
                                                      color: value.canRedo
                                                          ? Colors
                                                              .lightBlueAccent
                                                          : AppColors
                                                              .titleBarTextSecondary,
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(),
                                                      tooltip: 'Redo',
                                                    ),
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.delete_outline,
                                                          size: 16),
                                                      onPressed: () {
                                                        descController.clear();
                                                      },
                                                      color: AppColors.error,
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(),
                                                      tooltip:
                                                          'Clear Description',
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        TextField(
                                          focusNode: _descFocusNode,
                                          controller: descController,
                                          contextMenuBuilder: SpellCheckTextEditingController.buildContextMenu,
                                          undoController: descUndo,
                                          style: TextStyle(
                                              color: AppColors.panelTextPrimary,
                                              fontFamily: 'monospace',
                                              fontSize:
                                                  AppUIConfig.rootFontSize *
                                                      1.0),
                                          minLines: 1,
                                          maxLines: 5,
                                          keyboardType: TextInputType.multiline,
                                          textInputAction:
                                              TextInputAction.newline,
                                          cursorColor: Colors.amberAccent,
                                          decoration: InputDecoration(
                                            enabledBorder: UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: AppColors
                                                        .borderSubtle)),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('SUMMARY',
                                                style: TextStyle(
                                                    color: AppColors.accent,
                                                    fontSize: AppUIConfig
                                                        .rootFontSize,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            ValueListenableBuilder<
                                                UndoHistoryValue>(
                                              valueListenable: summaryUndo,
                                              builder: (context, value, child) {
                                                return Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    ListenableBuilder(
                                                      listenable: LocalAiService.instance,
                                                      builder: (context, _) {
                                                        final isProcessing = LocalAiService.instance.isProcessing;
                                                        return IconButton(
                                                          icon: isProcessing
                                                              ? const SizedBox(
                                                                  width: 16,
                                                                  height: 16,
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth: 2,
                                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                                                                  ),
                                                                )
                                                              : const Icon(Icons.auto_awesome, size: 16),
                                                          onPressed: isProcessing
                                                              ? null
                                                              : () async {
                                                                  if (notesController.text.isEmpty && descController.text.isEmpty) return;
                                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating summary...')));
                                                                  final input = 'Description:\n${descController.text}\n\nNotes:\n${notesController.text}';
                                                                  final result = await LocalAiService.instance.summarizeTask(input);
                                                                  if (result != null && context.mounted) {
                                                                    setStateBuilder(() {
                                                                      summaryController.text = result;
                                                                    });
                                                                    _executeAutoSave();
                                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Summary generated!')));
                                                                  } else if (context.mounted) {
                                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${LocalAiService.instance.lastError}')));
                                                                  }
                                                                },
                                                          color: Colors.amberAccent,
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                          tooltip: isProcessing ? 'Generating...' : 'Generate Summary with AI',
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.undo,
                                                          size: 16),
                                                      onPressed: value.canUndo
                                                          ? () =>
                                                              summaryUndo.undo()
                                                          : null,
                                                      color: value.canUndo
                                                          ? Colors
                                                              .lightBlueAccent
                                                          : AppColors
                                                              .titleBarTextSecondary,
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(),
                                                      tooltip: 'Undo',
                                                    ),
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.redo,
                                                          size: 16),
                                                      onPressed: value.canRedo
                                                          ? () =>
                                                              summaryUndo.redo()
                                                          : null,
                                                      color: value.canRedo
                                                          ? Colors
                                                              .lightBlueAccent
                                                          : AppColors
                                                              .titleBarTextSecondary,
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(),
                                                      tooltip: 'Redo',
                                                    ),
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.delete_outline,
                                                          size: 16),
                                                      onPressed: () {
                                                        summaryController.clear();
                                                        _executeAutoSave();
                                                      },
                                                      color: AppColors.error,
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(),
                                                      tooltip:
                                                          'Clear Summary',
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        TextField(
                                          focusNode: _summaryFocusNode,
                                          controller: summaryController,
                                          contextMenuBuilder: SpellCheckTextEditingController.buildContextMenu,
                                          undoController: summaryUndo,
                                          style: TextStyle(
                                              color: AppColors.panelTextPrimary,
                                              fontFamily: 'monospace',
                                              fontSize:
                                                  AppUIConfig.rootFontSize *
                                                      1.0),
                                          minLines: 1,
                                          maxLines: 5,
                                          keyboardType: TextInputType.multiline,
                                          textInputAction:
                                              TextInputAction.newline,
                                          cursorColor: Colors.amberAccent,
                                          decoration: InputDecoration(
                                            enabledBorder: UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: AppColors
                                                        .borderSubtle)),
                                          ),
                                        ),
                                          if (!isFolder && !isWorksheet) ...[
                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              children: [
                                                TextButton(
                                                  onPressed: () => setStateBuilder(() => _selectedTabIndex = 0),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: _selectedTabIndex == 0 ? AppColors.accent : AppColors.textPrimary.withOpacity(0.5),
                                                    backgroundColor: _selectedTabIndex == 0 ? AppColors.accent.withOpacity(0.1) : Colors.transparent,
                                                  ),
                                                  child: const Text('CHECKLIST', style: TextStyle(fontWeight: FontWeight.bold)),
                                                ),
                                                const SizedBox(width: 8),
                                                TextButton(
                                                  onPressed: () => setStateBuilder(() => _selectedTabIndex = 1),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: _selectedTabIndex == 1 ? AppColors.accent : AppColors.textPrimary.withOpacity(0.5),
                                                    backgroundColor: _selectedTabIndex == 1 ? AppColors.accent.withOpacity(0.1) : Colors.transparent,
                                                  ),
                                                  child: const Text('NOTES', style: TextStyle(fontWeight: FontWeight.bold)),
                                                ),
                                                if (_selectedTabIndex == 0 && verificationCriteriaList.isNotEmpty) ...[
                                                  const Spacer(),
                                                  IconButton(
                                                    tooltip: 'Uncheck All',
                                                    onPressed: () {
                                                      setStateBuilder(() {
                                                        for (var item in verificationCriteriaList) {
                                                          item.isVerified = false;
                                                          item.status = AiVerificationStatus.none;
                                                          item.proof = null;
                                                          item.isCommitted = false;
                                                        }
                                                        _executeAutoSave();
                                                      });
                                                    },
                                                    icon: const Icon(Icons.deselect, size: 18),
                                                    color: AppColors.accent,
                                                    splashRadius: 18,
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Complete All',
                                                    onPressed: () {
                                                      setStateBuilder(() {
                                                        for (var item in verificationCriteriaList) {
                                                          item.isVerified = true;
                                                          item.status = AiVerificationStatus.verified;
                                                        }
                                                        _executeAutoSave();
                                                      });
                                                    },
                                                    icon: const Icon(Icons.done_all, size: 18),
                                                    color: AppColors.accent,
                                                    splashRadius: 18,
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Divider(color: Colors.white.withOpacity(0.2), height: 1),
                                            const SizedBox(height: 8),
                                          ],
                                        Expanded(
                                          child: Builder(builder: (ctx) {
                                            if (_selectedTabIndex == 0) {
                                              return _buildVerificationCriteriaSection();
                                            }
                                            if (_selectedTabIndex == 1) {
                                              return Container(
                                              decoration: BoxDecoration(
                                              color: Colors.transparent,
                                              borderRadius:
                                              BorderRadius.circular(4),
                                              ),
                                              padding: const EdgeInsets.all(0.0),
                                              child: Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                              children: [
                                              Row(
                                              mainAxisAlignment:
                                              MainAxisAlignment
                                              .spaceBetween,
                                              children: [
                                              Text('NOTES',
                                              style: TextStyle(
                                              color: AppColors
                                              .accent,
                                              fontSize: AppUIConfig
                                              .rootFontSize,
                                              fontWeight:
                                              FontWeight
                                              .bold)),
                                              Row(
                                              mainAxisSize:
                                              MainAxisSize.min,
                                              children: [
                                              IconButton(
                                              icon: Icon(
                                              isPreviewingNotes
                                              ? Icons.edit
                                              : Icons
                                              .visibility,
                                              size: 16),
                                              color:
                                              AppColors.accent,
                                              tooltip: isPreviewingNotes
                                              ? 'Edit Notes'
                                              : 'Preview Notes',
                                              padding:
                                              const EdgeInsets
                                              .all(4),
                                              constraints:
                                              const BoxConstraints(),
                                              onPressed: () {
                                              setStateBuilder(() {
                                              isPreviewingNotes =
                                              !isPreviewingNotes;
                                              });
                                              },
                                              ),
                                              const SizedBox(
                                              width: 8),
                                              IconButton(
                                              icon: const Icon(
                                              Icons.delete,
                                              size: 16),
                                              color:
                                              AppColors.error,
                                              tooltip:
                                              'Clear Notes',
                                              padding:
                                              const EdgeInsets
                                              .all(4),
                                              constraints:
                                              const BoxConstraints(),
                                              onPressed: () {
                                              notesController
                                              .clear();
                                              _executeAutoSave();
                                              },
                                              ),
                                              const SizedBox(
                                              width: 8),
                                              ElevatedButton.icon(
                                              icon: const Icon(
                                              Icons.open_in_new,
                                              size: 14),
                                              label: Text(
                                              'Open',
                                              style: TextStyle(
                                              fontSize:
                                              AppUIConfig
                                              .rootFontSize)),
                                              style: ElevatedButton
                                              .styleFrom(
                                              backgroundColor:
                                              AppColors
                                              .panelBackground
                                              .withOpacity(
                                              0.5),
                                              foregroundColor:
                                              AppColors
                                              .textPrimary,
                                              padding:
                                              const EdgeInsets
                                              .symmetric(
                                              horizontal:
                                              12,
                                              vertical:
                                              8),
                                              ),
                                              onPressed: () {
                                              setStateBuilder(() =>
                                              isPreviewingNotes =
                                              true);
                                              GlobalPickerState
                                              .instance
                                              .requestNotes(
                                              controller:
                                              notesController,
                                              title: existingTask
                                              ?.name ??
                                              'Task Notes',
                                              onSaved:
                                              () {
                                              _executeAutoSave();
                                              });
                                              showNotesEditorWindow(
                                              context);
                                              },
                                              ),
                                              ],
                                              ),
                                              ],
                                              ),
                                              const SizedBox(height: 8),
                                              Expanded(
                                                child: Container(
                                                  width: double.infinity,
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: isPreviewingNotes
                                                        ? AppUIConfig.markupBackgroundColor
                                                        : Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: SingleChildScrollView(
                                                    child: isPreviewingNotes
                                                        ? ValueListenableBuilder<
                                                                TextEditingValue>(
                                                            valueListenable:
                                                                notesController,
                                                            builder: (context,
                                                                value, child) {
                                                              return MarkdownRenderer(
                                                                fitContent: false,
                                                                data: value.text
                                                                        .trim()
                                                                        .isEmpty
                                                                    ? '*No notes provided...*'
                                                                    : value.text,
                                                                softLineBreak: true,
                                                                styleSheet: buildMarkdownStyleSheet(AppUIConfig.rootFontSize),
                                                              );
                                                            })
                                                        : TextField(
                                                            controller:
                                                                notesController,
                                                            contextMenuBuilder: SpellCheckTextEditingController.buildContextMenu,
                                                            undoController:
                                                                notesUndo,
                                                            maxLines: null,
                                                            minLines: 3,
                                                            style: TextStyle(
                                                              color: AppColors
                                                                  .panelTextPrimary,
                                                              fontSize: AppUIConfig
                                                                  .rootFontSize,
                                                              fontFamily:
                                                                  'monospace',
                                                            ),
                                                            decoration:
                                                                InputDecoration(
                                                              hintText:
                                                                  'Enter notes here...',
                                                              hintStyle:
                                                                  TextStyle(
                                                                color: AppColors
                                                                    .panelTextSecondary,
                                                                fontSize: AppUIConfig
                                                                    .rootFontSize,
                                                              ),
                                                              border: InputBorder
                                                                  .none,
                                                              isDense: true,
                                                              contentPadding:
                                                                  EdgeInsets.zero,
                                                            ),
                                                            onChanged: (val) =>
                                                                _executeAutoSave(),
                                                          ),
                                                  ),
                                                ),
                                              ),
                                              ],
                                            ),
                                          );
                                            }
                                            return const SizedBox.shrink();
                                          }),
                                        ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 24, right: 24, top: 16, bottom: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (existingTask != null) ...[
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.settings_backup_restore,
                                                  size: 16),
                                              tooltip:
                                                  'Open Task Backup Window',
                                              color:
                                                  AppColors.panelTextSecondary,
                                              onPressed: () {
                                                showBackupWindow(context);
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.copy,
                                                  size: 16),
                                              tooltip: 'Duplicate Task',
                                              color:
                                                  AppColors.panelTextSecondary,
                                              onPressed: () async {
                                                await AiBridgeService.instance
                                                    .addTask(
                                                  '${existingTask!.name} (Copy)',
                                                  existingTask!.description,
                                                  notes: existingTask!.notes,
                                                  isFolder:
                                                      existingTask!.isFolder,
                                                  isNote: existingTask!.isNote,
                                                  isKnowledgeSummary:
                                                      existingTask!
                                                          .isKnowledgeSummary,
                                                  parentId:
                                                      existingTask!.parentId,
                                                  status: existingTask!.status,
                                                  highlightColor: existingTask!
                                                      .highlightColor,
                                                  iconBackgroundColor:
                                                      existingTask!
                                                          .iconBackgroundColor,
                                                  iconColor:
                                                      existingTask!.iconColor,
                                                  iconCodePoint: existingTask!
                                                      .iconCodePoint,
                                                  preventDeletion: existingTask!
                                                      .preventDeletion,
                                                  applyLocksToChildren:
                                                      existingTask!
                                                          .applyLocksToChildren,
                                                  isReadOnly:
                                                      existingTask!.isReadOnly,
                                                  isIgnored:
                                                      existingTask!.isIgnored,
                                                  llmPromptStyleOverride:
                                                      existingTask!
                                                          .llmPromptStyleOverride,
                                                  fileAttachments: List.from(
                                                      existingTask!
                                                          .fileAttachments),
                                                  hyperlinks: List.from(
                                                      existingTask!.hyperlinks),
                                                  verificationCriteria: existingTask!.verificationCriteria
                                                      .map((item) => AiVerificationCriteria(
                                                            description: item.description,
                                                            goal: item.goal,
                                                            isVerified: item.isVerified,
                                                            status: item.status,
                                                            proof: item.proof,
                                                            notes: item.notes,
                                                            requestClarification: item.requestClarification,
                                                            tryCount: item.tryCount,
                                                            isCommitted: item.isCommitted,
                                                            isPreview: item.isPreview,
                                                            attachments: List<String>.from(item.attachments),
                                                          ))
                                                      .toList(),
                                                );
                                                setStateBuilder(() =>
                                                    isForceClosing = true);
                                                _handleClose();
                                              },
                                            ),

                                          ],
                                          if (!isFolder && !isWorksheet) ...[
                                            ...fileAttachments
                                                .asMap()
                                                .entries
                                                .map((e) {
                                              final idx = e.key;
                                              final path = e.value;
                                              final fileName = path
                                                  .split(RegExp(r'[/\\]'))
                                                  .last;
                                              return PopupMenuButton<String>(
                                                tooltip: fileName,
                                                icon: _isImageFile(path)
                                                    ? ClipRRect(
                                                        borderRadius: BorderRadius.circular(3),
                                                        child: Image.file(
                                                          File(path),
                                                          width: 20,
                                                          height: 20,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (_, __, ___) => Icon(
                                                              Icons.insert_drive_file,
                                                              size: 16,
                                                              color: AppColors.panelTextSecondary),
                                                        ),
                                                      )
                                                    : Icon(
                                                        Icons.insert_drive_file,
                                                        size: 16,
                                                        color: AppColors.panelTextSecondary),
                                                color:
                                                    AppColors.panelBackground,
                                                onSelected: (val) {
                                                  if (val == 'remove') {
                                                    setStateBuilder(() =>
                                                        fileAttachments
                                                            .removeAt(idx));
                                                    _executeAutoSave();
                                                  } else if (val == 'open') {
                                                    try {
                                                      launchUrl(Uri.file(path));
                                                    } catch (_) {
                                                      Process.run(
                                                          'start', [path],
                                                          runInShell: true);
                                                    }
                                                  } else if (val == 'view') {
                                                    GlobalPickerState.instance.requestAttachmentViewer(
                                                      contextLabel: existingTask?.name ?? 'Task Attachments',
                                                      onLink: (linkedPath) {
                                                        if (!fileAttachments.contains(linkedPath)) {
                                                          setStateBuilder(() {
                                                            fileAttachments.add(linkedPath);
                                                            _executeAutoSave();
                                                          });
                                                        }
                                                      },
                                                    );
                                                    showAttachmentViewerWindow(context);
                                                  }
                                                },
                                                itemBuilder: (ctx) => [
                                                  PopupMenuItem(
                                                      value: 'view',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.visibility, size: 14, color: AppColors.accent),
                                                          const SizedBox(width: 8),
                                                          Text('View in Viewer',
                                                              style: TextStyle(
                                                                  color: AppColors.panelTextPrimary)),
                                                        ],
                                                      )),
                                                  PopupMenuItem(
                                                      value: 'open',
                                                      child: Text('Open File',
                                                          style: TextStyle(
                                                              color: AppColors
                                                                  .panelTextPrimary))),
                                                  PopupMenuItem(
                                                      value: 'remove',
                                                      child: Text('Delete',
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.red))),
                                                ],
                                              );
                                            }).toList(),

                                            IconButton(
                                              icon: const Icon(Icons.add_link,
                                                  size: 16),
                                              tooltip: 'Add Hyperlink',
                                              color:
                                                  AppColors.panelTextSecondary,
                                              onPressed: () async {
                                                final TextEditingController
                                                    linkCtrl =
                                                    TextEditingController();
                                                await showDialog<String>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    backgroundColor: AppColors
                                                        .panelBackground,
                                                    title: Text('Add Hyperlink',
                                                        style: TextStyle(
                                                            color: AppColors
                                                                .panelTextPrimary)),
                                                    content: TextField(
                                                      controller: linkCtrl,
                                                      style: TextStyle(
                                                          color: AppColors
                                                              .panelTextPrimary),
                                                      decoration:
                                                          InputDecoration(
                                                        hintText: 'https://...',
                                                        hintStyle: TextStyle(
                                                            color: AppColors
                                                                .panelTextSecondary),
                                                        enabledBorder: UnderlineInputBorder(
                                                            borderSide: BorderSide(
                                                                color: AppColors
                                                                    .borderSubtle)),
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx),
                                                        child: Text('Cancel',
                                                            style: TextStyle(
                                                                color: AppColors
                                                                    .panelTextSecondary)),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          if (linkCtrl.text
                                                              .isNotEmpty) {
                                                            setStateBuilder(() {
                                                              hyperlinks.add(
                                                                  linkCtrl
                                                                      .text);
                                                              if (existingTask !=
                                                                  null)
                                                                existingTask!
                                                                    .hyperlinks
                                                                    .add(linkCtrl
                                                                        .text);
                                                            });
                                                            _executeAutoSave();
                                                          }
                                                          Navigator.pop(ctx);
                                                        },
                                                        child: Text('Add',
                                                            style: TextStyle(
                                                                color: AppColors
                                                                    .accent)),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                            ...hyperlinks
                                                .asMap()
                                                .entries
                                                .map((e) {
                                              final idx = e.key;
                                              final link = e.value;
                                              String shortLink = link;
                                              if (shortLink
                                                  .startsWith('https://'))
                                                shortLink =
                                                    shortLink.substring(8);
                                              if (shortLink
                                                  .startsWith('http://'))
                                                shortLink =
                                                    shortLink.substring(7);
                                              if (shortLink.length > 20)
                                                shortLink =
                                                    shortLink.substring(0, 17) +
                                                        '...';
                                              return PopupMenuButton<String>(
                                                tooltip: shortLink,
                                                icon: Icon(Icons.link,
                                                    size: 16,
                                                    color: AppColors
                                                        .panelTextSecondary),
                                                color:
                                                    AppColors.panelBackground,
                                                onSelected: (val) {
                                                  if (val == 'remove') {
                                                    setStateBuilder(() =>
                                                        hyperlinks
                                                            .removeAt(idx));
                                                    _executeAutoSave();
                                                  } else if (val == 'open') {
                                                    try {
                                                      launchUrl(
                                                          Uri.parse(link));
                                                    } catch (_) {}
                                                  }
                                                },
                                                itemBuilder: (ctx) => [
                                                  PopupMenuItem(
                                                      value: 'open',
                                                      child: Text(
                                                          'Open Hyperlink',
                                                          style: TextStyle(
                                                              color: AppColors
                                                                  .panelTextPrimary))),
                                                  PopupMenuItem(
                                                      value: 'remove',
                                                      child: Text('Delete',
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.red))),
                                                ],
                                              );
                                            }).toList(),

                                          ],
                                          IconButton(
                                            icon: Icon(
                                                preventDeletion
                                                    ? Icons.shield
                                                    : Icons.shield_outlined,
                                                size: 16),
                                            tooltip: 'Prevent Deletion',
                                            color: preventDeletion
                                                ? Colors.green
                                                : AppColors.panelTextSecondary,
                                            onPressed: () {
                                              setStateBuilder(() =>
                                                  preventDeletion =
                                                      !preventDeletion);
                                              _executeAutoSave();
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(
                                                isReadOnly
                                                    ? Icons.lock
                                                    : Icons.lock_outline,
                                                size: 16),
                                            tooltip: 'Read Only',
                                            color: isReadOnly
                                                ? Colors.orange
                                                : AppColors.panelTextSecondary,
                                            onPressed: () {
                                              setStateBuilder(() =>
                                                  isReadOnly = !isReadOnly);
                                              _executeAutoSave();
                                            },
                                          ),
                                          if (isFolder)
                                            IconButton(
                                              icon: Icon(
                                                  applyLocksToChildren
                                                      ? Icons.lock_clock
                                                      : Icons
                                                          .lock_clock_outlined,
                                                  size: 16),
                                              tooltip:
                                                  'Apply Locks To Children',
                                              color: applyLocksToChildren
                                                  ? Colors.purpleAccent
                                                  : AppColors
                                                      .panelTextSecondary,
                                              onPressed: () {
                                                setStateBuilder(() =>
                                                    applyLocksToChildren =
                                                        !applyLocksToChildren);
                                                _executeAutoSave();
                                              },
                                            ),
                                          IconButton(
                                            icon: Icon(
                                                isIgnored
                                                    ? Icons.visibility_off
                                                    : Icons.visibility,
                                                size: 16),
                                            tooltip: "Don't Process (Ignore)",
                                            color: isIgnored
                                                ? Colors.redAccent
                                                : AppColors.panelTextSecondary,
                                            onPressed: () {
                                              setStateBuilder(
                                                  () => isIgnored = !isIgnored);
                                              _executeAutoSave();
                                            },
                                          ),
                                          const SizedBox(width: 16),
                                          if (isTaskReadOnly)
                                            Padding(
                                                padding: EdgeInsets.only(
                                                    right: 12.0),
                                                child: Row(children: [
                                                  Icon(
                                                      Icons
                                                          .warning_amber_rounded,
                                                      color: AppColors.summary,
                                                      size: 14),
                                                  SizedBox(width: 4),
                                                  Text(
                                                      'Task is locked (Read Only)',
                                                      style: TextStyle(
                                                          color:
                                                              AppColors.summary,
                                                          fontSize: AppUIConfig
                                                              .rootFontSize))
                                                ])),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              elevation: 0,
                                              side: BorderSide(
                                                  color: AppColors.error
                                                      .withOpacity(0.5)),
                                            ),
                                            onPressed: () {
                                              setStateBuilder(() {
                                                notesController.clear();
                                                summaryController.clear();
                                                verificationCriteriaList
                                                    .clear();
                                                for (var c
                                                    in _verificationControllers) {
                                                  c.dispose();
                                                }
                                                _verificationControllers
                                                    .clear();
                                                reviewQuestionsList.clear();
                                                fileAttachments.clear();
                                                hyperlinks.clear();
                                                isIgnored = false;
                                                isReadOnly = false;
                                                preventDeletion = false;
                                                applyLocksToChildren = false;
                                                customHighlightColor = null;
                                                customIconBackgroundColor =
                                                    null;
                                                customIconColor = null;
                                                customToolbarIconColor = null;
                                                customIconCode = null;
                                                _executeAutoSave();
                                              });
                                            },
                                            icon: Icon(
                                                Icons
                                                    .cleaning_services_outlined,
                                                size: 14,
                                                color: AppColors.error
                                                    .withOpacity(0.8)),
                                            label: Text('Reset',
                                                style: TextStyle(
                                                    color: AppColors.error
                                                        .withOpacity(0.8))),
                                          ),
                                          const SizedBox(width: 8),
                                          ValueListenableBuilder<String>(
                                            valueListenable: isTextInputFocusedNotifier,
                                            builder: (context, focusStatus, child) {
                                               return Tooltip(
                                                 message: 'Focus: $focusStatus',
                                                 child: Padding(
                                                   padding: const EdgeInsets.only(right: 8),
                                                   child: Icon(Icons.edit_note, color: focusStatus.startsWith('YES') ? Colors.redAccent : Colors.transparent, size: 20),
                                                 ),
                                               );
                                            }
                                          ),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: hasUnsavedEdits
                                                  ? AppColors.accent
                                                      .withOpacity(0.8)
                                                  : Colors.transparent,
                                              elevation:
                                                  hasUnsavedEdits ? 2 : 0,
                                              side: hasUnsavedEdits
                                                  ? null
                                                  : BorderSide(
                                                      color: AppColors.controlBorder),
                                            ),
                                            onPressed: () {
                                              if (newSubTaskController.text.trim().isNotEmpty) {
                                                setStateBuilder(() {
                                                  verificationCriteriaList.add(AiVerificationCriteria(
                                                      description: newSubTaskController.text.trim()));
                                                  _verificationControllers.add(TextEditingController(
                                                      text: newSubTaskController.text.trim()));
                                                  _verificationGoalControllers.add(TextEditingController());
                                                  newSubTaskController.clear();
                                                });
                                              }
                                              _executeAutoSave(instant: true);
                                            },
                                            icon: Icon(
                                                hasUnsavedEdits
                                                    ? Icons.save
                                                    : Icons.save_outlined,
                                                size: 14,
                                                color: Colors.white),
                                            label: Text('Save',
                                                style: TextStyle(
                                                    color: AppColors
                                                        .panelTextPrimary)),
                                          ),
                                          if (isTaskReadOnly) ...[
                                            const SizedBox(width: 16),
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.orange
                                                      .withOpacity(0.8)),
                                              onPressed: () {
                                                AiBridgeService.instance
                                                    .unlockTask(
                                                        existingTask!.id);
                                                setStateBuilder(() =>
                                                    isTaskReadOnly = false);
                                              },
                                              icon: const Icon(Icons.lock_open,
                                                  size: 14),
                                              label: Text('Unlock',
                                                  style: TextStyle(
                                                      color: AppColors
                                                          .panelTextPrimary)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ], // end Column children
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.isDocked) {
      return Container(
        color: AppColors.windowBackground,
        child: contentWidget,
      );
    }

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      width: _width,
      height: _height,
      child: Listener(
        onPointerDown: (_) => widget.onFocus?.call(),
        child: Material(
          color: Colors.transparent,
          elevation: 8,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.windowBackground.withOpacity(_bgOpacity),
              borderRadius:
                  BorderRadius.circular(AppUIConfig.windowBorderRadius),
              border: AppUIConfig.windowBorderWidth > 0 
                  ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'task_editor' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) 
                  : null,
              boxShadow: [
                BoxShadow(
                    color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))
              ],
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    GestureDetector(
                      onPanUpdate: (d) {
                        setState(() {
                          _offset += d.delta;
                        });
                      },
                      onPanEnd: (_) => _savePreferences(),
                      child: Container(
                        height: AppUIConfig.titleBarHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                              color: AppColors.titleBarBackground
                                .withOpacity(_bgOpacity),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(
                                    AppUIConfig.windowBorderRadius))),
                        child: Row(
                          children: [
                            Icon(
                                AppUIConfig.bridgeIconCodePoint != null
                                    ? IconData(AppUIConfig.bridgeIconCodePoint!,
                                        fontFamily: 'MaterialIcons')
                                    : Icons.edit_note,
                                size: 20,
                                color: AppUIConfig.bridgeIconColor ??
                                    AppToolWindows.getDef('task_editor')
                                        .color ??
                                    AppColors.accent),
                            const SizedBox(width: 8),
                             Text(AppUIConfig.formatWindowTitle('Task Editor'),
                                 style: TextStyle(
                                     color: AppColors.titleBarTextPrimary,
                                     fontSize: AppUIConfig.windowTitleFontSize,
                                     fontWeight: AppUIConfig.windowTitleFontWeight)),

                             Expanded(child: const SizedBox()),
                             ..._buildCustomizationButtons(context),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: Icon(Icons.close,
                                  size: 18,
                                  color: AppColors.titleBarTextSecondary),
                              onPressed: _handleClose,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                            bottomLeft:
                                Radius.circular(AppUIConfig.windowBorderRadius),
                            bottomRight: Radius.circular(
                                AppUIConfig.windowBorderRadius)),
                        child: contentWidget,
                      ),
                    ),
                  ],
                ),
                rz(
                    t: 0,
                    b: 0,
                    l: -3,
                    w: 6,
                    cursor: SystemMouseCursors.resizeLeftRight,
                    pan: (d) {
                      _width -= d.delta.dx;
                      _offset += Offset(d.delta.dx, 0);
                    }),
                rz(
                    t: 0,
                    b: 0,
                    r: -3,
                    w: 6,
                    cursor: SystemMouseCursors.resizeLeftRight,
                    pan: (d) {
                      _width += d.delta.dx;
                    }),
                rz(
                    l: 0,
                    r: 0,
                    t: -3,
                    h: 6,
                    cursor: SystemMouseCursors.resizeUpDown,
                    pan: (d) {
                      _height -= d.delta.dy;
                      _offset += Offset(0, d.delta.dy);
                    }),
                rz(
                    l: 0,
                    r: 0,
                    b: -3,
                    h: 6,
                    cursor: SystemMouseCursors.resizeUpDown,
                    pan: (d) {
                      _height += d.delta.dy;
                    }),
                rz(
                    t: -3,
                    l: -3,
                    w: 6,
                    h: 6,
                    cursor: SystemMouseCursors.resizeUpLeftDownRight,
                    pan: (d) {
                      _width -= d.delta.dx;
                      _height -= d.delta.dy;
                      _offset += d.delta;
                    }),
                rz(
                    t: -3,
                    r: -3,
                    w: 6,
                    h: 6,
                    cursor: SystemMouseCursors.resizeUpRightDownLeft,
                    pan: (d) {
                      _width += d.delta.dx;
                      _height -= d.delta.dy;
                      _offset += Offset(0, d.delta.dy);
                    }),
                rz(
                    b: -3,
                    l: -3,
                    w: 6,
                    h: 6,
                    cursor: SystemMouseCursors.resizeUpRightDownLeft,
                    pan: (d) {
                      _width -= d.delta.dx;
                      _height += d.delta.dy;
                      _offset += Offset(d.delta.dx, 0);
                    }),
                rz(
                    b: -3,
                    r: -3,
                    w: 6,
                    h: 6,
                    cursor: SystemMouseCursors.resizeUpLeftDownRight,
                    pan: (d) {
                      _width += d.delta.dx;
                      _height += d.delta.dy;
                    }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}