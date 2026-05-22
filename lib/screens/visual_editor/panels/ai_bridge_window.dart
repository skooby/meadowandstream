import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../visual_editor_screen.dart';
import '../../../constants.dart';
import '../../../services/ai_bridge_service.dart';
import '../../../services/antigravity_status_service.dart';
import 'ai_task_manager_panel.dart';

class AiBridgeActivityIcon extends StatefulWidget {
  final double size;
  final Color? color;
  final IconData defaultIcon;

  const AiBridgeActivityIcon({
    super.key,
    required this.size,
    this.color,
    required this.defaultIcon,
  });

  @override
  State<AiBridgeActivityIcon> createState() => _AiBridgeActivityIconState();
}

class _AiBridgeActivityIconState extends State<AiBridgeActivityIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (AiBridgeService.instance.isThinking) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AiBridgeService.instance,
      builder: (context, child) {
        final isThinking = AiBridgeService.instance.isThinking;
        final isTesting = AiBridgeService.instance.isTesting;
        final iconData = isTesting ? Icons.science : widget.defaultIcon;
        final iconColor = isTesting ? Colors.amberAccent : (widget.color ?? Colors.white70);

        if (isThinking) {
          if (!_controller.isAnimating) {
            _controller.repeat(reverse: true);
          }
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: 0.3 + (_controller.value * 0.7),
                child: Icon(
                  iconData,
                  size: widget.size,
                  color: iconColor,
                ),
              );
            },
          );
        } else {
          if (_controller.isAnimating) {
            _controller.stop();
          }
          return Icon(
            iconData,
            size: widget.size,
            color: iconColor,
          );
        }
      },
    );
  }
}

class AiBridgeWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback? onClose;
  final VoidCallback? onFocus;

  static final ValueNotifier<bool> showBridgeMonitorNotifier = ValueNotifier<bool>(false);

  static Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    showBridgeMonitorNotifier.value = prefs.getBool(VisualEditorScreen.getPrefKey('ai_bridge_show_monitor')) ?? false;
  }

  static void toggleMode() async {
    final show = !showBridgeMonitorNotifier.value;
    showBridgeMonitorNotifier.value = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(VisualEditorScreen.getPrefKey('ai_bridge_show_monitor'), show);
  }

  const AiBridgeWindow({
    super.key,
    required this.isDocked,
    this.onClose,
    this.onFocus,
  });

  @override
  State<AiBridgeWindow> createState() => _AiBridgeWindowState();
}

class _AiBridgeWindowState extends State<AiBridgeWindow> {
  Offset _position = const Offset(100, 100);
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
          prefs.getDouble(VisualEditorScreen.getPrefKey('ai_bridge_x')) ?? 100,
          prefs.getDouble(VisualEditorScreen.getPrefKey('ai_bridge_y')) ?? 100,
        );
        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('ai_bridge_w')) ?? 750;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('ai_bridge_h')) ?? 650;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.4;
      });
      AiBridgeWindow.showBridgeMonitorNotifier.value = prefs.getBool(VisualEditorScreen.getPrefKey('ai_bridge_show_monitor')) ?? false;
    }
  }

  void _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('ai_bridge_x'), _position.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('ai_bridge_y'), _position.dy);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('ai_bridge_w'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('ai_bridge_h'), _height);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDocked) {
      return Material(
        color: AppColors.windowBackground,
        child: ValueListenableBuilder<bool>(
          valueListenable: AiBridgeWindow.showBridgeMonitorNotifier,
          builder: (context, showBridgeMonitor, _) {
            return showBridgeMonitor
                ? const AiBridgePanel()
                : AiTaskManagerPanel(
                    key: globalTaskManagerKey,
                    isDocked: true,
                    onClose: widget.onClose,
                    onFocus: widget.onFocus,
                  );
          },
        ),
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
                          color: VisualEditorScreen.activeWindowNotifier.value == 'ai_bridge'
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
                        height: 40,
                        color: AppColors.titleBarBackground.withValues(alpha: _bgOpacity),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            AiBridgeActivityIcon(
                              size: 16,
                              color: AppToolWindows.getDef('ai_bridge').color,
                              defaultIcon: AppToolWindows.getDef('ai_bridge').icon,
                            ),
                            const SizedBox(width: 8),
                            ValueListenableBuilder<bool>(
                              valueListenable: AiBridgeWindow.showBridgeMonitorNotifier,
                              builder: (context, showBridgeMonitor, _) {
                                return Text(
                                  AppUIConfig.formatWindowTitle(
                                      showBridgeMonitor ? 'Bridge Monitor' : 'Task Manager'),
                                  style: TextStyle(
                                    color: AppColors.titleBarTextPrimary,
                                    fontSize: AppUIConfig.windowTitleFontSize,
                                    fontWeight: AppUIConfig.windowTitleFontWeight,
                                  ),
                                );
                              },
                            ),
                            const Spacer(),
                            ValueListenableBuilder<bool>(
                              valueListenable: AiBridgeWindow.showBridgeMonitorNotifier,
                              builder: (context, showBridgeMonitor, _) {
                                return IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  tooltip: showBridgeMonitor
                                      ? 'Switch to Task Manager'
                                      : 'Switch to Bridge Monitor',
                                  icon: Icon(
                                    showBridgeMonitor ? Icons.assignment : Icons.analytics,
                                    color: AppColors.panelTextSecondary,
                                    size: 16,
                                  ),
                                  onPressed: AiBridgeWindow.toggleMode,
                                );
                              },
                            ),
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
                        child: ValueListenableBuilder<bool>(
                          valueListenable: AiBridgeWindow.showBridgeMonitorNotifier,
                          builder: (context, showBridgeMonitor, _) {
                            return showBridgeMonitor
                                ? const AiBridgePanel()
                                : AiTaskManagerPanel(
                                    key: globalTaskManagerKey,
                                    isDocked: true,
                                    onClose: widget.onClose,
                                    onFocus: widget.onFocus,
                                  );
                          },
                        ),
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

  // Log Monitoring
  String _selectedLogFile = 'bridge_debug.txt';
  String _logContents = '';
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _loadLogFile();
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

  Future<void> _loadLogFile() async {
    try {
      final file = File('.ai_bridge/$_selectedLogFile');
      if (await file.exists()) {
        final contents = await file.readAsString();
        if (mounted) {
          setState(() {
            _logContents = contents.trim().isEmpty ? '(File is empty)' : contents;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _logContents = '(File does not exist)';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _logContents = 'Error reading file: $e';
        });
      }
    }
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

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
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
                    const SizedBox(height: 12),
                    // Log Outcomes Monitor
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
                                Text(
                                  'Log Outcomes Monitor',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                DropdownButton<String>(
                                  value: _selectedLogFile,
                                  dropdownColor: AppColors.panelBackground,
                                  underline: Container(),
                                  style: TextStyle(color: AppColors.textPrimary, fontSize: 11),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedLogFile = val;
                                      });
                                      _loadLogFile();
                                    }
                                  },
                                  items: const [
                                    DropdownMenuItem(value: 'bridge_debug.txt', child: Text('bridge_debug.txt')),
                                    DropdownMenuItem(value: 'bridge_error.txt', child: Text('bridge_error.txt')),
                                    DropdownMenuItem(value: 'bridge_compile_log.txt', child: Text('bridge_compile_log.txt')),
                                    DropdownMenuItem(value: 'bridge_commit_debug.txt', child: Text('bridge_commit_debug.txt')),
                                    DropdownMenuItem(value: 'latest_notes.json', child: Text('latest_notes.json')),
                                    DropdownMenuItem(value: 'latest_verification.json', child: Text('latest_verification.json')),
                                    DropdownMenuItem(value: 'agent_status.txt', child: Text('agent_status.txt')),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.refresh, size: 16, color: AppColors.textSecondary),
                                  onPressed: _loadLogFile,
                                  tooltip: 'Reload File',
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white12, height: 16),
                            Container(
                              height: 250,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Scrollbar(
                                controller: _logScrollController,
                                child: SingleChildScrollView(
                                  controller: _logScrollController,
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    _logContents,
                                    style: TextStyle(
                                      color: AppColors.textPrimary.withOpacity(0.8),
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
            ),
          ],
        );
      },
    );
  }
}
