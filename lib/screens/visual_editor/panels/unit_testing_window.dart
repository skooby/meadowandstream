import 'dart:io';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_task_manager_panel.dart';
import '../../../services/ai_bridge_service.dart';
import '../visual_editor_screen.dart';
import '../../../constants.dart';

final ValueNotifier<bool> showUnitTestingNotifier = ValueNotifier(false);

void showUnitTestingWindow(BuildContext context) {
  if (showUnitTestingNotifier.value) return;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showUnitTesting'), true));
  showUnitTestingNotifier.value = true;
}

void hideUnitTestingWindow() {
  showUnitTestingNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showUnitTesting'), false));
}

class _UnitTestResult {
  final String name;
  final bool passed;
  final String details;
  _UnitTestResult(this.name, this.passed, this.details);
}

class UnitTestingWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  const UnitTestingWindow({super.key, required this.onClose, this.onFocus, this.isDocked = false});
  @override
  State<UnitTestingWindow> createState() => _UnitTestingWindowState();
}
class _UnitTestingWindowState extends State<UnitTestingWindow> {
  bool _isLoaded = false;

  double _width = 500;
  double _height = 450;
  bool _isCollapsed = false;
  double _bgOpacity = 0.8;
  Offset _offset = const Offset(200, 200);

  final List<_UnitTestResult> _testResults = [];

  void _runMockTest(String name, bool pass, String details) {
    setState(() {
      _testResults.add(_UnitTestResult(name, pass, details));
    });
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    VisualEditorScreen.currentWorkspace.addListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.addListener(_loadPreferences);
    VisualEditorScreen.activeWindowNotifier.addListener(_onActiveWindowChanged);
  }

  @override
  void dispose() {
    VisualEditorScreen.currentWorkspace.removeListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.removeListener(_loadPreferences);
    VisualEditorScreen.activeWindowNotifier.removeListener(_onActiveWindowChanged);
    super.dispose();
  }

  void _onActiveWindowChanged() {
    if (mounted) setState(() {});
  }
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isLoaded = true;

        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('testing_width')) ?? 500;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('testing_height')) ?? 450;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.8;
        _isCollapsed = prefs.getBool(VisualEditorScreen.getPrefKey('testing_isCollapsed')) ?? false;
        double dx = prefs.getDouble(VisualEditorScreen.getPrefKey('testing_dx')) ?? 200;
        double dy = prefs.getDouble(VisualEditorScreen.getPrefKey('testing_dy')) ?? 200;
        _offset = Offset(dx, dy);
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('testing_width'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('testing_height'), _height);
    await prefs.setBool(VisualEditorScreen.getPrefKey('testing_isCollapsed'), _isCollapsed);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('testing_dx'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('testing_dy'), _offset.dy);
  }
  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    if (widget.isDocked) return Material(color: Colors.transparent, child: _buildTestsContent());
    Widget rz({
      double? t, double? b, double? l, double? r, double? w, double? h,
      required SystemMouseCursor cursor,
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
            child: Transform.scale(scale: 1.0, alignment: Alignment.topLeft,
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
                    width: _width,
                    height: _isCollapsed ? null : _height,
                    clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'unit_testing' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) : null,
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
                          height: AppUIConfig.titleBarHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                              color: AppColors.titleBarBackground.withValues(alpha: _bgOpacity),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(AppUIConfig.windowBorderRadius))),
                          child: Row(
                            children: [
                              Icon((AppToolWindows.getDef('unit_testing')?.icon ?? Icons.science), size: 16, color: (AppToolWindows.getDef('unit_testing')?.color ?? Colors.grey)),
                              const SizedBox(width: 8),
                              Text((AppToolWindows.getDef('unit_testing')?.name ?? 'Unit Testing').toUpperCase(), style: TextStyle(
                                      color: AppColors.titleBarTextPrimary,
                                      fontSize: AppUIConfig.windowTitleFontSize,
                                      fontWeight: AppUIConfig.windowTitleFontWeight)),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(Icons.close, size: 18, color: AppColors.titleBarTextSecondary),
                                  onPressed: widget.onClose,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              ],
                            ),
                          ),
                        ),
                        if (!_isCollapsed)
                          Expanded(child: _buildTestsContent()),
                      ])
                  ),
                ),
              ),
                rz(t: 0, l: 12, r: 12, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){
                    double nH = _height - d.delta.dy;
                    if (nH >= 300 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy); }
                })),
                rz(b: 0, l: 12, r: 12, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){
                    double nH = _height + d.delta.dy;
                    if (nH >= 300 && nH <= 1200) { _height = nH; }
                })),
                rz(l: 0, t: 12, b: 12, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){
                    double nW = _width - d.delta.dx;
                    if (nW >= 300 && nW <= 1600) { _width = nW; _offset += Offset(d.delta.dx, 0); }
                })),
                rz(r: 0, t: 12, b: 12, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){
                    double nW = _width + d.delta.dx;
                    if (nW >= 300 && nW <= 1600) { _width = nW; }
                })),
                rz(t: 0, l: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){
                    double nW = _width - d.delta.dx; double nH = _height - d.delta.dy;
                    if (nW >= 300 && nW <= 1600) { _width = nW; _offset += Offset(d.delta.dx, 0); }
                    if (nH >= 300 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy); }
                })),
                rz(t: 0, r: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (d) => setState((){
                    double nW = _width + d.delta.dx; double nH = _height - d.delta.dy;
                    if (nW >= 300 && nW <= 1600) { _width = nW; }
                    if (nH >= 300 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy); }
                })),
                rz(b: 0, l: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (d) => setState((){
                    double nW = _width - d.delta.dx; double nH = _height + d.delta.dy;
                    if (nW >= 300 && nW <= 1600) { _width = nW; _offset += Offset(d.delta.dx, 0); }
                    if (nH >= 300 && nH <= 1200) { _height = nH; }
                })),
                rz(b: 0, r: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){
                    double nW = _width + d.delta.dx; double nH = _height + d.delta.dy;
                    if (nW >= 300 && nW <= 1600) { _width = nW; }
                    if (nH >= 300 && nH <= 1200) { _height = nH; }
                })),
              ],
            ),
           ),
          );
        },
    );
  }

  Widget _buildTestsContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Test Commands', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.panelBackground,
                      shape: RoundedRectangleBorder(side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(4))
                    ),
                    onPressed: () => _runMockTest('Timeline Layer Bounds', true, 'Raster metrics confirmed visual constraints perfectly aligned with 16ms boundaries.'),
                    icon: Icon(Icons.play_arrow, size: 14, color: AppColors.accent),
                    label: Text('Widget Rendering Tests', style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.panelBackground,
                      shape: RoundedRectangleBorder(side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(4))
                    ),
                    onPressed: () => _runMockTest('Supabase Auth Cache', false, 'NullPointerException: Expected valid JWT token inside SharedPreferences but found null pointer during Boot sequence!'),
                    icon: Icon(Icons.play_arrow, size: 14, color: AppColors.accent),
                    label: Text('State Hydration Tests', style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.panelBackground,
                      shape: RoundedRectangleBorder(side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(4))
                    ),
                    onPressed: () => _runMockTest('AiBridge JSON Sync', true, 'File safely written continuously over 300 IOps asynchronously!'),
                    icon: Icon(Icons.play_arrow, size: 14, color: AppColors.accent),
                    label: Text('IO Bridge API Tests', style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.panelBackground,
                      shape: RoundedRectangleBorder(side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(4))
                    ),
                    onPressed: () async {
                        try {
                           final bridge = AiBridgeService.instance;
                           
                           // Atari 2600 mode: Just construct the literal string exactly as it looks natively
                           await bridge.compilePrimaryDirectivesFile();
                           final StringBuffer sb = StringBuffer();
                           sb.writeln('# PRIMARY DIRECTIVES');
                           sb.writeln('> [!IMPORTANT]');
                           sb.writeln('CRITICAL: You MUST read the `.ai_bridge/primary_directives.md` file natively using your tool to understand the GLOBAL CONSTRAINTS and NATIVE SYSTEM HOOKS before proceeding. Failure to do so will break the application.');
                           sb.writeln('To align context with the current workspace state, you must also read the recent conversation history in `.ai_bridge/conversation_history.md` and the database dump in `.ai_bridge/db_dump.json` using your file-reading tools.\n');
                           
                           sb.writeln('SAFETY ABORT PROTOCOL: Regardless of whether you are in LIVE or PREVIEW mode, if a task is not clear, potentially harmful, extensive, or requires system-wide core changes, DO NOT execute code. Instead, generate a `.ai_bridge/latest_preview.json` containing your questions or concerns to be resolved (use the description field), and write `PREVIEW` to `.ai_bridge/agent_status.txt`. This will dynamically switch the app to preview mode and pause for human review.');
                           
                           if (bridge.isPreviewMode) {
                             sb.writeln('CRITICAL RULE: If the user provides a review of preview items, you CANNOT and MUST NOT proceed with actual code changes if ANY item is marked as "Approved: NO". You must adjust your plan and generate a NEW `.ai_bridge/latest_preview.json` file for further review. ONLY proceed with code execution when explicitly approved.');
                           } else {
                             sb.writeln('Voice: Direct / Robotic (Be objective, factual, concise, and eliminate personality)');
                             sb.writeln('Complexity: Concise (Keep your response short and strictly to the point)\\n');
                           }
                           sb.writeln(bridge.quickInstructions);
                           
                           sb.writeln('--- DATA MUTATION SANDBOX ---');
                           sb.writeln('Do not attempt to edit `.ai_bridge/tasks.json` directly. The application framework natively manages all task statuses (e.g., inProgress, inTesting) and SubTask checkboxes mechanics on your behalf.');
                           sb.writeln('To log notes for this execution, you must write conversational raw text exactly to `.ai_bridge/latest_notes.md`. Doing so natively queues your notes to be absorbed into the JSON state securely.');
                           sb.writeln('CRITICAL INSTRUCTION: You are being directed to work on ONE specific task only. The native app will mark the active subtask complete when you push IDLE. DO NOT process, review, or address any other tasks.');
                           
                           sb.writeln('\\n--- COMPILATION INTEGRITY LOCK ---');
                           sb.writeln('You are fundamentally forbidden from unblocking the queue or marking tasks complete if your code destroys logical compilation integrity.');
                           sb.writeln('BEFORE YOUR FINAL STEP, you are COMMANDED to physically execute `dart analyze` or `flutter analyze` internally within your console environment to absolutely verify your code compiles flawlessly.');
                           sb.writeln('If any `error` level syntax issues exist, DO NOT release the queue. Rapidly patch them dynamically using internal tool calls until the build passes.');
                           sb.writeln('\\nOnce verified: As your ABSOLUTE FINAL STEP after exhausting all operations and completing your internal pipeline, you MUST overwrite the `.ai_bridge/agent_status.txt` file with the exact physical unquoted text `IDLE`. This will unblock the overarching queue and release the next task to you.');
                           sb.writeln('Update file when complete\\n');
                           
                           sb.writeln('# TASKS TO ADDRESS');
                           sb.writeln('Task: Mock Unit Test (Visual Preview Only)');
                           sb.writeln('Area: PIPELINE TEST BED > SIMPLE THREE POINT TEST');
                           sb.writeln('Status: IN PROGRESS');
                           sb.writeln('---');
                           
                           String directive = sb.toString().trim();
                           
                           dev.log('\\n=== AI BRIDGE PROMPT PAYLOAD ===\\n\$directive\\n===============================', name: 'UNIT_TEST');
                           
                           _runMockTest('Primary Directive Logic', true, directive);
                        } catch (e) {
                           print('Error: \$e');
                           dev.log('Error generating directive: \$e', name: 'UNIT_TEST', error: e);
                           _runMockTest('Primary Directive Logic', false, e.toString());
                        }
                    },
                    icon: Icon(Icons.play_arrow, size: 14, color: AppColors.accent),
                    label: Text('Test Primary Directive', style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.panelBackground,
                      shape: RoundedRectangleBorder(side: BorderSide(color: AppColors.overlaySubtle), borderRadius: BorderRadius.circular(4))
                    ),
                    onPressed: () => setState(() => _testResults.clear()),
                    icon: Icon(Icons.clear, size: 14, color: AppColors.panelTextSecondary),
                    label: Text('Clear', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
                  )
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.overlaySubtle),
        Expanded(
          child: _testResults.isEmpty
              ? Center(child: Text('No results recorded.\nRun tests from the command panel.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: AppUIConfig.rootFontSize)))
              : ListView.builder(
                  itemCount: _testResults.length,
                  itemBuilder: (context, index) {
                    final res = _testResults[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.overlaySubtle))
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(res.passed ? Icons.check_circle : Icons.error, color: res.passed ? Colors.green : Colors.redAccent, size: 16),
                              const SizedBox(width: 8),
                              Text(res.name.toUpperCase(), style: TextStyle(color: res.passed ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: AppUIConfig.rootFontSize)),
                              const Spacer(),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.panelBackground,
                                  shape: RoundedRectangleBorder(side: BorderSide(color: AppColors.overlaySubtle), borderRadius: BorderRadius.circular(4)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  minimumSize: const Size(0, 24)
                                ),
                                onPressed: () {
                                    AiBridgeService.instance.addTask(
                                      res.passed ? 'Review Success Logs: ${res.name}' : 'Fix Failed Test: ${res.name}', '',
                                      notes: res.details,
                                      parentId: '1774879454129'
                                    );
                                },
                                icon: const Icon(Icons.send_to_mobile, size: 12, color: Colors.amberAccent),
                                label: Text('Send to Task Folder', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.smallFontSize)),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.copy, size: 14, color: AppColors.accent),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: res.details));
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied output to clipboard!', style: TextStyle(fontSize: AppUIConfig.rootFontSize)), duration: const Duration(seconds: 2)));
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                tooltip: 'Copy Output',
                              )
                            ]
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 24),
                            child: SizedBox(
                              width: double.infinity,
                              child: SelectableText(res.details, style: TextStyle(color: res.passed ? AppColors.panelTextSecondary : Colors.red.withOpacity(0.8), fontSize: AppUIConfig.rootFontSize, fontFamily: 'monospace')),
                            ),
                          )
                        ]
                      )
                    );
                  }
                )
        )
      ]
    );
  }
}
