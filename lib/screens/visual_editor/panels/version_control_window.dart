import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../visual_editor_screen.dart';
import '../../../constants.dart';
import '../../../services/version_control_service.dart';
import '../../../services/ai_bridge_service.dart';
import '../../../services/sandbox_service.dart';
import 'global_task_editor_window.dart';
import '../../../state/global_task_editor_state.dart';
import '../components/folder_hierarchy_view.dart';
import 'file_history_dialog.dart';

final ValueNotifier<bool> showVersionControlNotifier = ValueNotifier(false);

void showVersionControlWindow(BuildContext context) {
  if (showVersionControlNotifier.value) return;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showVersionControl'), true));
  showVersionControlNotifier.value = true;
}

void hideVersionControlWindow() {
  showVersionControlNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showVersionControl'), false));
}

class VersionControlWindow extends StatefulWidget {
  static final ValueNotifier<String?> highlightedTaskId = ValueNotifier(null);
  final bool isDocked;
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  const VersionControlWindow({super.key, required this.onClose, this.onFocus, this.isDocked = false});
  @override
  State<VersionControlWindow> createState() => _VersionControlWindowState();
}

class _VersionControlWindowState extends State<VersionControlWindow> with SingleTickerProviderStateMixin {
  final Map<String, GlobalKey> _timelineKeys = {};
  final Map<String, Future<List<Map<String, String>>>> _commitFutures = {};
  late TabController _tabController;

  bool _isLoaded = false;
  double _width = 500;
  double _height = 400;
  double _bgOpacity = 0.8;
  Offset _offset = const Offset(200, 200);

  Directory? _currentExplorerFolder;
  List<Directory> _explorerFolderPath = [];
  List<FileSystemEntity> _explorerItems = [];
  FileSystemEntity? _selectedExplorerItem;
  bool _isExplorerLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    SandboxService.instance.init();
    AiBridgeService.instance.reloadTimelineHistory();
    VersionControlWindow.highlightedTaskId.addListener(_scrollToHighlightedTask);
    _loadPreferences();
    _loadExplorerFiles();
    VisualEditorScreen.currentWorkspace.addListener(_loadPreferences);
    VisualEditorScreen.currentWorkspace.addListener(_loadExplorerFiles);
    VisualEditorScreen.configRefreshNotifier.addListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.addListener(_loadExplorerFiles);
    VisualEditorScreen.activeWindowNotifier.addListener(_onActiveWindowChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    VersionControlWindow.highlightedTaskId.removeListener(_scrollToHighlightedTask);
    VisualEditorScreen.currentWorkspace.removeListener(_loadPreferences);
    VisualEditorScreen.currentWorkspace.removeListener(_loadExplorerFiles);
    VisualEditorScreen.configRefreshNotifier.removeListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.removeListener(_loadExplorerFiles);
    VisualEditorScreen.activeWindowNotifier.removeListener(_onActiveWindowChanged);
    super.dispose();
  }

  String _formatDateStr(String d) {
    final dt = DateTime.tryParse(d)?.toLocal();
    if (dt != null) {
      String hour = dt.hour.toString().padLeft(2, '0');
      String minute = dt.minute.toString().padLeft(2, '0');
      String datePart = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      return '$datePart $hour:$minute'.trim();
    }
    return d;
  }

  String _formatRelativeTime(String dateStr) {
    final dt = DateTime.tryParse(dateStr)?.toLocal();
    if (dt == null) return dateStr;
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays >= 365) {
      final years = (difference.inDays / 365).floor();
      return 'committed $years ${years == 1 ? "year" : "years"} ago';
    } else if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      return 'committed $months ${months == 1 ? "month" : "months"} ago';
    } else if (difference.inDays >= 7) {
      final weeks = (difference.inDays / 7).floor();
      return 'committed $weeks ${weeks == 1 ? "week" : "weeks"} ago';
    } else if (difference.inDays >= 1) {
      return 'committed ${difference.inDays} ${difference.inDays == 1 ? "day" : "days"} ago';
    } else if (difference.inHours >= 1) {
      return 'committed ${difference.inHours} ${difference.inHours == 1 ? "hour" : "hours"} ago';
    } else if (difference.inMinutes >= 1) {
      return 'committed ${difference.inMinutes} ${difference.inMinutes == 1 ? "minute" : "minutes"} ago';
    } else {
      return 'committed just now';
    }
  }

  String _getBasename(String path) {
    var p = path.replaceAll('\\', '/');
    while (p.endsWith('/') && p.length > 1) {
      p = p.substring(0, p.length - 1);
    }
    return p.split('/').last;
  }

  String _normalizePath(String path) {
    var p = path.replaceAll('\\', '/').toLowerCase();
    while (p.endsWith('/') && p.length > 1) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  void _scrollToHighlightedTask() {
    final taskId = VersionControlWindow.highlightedTaskId.value;
    if (taskId != null) {
      if (_tabController.index != 1) {
        _tabController.animateTo(1);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted) return;
          final timelineCommits = AiBridgeService.instance.timelineHistory;
          final commit = timelineCommits.firstWhere(
            (c) => c.taskIds.contains(taskId),
            orElse: () => timelineCommits.firstWhere(
              (c) => c.id == taskId,
              orElse: () => TimelineCommit(id: '', taskIds: [], title: '', summary: '', commitHash: '', commitDate: '')
            )
          );
          if (commit.id.isNotEmpty) {
            final key = _timelineKeys[commit.id];
            if (key != null && key.currentContext != null) {
              Scrollable.ensureVisible(key.currentContext!, duration: const Duration(milliseconds: 300), alignment: 0.5);
            }
          }
        });
      });
    }
  }

  void _onActiveWindowChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isLoaded = true;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.8;
        if (!widget.isDocked) {
          _width = prefs.getDouble(VisualEditorScreen.getPrefKey('versionControlWidth')) ?? 500;
          _height = prefs.getDouble(VisualEditorScreen.getPrefKey('versionControlHeight')) ?? 400;
          final dx = prefs.getDouble(VisualEditorScreen.getPrefKey('versionControlX'));
          final dy = prefs.getDouble(VisualEditorScreen.getPrefKey('versionControlY'));
          if (dx != null && dy != null) {
             _offset = Offset(dx, dy);
          }
        }
      });
    }
  }




  Future<void> _savePreferences() async {
    if (widget.isDocked) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('versionControlWidth'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('versionControlHeight'), _height);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('versionControlX'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('versionControlY'), _offset.dy);
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController.length != 3) {
      final oldIndex = _tabController.index;
      _tabController.dispose();
      _tabController = TabController(
        length: 3,
        vsync: this,
        initialIndex: oldIndex < 3 ? oldIndex : 0,
      );
    }
    if (!_isLoaded) return const SizedBox.shrink();

    Widget contentWidget = _buildContent();

    if (widget.isDocked) {
      return Container(
        color: AppColors.windowBackground,
        child: contentWidget,
      );
    }

    Widget rz({
      double? t, double? b, double? l, double? r, double? w, double? h,
      required MouseCursor cursor,
      required void Function(DragUpdateDetails) pan,
    }) => Positioned(
      top: t, bottom: b, left: l, right: r, width: w, height: h,
      child: MouseRegion(cursor: cursor, child: GestureDetector(behavior: HitTestBehavior.opaque, onPanUpdate: pan, onPanEnd: (_) => _savePreferences(), child: Container(color: Colors.transparent)))
    );

    return ValueListenableBuilder<double>(
        valueListenable: VisualEditorScreen.globalUiScale,
        builder: (context, scale, child) {
          final mq = MediaQuery.of(context).size;
          final dx = _offset.dx.clamp(0.0, (mq.width - 100).clamp(0.0, double.infinity));
          final dy = _offset.dy.clamp(0.0, (mq.height - 100).clamp(0.0, double.infinity));

          return Positioned(
            left: dx,
            top: dy,
            child: Transform.scale(scale: scale, alignment: Alignment.topLeft,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Listener(
                  onPointerDown: (_) => widget.onFocus?.call(),
                  behavior: HitTestBehavior.deferToChild,
                  child: Material(
                    color: Colors.transparent,
                  elevation: 8,
                  child: Container(
                    width: _width / scale,
                    height: _height / scale,
                    clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'version_control' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) : null,
                      color: AppColors.windowBackground.withValues(alpha: _bgOpacity),
                      borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                    ),
                    child: Column(children: [
                      GestureDetector(
                        onPanUpdate: (details) {
                          setState(() => _offset += details.delta);
                        },
                        onPanEnd: (_) => _savePreferences(),
                        child: Container(
                          height: AppUIConfig.titleBarHeight / scale,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                              color: AppColors.titleBarBackground.withValues(alpha: _bgOpacity),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(AppUIConfig.windowBorderRadius))),
                          child: Row(
                            children: [
                              Icon((AppToolWindows.getDef('version_control')?.icon ?? Icons.source), size: 16 / scale, color: (AppToolWindows.getDef('version_control')?.color ?? Colors.grey)),
                              const SizedBox(width: 8),
                              Text(AppUIConfig.windowTitleUppercase ? (AppToolWindows.getDef('version_control')?.name ?? 'Version Control').toUpperCase() : (AppToolWindows.getDef('version_control')?.name ?? 'Version Control'), style: TextStyle(
                                      color: AppColors.titleBarTextPrimary,
                                      fontSize: AppUIConfig.windowTitleFontSize / scale,
                                      fontWeight: AppUIConfig.windowTitleFontWeight)),
                                const Spacer(),
                                Tooltip(
                                  message: 'Refresh',
                                  child: IconButton(
                                    icon: Icon(Icons.refresh, size: 16 / scale, color: AppColors.titleBarTextSecondary),
                                    onPressed: () {
                                      setState(() {
                                        _commitFutures.clear();
                                      });
                                      SandboxService.instance.reload();
                                      AiBridgeService.instance.reloadTimelineHistory();
                                      _loadExplorerFiles();
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: Icon(Icons.close, size: 18 / scale, color: AppColors.titleBarTextSecondary),
                                  onPressed: widget.onClose,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              ],
                            ),
                          ),
                        ),
                        Expanded(child: contentWidget),
                      ])
                  ),
                ),
              ),
                rz(t: 0, l: 12, r: 12, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){
                    double nH = _height - (d.delta.dy * scale);
                    if (nH >= 200 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy * scale); }
                })),
                rz(b: 0, l: 12, r: 12, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){
                    double nH = _height + (d.delta.dy * scale);
                    if (nH >= 200 && nH <= 1200) { _height = nH; }
                })),
                rz(l: 0, t: 12, b: 12, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){
                    double nW = _width - (d.delta.dx * scale);
                    if (nW >= 200 && nW <= 1600) { _width = nW; _offset += Offset(d.delta.dx * scale, 0); }
                })),
                rz(r: 0, t: 12, b: 12, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){
                    double nW = _width + (d.delta.dx * scale);
                    if (nW >= 200 && nW <= 1600) { _width = nW; }
                })),
                rz(t: 0, l: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){
                    double nW = _width - (d.delta.dx * scale); double nH = _height - (d.delta.dy * scale);
                    if (nW >= 200 && nW <= 1600) { _width = nW; _offset += Offset(d.delta.dx * scale, 0); }
                    if (nH >= 200 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy * scale); }
                })),
                rz(t: 0, r: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (d) => setState((){
                    double nW = _width + (d.delta.dx * scale); double nH = _height - (d.delta.dy * scale);
                    if (nW >= 200 && nW <= 1600) { _width = nW; }
                    if (nH >= 200 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy * scale); }
                })),
                rz(b: 0, l: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (d) => setState((){
                    double nW = _width - (d.delta.dx * scale); double nH = _height + (d.delta.dy * scale);
                    if (nW >= 200 && nW <= 1600) { _width = nW; _offset += Offset(d.delta.dx * scale, 0); }
                    if (nH >= 200 && nH <= 1200) { _height = nH; }
                })),
                rz(b: 0, r: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){
                    double nW = _width + (d.delta.dx * scale); double nH = _height + (d.delta.dy * scale);
                    if (nW >= 200 && nW <= 1600) { _width = nW; }
                    if (nH >= 200 && nH <= 1200) { _height = nH; }
                })),
              ],
            ),
           ),
          );
        },
    );
  }

  Future<void> _copyTaskPromptToClipboard(BuildContext context, AiTask task) async {
    await AiBridgeService.instance.compilePrimaryDirectivesFile(task);
    final prompt = await AiBridgeService.instance.buildTaskPrompt(task);
    
    await Clipboard.setData(ClipboardData(text: prompt));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Prompt for "${task.name}" copied to clipboard!'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _sendTaskToAiBridge(BuildContext context, AiTask task) async {
    final uncheckedTasks = task.verificationCriteria
        .where((e) => (e.status != AiVerificationStatus.verified &&
            e.status != AiVerificationStatus.ignored &&
            !e.isPreview))
        .toList();
    if (uncheckedTasks.isNotEmpty) {
      uncheckedTasks.first.status = AiVerificationStatus.pendingReview;
      final updatedCriteria = task.verificationCriteria
          .map((e) => AiVerificationCriteria(
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
              ))
          .toList();
      await AiBridgeService.instance.updateTaskDetails(
        task.id,
        task.name,
        task.description,
        verificationCriteria: updatedCriteria,
        status: AiTaskStatus.inTesting,
      );
    } else {
      await AiBridgeService.instance.updateTaskStatus(task.id, AiTaskStatus.inTesting);
    }

    final updatedTask = AiBridgeService.instance.tasks.firstWhere((t) => t.id == task.id, orElse: () => task);

    await AiBridgeService.instance.compilePrimaryDirectivesFile(updatedTask);
    final prompt = await AiBridgeService.instance.buildTaskPrompt(updatedTask);

    await AiBridgeService.instance.sendToQueue(prompt, true, taskIds: [task.id]);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Task "${task.name}" sent to AI Bridge!'),
        duration: const Duration(seconds: 4),
      ));
    }
  }

  Widget _buildContent() {
    return ListenableBuilder(
      listenable: Listenable.merge([AiBridgeService.instance, GlobalTaskEditorState.instance.activeRequest, SandboxService.instance]),
      builder: (context, _) {
        final tasks = AiBridgeService.instance.tasks;
        
        final sandboxTaskIds = SandboxService.instance.sandboxTaskIds;
        
        bool isTaskCommitted(AiTask t) {
          return t.status == AiTaskStatus.completed;
        }

        final activeTasks = tasks.where((t) => !t.isFolder && sandboxTaskIds.contains(t.id) && !isTaskCommitted(t)).toList();
        
        final timelineCommits = AiBridgeService.instance.timelineHistory;
        
        return Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: Colors.blueAccent,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
              tabs: const [
                Tab(text: 'ACTIVE TASKS'),
                Tab(text: 'TIMELINE HISTORY'),
                Tab(text: 'EXPLORER'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // TAB 1: ACTIVE TASKS
                  Column(
                    children: [
                      Container(
                        height: 36,
                        width: double.infinity,
                        color: AppColors.toolbarBackground,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Tooltip(
                              message: 'Send to AI Bridge',
                              child: IconButton(
                                icon: const Icon(Icons.flash_on, size: 16),
                                color: activeTasks.isNotEmpty ? Colors.amber : AppColors.textMuted,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: activeTasks.isNotEmpty
                                    ? () => _sendTaskToAiBridge(context, activeTasks.first)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Tooltip(
                              message: 'Copy prompt to clipboard',
                              child: IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                color: activeTasks.isNotEmpty ? AppColors.toolbarTextPrimary : AppColors.textMuted,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: activeTasks.isNotEmpty
                                    ? () => _copyTaskPromptToClipboard(context, activeTasks.first)
                                    : null,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              icon: const Icon(Icons.commit, size: 14, color: Colors.blueAccent),
                              label: const Text('Commit Tasks', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                              onPressed: () async {
                                if (AiBridgeService.instance.isThinking) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot commit while AI bridge is working.')));
                                  return;
                                }
                                if (activeTasks.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active tasks to commit.')));
                                  return;
                                }
                                
                                bool hasOpen = false;
                                for (var t in activeTasks) {
                                  if (t.verificationCriteria.any((e) => e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored)) {
                                    hasOpen = true;
                                    break;
                                  }
                                }
                                
                                if (hasOpen) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please resolve all open checklist items before committing, or ignore them.')));
                                  return;
                                }
                                
                                final defaultCommitName = AiBridgeService.instance.generateCommitName(activeTasks);
                                
                                final taskIds = activeTasks.map((t) => t.id).toList();
                                final success = await AiBridgeService.instance.performManualCommitAll(taskIds, defaultCommitName);
                                if (success && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tasks committed successfully.')));
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      Container(height: 1, color: AppColors.border),
                      Expanded(
                        child: activeTasks.isEmpty 
                          ? Center(child: Text('No active tasks', style: TextStyle(color: AppColors.textMuted)))
                          : ListView.builder(
                              itemCount: activeTasks.length,
                              itemBuilder: (ctx, i) {
                                final t = activeTasks[i];
                                final isEvenTask = (i % 2 == 0);
                                List<Widget> taskChildren = [];
                                if (t.verificationCriteria.isEmpty) {
                                  taskChildren.add(
                                    InkWell(
                                      onTap: () {
                                        GlobalTaskEditorState.instance.requestEdit(existingTask: t);
                                        showTaskEditorWindow(context);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.info_outline, color: Colors.blueAccent, size: 14),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                t.description.isNotEmpty ? t.description : 'Pending implementation',
                                                style: TextStyle(color: AppColors.textMuted, fontSize: AppUIConfig.smallFontSize),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  );
                                } else {
                                  int vcIndex = 0;
                                  taskChildren.addAll(t.verificationCriteria.map((vc) {
                                    final isEvenVc = (vcIndex++ % 2 == 0);
                                    final vcBg = isEvenVc
                                        ? Colors.white.withValues(alpha: 0.02)
                                        : Colors.white.withValues(alpha: 0.05);
                                    IconData iconData = Icons.radio_button_unchecked;
                                    Color iconColor = AppColors.textMuted;
                                    
                                    if (vc.isVerified) {
                                      iconData = Icons.check_circle;
                                      iconColor = Colors.green;
                                    } else if (vc.status == AiVerificationStatus.pendingReview) {
                                      iconData = Icons.hourglass_empty;
                                      iconColor = Colors.orange;
                                    } else if (vc.status == AiVerificationStatus.ignored) {
                                      iconData = Icons.block;
                                      iconColor = Colors.redAccent;
                                    }
                                    
                                    final decoration = vc.isPreview
                                        ? BoxDecoration(
                                            color: Colors.orange.withValues(alpha: 0.08),
                                            border: const Border(
                                              left: BorderSide(color: Colors.orange, width: 3),
                                            ),
                                          )
                                        : BoxDecoration(color: vcBg);
                                    
                                    return Container(
                                      decoration: decoration,
                                      child: InkWell(
                                        onTap: () {
                                          GlobalTaskEditorState.instance.requestEdit(existingTask: t);
                                          showTaskEditorWindow(context);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Icon(iconData, color: iconColor, size: 14),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Row(
                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                      children: [
                                                        if (vc.isPreview) ...[
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
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
                                                          const SizedBox(width: 6),
                                                        ],
                                                        Expanded(
                                                          child: Text(
                                                            vc.description,
                                                            style: TextStyle(
                                                              color: AppColors.textPrimary,
                                                              fontSize: AppUIConfig.smallFontSize,
                                                              decoration: vc.isVerified ? TextDecoration.lineThrough : null,
                                                              decorationColor: Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (vc.goal.isNotEmpty)
                                                      Text(
                                                        vc.goal,
                                                        style: TextStyle(
                                                          color: AppColors.textSecondary,
                                                          fontSize: AppUIConfig.smallFontSize * 0.85,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }));
                                  
                                  if (t.verificationCriteria.any((e) => e.isPreview)) {
                                    taskChildren.add(_buildPreviewActionBanner(context, t));
                                  }
                                }

                                return Container(
                                  color: isEvenTask
                                      ? Colors.white.withValues(alpha: 0.01)
                                      : Colors.white.withValues(alpha: 0.03),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                      key: PageStorageKey<String>('active_task_${t.id}'),
                                      initiallyExpanded: true,
                                      tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                      title: Text(t.name, style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.smallFontSize, fontWeight: FontWeight.bold)),
                                      subtitle: t.summary.isNotEmpty ? Text(t.summary, style: TextStyle(color: AppColors.textMuted, fontSize: AppUIConfig.smallFontSize * 0.85, fontStyle: FontStyle.italic)) : null,
                                      children: taskChildren,
                                    ),
                                  ),
                                );
                              }
                            ),
                      ),
                    ],
                  ),
                  
                  // TAB 2: TIMELINE HISTORY
                  Column(
                    children: [
                      Container(
                        height: 36,
                        width: double.infinity,
                        color: AppColors.toolbarBackground,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.save_alt, size: 14, color: Colors.orangeAccent),
                              label: const Text('Create Restore Point', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                              onPressed: () async {
                                final controller = TextEditingController();
                                final note = await showDialog<String>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AppColors.panelBackground,
                                    title: const Text('Create Restore Point', style: TextStyle(color: Colors.white)),
                                    content: TextField(
                                      controller: controller,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: const InputDecoration(
                                        hintText: 'Enter restore point name...',
                                        hintStyle: TextStyle(color: Colors.white54),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, null),
                                        child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, controller.text),
                                        child: Text('Create', style: const TextStyle(color: Colors.blueAccent)),
                                      ),
                                    ],
                                  ),
                                );

                                if (note == null || note.isEmpty) return;

                                try {
                                  final desc = note;
                                  final hash = await VersionControlService.instance.createRestorePoint(desc);
                                  
                                  if (hash.isNotEmpty && !hash.startsWith('No changes') && !hash.startsWith('Failed') && !hash.startsWith('Local')) {
                                    final openTask = GlobalTaskEditorState.instance.activeRequest.value?.existingTask;
                                    final taskIds = openTask != null ? [openTask.id] : <String>[];
                                    await AiBridgeService.instance.appendCheckpointToTimeline(desc, hash, taskIds: taskIds);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore Point Created')));
                                    }
                                  } else if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create checkpoint: $hash')));
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      Container(height: 1, color: AppColors.border),
                      Expanded(
                        child: timelineCommits.isEmpty
                          ? Center(child: Text('No completed tasks yet', style: TextStyle(color: AppColors.textMuted)))
                          : SingleChildScrollView(
                              child: Column(
                                children: _buildTimelineNodes(context, timelineCommits),
                              ),
                            ),
                      ),
                    ],
                  ),
                  
                  // TAB 3: FILES EXPLORER
                  Column(
                    children: [
                      Expanded(
                        child: _buildExplorerTab(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }
    );
  }

  List<Widget> _buildTimelineNodes(BuildContext context, List<TimelineCommit> commits) {
    if (commits.isEmpty) return [];

    List<Widget> result = [];
    for (int i = 0; i < commits.length; i++) {
      final c = commits[i];
      _timelineKeys[c.id] ??= GlobalKey();

      // Consolidated trailing icons — no SizedBox spacers between them
      Widget trailingRow = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (i + 1 < commits.length) ...[
            IconButton(
              icon: const Icon(Icons.cleaning_services, size: 14, color: Colors.blueAccent),
              tooltip: 'Squash Older History',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.panelBackground,
                    title: const Text('Squash Older History', style: TextStyle(color: Colors.white)),
                    content: Text('This will permanently squash all checkpoints older than this one into a single baseline commit to reduce repository bloat. This cannot be undone. Proceed?', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Squash', style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                );
                if (confirm != true) return;
                try {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Squashing older history...')));
                  await VersionControlService.instance.cleanupTimelineHistory(i + 1);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('History squashed successfully!')));
                    SandboxService.instance.reload();
                  }
                } catch (e, st) {
                  debugPrint('Squash Error: $e\n$st');
                  try {
                    File('.ai_bridge/bridge_error.txt').writeAsStringSync('Squash Error:\n$e\n$st', mode: FileMode.append);
                  } catch (_) {}
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Failed: $e',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                              tooltip: 'Copy Error Log',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: 'Squash Error:\n$e\n$st'));
                              },
                            ),
                          ],
                        ),
                        backgroundColor: Colors.red.shade900,
                        duration: const Duration(seconds: 8),
                      ),
                    );
                  }
                }
              },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
            tooltip: 'Delete Timeline Entry',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () {
              AiBridgeService.instance.deleteTimelineCommit(c.id);
            },
          ),
          IconButton(
            icon: const Icon(Icons.restore, size: 14, color: Colors.orange),
            tooltip: 'Restore to Here',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () async {
              try {
                await VersionControlService.instance.restoreToCommit(c.commitHash);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restored successfully!')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to restore: $e')));
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser, size: 14, color: Colors.blueAccent),
            tooltip: 'Open in GitHub',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () async {
              await VersionControlService.instance.openGithubCommit(c.commitHash);
            },
          ),
        ],
      );

      if (c.title == 'Checkpoint') {
        // Restore Point — title at rootFontSize (20% bigger than smallFontSize which is rootFontSize*0.8)
        result.add(
          ValueListenableBuilder<String?>(
            valueListenable: VersionControlWindow.highlightedTaskId,
            builder: (ctx, highlightedId, _) {
              final isHighlighted = highlightedId != null && c.taskIds.contains(highlightedId);
              return Container(
                key: _timelineKeys[c.id],
                margin: const EdgeInsets.only(top: 3, bottom: 1),
                decoration: BoxDecoration(
                   border: Border.all(color: (isHighlighted ? Colors.green : Colors.orangeAccent).withValues(alpha: 0.3)),
                   borderRadius: BorderRadius.circular(4),
                   color: (isHighlighted ? Colors.green : Colors.orangeAccent).withValues(alpha: 0.05),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    title: InkWell(
                      onTap: () {
                        if (c.taskIds.isNotEmpty) {
                          try {
                            final t = AiBridgeService.instance.tasks.firstWhere((task) => task.id == c.taskIds.first);
                            GlobalTaskEditorState.instance.requestEdit(existingTask: t);
                            showTaskEditorWindow(context);
                          } catch (_) {}
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: AppUIConfig.rootFontSize),
                          ),
                          const SizedBox(height: 2),
                          Text(
                             _formatRelativeTime(c.commitDate),
                             maxLines: 1,
                             overflow: TextOverflow.ellipsis,
                             style: TextStyle(color: AppColors.textMuted, fontSize: AppUIConfig.smallFontSize * 0.85),
                          ),
                        ],
                      ),
                    ),
                    trailing: trailingRow,
                    children: _buildTimelineNodes(context, commits.sublist(i + 1)),
                  ),
                ),
              );
            }
          )
        );
        break; // Rest of the commits are children of this checkpoint
      } else {
        // Standard commit rows — alternating row colors, hash left of timestamp in subtitle
        final isEvenRow = (i % 2 == 0);
        final rowBg = isEvenRow
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.white.withValues(alpha: 0.05);

        final shortHash = c.commitHash.length > 7
            ? c.commitHash.substring(0, 7)
            : c.commitHash;
        final isRealHash = c.commitHash.isNotEmpty &&
            c.commitHash != 'No Git Changes' &&
            !c.commitHash.startsWith('No changes');
        final subtitleText = isRealHash
            ? '$shortHash  ·  ${_formatRelativeTime(c.commitDate)}'
            : _formatRelativeTime(c.commitDate);

        result.add(
          ValueListenableBuilder<String?>(
            valueListenable: VersionControlWindow.highlightedTaskId,
            builder: (ctx, highlightedId, _) {
              final isHighlighted = highlightedId != null && c.taskIds.contains(highlightedId);
              return Container(
                key: _timelineKeys[c.id],
                color: isHighlighted ? Colors.green.withValues(alpha: 0.2) : rowBg,
                child: InkWell(
                  onTap: () {
                    if (c.taskIds.isNotEmpty) {
                      try {
                        final t = AiBridgeService.instance.tasks.firstWhere((task) => task.id == c.taskIds.first);
                        GlobalTaskEditorState.instance.requestEdit(existingTask: t);
                        showTaskEditorWindow(context);
                      } catch (_) {}
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.commit, color: Colors.green, size: 14),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                c.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.smallFontSize),
                              ),
                              Text(
                                subtitleText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: AppUIConfig.smallFontSize * 0.85,
                                  fontFamily: isRealHash ? 'monospace' : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        trailingRow,
                      ],
                    ),
                  ),
                ),
              );
            }
          )
        );
      }
    }
    return result;
  }

  Future<void> _loadExplorerFiles() async {
    final repoPath = await VersionControlService.instance.getLocalRepositoryPath();
    if (repoPath == null || repoPath.isEmpty) {
      if (mounted) {
        setState(() {
          _explorerItems = [];
          _isExplorerLoading = false;
        });
      }
      return;
    }

    if (_isExplorerLoading == false && _explorerItems.isEmpty) {
      setState(() {
        _isExplorerLoading = true;
      });
    }

    try {
      final targetDir = _currentExplorerFolder ?? Directory(repoPath);
      if (await targetDir.exists()) {
        final list = await targetDir.list().toList();
        final filteredList = list.where((entity) {
          final name = _getBasename(entity.path);
          if (name == '.git') return false;
          if (name == 'build' || name == 'node_modules') return false;
          return true;
        }).toList();

        filteredList.sort((a, b) {
          final aIsDir = a is Directory;
          final bIsDir = b is Directory;
          if (aIsDir && !bIsDir) return -1;
          if (!aIsDir && bIsDir) return 1;
          return a.path.compareTo(b.path);
        });

        if (mounted) {
          setState(() {
            _explorerItems = filteredList;
            _isExplorerLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _explorerItems = [];
            _isExplorerLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading explorer files: $e');
      if (mounted) {
        setState(() {
          _explorerItems = [];
          _isExplorerLoading = false;
        });
      }
    }
  }

  void _navigateExplorerToFolder(Directory? folder) async {
    final repoPathRaw = await VersionControlService.instance.getLocalRepositoryPath();
    if (repoPathRaw == null || repoPathRaw.isEmpty) return;
    final repoPath = _normalizePath(repoPathRaw);

    List<Directory> newPath = [];
    if (folder != null) {
      var current = folder;
      while (_normalizePath(current.path) != repoPath && current.parent.path != current.path) {
        newPath.insert(0, current);
        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    }

    setState(() {
      _currentExplorerFolder = folder;
      _explorerFolderPath = newPath;
      _selectedExplorerItem = null;
    });

    _loadExplorerFiles();
  }

  void _openRestoreGitForLocalFile(FileSystemEntity file) {
    showDialog(
      context: context,
      builder: (context) => FileHistoryDialog(
        filePath: file.path,
        fileName: _getBasename(file.path),
        isGithub: false,
      ),
    );
  }

  void _openRestoreGithubForLocalFile(FileSystemEntity file) {
    showDialog(
      context: context,
      builder: (context) => FileHistoryDialog(
        filePath: file.path,
        fileName: _getBasename(file.path),
        isGithub: true,
      ),
    );
  }

  Widget _buildExplorerTab(BuildContext context) {
    if (_isExplorerLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_explorerItems.isEmpty && _explorerFolderPath.isEmpty) {
      return FutureBuilder<String?>(
        future: VersionControlService.instance.getLocalRepositoryPath(),
        builder: (context, snapshot) {
          final path = snapshot.data;
          if (path == null || path.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Local Repository Path is not configured.\nPlease set it in Project Configuration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            );
          }
          return Center(
            child: Text(
              'No files found in repository.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: FolderHierarchyView<FileSystemEntity, Directory>(
            currentPath: _explorerFolderPath,
            currentFolder: _currentExplorerFolder,
            getFolderId: (dir) => dir.path,
            getFolderName: (dir) => _getBasename(dir.path),
            rootName: 'Repository Root',
            items: _explorerItems,
            selectedItem: _selectedExplorerItem,
            isItemFolder: (entity) => entity is Directory,
            getItemId: (entity) => entity.path,
            itemPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            buildItemName: (entity) {
              final name = _getBasename(entity.path);
              return Text(
                name,
                style: TextStyle(
                  color: AppColors.panelTextPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              );
            },
            getItemSubtitle: (entity) => null,
            getItemColor: (entity) => entity is Directory
                ? Colors.amberAccent
                : AppColors.accent,
            isItemSelected: (entity) => _selectedExplorerItem?.path == entity.path,
            getItemLeading: (entity) => Icon(
              entity is Directory ? Icons.folder : Icons.insert_drive_file,
              color: entity is Directory ? Colors.amberAccent : AppColors.panelTextSecondary,
              size: 18,
            ),
            getItemTrailing: (entity) {
              if (entity is! File) return const SizedBox.shrink();
              String sizeStr = '';
              try {
                final len = entity.lengthSync();
                if (len < 1024) {
                  sizeStr = '$len B';
                } else if (len < 1024 * 1024) {
                  sizeStr = '${(len / 1024).toStringAsFixed(1)} KB';
                } else {
                  sizeStr = '${(len / (1024 * 1024)).toStringAsFixed(1)} MB';
                }
              } catch (_) {}
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sizeStr.isNotEmpty) ...[
                    Text(
                      sizeStr,
                      style: TextStyle(
                        color: AppColors.panelTextSecondary,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.blueAccent, size: 16),
                    tooltip: 'Restore from Git',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () => _openRestoreGitForLocalFile(entity),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cloud_download, color: Colors.tealAccent, size: 16),
                    tooltip: 'Restore from GitHub',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () => _openRestoreGithubForLocalFile(entity),
                  ),
                ],
              );
            },
            onItemSecondaryTap: (entity, details) {
              if (entity is! File) return;
              showMenu<String>(
                context: context,
                color: AppColors.panelBackground,
                position: RelativeRect.fromLTRB(
                  details.globalPosition.dx,
                  details.globalPosition.dy,
                  details.globalPosition.dx,
                  details.globalPosition.dy,
                ),
                items: [
                  PopupMenuItem(
                    value: 'restore_git',
                    child: Row(
                      children: [
                        const Icon(Icons.history, color: Colors.blueAccent, size: 16),
                        const SizedBox(width: 8),
                        Text('Restore from Git', style: TextStyle(color: AppColors.panelTextPrimary, fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'restore_github',
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_download, color: Colors.tealAccent, size: 16),
                        const SizedBox(width: 8),
                        Text('Restore from GitHub', style: TextStyle(color: AppColors.panelTextPrimary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ).then((value) {
                if (value == 'restore_git') {
                  _openRestoreGitForLocalFile(entity);
                } else if (value == 'restore_github') {
                  _openRestoreGithubForLocalFile(entity);
                }
              });
            },
            onNavigateToFolder: (dir) => _navigateExplorerToFolder(dir),
            onNavigateToItemFolder: (entity) {
              if (entity is Directory) {
                _navigateExplorerToFolder(entity as Directory);
              }
            },
            onSelectItem: (entity) {
              setState(() {
                _selectedExplorerItem = entity;
              });
              if (entity is Directory) {
                _navigateExplorerToFolder(entity);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewActionBanner(BuildContext context, AiTask t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
}

