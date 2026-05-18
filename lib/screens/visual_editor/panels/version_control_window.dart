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

class _VersionControlWindowState extends State<VersionControlWindow> {
  final Map<String, GlobalKey> _timelineKeys = {};
  final Map<String, Future<List<Map<String, String>>>> _commitFutures = {};

  bool _isLoaded = false;
  bool _isSyncing = false;
  double _width = 500;
  double _height = 400;
  double _bgOpacity = 0.8;
  Offset _offset = const Offset(200, 200);

  @override
  void initState() {
    super.initState();
    SandboxService.instance.init();
    VersionControlWindow.highlightedTaskId.addListener(_scrollToHighlightedTask);
    _loadPreferences();
    VisualEditorScreen.currentWorkspace.addListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.addListener(_loadPreferences);
    VisualEditorScreen.activeWindowNotifier.addListener(_onActiveWindowChanged);
  }

  @override
  void dispose() {
    VersionControlWindow.highlightedTaskId.removeListener(_scrollToHighlightedTask);
    VisualEditorScreen.currentWorkspace.removeListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.removeListener(_loadPreferences);
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

  void _scrollToHighlightedTask() {
    final taskId = VersionControlWindow.highlightedTaskId.value;
    if (taskId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _timelineKeys[taskId];
        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(key.currentContext!, duration: const Duration(milliseconds: 300), alignment: 0.5);
        }
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
            Container(
              height: 36,
              width: double.infinity,
              color: AppColors.toolbarBackground,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Tooltip(
                    message: 'Refresh',
                    child: IconButton(
                      icon: const Icon(Icons.refresh, size: 16),
                      color: AppColors.toolbarTextPrimary,
                      onPressed: () {
                        setState(() {
                          _commitFutures.clear();
                        });
                        SandboxService.instance.reload();
                      },
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
                      
                      final commitNameController = TextEditingController(text: activeTasks.length == 1 ? activeTasks.first.name : 'Merged Checkpoint');
                      final bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.panelBackground,
                          title: const Text('Verify Commit Name', style: TextStyle(color: Colors.white)),
                          content: TextField(
                            controller: commitNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Commit Name',
                              labelStyle: TextStyle(color: Colors.white70),
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Commit', style: TextStyle(color: Colors.blueAccent))),
                          ],
                        ),
                      );
                      
                      if (confirm == true) {
                        final taskIds = activeTasks.map((t) => t.id).toList();
                        final success = await AiBridgeService.instance.performManualCommitAll(taskIds, commitNameController.text);
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tasks committed successfully.')));
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 8),
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
                              hintText: 'Enter a note or description...',
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
                        final desc = 'Manual Checkpoint: $note';
                        final hash = await VersionControlService.instance.createRestorePoint(desc);
                        
                        if (hash.isNotEmpty && !hash.startsWith('No changes') && !hash.startsWith('Failed') && !hash.startsWith('Local')) {
                          await AiBridgeService.instance.appendCheckpointToTimeline(desc, hash);
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
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: Colors.blueAccent,
                      unselectedLabelColor: AppColors.textMuted,
                      indicatorColor: Colors.blueAccent,
                      labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
                      tabs: [
                        Tab(text: 'ACTIVE TASKS'),
                        Tab(text: 'TIMELINE HISTORY'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // TAB 1: ACTIVE TASKS
                          activeTasks.isEmpty 
                            ? Center(child: Text('No active tasks', style: TextStyle(color: AppColors.textMuted)))
                            : ListView.builder(
                                itemCount: activeTasks.length,
                                itemBuilder: (ctx, i) {
                                  final t = activeTasks[i];
                                  List<Widget> taskChildren = [];
                                  if (t.verificationCriteria.isEmpty) {
                                    taskChildren.add(
                                      ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.info_outline, color: Colors.blueAccent, size: 16),
                                        title: Text(
                                          t.description.isNotEmpty ? t.description : 'Pending implementation',
                                          style: TextStyle(color: AppColors.textMuted, fontSize: AppUIConfig.smallFontSize),
                                        ),
                                        onTap: () {
                                          GlobalTaskEditorState.instance.requestEdit(existingTask: t);
                                          showTaskEditorWindow(context);
                                        },
                                      )
                                    );
                                  } else {
                                    taskChildren.addAll(t.verificationCriteria.map((vc) {
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
                                      
                                      return ListTile(
                                        dense: true,
                                        leading: Icon(iconData, color: iconColor, size: 16),
                                        title: Text(
                                          vc.description,
                                          style: TextStyle(
                                            color: AppColors.textPrimary, 
                                            fontSize: AppUIConfig.smallFontSize,
                                            decoration: vc.isVerified ? TextDecoration.lineThrough : null,
                                            decorationColor: Colors.white,
                                          ),
                                        ),
                                        subtitle: vc.goal.isNotEmpty
                                            ? Text(
                                                vc.goal,
                                                style: TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontSize: AppUIConfig.smallFontSize - 1,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              )
                                            : null,
                                        onTap: () {
                                          GlobalTaskEditorState.instance.requestEdit(existingTask: t);
                                          showTaskEditorWindow(context);
                                        },
                                      );
                                    }));
                                  }



                                  return ExpansionTile(
                                    key: PageStorageKey<String>('active_task_${t.id}'),
                                    initiallyExpanded: true,
                                    title: Text(t.name, style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold)),
                                    subtitle: t.summary.isNotEmpty ? Text(t.summary, style: TextStyle(color: AppColors.textMuted, fontSize: AppUIConfig.smallFontSize, fontStyle: FontStyle.italic)) : null,
                                    children: taskChildren,
                                  );
                                }
                              ),
                          
                          // TAB 2: TIMELINE HISTORY
                          timelineCommits.isEmpty
                            ? Center(child: Text('No completed tasks yet', style: TextStyle(color: AppColors.textMuted)))
                            : SingleChildScrollView(
                                child: Column(
                                  children: _buildTimelineNodes(context, timelineCommits),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
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

      Widget trailingRow = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (i + 1 < commits.length) ...[
            IconButton(
              icon: const Icon(Icons.cleaning_services, size: 16, color: Colors.blueAccent),
              tooltip: 'Squash Older History',
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
                    // The setState will happen implicitly if AiBridgeService triggers notifyListeners() and this widget rebuilds.
                    // But we can also manually trigger a refresh of the commits.
                    SandboxService.instance.reload(); // Cheap way to trigger global listenable
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
                              icon: const Icon(Icons.copy, color: Colors.white, size: 20),
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
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
            tooltip: 'Delete Timeline Entry',
            onPressed: () {
              AiBridgeService.instance.deleteTimelineCommit(c.id);
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.restore, size: 16, color: Colors.orange),
            tooltip: 'Restore to Here',
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
          const SizedBox(width: 4),
          if (c.title != 'Checkpoint') ...[
            IconButton(
              icon: const Icon(Icons.open_in_browser, size: 16, color: Colors.blueAccent),
              tooltip: 'Open in GitHub',
              onPressed: () async {
                await VersionControlService.instance.openGithubCommit(c.commitHash);
              },
            ),
            const SizedBox(width: 4),
            Text(
              c.commitHash.length > 7 ? c.commitHash.substring(0, 7) : c.commitHash,
              style: TextStyle(color: AppColors.textMuted, fontSize: AppUIConfig.smallFontSize * 0.9, fontFamily: 'monospace'),
            ),
          ],
        ],
      );

      if (c.title == 'Checkpoint') {
        result.add(
          Container(
            key: _timelineKeys[c.id],
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            decoration: BoxDecoration(
               border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
               borderRadius: BorderRadius.circular(4),
               color: Colors.orangeAccent.withValues(alpha: 0.05),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Row(
                  children: [
                    const Icon(Icons.flag, color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.summary,
                        style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                   _formatDateStr(c.commitDate),
                   style: TextStyle(color: AppColors.textMuted, fontSize: AppUIConfig.smallFontSize),
                ),
                trailing: trailingRow,
                children: _buildTimelineNodes(context, commits.sublist(i + 1)),
              ),
            ),
          )
        );
        break; // Rest of the commits are children of this checkpoint
      } else {
        result.add(
          ValueListenableBuilder<String?>(
            valueListenable: VersionControlWindow.highlightedTaskId,
            builder: (ctx, highlightedId, _) {
              final isHighlighted = highlightedId != null && c.taskIds.contains(highlightedId);
              return Container(
                key: _timelineKeys[c.id],
                color: isHighlighted ? Colors.green.withValues(alpha: 0.2) : Colors.transparent,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.commit, color: Colors.green, size: 16),
                  title: Text(c.title, style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize)),
                  subtitle: Text(
                    _formatDateStr(c.commitDate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textMuted, fontSize: AppUIConfig.smallFontSize),
                  ),
                  trailing: trailingRow,
                  onTap: () {
                    if (c.taskIds.isNotEmpty) {
                      try {
                        final t = AiBridgeService.instance.tasks.firstWhere((task) => task.id == c.taskIds.first);
                        GlobalTaskEditorState.instance.requestEdit(existingTask: t);
                        showTaskEditorWindow(context);
                      } catch (_) {}
                    }
                  },
                ),
              );
            }
          )
        );
      }
    }
    return result;
  }
}
