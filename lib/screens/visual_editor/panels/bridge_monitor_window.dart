import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../visual_editor_screen.dart';
import '../../../constants.dart';
import '../../../services/ai_bridge_service.dart';
import '../../../services/local_ai_service.dart';
import '../../../services/antigravity_status_service.dart';
import '../../../state/global_picker_state.dart';
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

class AiBridgePanel extends StatefulWidget {
  const AiBridgePanel({super.key});

  @override
  State<AiBridgePanel> createState() => _AiBridgePanelState();
}

class _AiBridgePanelState extends State<AiBridgePanel> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Connectivity
  bool _isOnline = false;
  String _bridgeUrl = '';
  String _globalStatus = 'UNKNOWN';
  int _activeJobsCount = 0;
  bool _processRunning = false;
  Timer? _statusTimer;

  // Diagnostics & Tests
  bool _isRunningTest = false;
  String _diagnosticOutput = '';
  final ScrollController _diagnosticScrollController = ScrollController();

  // AI Assistant tab — read-only transcript viewer
  String _assistantLastPrompt = '';
  String _assistantLastOutput = '';
  String _assistantTranscriptPath = '';
  final ScrollController _assistantOutputScrollController = ScrollController();
  final ScrollController _assistantPromptScrollController = ScrollController();

  Future<void> _loadAssistantTranscript() async {
    try {
      final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
      final brainDir = Directory('$userProfile\\.gemini\\antigravity\\brain');
      if (!await brainDir.exists()) return;
      // Find latest transcript
      final List<FileSystemEntity> all = await brainDir.list(recursive: true, followLinks: false).toList();
      final transcripts = all
          .whereType<File>()
          .where((f) => f.path.endsWith('transcript.jsonl'))
          .toList();
      if (transcripts.isEmpty) return;
      final times = <File, DateTime>{};
      for (final t in transcripts) {
        try { times[t] = await t.lastModified(); } catch (_) {}
      }
      transcripts.sort((a, b) =>
          (times[b] ?? DateTime(0)).compareTo(times[a] ?? DateTime(0)));
      final latest = transcripts.first;
      final path = latest.path;
      // Parse JSONL — grab the most recent USER_INPUT and PLANNER_RESPONSE
      final lines = await latest.readAsLines();
      String lastPrompt = '';
      String lastOutput = '';
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('{')) continue;
        try {
          final map = jsonDecode(trimmed) as Map<String, dynamic>;
          final type = (map['type'] as String? ?? '').toUpperCase();
          final content = (map['content'] as String? ?? '').trim();
          if (type == 'USER_INPUT' && content.isNotEmpty) lastPrompt = content;
          if (type == 'PLANNER_RESPONSE' && content.isNotEmpty) lastOutput = content;
        } catch (_) {}
      }
      if (mounted &&
          (lastPrompt != _assistantLastPrompt ||
           lastOutput != _assistantLastOutput ||
           path != _assistantTranscriptPath)) {
        setState(() {
          _assistantLastPrompt = lastPrompt;
          _assistantLastOutput = lastOutput;
          _assistantTranscriptPath = path;
        });
      }
    } catch (_) {}
  }

  // Collapsible Logs
  final List<String> _logFiles = [
    'current_task.json',
    'bridge_debug.txt',
    'bridge_error.txt',
    'bridge_compile_log.txt',
    'bridge_commit_debug.txt',
    'latest_notes.json',
    'latest_verification.json',
    'agent_status.txt',
    'queue_status.txt',
  ];
  final Map<String, String> _loadedLogs = {};
  final Map<String, bool> _collapsedStates = {};

  void _onAiBridgeServiceChanged() {
    if (mounted) {
      setState(() {});
      _checkStatus();
      _loadAllLogs();
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    AiBridgeService.instance.removeListener(_onAiBridgeServiceChanged);
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _assistantOutputScrollController.dispose();
    _assistantPromptScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadSelectedTab();
    _checkStatus();
    _loadCollapsedStates().then((_) => _loadAllLogs());
    AiBridgeService.instance.addListener(_onAiBridgeServiceChanged);
    
    // Poll status and logs in real-time every 2 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        _checkStatus();
        _loadAllLogs();
        _loadAssistantTranscript();
      }
    });
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      _saveSelectedTab(_tabController.index);
    }
  }

  Future<void> _loadSelectedTab() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('ai_bridge_selected_tab') ?? 0;
    if (mounted) {
      _tabController.index = savedIndex.clamp(0, 2);
    }
  }

  Future<void> _saveSelectedTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ai_bridge_selected_tab', index);
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
        final file = File('${AiBridgeService.instance.bridgeDirPath}/$filename');
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
      final file = File('${AiBridgeService.instance.bridgeDirPath}/bridge_design_and_flow.md');
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
      final statusFile = File('${AiBridgeService.instance.bridgeDirPath}/agent_status.txt');
      await statusFile.writeAsString('IDLE');

      final notesFile = File('${AiBridgeService.instance.bridgeDirPath}/latest_notes.json');
      if (await notesFile.exists()) {
        await notesFile.writeAsString(jsonEncode({
          "notes": "System reset to clean state.",
          "task_completed": false,
          "details": ""
        }));
      }

      final verifFile = File('${AiBridgeService.instance.bridgeDirPath}/latest_verification.json');
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
        final f = File('${AiBridgeService.instance.bridgeDirPath}/$filename');
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
      output.writeln('LLM Busy Status (Status File): ${AiBridgeService.instance.isAntigravityBusy ? "BUSY" : "IDLE"}');
      output.writeln('LLM Thinking/Active State: ${AiBridgeService.instance.isThinking ? "BUSY" : "IDLE"}');
      output.writeln('Active Queue Prompt: ${AiBridgeService.instance.activePrompt != null ? "YES" : "NO"}');
      output.writeln('Daemon Process Running: ${_processRunning ? "YES" : "NO"}');
      output.writeln('Sync Error Detected: ${AiBridgeService.instance.isSyncErrorDetected ? "YES" : "NO"}');
      output.writeln('Antigravity Last Change Observed: $formattedLastObserved');
      output.writeln('Active Subagents count: ${AiBridgeService.instance.activeAgents.length}');
      // Pipeline lock diagnostics
      final isLocked = AiBridgeService.instance.isHandlingAgentStatus;
      final lockAcquiredAt = AiBridgeService.instance.statusHandlingLockAcquiredAt;
      final lockAge = lockAcquiredAt != null ? DateTime.now().difference(lockAcquiredAt) : null;
      output.writeln('Pipeline Status Lock: ${isLocked ? "LOCKED" : "FREE"}');
      if (lockAge != null) {
        output.writeln('  Lock held for: ${lockAge.inSeconds}s (watchdog fires at 720s / 12 min)');
      }
      output.writeln('Timeout Guards: SharedPreferences=8s, disk save=15s');

      for (final entry in AiBridgeService.instance.activeAgents.entries) {
        output.writeln('  - Agent ${entry.key}: Status: ${entry.value.currentStatus}');
      }

      final pendingReview = AiBridgeService.instance.pendingReview;
      output.writeln('Pending Document Review: ${pendingReview != null ? "YES — ${pendingReview.fileName}" : "NO"}');
      if (pendingReview != null) {
        output.writeln('  File: ${pendingReview.filePath}');
        output.writeln('  Reason: ${pendingReview.reason}');
      }

      final statusFile = File('${AiBridgeService.instance.bridgeDirPath}/agent_status.txt');
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
        final errorText = _loadedLogs['bridge_error.txt'] ?? '';
        final hasGitPushErrorTask = AiBridgeService.instance.tasks.any((t) => t.name.toLowerCase() == 'fix git push errors');
        final errorTextLower = errorText.toLowerCase();
        final hasGitPushError = hasGitPushErrorTask ||
            errorTextLower.contains('git push') ||
            errorTextLower.contains('rejected') ||
            errorTextLower.contains('conflict') ||
            errorTextLower.contains('auto-commit failed');
        final subagents = AiBridgeService.instance.activeAgents;
        final isTesting = AiBridgeService.instance.isTesting;

        final isLlmBusy = AiBridgeService.instance.isThinking || AiBridgeService.instance.isAntigravityBusy;
        final isRunning = AiBridgeService.instance.isDaemonRunning;
        final isPromptDispatched = AiBridgeService.instance.isPromptDispatched;
        final lastObservedSecs = AiBridgeService.instance.antigravityLastChangeObservedAt != null
            ? DateTime.now().difference(AiBridgeService.instance.antigravityLastChangeObservedAt!).inSeconds
            : null;
        final isLastChangeBusy = lastObservedSecs != null && lastObservedSecs < 90;

        // Build a human-readable list of which conditions are driving isThinking
        final List<String> thinkingReasons = [];
        if (AiBridgeService.instance.activeAgents.isNotEmpty) thinkingReasons.add('active subagents');
        if (AiBridgeService.instance.isAntigravityBusy) thinkingReasons.add('isAntigravityBusy');
        if (AiBridgeService.instance.activePrompt != null) thinkingReasons.add('activePrompt set');
        if (isPromptDispatched) thinkingReasons.add('promptDispatched');
        if (AiBridgeService.instance.isTranscriptActive) thinkingReasons.add('transcript active <60s');
        if (isLastChangeBusy) thinkingReasons.add('lastChange ${lastObservedSecs}s ago (<90s)');

        final Color llmColor;
        final String llmStateText;

        if (isLlmBusy) {
          llmColor = Colors.orangeAccent;
          llmStateText = 'BUSY / GENERATING';
        } else if (isRunning || _isOnline) {
          llmColor = Colors.greenAccent;
          llmStateText = 'ONLINE / IDLE';
        } else {
          llmColor = Colors.redAccent;
          llmStateText = 'OFFLINE';
        }

        final activePrompt = AiBridgeService.instance.activePrompt;
        final activePromptText = activePrompt != null
            ? (activePrompt.text.length > 80 ? '${activePrompt.text.substring(0, 80)}...' : activePrompt.text)
            : 'None (Idle)';

        final activeTaskId = AiBridgeService.instance.activeProcessingTaskId;
        final activeTaskIdText = activeTaskId ?? 'None';

        final activeSubagentsText = subagents.isEmpty
            ? 'None'
            : '${subagents.length} active (${subagents.values.map((a) => a.currentStatus).join(", ")})';

        final agentStatusText = (_loadedLogs['agent_status.txt'] ?? 'UNKNOWN').trim();

        return Column(
          children: [
            // Quick Access Indicator Toolbar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.panelBackground.withValues(alpha: 0.3),
                border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickIndicator(
                      label: 'Queue',
                      value: AiBridgeService.instance.queueStatus,
                      color: AiBridgeService.instance.queueStatus == 'BUSY' ? Colors.orangeAccent : Colors.greenAccent,
                      icon: Icons.queue_play_next_outlined,
                    ),
                    const SizedBox(width: 12),
                    _buildQuickIndicator(
                      label: 'Bridge',
                      value: _isOnline ? 'Online' : 'Offline',
                      color: _isOnline ? Colors.greenAccent : Colors.redAccent,
                      icon: Icons.alt_route_outlined,
                    ),
                    const SizedBox(width: 12),
                    _buildQuickIndicator(
                      label: 'Daemon',
                      value: _processRunning ? 'Running' : 'Stopped',
                      color: _processRunning ? Colors.greenAccent : Colors.orangeAccent,
                      icon: Icons.settings_system_daydream_outlined,
                    ),
                    const SizedBox(width: 12),
                    _buildQuickIndicator(
                      label: 'Agent',
                      value: AiBridgeService.instance.isThinking
                          ? 'Thinking'
                          : (AiBridgeService.instance.isAntigravityBusy
                              ? 'Busy'
                              : (isPromptDispatched ? 'Dispatched' : 'Idle')),
                      color: AiBridgeService.instance.isThinking
                          ? Colors.orangeAccent
                          : (AiBridgeService.instance.isAntigravityBusy
                              ? Colors.amberAccent
                              : (isPromptDispatched ? Colors.yellowAccent : Colors.cyanAccent)),
                      icon: Icons.psychology_outlined,
                    ),
                    const SizedBox(width: 12),
                    _buildQuickIndicator(
                      label: 'Sync',
                      value: isSyncError ? 'Error' : 'Healthy',
                      color: isSyncError ? Colors.redAccent : Colors.greenAccent,
                      icon: isSyncError ? Icons.sync_problem : Icons.sync,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.panelBackground.withValues(alpha: 0.2),
                border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: TabBar(
                controller: _tabController,
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
                      icon: Icon(Icons.alt_route_outlined, size: 18),
                      text: 'Dry Run Simulation',
                    ),
                    Tab(
                      icon: Icon(Icons.swap_horiz_outlined, size: 18),
                      text: 'I/O',
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
                  controller: _tabController,
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
                                                const maxHeight = 120.0;

                                                if (textHeight > maxHeight) {
                                                  return Container(
                                                    height: maxHeight,
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
                          // Finalized Ingestion & Review Status Card
                          Card(
                            key: const ValueKey('finalized_review_status_card'),
                            color: AppColors.panelBackground.withValues(alpha: 0.8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(color: Colors.greenAccent.withOpacity(0.3), width: 1.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.fact_check_outlined, size: 16, color: Colors.greenAccent),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Finalized Ingestion & Review Status',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _buildReviewFileRow(
                                    fileName: 'current_task.json',
                                    isOk: _loadedLogs['current_task.json'] != null && 
                                          !_loadedLogs['current_task.json']!.contains('File does not exist'),
                                    detail: _getTaskDetailSummary(),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildReviewFileRow(
                                    fileName: 'latest_notes.json',
                                    isOk: _loadedLogs['latest_notes.json'] != null && 
                                          !_loadedLogs['latest_notes.json']!.contains('File does not exist') &&
                                          !_loadedLogs['latest_notes.json']!.contains('(File is empty)'),
                                    detail: _getNotesDetailSummary(),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildReviewFileRow(
                                    fileName: 'latest_verification.json',
                                    isOk: _loadedLogs['latest_verification.json'] != null && 
                                          !_loadedLogs['latest_verification.json']!.contains('File does not exist') &&
                                          !_loadedLogs['latest_verification.json']!.contains('(File is empty)'),
                                    detail: _getVerificationDetailSummary(),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildReviewFileRow(
                                    fileName: 'agent_status.txt',
                                    isOk: true,
                                    detail: 'Current Status: ${agentStatusText}',
                                    statusColor: agentStatusText == 'IDLE' ? Colors.greenAccent : Colors.orangeAccent,
                                  ),
                                  const SizedBox(height: 6),
                                  _buildReviewFileRow(
                                    fileName: 'queue_status.txt',
                                    isOk: true,
                                    detail: 'Current Status: ${(_loadedLogs['queue_status.txt'] ?? 'UNKNOWN').trim()}',
                                    statusColor: (_loadedLogs['queue_status.txt'] ?? 'UNKNOWN').trim() == 'IDLE' ? Colors.greenAccent : Colors.orangeAccent,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Dedicated LLM/Agent Health and State Banner
                          Card(
                            key: const ValueKey('diagnostics_llm_state_card'),
                            color: AppColors.panelBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: llmColor.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          _DiagnosticsPulsingDot(color: llmColor),
                                          const SizedBox(width: 10),
                                          Text(
                                            'LLM AGENT STATE: $llmStateText',
                                            style: TextStyle(
                                              color: llmColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isLlmBusy)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.orangeAccent.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
                                          ),
                                          child: const Text(
                                            'ACTIVE EXECUTION',
                                            style: TextStyle(
                                              color: Colors.orangeAccent,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1, color: Colors.white10),
                                  const SizedBox(height: 12),
                                  _buildDetailRow('Active Processing Prompt', activePromptText, isHighlighted: isLlmBusy),
                                  _buildDetailRow('Active Task ID', activeTaskIdText),
                                  _buildDetailRow('Active Subagents Running', activeSubagentsText, isHighlighted: subagents.isNotEmpty),
                                  _buildDetailRow('Status File (agent_status.txt)', agentStatusText, isHighlighted: agentStatusText == 'BUSY'),
                                  _buildDetailRow('Last Activity Observed', formattedLastObserved),
                                  const SizedBox(height: 8),
                                  const Divider(height: 1, color: Colors.white10),
                                  const SizedBox(height: 6),
                                  Text(
                                    'isThinking Conditions',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildThinkingConditionRow('Active Subagents', AiBridgeService.instance.activeAgents.isNotEmpty),
                                  _buildThinkingConditionRow('isAntigravityBusy', AiBridgeService.instance.isAntigravityBusy),
                                  _buildThinkingConditionRow('activePrompt set', AiBridgeService.instance.activePrompt != null),
                                  _buildThinkingConditionRow('promptDispatched', isPromptDispatched),
                                  _buildThinkingConditionRow('transcriptActive (<60s)', AiBridgeService.instance.isTranscriptActive),
                                  _buildThinkingConditionRow(
                                    'lastChange window (<90s)${lastObservedSecs != null ? " — ${lastObservedSecs}s ago" : ""}',
                                    isLastChangeBusy,
                                  ),
                                  const SizedBox(height: 6),
                                  if (isLlmBusy && thinkingReasons.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.orangeAccent.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Why: ', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                          Expanded(
                                            child: Text(
                                              thinkingReasons.join(' · '),
                                              style: const TextStyle(color: Colors.orangeAccent, fontSize: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
                                      ),
                                      child: const Text(
                                        'No active conditions — agent is idle.',
                                        style: TextStyle(color: Colors.greenAccent, fontSize: 10),
                                      ),
                                    ),
                                ],

                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
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
                                        const SizedBox(height: 4),
                                        Text(
                                          'LLM/Agent Busy (Status File): ${AiBridgeService.instance.isAntigravityBusy ? "YES" : "NO"}',
                                          style: TextStyle(
                                            color: AiBridgeService.instance.isAntigravityBusy ? Colors.orangeAccent : AppColors.textSecondary,
                                            fontSize: 11,
                                            fontWeight: AiBridgeService.instance.isAntigravityBusy ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'LLM/Agent Thinking (Active State): ${AiBridgeService.instance.isThinking ? "YES" : "NO"}',
                                          style: TextStyle(
                                            color: AiBridgeService.instance.isThinking ? Colors.amberAccent : AppColors.textSecondary,
                                            fontSize: 11,
                                            fontWeight: AiBridgeService.instance.isThinking ? FontWeight.bold : FontWeight.normal,
                                          ),
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
                                          'Checks: Antigravity.exe, agy.exe, antigravity-server, kiro',
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
                          if (hasGitPushError) ...[
                            const SizedBox(height: 12),
                            Card(
                              color: AppColors.panelBackground,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.5)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.sync_problem,
                                          color: Colors.orangeAccent,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Git Push or Conflict Failure Detected',
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.orangeAccent.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        errorText.isNotEmpty
                                            ? errorText
                                            : 'The remote git push failed. A conflict or repository rule violation might have occurred.',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'monospace'),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orangeAccent.withValues(alpha: 0.1),
                                          foregroundColor: Colors.orangeAccent,
                                          side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.5)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        icon: const Icon(Icons.build_circle_outlined, size: 16),
                                        label: const Text('Resolve Conflict & Notify LLM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        onPressed: () async {
                                          final details = 'Git push/sync failure details:\n$errorText';
                                          await AiBridgeService.instance.forceDispatchGitPushError(details);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Dispatched git error task and notified LLM to resolve the problem!')),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          // Pipeline Lock Status Card
                          Builder(builder: (context) {
                            final isLocked = AiBridgeService.instance.isHandlingAgentStatus;
                            final lockAcquiredAt = AiBridgeService.instance.statusHandlingLockAcquiredAt;
                            final lockAge = lockAcquiredAt != null
                                ? DateTime.now().difference(lockAcquiredAt)
                                : null;
                            final lockAgeSeconds = lockAge?.inSeconds ?? 0;
                            // Color coding: green=free, amber=locked<60s, red=locked>60s
                            final lockColor = !isLocked
                                ? Colors.greenAccent
                                : (lockAgeSeconds > 60 ? Colors.redAccent : Colors.amberAccent);
                            final lockIcon = !isLocked
                                ? Icons.lock_open_outlined
                                : (lockAgeSeconds > 60 ? Icons.lock : Icons.lock_clock);
                            return Card(
                              color: AppColors.panelBackground,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isLocked
                                      ? lockColor.withOpacity(0.5)
                                      : AppColors.border,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(lockIcon, color: lockColor, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          isLocked ? 'Pipeline Lock: HELD' : 'Pipeline Lock: FREE',
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (isLocked && lockAge != null) ...[
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: lockColor.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${lockAgeSeconds}s / 720s',
                                              style: TextStyle(color: lockColor, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (!isLocked)
                                      Text(
                                        'No active status-change processing. Pipeline is ready to accept IDLE/PREVIEW signals.',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      )
                                    else ...[
                                      Text(
                                        '_processStatusChange is running. Lock acquired at ${lockAcquiredAt!.toLocal().toString().split(".").first}.',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                      const SizedBox(height: 6),
                                      if (lockAgeSeconds > 60)
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            '⚠ Lock held >60 seconds — may be stuck. Use Clear Queue or Force Reset to recover. '
                                            'Watchdog will auto-release at 720 seconds.',
                                            style: TextStyle(color: Colors.redAccent, fontSize: 11),
                                          ),
                                        ),
                                    ],
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        _buildTimeoutBadge('Watchdog', '12 min', Colors.purpleAccent),
                                        _buildTimeoutBadge('SharedPrefs', '8 s', Colors.cyanAccent),
                                        _buildTimeoutBadge('Disk Save', '15 s', Colors.tealAccent),
                                        _buildTimeoutBadge('Bounce Wait', '5 min', Colors.orangeAccent),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                          // Pipeline Phase Log Card
                          Builder(builder: (context) {
                            final phaseLog = AiBridgeService.instance.pipelinePhaseLog;
                            return Card(
                              color: AppColors.panelBackground,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: phaseLog.isNotEmpty
                                      ? Colors.cyanAccent.withOpacity(0.3)
                                      : AppColors.border,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.timeline, size: 16, color: Colors.cyanAccent),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Pipeline Phase Log',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${phaseLog.length} event${phaseLog.length == 1 ? '' : 's'}',
                                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () async {
                                            final text = phaseLog.join('\n');
                                            await Clipboard.setData(ClipboardData(text: text));
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Pipeline phase log copied to clipboard')),
                                              );
                                            }
                                          },
                                          child: const Icon(Icons.copy_all, size: 13, color: Colors.white38),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Divider(height: 1, color: Colors.white10),
                                    const SizedBox(height: 8),
                                    if (phaseLog.isEmpty)
                                      const Text(
                                        'No pipeline phase events yet. Events appear here when the AI bridge triggers completion.',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      )
                                    else
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxHeight: 200),
                                        child: Scrollbar(
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: phaseLog.length,
                                            itemBuilder: (context, idx) {
                                              final msg = phaseLog[idx];
                                              // Color-code by phase type
                                              final Color lineColor;
                                              if (msg.contains('ABORTED')) {
                                                lineColor = Colors.redAccent;
                                              } else if (msg.contains('MISSING FILES') || msg.contains('REMINDER')) {
                                                lineColor = Colors.orangeAccent;
                                              } else if (msg.contains('BOUNCE PHASE 1: BUSY')) {
                                                lineColor = Colors.amberAccent;
                                              } else if (msg.contains('TRIGGER')) {
                                                lineColor = Colors.cyanAccent;
                                              } else if (msg.contains('LOCK ACQUIRED')) {
                                                lineColor = Colors.blueAccent;
                                              } else if (msg.contains('RECOVERY')) {
                                                lineColor = Colors.greenAccent;
                                              } else {
                                                lineColor = Colors.white60;
                                              }
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 2),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      idx == 0 ? '● ' : '◦ ',
                                                      style: TextStyle(
                                                        color: lineColor,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        msg,
                                                        style: TextStyle(
                                                          color: idx == 0 ? lineColor : lineColor.withOpacity(0.75),
                                                          fontSize: 10,
                                                          fontFamily: 'monospace',
                                                          fontWeight: idx == 0 ? FontWeight.bold : FontWeight.normal,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
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
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Builder(builder: (context) {
                        final isDry = AiBridgeService.instance.isDryRunMode;
                        final actions = AiBridgeService.instance.simulatedActions;
                        final modeColor = isDry ? Colors.amberAccent : Colors.greenAccent;
                        final modeLabel = isDry ? 'DRY RUN' : 'LIVE SESSION';
                        final modeIcon = isDry ? Icons.alt_route_outlined : Icons.cable_outlined;

                        // Build per-type counts
                        final Map<String, int> typeCounts = {};
                        for (final a in actions) {
                          typeCounts[a.type] = (typeCounts[a.type] ?? 0) + 1;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Session Banner ──────────────────────────────────
                            Card(
                              color: AppColors.panelBackground,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: modeColor.withOpacity(0.4), width: 1.5),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header row
                                    Row(
                                      children: [
                                        Icon(modeIcon, size: 16, color: modeColor),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Simulated Dry Run Mode',
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Switch(
                                          value: isDry,
                                          onChanged: (val) {
                                            AiBridgeService.instance.setDryRunMode(val);
                                          },
                                          activeColor: AppColors.accent,
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: modeColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: modeColor.withOpacity(0.5)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(modeIcon, size: 11, color: modeColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                modeLabel,
                                                style: TextStyle(
                                                  color: modeColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isDry) ...[
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                                            color: Colors.redAccent,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              AiBridgeService.instance.clearSimulatedActions();
                                            },
                                            tooltip: 'Clear Log',
                                          ),
                                        ],
                                      ],
                                    ),
                                    const Divider(color: Colors.white12, height: 16),
                                    // ── Active Session State ─────────────────────
                                    Text(
                                      isDry ? 'Dry Run Session State' : 'Live Session State',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDryRunDetailRow('Bridge Mode', AiBridgeService.instance.bridgeMode.toString().split('.').last, modeColor),
                                    _buildDryRunDetailRow('Queue Status', AiBridgeService.instance.queueStatus,
                                        AiBridgeService.instance.queueStatus == 'BUSY' ? Colors.orangeAccent : Colors.greenAccent),
                                    _buildDryRunDetailRow('Agent Status (file)', (_loadedLogs['agent_status.txt'] ?? 'UNKNOWN').trim(),
                                        (_loadedLogs['agent_status.txt'] ?? '').trim() == 'BUSY' ? Colors.orangeAccent : Colors.greenAccent),
                                    _buildDryRunDetailRow('Prompt Dispatched', AiBridgeService.instance.isPromptDispatched ? 'YES' : 'NO',
                                        AiBridgeService.instance.isPromptDispatched ? Colors.amberAccent : Colors.white38),
                                    _buildDryRunDetailRow('isThinking', AiBridgeService.instance.isThinking ? 'YES' : 'NO',
                                        AiBridgeService.instance.isThinking ? Colors.orangeAccent : Colors.white38),
                                    _buildDryRunDetailRow('isAntigravityBusy', AiBridgeService.instance.isAntigravityBusy ? 'YES' : 'NO',
                                        AiBridgeService.instance.isAntigravityBusy ? Colors.amberAccent : Colors.white38),
                                    _buildDryRunDetailRow(
                                      'Active Task ID',
                                      AiBridgeService.instance.activeProcessingTaskId ?? 'None',
                                      AiBridgeService.instance.activeProcessingTaskId != null ? Colors.cyanAccent : Colors.white38,
                                    ),
                                    _buildDryRunDetailRow(
                                      'Active Prompt',
                                      AiBridgeService.instance.activePrompt != null
                                          ? (AiBridgeService.instance.activePrompt!.text.length > 60
                                              ? '${AiBridgeService.instance.activePrompt!.text.substring(0, 60)}…'
                                              : AiBridgeService.instance.activePrompt!.text)
                                          : 'None',
                                      AiBridgeService.instance.activePrompt != null ? Colors.cyanAccent : Colors.white38,
                                    ),
                                    _buildDryRunDetailRow('Pipeline Lock Held', AiBridgeService.instance.isHandlingAgentStatus ? 'YES' : 'NO',
                                        AiBridgeService.instance.isHandlingAgentStatus ? Colors.redAccent : Colors.white38),
                                    _buildDryRunDetailRow('Dry Run Mode', isDry ? 'ENABLED — actions logged only' : 'DISABLED — live execution', modeColor),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // ── Event Log Stats ──────────────────────────────────
                            if (actions.isNotEmpty) ...[
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
                                      Row(
                                        children: [
                                          Icon(Icons.bar_chart, size: 14, color: AppColors.accent),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${isDry ? "Dry Run" : "Live Session"} Event Summary — ${actions.length} total event${actions.length == 1 ? "" : "s"}',
                                            style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          for (final entry in typeCounts.entries)
                                            _buildEventTypeBadge(entry.key, entry.value),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            // ── Action Buttons ───────────────────────────────────
                            Row(
                              children: [
                                if (isDry) ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent.withOpacity(0.1),
                                      foregroundColor: AppColors.accent,
                                      side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    icon: const Icon(Icons.send_and_archive_outlined, size: 14),
                                    label: const Text('Simulate Send Prompt', style: TextStyle(fontSize: 11)),
                                    onPressed: () async {
                                      await AiBridgeService.instance.sendToQueue(
                                        'SIMULATED DRY RUN PROMPT TEXT: Verify system state and print status.',
                                        false,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber.withOpacity(0.1),
                                      foregroundColor: Colors.amber,
                                      side: BorderSide(color: Colors.amber.withOpacity(0.5)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    icon: const Icon(Icons.play_circle_outline, size: 14),
                                    label: const Text('Simulate Bridge Connect', style: TextStyle(fontSize: 11)),
                                    onPressed: () {
                                      AiBridgeService.instance.logSimulatedAction(
                                        'MACRO',
                                        'Manual Trigger ConnectBridge',
                                        'Executing ConnectBridge macro containing SetWindowAntigravity.',
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.cyan.withOpacity(0.1),
                                    foregroundColor: Colors.cyan,
                                    side: BorderSide(color: Colors.cyan.withOpacity(0.5)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  icon: const Icon(Icons.copy_all_outlined, size: 14),
                                  label: Text(
                                    isDry ? 'Copy Dry Run Log' : 'Copy Live Session Log',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () async {
                                    final buffer = StringBuffer();
                                    buffer.writeln(isDry ? '=== DRY RUN SESSION LOG ===' : '=== LIVE SESSION LOG ===');
                                    buffer.writeln('Mode: $modeLabel');
                                    buffer.writeln('Bridge Mode: ${AiBridgeService.instance.bridgeMode}');
                                    buffer.writeln('Queue Status: ${AiBridgeService.instance.queueStatus}');
                                    buffer.writeln('Agent Status: ${(_loadedLogs['agent_status.txt'] ?? 'UNKNOWN').trim()}');
                                    buffer.writeln('Prompt Dispatched: ${AiBridgeService.instance.isPromptDispatched}');
                                    buffer.writeln('isThinking: ${AiBridgeService.instance.isThinking}');
                                    buffer.writeln('isAntigravityBusy: ${AiBridgeService.instance.isAntigravityBusy}');
                                    buffer.writeln('Active Task ID: ${AiBridgeService.instance.activeProcessingTaskId ?? "None"}');
                                    buffer.writeln('Active Prompt: ${AiBridgeService.instance.activePrompt?.text ?? "None"}');
                                    buffer.writeln('Pipeline Lock: ${AiBridgeService.instance.isHandlingAgentStatus ? "HELD" : "FREE"}');
                                    buffer.writeln('\nEvent totals: ${typeCounts.entries.map((e) => "${e.key}=${e.value}").join(", ")}');
                                    buffer.writeln('\n=== EVENT LOG (${actions.length} events) ===');
                                    for (int i = 0; i < actions.length; i++) {
                                      final act = actions[i];
                                      buffer.writeln('[${i + 1}] [${act.timestamp.toLocal().toString().split(' ').last.split('.').first}] [${act.type}] ${act.title}: ${act.detail}');
                                    }
                                    await Clipboard.setData(ClipboardData(text: buffer.toString()));
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(isDry ? 'Dry run log copied!' : 'Live session log copied!')),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // ── Event Log ────────────────────────────────────────
                            Expanded(
                              child: Card(
                                color: AppColors.panelBackground,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: AppColors.border),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                                        child: Row(
                                          children: [
                                            Icon(Icons.list_alt, size: 13, color: AppColors.textSecondary),
                                            const SizedBox(width: 6),
                                            Text(
                                              isDry ? 'Simulated Action Log' : 'Live Bridge Event Log',
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              '${actions.length} event${actions.length == 1 ? "" : "s"} (newest at top)',
                                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1, color: Colors.white10),
                                      Expanded(
                                        child: actions.isEmpty
                                            ? Center(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isDry ? Icons.science_outlined : Icons.cable_outlined,
                                                      size: 32,
                                                      color: Colors.white12,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      isDry
                                                          ? 'No simulated events captured yet.\nUse the buttons above to simulate actions.'
                                                          : 'No live bridge events captured yet.\nEvents appear here when the pipeline runs.',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        color: AppColors.textMuted,
                                                        fontSize: 11,
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : ListView.builder(
                                                itemCount: actions.length,
                                                itemBuilder: (context, idx) {
                                                  final act = actions[idx];
                                                  Color chipColor = Colors.grey;
                                                  switch (act.type) {
                                                    case 'PROMPT':
                                                      chipColor = Colors.greenAccent;
                                                      break;
                                                    case 'VBS_SCRIPT':
                                                      chipColor = Colors.blueAccent;
                                                      break;
                                                    case 'MACRO':
                                                      chipColor = Colors.orangeAccent;
                                                      break;
                                                    case 'QUEUE':
                                                      chipColor = Colors.cyanAccent;
                                                      break;
                                                    case 'API_CALL':
                                                      chipColor = Colors.purpleAccent;
                                                      break;
                                                    case 'FILE_WRITE':
                                                      chipColor = Colors.amberAccent;
                                                      break;
                                                    case 'FILE_READ':
                                                      chipColor = Colors.tealAccent;
                                                      break;
                                                    case 'STATE':
                                                      chipColor = Colors.pinkAccent;
                                                      break;
                                                    case 'STATUS_WRITE':
                                                      chipColor = Colors.tealAccent;
                                                      break;
                                                    default:
                                                      chipColor = Colors.grey;
                                                  }

                                                  return Card(
                                                    margin: const EdgeInsets.only(bottom: 6),
                                                    color: Colors.black.withOpacity(0.2),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(4),
                                                      side: const BorderSide(color: Colors.white10, width: 0.5),
                                                    ),
                                                    child: ExpansionTile(
                                                      dense: true,
                                                      iconColor: AppColors.textSecondary,
                                                      collapsedIconColor: AppColors.textSecondary,
                                                      title: Row(
                                                        children: [
                                                          // Index badge
                                                          Text(
                                                            '#${actions.length - idx}',
                                                            style: const TextStyle(
                                                              color: Colors.white24,
                                                              fontSize: 9,
                                                              fontFamily: 'monospace',
                                                            ),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          // Type chip
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: chipColor.withOpacity(0.15),
                                                              borderRadius: BorderRadius.circular(4),
                                                              border: Border.all(color: chipColor.withOpacity(0.5)),
                                                            ),
                                                            child: Text(
                                                              act.type,
                                                              style: TextStyle(
                                                                color: chipColor,
                                                                fontSize: 9,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              act.title,
                                                              style: TextStyle(
                                                                color: AppColors.textPrimary,
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      subtitle: Text(
                                                        act.timestamp.toLocal().toString().split(' ').last.split('.').first,
                                                        style: TextStyle(
                                                          color: AppColors.textMuted,
                                                          fontSize: 9,
                                                        ),
                                                      ),
                                                      children: [
                                                        Container(
                                                          width: double.infinity,
                                                          padding: const EdgeInsets.all(10),
                                                          decoration: BoxDecoration(
                                                            color: Colors.black38,
                                                            border: Border(top: BorderSide(color: chipColor.withOpacity(0.2))),
                                                          ),
                                                          child: SelectableText(
                                                            act.detail,
                                                            style: const TextStyle(
                                                              color: Colors.lightGreenAccent,
                                                              fontFamily: 'monospace',
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                        ),
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
                          ],
                        );
                      }),
                    ),

                    // ── Tab 4: AI Assistant ── read-only transcript viewer ──────────────
                    AiAssistantTab(
                      lastPrompt: _assistantLastPrompt,
                      lastOutput: _assistantLastOutput,
                      transcriptPath: _assistantTranscriptPath,
                      outputScrollController: _assistantOutputScrollController,
                      promptScrollController: _assistantPromptScrollController,
                      isThinking: AiBridgeService.instance.isThinking,
                    ),


                  ],
                ),
              ),
            ],
          );
      },
    );
  }

  Widget _buildQuickIndicator({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Small pill badge showing a named timeout guard and its limit.
  Widget _buildTimeoutBadge(String label, String limit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 11, color: color.withOpacity(0.8)),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
          ),
          Text(
            limit,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewFileRow({
    required String fileName,
    required bool isOk,
    required String detail,
    Color? statusColor,
  }) {
    final themeColor = statusColor ?? (isOk ? Colors.greenAccent : Colors.redAccent);
    return Row(
      children: [
        Icon(
          isOk ? Icons.check_box : Icons.check_box_outline_blank,
          size: 14,
          color: themeColor,
        ),
        const SizedBox(width: 8),
        Text(
          fileName,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            detail,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _getTaskDetailSummary() {
    final raw = _loadedLogs['current_task.json'];
    if (raw == null || raw.contains('File does not exist')) return 'No active task file found';
    try {
      final json = jsonDecode(raw);
      final name = json['name'] ?? 'Unnamed Task';
      final status = json['status'] ?? 'unknown';
      return '$name (Status: $status)';
    } catch (e) {
      debugPrint('[AiBridge] Error parsing current_task.json: $e (Content raw: "$raw")');
      return 'Malformed task JSON';
    }
  }

  String _getNotesDetailSummary() {
    final raw = _loadedLogs['latest_notes.json'];
    if (raw == null || raw.contains('File does not exist') || raw.contains('(File is empty)')) return 'No progress notes recorded';
    try {
      final json = jsonDecode(raw);
      final notes = json['notes'] ?? '';
      return notes.toString();
    } catch (e) {
      debugPrint('[AiBridge] Error parsing latest_notes.json: $e (Content raw: "$raw")');
      return 'Malformed notes JSON';
    }
  }

  String _getVerificationDetailSummary() {
    final raw = _loadedLogs['latest_verification.json'];
    if (raw == null || raw.contains('File does not exist') || raw.contains('(File is empty)')) return 'No verification proofs recorded';
    try {
      final json = jsonDecode(raw);
      if (json is List) {
        final verifiedCount = json.where((e) => e['isVerified'] == true).length;
        return 'Verified $verifiedCount / ${json.length} criteria';
      }
      return 'Invalid verification schema';
    } catch (e) {
      debugPrint('[AiBridge] Error parsing latest_verification.json: $e (Content raw: "$raw")');
      return 'Malformed verification JSON';
    }
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isHighlighted ? Colors.amberAccent : AppColors.textPrimary,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDryRunDetailRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTypeBadge(String type, int count) {
    Color chipColor;
    switch (type) {
      case 'PROMPT':
        chipColor = Colors.greenAccent;
        break;
      case 'VBS_SCRIPT':
        chipColor = Colors.blueAccent;
        break;
      case 'MACRO':
        chipColor = Colors.orangeAccent;
        break;
      case 'QUEUE':
        chipColor = Colors.cyanAccent;
        break;
      case 'API_CALL':
        chipColor = Colors.purpleAccent;
        break;
      case 'FILE_WRITE':
        chipColor = Colors.amberAccent;
        break;
      case 'FILE_READ':
        chipColor = Colors.tealAccent;
        break;
      case 'STATE':
        chipColor = Colors.pinkAccent;
        break;
      case 'STATUS_WRITE':
        chipColor = Colors.tealAccent;
        break;
      default:
        chipColor = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            type,
            style: TextStyle(color: chipColor, fontSize: 9, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: chipColor.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(color: chipColor, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingConditionRow(String label, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 12,
            color: isActive ? Colors.greenAccent : Colors.white24,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.greenAccent : Colors.white38,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isActive ? Colors.greenAccent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              isActive ? 'YES' : 'NO',
              style: TextStyle(
                color: isActive ? Colors.greenAccent : Colors.white24,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── I/O Tab ──────────────────────────────────────────────────────────────────
// Two-mode panel toggled by a header switch:
//   • Agent (AI Bridge): read-only live transcript viewer — shows USER_INPUT
//     and PLANNER_RESPONSE from the active brain transcript.jsonl, refreshed
//     every 2 s by the parent's _statusTimer.
//   • AI Assistant (Ollama): a freeform chat interface backed by LocalAiService
//     (the same Ollama integration used in the Task Editor).
class AiAssistantTab extends StatefulWidget {
  final String lastPrompt;
  final String lastOutput;
  final String transcriptPath;
  final ScrollController outputScrollController;
  final ScrollController promptScrollController;
  final bool isThinking;

  const AiAssistantTab({
    super.key,
    required this.lastPrompt,
    required this.lastOutput,
    required this.transcriptPath,
    required this.outputScrollController,
    required this.promptScrollController,
    required this.isThinking,
  });

  @override
  State<AiAssistantTab> createState() => _AiAssistantTabState();
}

class _AiAssistantTabState extends State<AiAssistantTab> {
  // ── mode toggle ─────────────────────────────────────────────────────────────
  bool _isAiAssistantMode = false;

  // ── AI Assistant polled state ────────────────────────────────────────────
  // Polled from LocalAiService every 500 ms via _aiPollTimer.
  // Using a timer (not ListenableBuilder) avoids the _debugDuringDeviceUpdate
  // crash that occurs when notifyListeners() fires during mouse event dispatch.
  Timer? _aiPollTimer;
  String _aiPrompt = '';
  String _aiResponse = '';
  bool _aiIsProcessing = false;
  String _aiModel = '';

  late final ScrollController _localAiPromptScrollController;
  late final ScrollController _localAiOutputScrollController;
  late final TextEditingController _promptController;
  late final FocusNode _promptFocusNode;

  @override
  void initState() {
    super.initState();
    _localAiPromptScrollController = ScrollController();
    _localAiOutputScrollController = ScrollController();
    _promptController = TextEditingController(text: LocalAiService.instance.lastPromptSent);
    _promptFocusNode = FocusNode();
    // Seed immediately so the view isn't blank on first frame.
    _syncAiState();
    // Poll every 500 ms — safe because Timer callbacks run outside pointer dispatch.
    _aiPollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _syncAiState());
  }

  /// Reads the latest values from LocalAiService and calls setState only when
  /// something has actually changed (avoids unnecessary rebuilds).
  void _syncAiState() {
    if (!mounted) return;
    final svc = LocalAiService.instance;
    final prompt = svc.lastPromptSent;
    final response = svc.lastResponseReceived;
    final processing = svc.isProcessing;
    final model = svc.effectiveModel;
    if (prompt != _aiPrompt ||
        response != _aiResponse ||
        processing != _aiIsProcessing ||
        model != _aiModel) {
      setState(() {
        _aiPrompt = prompt;
        _aiResponse = response;
        _aiIsProcessing = processing;
        _aiModel = model;
        // Only auto-fill the prompt field when the user is NOT actively editing it.
        // This keeps the field updated with the last sent prompt while preserving
        // any tags ({NAME} etc.) the user is composing.
        if (!_promptFocusNode.hasFocus && _promptController.text != prompt) {
          _promptController.text = prompt;
        }
      });
    }
  }

  @override
  void dispose() {
    _aiPollTimer?.cancel();
    _localAiPromptScrollController.dispose();
    _localAiOutputScrollController.dispose();
    _promptFocusNode.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard'), duration: const Duration(seconds: 1)),
    );
  }

  // ── Shared read-only content panel (used in Agent mode) ──────────────────
  Widget _buildReadOnlyPanel({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color borderColor,
    required Color textColor,
    required String content,
    required ScrollController scrollController,
    required String emptyMessage,
    bool isProcessing = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            if (content.isNotEmpty)
              InkWell(
                onTap: () => _copyToClipboard(context, content, label),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.copy, size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text('Copy', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: content.isNotEmpty ? borderColor : AppColors.border,
              ),
            ),
            child: content.isEmpty
                ? Center(
                    child: isProcessing
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _DiagnosticsPulsingDot(color: Colors.purpleAccent),
                              const SizedBox(width: 8),
                              Text(emptyMessage,
                                  style: const TextStyle(color: Colors.purpleAccent, fontSize: 11)),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.swap_horiz_outlined, size: 28, color: Colors.white12),
                              const SizedBox(height: 6),
                              Text(
                                emptyMessage,
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                  )
                : Scrollbar(
                    controller: scrollController,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(10),
                      child: SelectableText(
                        content,
                        style: TextStyle(
                          color: textColor,
                          fontSize: AppUIConfig.rootFontSize,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ── Mode toggle header ───────────────────────────────────────────────────
  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeToggleButton(
            label: 'Agent',
            icon: Icons.psychology_outlined,
            isSelected: !_isAiAssistantMode,
            selectedColor: Colors.cyanAccent,
            onTap: () => setState(() => _isAiAssistantMode = false),
          ),
          const SizedBox(width: 4),
          _ModeToggleButton(
            label: 'AI Assistant',
            icon: Icons.smart_toy_outlined,
            isSelected: _isAiAssistantMode,
            selectedColor: Colors.purpleAccent,
            onTap: () => setState(() => _isAiAssistantMode = true),
          ),
        ],
      ),
    );
  }

  // ── Agent (Bridge) view ──────────────────────────────────────────────────
  Widget _buildAgentView(BuildContext context) {
    final shortPath = widget.transcriptPath.isNotEmpty
        ? widget.transcriptPath.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).take(2).join('/')
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // status row
        Row(
          children: [
            Icon(Icons.psychology_outlined, size: 13, color: Colors.cyanAccent),
            const SizedBox(width: 5),
            Text('AI Bridge — Live Transcript',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (widget.isThinking) ...[
              const _DiagnosticsPulsingDot(color: Colors.amberAccent),
              const SizedBox(width: 4),
              const Text('Thinking...', style: TextStyle(color: Colors.amberAccent, fontSize: 10)),
            ] else if (shortPath.isNotEmpty)
              Expanded(
                child: Text('.../$shortPath',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                    overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // PROMPT panel
        Expanded(
          flex: 2,
          child: _buildReadOnlyPanel(
            context: context,
            label: 'PROMPT',
            icon: Icons.person_outline,
            borderColor: Colors.cyanAccent.withOpacity(0.35),
            textColor: Colors.cyanAccent.shade100,
            content: widget.lastPrompt,
            scrollController: widget.promptScrollController,
            emptyMessage: 'No prompt received yet',
          ),
        ),
        const SizedBox(height: 8),
        // OUTPUT panel
        Expanded(
          flex: 3,
          child: _buildReadOnlyPanel(
            context: context,
            label: 'OUTPUT',
            icon: Icons.output,
            borderColor: Colors.cyanAccent.withOpacity(0.25),
            textColor: Colors.cyanAccent.shade200,
            content: widget.lastOutput,
            scrollController: widget.outputScrollController,
            emptyMessage: 'No response yet',
          ),
        ),
      ],
    );
  }

  // ── AI Assistant (Ollama) read-only monitor ──────────────────────────────
  // Reads from polled state (_aiPrompt/_aiResponse/_aiIsProcessing/_aiModel).
  // No ListenableBuilder — polling via _aiPollTimer avoids the
  // _debugDuringDeviceUpdate assertion caused by notifyListeners() firing
  // during mouse-event dispatch.
  Widget _buildAiAssistantView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Model info / status row ─────────────────────────────────────────
        Row(
          children: [
            const Icon(Icons.smart_toy_outlined, size: 13, color: Colors.purpleAccent),
            const SizedBox(width: 5),
            Text(
              LocalAiService.instance.customModelName.isNotEmpty
                  ? LocalAiService.instance.customModelName
                  : 'AI Assistant',
              style: const TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            if (LocalAiService.instance.customModelBase.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.purpleAccent.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_tree_outlined, size: 9, color: Colors.purpleAccent.withOpacity(0.6)),
                    const SizedBox(width: 3),
                    Text(
                      LocalAiService.instance.customModelBase,
                      style: TextStyle(
                          color: Colors.purpleAccent.withOpacity(0.7),
                          fontSize: 9,
                          fontFamily: 'monospace'),
                    ),
                  ],
                ),
              )
            else if (_aiModel.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.purpleAccent.withOpacity(0.35)),
                ),
                child: Text(_aiModel,
                    style: const TextStyle(
                        color: Colors.purpleAccent, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              ),
            const Spacer(),
            if (_aiIsProcessing) ...[
              const _DiagnosticsPulsingDot(color: Colors.purpleAccent),
              const SizedBox(width: 5),
              const Text('Processing...', style: TextStyle(color: Colors.purpleAccent, fontSize: 10)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // ── PROMPT panel (top, 1 part, editable) ────────────────────────────
        Flexible(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.input_outlined, size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'PROMPT',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  if (_promptController.text.isNotEmpty)
                    InkWell(
                      onTap: () => _copyToClipboard(context, _promptController.text, 'PROMPT'),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 11, color: AppColors.textMuted),
                            const SizedBox(width: 3),
                            Text('Copy', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _aiIsProcessing
                        ? null
                        : () async {
                            final promptText = _promptController.text.trim();
                            if (promptText.isEmpty) return;
                            try {
                              final tags = LocalAiService.instance.tagsFromActiveTask();
                              await LocalAiService.instance.generateText(
                                promptText,
                                taskName: tags.taskName,
                                parentName: tags.parentName,
                                taskSummary: tags.taskSummary,
                                taskDescription: tags.taskDescription,
                                taskNotes: tags.taskNotes,
                                taskChecklist: tags.taskChecklist,
                              );
                            } catch (e) {
                              debugPrint('Failed to send prompt to AI Assistant: $e');
                            }
                          },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        children: [
                          _aiIsProcessing
                              ? const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.purpleAccent),
                                )
                              : const Icon(Icons.send_outlined, size: 11, color: Colors.purpleAccent),
                          const SizedBox(width: 4),
                          Text(
                            _aiIsProcessing ? 'Sending...' : 'Send',
                            style: TextStyle(
                              color: _aiIsProcessing ? AppColors.textMuted : Colors.purpleAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.purpleAccent.withOpacity(0.25),
                    ),
                  ),
                  child: TextField(
                    controller: _promptController,
                    focusNode: _promptFocusNode,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: TextStyle(
                      color: Colors.purpleAccent.shade100,
                      fontSize: AppUIConfig.rootFontSize,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(10),
                      hintText: 'Type a prompt here to send to the AI Assistant...',
                      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // ── OUTPUT panel (bottom, 2 parts) ──────────────────────────────────
        Flexible(
          flex: 2,
          child: _buildReadOnlyPanel(
            context: context,
            label: 'OUTPUT',
            icon: Icons.output_outlined,
            borderColor: Colors.purpleAccent.withOpacity(0.25),
            textColor: Colors.purpleAccent.shade100,
            content: _aiIsProcessing ? '' : _aiResponse,
            scrollController: _localAiOutputScrollController,
            emptyMessage: _aiIsProcessing ? 'Processing...' : 'No response yet',
            isProcessing: _aiIsProcessing,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: title + mode toggle ──────────────────────────────────
          Row(
            children: [
              Icon(Icons.swap_horiz_outlined, size: 15, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                'I/O',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _buildModeToggle(),
            ],
          ),
          const SizedBox(height: 10),
          // ── Tab body ─────────────────────────────────────────────────────
          Expanded(
            child: _isAiAssistantMode
                ? _buildAiAssistantView(context)
                : _buildAgentView(context),
          ),
        ],
      ),
    );
  }
}

// ── _ModeToggleButton ─────────────────────────────────────────────────────────
// Pill-shaped toggle used inside the I/O tab mode selector.
class _ModeToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _ModeToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected ? Border.all(color: selectedColor.withOpacity(0.5)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? selectedColor : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? selectedColor : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsPulsingDot extends StatefulWidget {
  final Color color;
  const _DiagnosticsPulsingDot({required this.color});

  @override
  State<_DiagnosticsPulsingDot> createState() => _DiagnosticsPulsingDotState();
}

class _DiagnosticsPulsingDotState extends State<_DiagnosticsPulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.3 + (_controller.value * 0.7)),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.2 + (_controller.value * 0.4)),
                blurRadius: 4 + (_controller.value * 6),
                spreadRadius: 1 + (_controller.value * 2),
              )
            ],
          ),
        );
      },
    );
  }
}

