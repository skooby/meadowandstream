

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../visual_editor_screen.dart';
import '../../../constants.dart';
import '../../../services/ai_bridge_service.dart';
import '../../../services/antigravity_status_service.dart';
import '../../../state/global_picker_state.dart';
import '../../../state/global_task_editor_state.dart';
import 'global_notes_editor_window.dart';
import 'ai_bridge_window.dart';

final ValueNotifier<bool> showBridgeMonitorNotifier = () {
  final notifier = ValueNotifier<bool>(false);
  SharedPreferences.getInstance().then((prefs) {
    if (prefs.getBool('ve_showBridgeMonitor') == true) {
      notifier.value = true;
    }
  });
  return notifier;
}();

void showBridgeMonitorWindow(BuildContext context) {
  if (showBridgeMonitorNotifier.value) return;
  SharedPreferences.getInstance().then((prefs) => prefs.setBool('ve_showBridgeMonitor', true));
  showBridgeMonitorNotifier.value = true;
}

void hideBridgeMonitorWindow() {
  showBridgeMonitorNotifier.value = false;
  SharedPreferences.getInstance().then((prefs) => prefs.setBool('ve_showBridgeMonitor', false));
}

void toggleBridgeMonitorWindow() async {
  showBridgeMonitorNotifier.value = !showBridgeMonitorNotifier.value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('ve_showBridgeMonitor', showBridgeMonitorNotifier.value);
}

class BridgeMonitorWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback? onClose;
  final VoidCallback? onFocus;

  const BridgeMonitorWindow({
    super.key,
    required this.isDocked,
    this.onClose,
    this.onFocus,
  });

  @override
  State<BridgeMonitorWindow> createState() => _BridgeMonitorWindowState();
}

class _BridgeMonitorWindowState extends State<BridgeMonitorWindow> {
  Offset _position = const Offset(120, 120);
  double _width = 750;
  double _height = 650;
  double _bgOpacity = 0.4;

  @override
  void initState() {
    super.initState();
    _loadState();
    VisualEditorScreen.currentWorkspace.addListener(_loadState);
    VisualEditorScreen.configRefreshNotifier.addListener(_loadState);
    VisualEditorScreen.activeWindowNotifier.addListener(_onActiveWindowChanged);
  }

  @override
  void dispose() {
    VisualEditorScreen.currentWorkspace.removeListener(_loadState);
    VisualEditorScreen.configRefreshNotifier.removeListener(_loadState);
    VisualEditorScreen.activeWindowNotifier.removeListener(_onActiveWindowChanged);
    super.dispose();
  }

  void _onActiveWindowChanged() {
    if (mounted) setState(() {});
  }

  void _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _position = Offset(
          prefs.getDouble(VisualEditorScreen.getPrefKey('bridge_monitor_x')) ?? 120,
          prefs.getDouble(VisualEditorScreen.getPrefKey('bridge_monitor_y')) ?? 120,
        );
        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('bridge_monitor_w')) ?? 750;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('bridge_monitor_h')) ?? 650;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.4;
      });
    }
  }

  void _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('bridge_monitor_x'), _position.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('bridge_monitor_y'), _position.dy);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('bridge_monitor_w'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('bridge_monitor_h'), _height);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDocked) {
      return const Material(
        color: Colors.transparent,
        child: AiBridgePanel(),
      );
    }

    final mq = MediaQuery.of(context).size;
    final w = _width.clamp(300.0, mq.width);
    final h = _height.clamp(200.0, mq.height);

    final dx = _position.dx.clamp(0.0, (mq.width - w).clamp(0.0, double.infinity));
    final dy = _position.dy.clamp(0.0, (mq.height - h).clamp(0.0, double.infinity));

    Widget rz({
      double? t, double? b, double? l, double? r, double? dw, double? dh,
      required MouseCursor cursor,
      required void Function(DragUpdateDetails) pan,
    }) => Positioned(
      top: t, bottom: b, left: l, right: r, width: dw, height: dh,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (_) => widget.onFocus?.call(),
          onPanUpdate: pan,
          onPanEnd: (_) => _saveState(),
          child: Container(color: Colors.transparent),
        ),
      ),
    );

    return Positioned(
      left: dx,
      top: dy,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: w,
            height: h,
            child: Material(
              color: Colors.transparent,
              elevation: 8,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  border: AppUIConfig.windowBorderWidth > 0
                      ? Border.all(
                          color: VisualEditorScreen.activeWindowNotifier.value == 'bridge_monitor'
                              ? AppColors.activeWindowBorder
                              : AppColors.border,
                          width: AppUIConfig.windowBorderWidth,
                        )
                      : null,
                  color: AppColors.windowBackground.withValues(alpha: _bgOpacity),
                  borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanDown: (_) => widget.onFocus?.call(),
                      onPanUpdate: (d) => setState(() => _position += d.delta),
                      onPanEnd: (_) => _saveState(),
                      child: Container(
                        height: AppUIConfig.titleBarHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.titleBarBackground.withValues(alpha: _bgOpacity),
                          border: Border(bottom: BorderSide(color: AppColors.overlaySubtle)),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppUIConfig.windowBorderRadius),
                          ),
                        ),
                        child: Row(
                          children: [
                            AiBridgeActivityIcon(
                              size: 16,
                              color: AppToolWindows.getDef('bridge_monitor').color,
                              defaultIcon: AppToolWindows.getDef('bridge_monitor').icon,
                              toolWindowId: 'bridge_monitor',
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppUIConfig.formatWindowTitle('Bridge Monitor'),
                              style: TextStyle(
                                color: AppColors.titleBarTextPrimary,
                                fontSize: AppUIConfig.windowTitleFontSize,
                                fontWeight: AppUIConfig.windowTitleFontWeight,
                              ),
                            ),
                            const Spacer(),
                            if (widget.onClose != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.close,
                                    color: AppColors.titleBarTextSecondary, size: 16),
                                onPressed: widget.onClose,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapDown: (_) => widget.onFocus?.call(),
                        child: const AiBridgePanel(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          rz(r: -5, b: -5, dw: 15, dh: 15, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){ double nW = _width + d.delta.dx; double nH = _height + d.delta.dy; if(nW > 300) _width = nW; if(nH > 200) _height = nH; })),
          rz(l: -5, b: -5, dw: 15, dh: 15, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){ double nW = _width - d.delta.dx; double nH = _height + d.delta.dy; if(nW > 300) { _width = nW; _position += Offset(d.delta.dx, 0); } if(nH > 200) _height = nH; })),
          rz(r: -5, t: -5, dw: 15, dh: 15, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){ double nW = _width + d.delta.dx; double nH = _height - d.delta.dy; if(nW > 300) _width = nW; if(nH > 200) { _height = nH; _position += Offset(0, d.delta.dy); } })),
          rz(l: -5, t: -5, dw: 15, dh: 15, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){ double nW = _width - d.delta.dx; double nH = _height - d.delta.dy; if(nW > 300) { _width = nW; _position += Offset(d.delta.dx, 0); } if(nH > 200) { _height = nH; _position += Offset(0, d.delta.dy); } })),
          rz(r: -5, t: 10, b: 10, dw: 10, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){ double nW = _width + d.delta.dx; if(nW > 300) _width = nW; })),
          rz(l: -5, t: 10, b: 10, dw: 10, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){ double nW = _width - d.delta.dx; if(nW > 300) { _width = nW; _position += Offset(d.delta.dx, 0); } })),
          rz(b: -5, l: 10, r: 10, dh: 10, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){ double nH = _height + d.delta.dy; if(nH > 200) _height = nH; })),
          rz(t: -5, l: 10, r: 10, dh: 10, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){ double nH = _height - d.delta.dy; if(nH > 200) { _height = nH; _position += Offset(0, d.delta.dy); } }))
        ],
      ),
    );
  }
}
enum LogType { info, success, warning, error, command, stdout, agent }

class SimulatedLogEntry {
  final String prefix;
  final String message;
  final LogType type;

  SimulatedLogEntry(this.prefix, this.message, this.type);
}

class AiBridgePanel extends StatefulWidget {
  const AiBridgePanel({super.key});

  @override
  State<AiBridgePanel> createState() => _AiBridgePanelState();
}

class _AiBridgePanelState extends State<AiBridgePanel> {
  // Connectivity
  bool _isOnline = false;
  String _bridgeUrl = '';
  String _globalStatus = 'UNKNOWN';
  int _activeJobsCount = 0;
  bool _processRunning = false;

  // Diagnostics & Tests
  bool _isRunningTest = false;
  String _diagnosticOutput = '';
  final ScrollController _diagnosticScrollController = ScrollController();

  // Collapsible Logs
  final List<String> _logFiles = [
    'bridge_debug.txt',
    'bridge_error.txt',
    'bridge_compile_log.txt',
    'bridge_commit_debug.txt',
    'latest_notes.json',
    'latest_verification.json',
    'agent_status.txt',
  ];
  final Map<String, String> _loadedLogs = {};
  final Map<String, bool> _collapsedStates = {};

  // Dry Run state
  String? _selectedDryRunTaskId;
  String _dryRunPrompt = '';
  String _dryRunJson = '';
  int _dryRunSubTab = 0; // 0 = Prompt, 1 = JSON
  bool _isSimulating = false;
  Timer? _simulationTimer;
  final List<SimulatedLogEntry> _displayedSimulationLogs = [];
  final ScrollController _simulationScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _loadCollapsedStates().then((_) => _loadAllLogs());
    AiBridgeService.instance.addListener(_onAiBridgeServiceChanged);
    GlobalTaskEditorState.instance.activeRequest.addListener(_onActiveRequestChanged);
    _updateDryRunData();
  }

  @override
  void dispose() {
    AiBridgeService.instance.removeListener(_onAiBridgeServiceChanged);
    GlobalTaskEditorState.instance.activeRequest.removeListener(_onActiveRequestChanged);
    _simulationTimer?.cancel();
    _simulationScrollController.dispose();
    super.dispose();
  }

  void _onActiveRequestChanged() {
    _updateDryRunData();
  }

  Future<void> _loadCollapsedStates() async {
    final prefs = await SharedPreferences.getInstance();
    for (final filename in _logFiles) {
      final isCollapsedDefault = (filename != 'bridge_debug.txt' && filename != 'agent_status.txt');
      final prefKey = 'ai_bridge_log_collapsed_$filename';
      _collapsedStates[filename] = prefs.getBool(prefKey) ?? isCollapsedDefault;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleCollapsedState(String filename) async {
    final prefs = await SharedPreferences.getInstance();
    final current = _collapsedStates[filename] ?? false;
    final newVal = !current;
    _collapsedStates[filename] = newVal;
    await prefs.setBool('ai_bridge_log_collapsed_$filename', newVal);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAllLogs() async {
    for (final filename in _logFiles) {
      try {
        final file = File('.ai_bridge/$filename');
        if (await file.exists()) {
          final contents = await file.readAsString();
          _loadedLogs[filename] = contents.trim().isEmpty ? '(File is empty)' : contents;
        } else {
          _loadedLogs[filename] = '(File does not exist)';
        }
      } catch (e) {
        _loadedLogs[filename] = 'Error reading file: $e';
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openBridgeDesignDocument() async {
    try {
      final file = File('.ai_bridge/bridge_design_and_flow.md');
      if (!await file.exists()) {
        await file.writeAsString('''# AI Bridge Design and Flow Reference

## 1. Overview
The AI Bridge facilitates seamless agentic execution within the local development workspace.

## 2. Component Design
- **Bridge Monitor Panel:** Houses diagnostics, test execution, and real-time log monitoring.
- **Task Manager Panel:** Focuses on checklist item workflow state and prompt execution.

## 3. Communication Protocols
- Status coordinates via `.ai_bridge/agent_status.txt` (IDLE, BUSY, PREVIEW).
- Context sync is passed through `.ai_bridge/current_task.json`.
- Logs outputted directly to files in `.ai_bridge/` for real-time monitoring.
''');
      }
      final content = await file.readAsString();
      final controller = TextEditingController(text: content);
      
      if (mounted) {
        GlobalPickerState.instance.requestNotes(
          controller: controller,
          title: 'Bridge Design & Flow',
          onSaved: () async {
            await file.writeAsString(controller.text);
          },
        );
        showNotesEditorWindow(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening design document: $e')),
        );
      }
    }
  }

  Future<void> _copyRebuildPrompt() async {
    const prompt = '''Please analyze the flow and state detection of the AI Bridge, keeping the analysis simple, very brief, and to the point.

Analyze if it is correctly doing a list of tasks. You MUST only analyze the following specific numbered areas so we can pinpoint exactly what is not working properly:
1. Launching app
2. After sending to AI Bridge
3. While processing
4. After returning to AI Bridge
5. Idle/sync transitions or any other relevant states

Write the findings back to `.ai_bridge/bridge_design_and_flow.md` as a numbered list corresponding to these specific areas, with brief status/issues for each.''';

    await Clipboard.setData(const ClipboardData(text: prompt));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rebuild prompt copied to clipboard! Paste it into the LLM manually.')),
      );
    }
  }

  Future<void> _resetBridgeToCleanState() async {
    try {
      final statusFile = File('.ai_bridge/agent_status.txt');
      await statusFile.writeAsString('IDLE');

      final notesFile = File('.ai_bridge/latest_notes.json');
      if (await notesFile.exists()) {
        await notesFile.writeAsString(jsonEncode({
          "notes": "System reset to clean state.",
          "task_completed": false,
          "details": ""
        }));
      }

      final verifFile = File('.ai_bridge/latest_verification.json');
      if (await verifFile.exists()) {
        await verifFile.delete();
      }

      final logsToReset = [
        'bridge_debug.txt',
        'bridge_error.txt',
        'bridge_compile_log.txt',
        'bridge_commit_debug.txt'
      ];
      for (final filename in logsToReset) {
        final f = File('.ai_bridge/$filename');
        if (await f.exists()) {
          await f.writeAsString('');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('ai_bridge_log_collapsed_')) {
          await prefs.remove(key);
        }
      }

      await _checkStatus();
      await _loadAllLogs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI Bridge successfully reset to a clean IDLE state.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resetting bridge: $e')),
        );
      }
    }
  }

  Future<void> _checkStatus() async {
    try {
      final url = await AntigravityStatusService.instance.getBridgeUrl();
      final statusMap = await AntigravityStatusService.instance.getHttpBridgeStatus();
      final procRunning = await AntigravityStatusService.instance.isProcessRunning();

      if (mounted) {
        setState(() {
          _bridgeUrl = url;
          _isOnline = statusMap != null;
          if (statusMap != null) {
            _globalStatus = statusMap['status'] ?? 'IDLE';
            _activeJobsCount = statusMap['active_jobs'] ?? 0;
          } else {
            _globalStatus = 'OFFLINE';
            _activeJobsCount = 0;
          }
          _processRunning = procRunning;
        });
      }
    } catch (_) {}
  }

  Future<void> _runDiagnostics() async {
    if (mounted) {
      setState(() {
        _diagnosticOutput = 'Starting connection diagnostics...\n';
      });
    }

    try {
      await _checkStatus();
      final lastObserved = AiBridgeService.instance.antigravityLastChangeObservedAt;
      final formattedLastObserved = lastObserved != null ? lastObserved.toLocal().toString() : 'None';

      final output = StringBuffer();
      output.writeln('=== CONNECTION DIAGNOSTICS REPORT ===');
      output.writeln('Timestamp: ${DateTime.now().toLocal()}');
      output.writeln('Bridge URL: $_bridgeUrl');
      output.writeln('HTTP Bridge Status: ${_isOnline ? "ONLINE" : "OFFLINE"}');
      output.writeln('HTTP Global Status: $_globalStatus');
      output.writeln('Active Jobs (HTTP): $_activeJobsCount');
      output.writeln('Daemon Process Running: ${_processRunning ? "YES" : "NO"}');
      output.writeln('Sync Error Detected: ${AiBridgeService.instance.isSyncErrorDetected ? "YES" : "NO"}');
      output.writeln('Antigravity Last Change Observed: $formattedLastObserved');
      output.writeln('Active Subagents count: ${AiBridgeService.instance.activeAgents.length}');

      for (final entry in AiBridgeService.instance.activeAgents.entries) {
        output.writeln('  - Agent ${entry.key}: Status: ${entry.value.currentStatus}');
      }

      final statusFile = File('.ai_bridge/agent_status.txt');
      if (await statusFile.exists()) {
        output.writeln('Local agent_status.txt: "${(await statusFile.readAsString()).trim()}"');
      } else {
        output.writeln('Local agent_status.txt: NOT FOUND');
      }

      output.writeln('\nDiagnostics complete successfully.');

      if (mounted) {
        setState(() {
          _diagnosticOutput = output.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _diagnosticOutput += '\nError during diagnostics: $e\n';
        });
      }
    }
  }

  Future<void> _runTestSuite() async {
    if (_isRunningTest) return;

    if (mounted) {
      setState(() {
        _isRunningTest = true;
        _diagnosticOutput = 'Starting test suite execution via flutter test...\n';
      });
    }
    AiBridgeService.instance.isTesting = true;

    try {
      final process = await Process.start(
        Platform.isWindows ? 'flutter.bat' : 'flutter',
        ['test'],
        runInShell: true,
      );

      process.stdout.transform(utf8.decoder).listen((data) {
        if (mounted) {
          setState(() {
            _diagnosticOutput += data;
          });
          _scrollToEnd();
        }
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        if (mounted) {
          setState(() {
            _diagnosticOutput += data;
          });
          _scrollToEnd();
        }
      });

      final exitCode = await process.exitCode;
      if (mounted) {
        setState(() {
          _diagnosticOutput += '\nTest suite finished with exit code $exitCode.\n';
          _isRunningTest = false;
        });
        _scrollToEnd();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _diagnosticOutput += '\nError executing test suite: $e\n';
          _isRunningTest = false;
        });
        _scrollToEnd();
      }
    } finally {
      AiBridgeService.instance.isTesting = false;
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_diagnosticScrollController.hasClients) {
        _diagnosticScrollController.animateTo(
          _diagnosticScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onAiBridgeServiceChanged() {
    _updateDryRunData();
  }

  String _getTaskPathName(AiTask task) {
    final path = <String>[];
    AiTask? current = task;
    final visited = <String>{};
    final allTasks = AiBridgeService.instance.tasks;
    while (current != null) {
      if (visited.contains(current.id)) break;
      visited.add(current.id);
      path.insert(0, current.name);
      
      if (current.parentId != null) {
        current = allTasks.cast<AiTask?>().firstWhere(
          (t) => t?.id == current!.parentId,
          orElse: () => null,
        );
      } else if (current.worksheetId != null && !current.isWorksheet) {
        current = allTasks.cast<AiTask?>().firstWhere(
          (t) => t?.id == current!.worksheetId,
          orElse: () => null,
        );
      } else {
        current = null;
      }
    }
    return path.join(' > ');
  }

  void _updateDryRunData() async {
    final activeId = AiBridgeService.instance.activeProcessingTaskId 
        ?? GlobalTaskEditorState.instance.activeRequest.value?.existingTask?.id
        ?? (AiBridgeService.instance.activeTaskIds.isNotEmpty ? AiBridgeService.instance.activeTaskIds.first : null);
    
    if (activeId != _selectedDryRunTaskId) {
      _simulationTimer?.cancel();
      _isSimulating = false;
      _displayedSimulationLogs.clear();
    }

    if (activeId == null) {
      if (mounted) {
        setState(() {
          _selectedDryRunTaskId = null;
          _dryRunPrompt = '';
          _dryRunJson = '';
        });
      }
      return;
    }

    final tasks = AiBridgeService.instance.tasks;
    var taskIdx = tasks.indexWhere((t) => t.id == activeId);
    AiTask? task;
    if (taskIdx != -1) {
      task = tasks[taskIdx];
    } else if (GlobalTaskEditorState.instance.activeRequest.value?.existingTask?.id == activeId) {
      task = GlobalTaskEditorState.instance.activeRequest.value?.existingTask;
    }

    if (task == null) {
      if (mounted) {
        setState(() {
          _selectedDryRunTaskId = null;
          _dryRunPrompt = '';
          _dryRunJson = '';
        });
      }
      return;
    }
    
    _selectedDryRunTaskId = task.id;
    
    try {
      final prompt = await AiBridgeService.instance.buildTaskPrompt(task);

      // Build JSON representation matching _writeCurrentTaskFile
      final json = task.toJson();
      json['name'] = _getTaskPathName(task);
      if (json['verificationCriteria'] != null) {
        final uncheckedTasks = task.verificationCriteria
            .where((e) =>
                e.status != AiVerificationStatus.verified &&
                e.status != AiVerificationStatus.ignored &&
                !e.isPreview)
            .toList();
        if (uncheckedTasks.isNotEmpty) {
          json['verificationCriteria'] = [uncheckedTasks.first.toJson()];
        } else {
          json['verificationCriteria'] = [];
        }
      }
      final jsonStr = const JsonEncoder.withIndent('  ').convert(json);

      if (mounted) {
        setState(() {
          _dryRunPrompt = prompt;
          _dryRunJson = jsonStr;
        });
      }
    } catch (e) {
      debugPrint('[BridgeMonitor] Error updating dry run data: $e');
    }
  }

  void _startDryRunSimulation(AiTask task) {
    if (_isSimulating) return;

    _simulationTimer?.cancel();
    setState(() {
      _isSimulating = true;
      _displayedSimulationLogs.clear();
    });

    final steps = _generateSimulationSteps(task);
    int stepIndex = 0;

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (stepIndex < steps.length) {
        if (mounted) {
          setState(() {
            _displayedSimulationLogs.add(steps[stepIndex]);
          });
          _scrollSimulationToEnd();
        }
        stepIndex++;
      } else {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isSimulating = false;
          });
        }
      }
    });
  }

  List<SimulatedLogEntry> _generateSimulationSteps(AiTask task) {
    final pathName = _getTaskPathName(task);
    final activeCriteria = task.verificationCriteria
        .where((e) => e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored && !e.isPreview)
        .toList();
    final hasCriteria = activeCriteria.isNotEmpty;
    final activeItemDesc = hasCriteria ? activeCriteria.first.description : 'No active checklist item';

    return [
      SimulatedLogEntry('[System]', 'Initializing dry run simulation for task: $pathName', LogType.info),
      SimulatedLogEntry('[System]', 'Creating local workspace sandbox at .ai_scratch/sandbox_${task.id}', LogType.info),
      SimulatedLogEntry('[System]', 'Preparing simulated environment state...', LogType.info),
      SimulatedLogEntry('[File Write]', 'Writing agent_status.txt -> BUSY', LogType.success),
      SimulatedLogEntry('[File Write]', 'Writing .ai_bridge/current_task.json', LogType.success),
      SimulatedLogEntry('[System]', 'Serialized task verification criteria. Count: ${hasCriteria ? 1 : 0} (isolated focus)', LogType.info),
      SimulatedLogEntry('[Macro]', 'Triggering "BridgeConnect" keyboard/mouse macro (runs paste.vbs)', LogType.warning),
      SimulatedLogEntry('[Clipboard]', 'Copied AI task prompt to system clipboard (length: ${_dryRunPrompt.length} chars)', LogType.success),
      SimulatedLogEntry('[System]', 'Simulated Bridge Connection established. Transferring control to LLM agent...', LogType.info),
      SimulatedLogEntry('[Agent]', 'Agent wakes up, detects active checklist item: "$activeItemDesc"', LogType.agent),
      SimulatedLogEntry('[Command]', 'Executing check: flutter analyze', LogType.command),
      SimulatedLogEntry('[Stdout]', 'Analyzing Project...\nNo issues found! (exit code: 0)', LogType.stdout),
      if (hasCriteria) ...[
        SimulatedLogEntry('[Agent]', 'Locating relevant files to satisfy checklist item...', LogType.agent),
        SimulatedLogEntry('[File Edit]', 'Simulating edits to fulfill requirement: "$activeItemDesc"', LogType.success),
      ],
      SimulatedLogEntry('[Command]', 'Executing test suite check: flutter test', LogType.command),
      SimulatedLogEntry('[Stdout]', 'Testing Project...\nAll tests passed successfully! (exit code: 0)', LogType.stdout),
      SimulatedLogEntry('[File Write]', 'Writing .ai_bridge/latest_notes.json', LogType.success),
      SimulatedLogEntry('[File Write]', 'Writing .ai_bridge/agent_status.txt -> IDLE', LogType.success),
      SimulatedLogEntry('[System]', 'Dry run simulation finished. Checklist item verified successfully!', LogType.info),
    ];
  }

  void _scrollSimulationToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_simulationScrollController.hasClients) {
        _simulationScrollController.animateTo(
          _simulationScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _getLogPrefixColor(LogType type) {
    switch (type) {
      case LogType.info:
        return Colors.cyanAccent;
      case LogType.success:
        return Colors.lightGreenAccent;
      case LogType.warning:
        return Colors.orangeAccent;
      case LogType.error:
        return Colors.redAccent;
      case LogType.command:
        return Colors.yellowAccent;
      case LogType.stdout:
        return Colors.white54;
      case LogType.agent:
        return const Color(0xFFE040FB);
    }
  }

  Color _getLogMessageColor(LogType type) {
    switch (type) {
      case LogType.stdout:
        return Colors.white70;
      case LogType.command:
        return Colors.white;
      default:
        return Colors.white.withOpacity(0.9);
    }
  }

  Widget _buildSubTabButton(int index, String title, IconData icon) {
    final isActive = _dryRunSubTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _dryRunSubTab = index;
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? AppColors.accent.withOpacity(0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _isOnline ? Colors.greenAccent : Colors.redAccent;
    final processColor = _processRunning ? Colors.greenAccent : Colors.orangeAccent;

    return ListenableBuilder(
      listenable: AiBridgeService.instance,
      builder: (context, child) {
        final lastObserved = AiBridgeService.instance.antigravityLastChangeObservedAt;
        final formattedLastObserved = lastObserved != null ? lastObserved.toLocal().toString().split('.').first : 'Never';
        final isSyncError = AiBridgeService.instance.isSyncErrorDetected;
        final subagents = AiBridgeService.instance.activeAgents;
        final isTesting = AiBridgeService.instance.isTesting;

        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.panelBackground.withValues(alpha: 0.2),
                  border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
                ),
                child: TabBar(
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.analytics_outlined, size: 18),
                      text: 'Log Outcomes',
                    ),
                    Tab(
                      icon: Icon(Icons.health_and_safety_outlined, size: 18),
                      text: 'Diagnostics & Status',
                    ),
                    Tab(
                      icon: Icon(Icons.play_circle_outline_rounded, size: 18),
                      text: 'Dry Run',
                    ),
                  ],
                  labelColor: AppColors.accent,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.accent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  unselectedLabelStyle: const TextStyle(fontSize: 12),
                  dividerColor: Colors.transparent,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.panelBackground.withValues(alpha: 0.1),
                  border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined, size: 13, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Text(
                        'Design Doc:',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: _openBridgeDesignDocument,
                        child: const Text(
                          'bridge_design_and_flow.md',
                          style: TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(Icons.edit_note, size: 13, color: AppColors.accent),
                        label: const Text(
                          'Edit Notes',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                        onPressed: _openBridgeDesignDocument,
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.copy, size: 11, color: Colors.amberAccent),
                        label: const Text(
                          'Copy Rebuild Prompt',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                        onPressed: _copyRebuildPrompt,
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.restart_alt, size: 13, color: Colors.redAccent),
                        label: const Text(
                          'Reset',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                        onPressed: _resetBridgeToCleanState,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Log Outcomes (occupies full space)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        color: AppColors.panelBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Log Outcomes Monitor',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: Icon(Icons.refresh, size: 16, color: AppColors.textSecondary),
                                    onPressed: _loadAllLogs,
                                    tooltip: 'Reload All Logs',
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white12, height: 16),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _logFiles.length,
                                  itemBuilder: (context, index) {
                                    final filename = _logFiles[index];
                                    final isCollapsed = _collapsedStates[filename] ?? false;
                                    final contents = _loadedLogs[filename] ?? 'Loading...';

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      color: AppColors.panelBackground.withValues(alpha: 0.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: BorderSide(color: AppColors.border, width: 0.5),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          InkWell(
                                            onTap: () => _toggleCollapsedState(filename),
                                            borderRadius: BorderRadius.circular(6),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isCollapsed ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down,
                                                    size: 16,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    filename,
                                                    style: TextStyle(
                                                      color: isCollapsed ? AppColors.textSecondary : AppColors.accent,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      fontFamily: 'monospace',
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    icon: const Icon(Icons.copy_all, size: 14, color: Colors.white54),
                                                    onPressed: () async {
                                                      await Clipboard.setData(ClipboardData(text: contents));
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('Copied $filename contents to clipboard!')),
                                                        );
                                                      }
                                                    },
                                                    tooltip: 'Copy Contents',
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (!isCollapsed) ...[
                                            const Divider(color: Colors.white10, height: 1),
                                            LayoutBuilder(
                                              builder: (context, constraints) {
                                                final textSpan = TextSpan(
                                                  text: contents,
                                                  style: TextStyle(
                                                    color: AppColors.textPrimary.withValues(alpha: 0.8),
                                                    fontFamily: 'monospace',
                                                    fontSize: 11,
                                                  ),
                                                );
                                                final textPainter = TextPainter(
                                                  text: textSpan,
                                                  textDirection: TextDirection.ltr,
                                                );
                                                final maxTextWidth = (constraints.maxWidth - 24).clamp(0.0, double.infinity);
                                                textPainter.layout(maxWidth: maxTextWidth);
                                                final textHeight = textPainter.height + 24;

                                                if (textHeight > 120) {
                                                  return Container(
                                                    height: 120,
                                                    padding: const EdgeInsets.all(8),
                                                    color: Colors.black.withValues(alpha: 0.3),
                                                    child: Scrollbar(
                                                      child: SingleChildScrollView(
                                                        padding: const EdgeInsets.all(4),
                                                        child: SizedBox(
                                                          width: double.infinity,
                                                          child: Text(
                                                            contents,
                                                            style: TextStyle(
                                                              color: AppColors.textPrimary.withValues(alpha: 0.8),
                                                              fontFamily: 'monospace',
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  return Container(
                                                    padding: const EdgeInsets.all(8),
                                                    color: Colors.black.withValues(alpha: 0.3),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(4),
                                                      child: SizedBox(
                                                        width: double.infinity,
                                                        child: Text(
                                                          contents,
                                                          style: TextStyle(
                                                            color: AppColors.textPrimary.withValues(alpha: 0.8),
                                                            fontFamily: 'monospace',
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Tab 2: Diagnostics & Status
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Mode Indicator
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Text(
                                  'BRIDGE ACTIVE MODE:',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isTesting ? Colors.amber.withOpacity(0.15) : Colors.blueAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isTesting ? Colors.amberAccent.withOpacity(0.5) : Colors.blueAccent.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isTesting ? Icons.science : Icons.leak_add,
                                        size: 12,
                                        color: isTesting ? Colors.amberAccent : Colors.blueAccent,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isTesting ? 'TEST STATE' : 'REGULAR STATE',
                                        style: TextStyle(
                                          color: isTesting ? Colors.amberAccent : Colors.blueAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Row for Status cards
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Connectivity Card
                              Expanded(
                                child: Card(
                                  color: AppColors.panelBackground,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: AppColors.border),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: statusColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _isOnline ? 'Bridge: ONLINE' : 'Bridge: OFFLINE',
                                              style: TextStyle(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'URL: $_bridgeUrl',
                                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'State: $_globalStatus (Jobs: $_activeJobsCount)',
                                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Daemon Process Card
                              Expanded(
                                child: Card(
                                  color: AppColors.panelBackground,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: AppColors.border),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: processColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _processRunning ? 'Process: ACTIVE' : 'Process: INACTIVE',
                                              style: TextStyle(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Checks: antigravity-server, language_server.exe, kiro',
                                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Sync Error & Watcher Card
                          Card(
                            color: AppColors.panelBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: isSyncError ? Colors.redAccent.withOpacity(0.5) : AppColors.border),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isSyncError ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                        color: isSyncError ? Colors.redAccent : Colors.greenAccent,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isSyncError ? 'AI Sync Status: Sync Error Detected' : 'AI Sync Status: Synchronized',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Last observed file system change: $formattedLastObserved',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                  ),
                                  if (isSyncError) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Sync Error: The system detected conversational/status information directly. '
                                        'Ensure latest_verification.json and latest_notes.json are correctly formatted '
                                        'and agent_status.txt is written as IDLE.',
                                        style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Active Subagents Card
                          Card(
                            color: AppColors.panelBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: AppColors.border),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Active Subagents (${subagents.length})',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Divider(color: Colors.white12, height: 16),
                                  if (subagents.isEmpty)
                                    Text(
                                      'No active background subagents running.',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
                                    )
                                  else
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: subagents.length,
                                      itemBuilder: (context, index) {
                                        final key = subagents.keys.elementAt(index);
                                        final conn = subagents[key]!;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.smart_toy, size: 14, color: Colors.cyanAccent),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Task ID: $key',
                                                  style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontFamily: 'monospace'),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                conn.currentStatus,
                                                style: const TextStyle(color: Colors.cyanAccent, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Diagnostic Triggers and Output
                          Card(
                            color: AppColors.panelBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: AppColors.border),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Diagnostic & Test Utilities',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.accent.withOpacity(0.1),
                                            foregroundColor: AppColors.accent,
                                            side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                          icon: const Icon(Icons.analytics_outlined, size: 16),
                                          label: const Text('Run Diagnostics', style: TextStyle(fontSize: 11)),
                                          onPressed: _runDiagnostics,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _isRunningTest ? Colors.grey.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
                                            foregroundColor: _isRunningTest ? Colors.grey : Colors.amber,
                                            side: BorderSide(color: _isRunningTest ? Colors.grey.withOpacity(0.5) : Colors.amber.withOpacity(0.5)),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                          icon: _isRunningTest
                                              ? const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation(Colors.grey)),
                                                )
                                              : const Icon(Icons.science_outlined, size: 16),
                                          label: Text(_isRunningTest ? 'Running Tests...' : 'Run Test Suite', style: const TextStyle(fontSize: 11)),
                                          onPressed: _isRunningTest ? null : _runTestSuite,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_diagnosticOutput.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 180,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Scrollbar(
                                        controller: _diagnosticScrollController,
                                        child: SingleChildScrollView(
                                          controller: _diagnosticScrollController,
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                            _diagnosticOutput,
                                            style: const TextStyle(
                                              color: Colors.lightGreenAccent,
                                              fontFamily: 'monospace',
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tab 3: Dry Run
                    Builder(
                      builder: (context) {
                        final tasks = AiBridgeService.instance.tasks;
                        final executableTasks = tasks.where((t) => !t.isFolder && !t.isWorksheet).toList();
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Top Control Bar: Dropdown + Play button
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.panelBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    // Active task status display
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: AppColors.border),
                                          borderRadius: BorderRadius.circular(4),
                                          color: Colors.black.withOpacity(0.2),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: _selectedDryRunTaskId != null ? Colors.greenAccent : Colors.grey,
                                                shape: BoxShape.circle,
                                                boxShadow: _selectedDryRunTaskId != null
                                                    ? [
                                                        BoxShadow(
                                                          color: Colors.greenAccent.withOpacity(0.5),
                                                          blurRadius: 4,
                                                          spreadRadius: 1,
                                                        )
                                                      ]
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'ACTIVE TASK',
                                                    style: TextStyle(
                                                      color: AppColors.accent,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 1.1,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Builder(
                                                    builder: (context) {
                                                      final activeTask = _selectedDryRunTaskId != null
                                                          ? tasks.cast<AiTask?>().firstWhere(
                                                              (t) => t?.id == _selectedDryRunTaskId,
                                                              orElse: () => null,
                                                            )
                                                          : null;
                                                      return Text(
                                                        activeTask != null
                                                            ? _getTaskPathName(activeTask)
                                                            : 'No active task currently processing',
                                                        style: TextStyle(
                                                          color: activeTask != null ? AppColors.textPrimary : AppColors.textSecondary,
                                                          fontSize: 12,
                                                          fontWeight: activeTask != null ? FontWeight.bold : FontWeight.normal,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      );
                                                    }
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Play / Simulation Button
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isSimulating
                                            ? Colors.grey.withOpacity(0.1)
                                            : AppColors.accent.withOpacity(0.15),
                                        foregroundColor: _isSimulating ? Colors.grey : AppColors.accent,
                                        side: BorderSide(
                                          color: _isSimulating
                                              ? Colors.grey.withOpacity(0.5)
                                              : AppColors.accent.withOpacity(0.5),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      icon: _isSimulating
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation(Colors.grey),
                                              ),
                                            )
                                          : const Icon(Icons.play_arrow_rounded, size: 16),
                                      label: Text(
                                        _isSimulating ? 'Simulating...' : 'Simulate Dry Run',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: _isSimulating || _selectedDryRunTaskId == null
                                          ? null
                                          : () {
                                              final task = tasks.firstWhere((t) => t.id == _selectedDryRunTaskId);
                                              _startDryRunSimulation(task);
                                            },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Split Screen Content
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Left Column: Terminal Simulation Logs
                                    Expanded(
                                      flex: 5,
                                      child: Card(
                                        color: Colors.black.withOpacity(0.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: BorderSide(color: AppColors.border),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            // Terminal Header
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.black26,
                                                border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.terminal_rounded, size: 14, color: Colors.white70),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    'Simulation Log Terminal',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  if (_displayedSimulationLogs.isNotEmpty)
                                                    IconButton(
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      icon: const Icon(Icons.delete_sweep_outlined, size: 14, color: Colors.white54),
                                                      onPressed: () {
                                                        setState(() {
                                                          _displayedSimulationLogs.clear();
                                                        });
                                                      },
                                                      tooltip: 'Clear Logs',
                                                    ),
                                                ],
                                              ),
                                            ),
                                            // Logs Content
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                color: Colors.black.withOpacity(0.2),
                                                child: _displayedSimulationLogs.isEmpty
                                                    ? Center(
                                                        child: Text(
                                                          'No simulation logs yet.\nClick "Simulate Dry Run" to run.',
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                            color: AppColors.textSecondary.withOpacity(0.5),
                                                            fontSize: 11,
                                                            fontStyle: FontStyle.italic,
                                                          ),
                                                        ),
                                                      )
                                                    : Scrollbar(
                                                        controller: _simulationScrollController,
                                                        child: ListView.builder(
                                                          controller: _simulationScrollController,
                                                          itemCount: _displayedSimulationLogs.length,
                                                          itemBuilder: (context, index) {
                                                            final entry = _displayedSimulationLogs[index];
                                                            final prefixColor = _getLogPrefixColor(entry.type);
                                                            final msgColor = _getLogMessageColor(entry.type);
                                                            return Padding(
                                                              padding: const EdgeInsets.symmetric(vertical: 2),
                                                              child: Text.rich(
                                                                TextSpan(
                                                                  children: [
                                                                    TextSpan(
                                                                      text: '${entry.prefix} ',
                                                                      style: TextStyle(
                                                                        color: prefixColor,
                                                                        fontWeight: FontWeight.bold,
                                                                        fontFamily: 'monospace',
                                                                        fontSize: 11,
                                                                      ),
                                                                    ),
                                                                    TextSpan(
                                                                      text: entry.message,
                                                                      style: TextStyle(
                                                                        color: msgColor,
                                                                        fontFamily: 'monospace',
                                                                        fontSize: 11,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Right Column: Payload Preview
                                    Expanded(
                                      flex: 6,
                                      child: Card(
                                        color: AppColors.panelBackground,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: BorderSide(color: AppColors.border),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            // Payload Header with Sub-tabs & Copy Button
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.panelBackground.withValues(alpha: 0.8),
                                                border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                                ),
                                              child: Row(
                                                children: [
                                                  _buildSubTabButton(0, 'AI Task Prompt', Icons.description_outlined),
                                                  const SizedBox(width: 6),
                                                  _buildSubTabButton(1, 'current_task.json', Icons.code_rounded),
                                                  const Spacer(),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    icon: const Icon(Icons.copy_all, size: 16, color: Colors.white70),
                                                    onPressed: () async {
                                                      final content = _dryRunSubTab == 0 ? _dryRunPrompt : _dryRunJson;
                                                      if (content.isNotEmpty) {
                                                        await Clipboard.setData(ClipboardData(text: content));
                                                        if (context.mounted) {
                                                          final label = _dryRunSubTab == 0 ? 'AI Task Prompt' : 'current_task.json';
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(content: Text('Copied $label to clipboard!')),
                                                          );
                                                        }
                                                      }
                                                    },
                                                    tooltip: 'Copy Payload',
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Code View Container
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                color: Colors.black.withOpacity(0.3),
                                                child: SingleChildScrollView(
                                                  child: Text(
                                                    _dryRunSubTab == 0
                                                        ? (_dryRunPrompt.isEmpty ? 'No prompt loaded.' : _dryRunPrompt)
                                                        : (_dryRunJson.isEmpty ? 'No task JSON loaded.' : _dryRunJson),
                                                    style: TextStyle(
                                                      color: AppColors.textPrimary.withOpacity(0.85),
                                                      fontFamily: 'monospace',
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
