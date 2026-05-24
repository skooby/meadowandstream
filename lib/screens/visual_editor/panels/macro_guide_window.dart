import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../visual_editor_screen.dart';
import '../../../constants.dart';

final ValueNotifier<bool> showMacroGuideNotifier = ValueNotifier(false);

void showMacroGuideWindow(BuildContext context) {
  if (showMacroGuideNotifier.value) return;

  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showMacroGuide'), true));

  showMacroGuideNotifier.value = true;
}

void hideMacroGuideWindow() {
  showMacroGuideNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showMacroGuide'), false));
}

class MacroGuideWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  const MacroGuideWindow({super.key, required this.onClose, this.onFocus, this.isDocked = false});

  @override
  State<MacroGuideWindow> createState() => _MacroGuideWindowState();
}
class _MacroGuideWindowState extends State<MacroGuideWindow> {
  bool _isLoaded = false;

  double _width = 850;
  double _height = 550;
  double _bgOpacity = 0.8;
  Offset _offset = const Offset(150, 150);

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

        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('macro_guide_width')) ?? 850;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('macro_guide_height')) ?? 550;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.8;
        double dx = prefs.getDouble(VisualEditorScreen.getPrefKey('macro_guide_dx')) ?? 150;
        double dy = prefs.getDouble(VisualEditorScreen.getPrefKey('macro_guide_dy')) ?? 150;
        _offset = Offset(dx, dy);
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('macro_guide_width'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('macro_guide_height'), _height);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('macro_guide_dx'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('macro_guide_dy'), _offset.dy);
  }
  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    if (widget.isDocked) return Material(color: Colors.transparent, child: _buildContent());

    Widget rz({
      double? t, double? b, double? l, double? r, double? w, double? h,
      required SystemMouseCursor cursor,
      required void Function(DragUpdateDetails) pan,
    }) => Positioned(
      top: t, bottom: b, left: l, right: r, width: w, height: h,
      child: MouseRegion(cursor: cursor, child: GestureDetector(behavior: HitTestBehavior.opaque, onPanUpdate: pan, onPanEnd: (_) => _savePreferences(), child: Container(color: Colors.transparent)))
    );

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: ValueListenableBuilder<double>(
        valueListenable: VisualEditorScreen.globalUiScale,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: 1.0, alignment: Alignment.topLeft,
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
                      height: _height,
                      clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'macro_guide' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) : null,
                        color: AppColors.windowBackground.withValues(alpha: _bgOpacity),
                        borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                        
                      ),
                      child: Column(
                        children: [
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
                                borderRadius: BorderRadius.vertical(top: Radius.circular(AppUIConfig.windowBorderRadius)),
                              ),
                              child: Row(
                                children: [
                                  Icon(AppToolWindows.getDef('macro_guide').icon, size: 16, color: AppToolWindows.getDef('macro_guide').color),
                                  const SizedBox(width: 8),
                                  Text(AppUIConfig.formatWindowTitle(AppToolWindows.getDef('macro_guide').name), style: TextStyle(color: AppColors.titleBarTextPrimary, fontSize: AppUIConfig.windowTitleFontSize, fontWeight: AppUIConfig.windowTitleFontWeight)),
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
                          Expanded(child: _buildContent()),
                        ],
                      ),
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
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            indicatorColor: AppColors.accent,
            labelColor: AppColors.panelTextPrimary,
            unselectedLabelColor: AppColors.panelTextSecondary,
            tabs: [
              Tab(text: "Commands"),
              Tab(text: "Examples"),
              Tab(text: "PowerShell"),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TabBarView(
                children: [
                  SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: IntrinsicColumnWidth(),
                        1: FlexColumnWidth(),
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        [ 'WaitMs(500)', 'Pause execution for given milliseconds' ],
                        [ 'MoveMouse(X, Y)', 'Move cursor to screen coords' ],
                        [ 'RelativeMouseMove("Corner", DX, DY)', 'Move relative to active window' ],
                        [ 'LeftClick() / RightClick() / MiddleClick()', 'Single mouse clicks' ],
                        [ 'LeftDoubleClick()', 'Double left click' ],
                        [ 'SwitchWindow("App Name")', 'Brings app to foreground' ],
                        [ 'ReturnToApp()', 'Brings this app back to foreground' ],
                        [ 'SendText("Hello")', 'Type literally' ],
                        [ 'Send("^v")', 'Send keystrokes (^=Ctrl, +=Shift, !=Alt)' ],
                        [ 'PixelIs("#FFFFFF")', 'Aborts macro if the underlying pixel at cursor does not match Hex' ],
                        [ 'PixelIsNot("#FFFFFF")', 'Evaluates to a boolean. Best used as: if (PixelIsNot("#FFFFFF")) { } else { }' ],
                        [ 'PixelMoreThan("#080808", 10)', 'Evaluates to boolean. Checks if pixel color Euclidean distance from hex is > threshold' ],
                        [ 'Run("Macro Name")', 'Injects and evaluates another entire macro conditionally' ],
                        [ 'SaveWindowPosSize()', 'Save active window bounds native to memory' ],
                        [ 'RestoreWindowPosSize()', 'Restore actively saved spatial window layout' ],
                        [ 'WinMove(X, Y, Width, Height)', 'Moves and resizes the currently active window' ],
                        [ 'BlockInput(true)', 'Blocks physical user keyboard and mouse input during execution' ],
                        [ 'Log("Message")', 'Relays structural output dynamically to the SystemLogs stream' ],
                        [ 'if (...) { } else { }', 'Standard powershell logic evaluation wrapper natively supported!' ],
                        [ '// comment', 'Add notes to script' ],
                        [ '/* comment */', 'Add multiline block notes' ],
                        [ 'System Global Hotkey', 'If timing is System, you can set a global hotkey! Format follows AutoHotkey (e.g. ^!p for Ctrl+Alt+P). Supported modifiers: ^(Ctrl), !(Alt), +(Shift), #(Win).' ],
                        [ 'AppendClipboard("String")', 'Append a string to the clipboard queue' ],
                        [ 'SetClipboard()', 'Sets clipboard to the 0 index of the clipboard queue' ],
                        [ 'NextClipboard()', 'Iterates to the next item in the clipboard queue and sets the clipboard' ],
                        [ 'GetBridgeMode()', 'Returns active AI Bridge mode string ("sdk", "desktop", "cli", "handsfree")' ],
                        [ 'LogPixelColor()', 'Logs Hex color of pixel currently under mouse cursor' ],
                        [ 'var name = value', 'Declare and initialize a local variable (JavaScript/C# style)' ],
                        [ '==  !=  <  >  <=  >=', 'Comparison operators (automatically translated to PowerShell -eq, -ne, etc.)' ],
                        [ 'expr1 + expr2', 'String concatenation (automatically grouped in parentheses for execution)' ],
                      ].map((row) => TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.only(right: 16, bottom: 8), child: SelectableText(row[0], style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace'))),
                          Padding(padding: EdgeInsets.only(bottom: 8), child: Text(row[1], style: TextStyle(color: AppColors.panelTextSecondary))),
                        ]
                      )).toList(),
                    ),
                  ),
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Log and Pause', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: AppUIConfig.rootFontSize)),
                        Container(
                          margin: const EdgeInsets.only(top: 4, bottom: 16),
                          padding: const EdgeInsets.all(8),
                          color: AppColors.windowBackground,
                          width: double.infinity,
                          child: const SelectableText('Log("Starting script")\nWaitMs(200)', style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
                        ),
                        
                        Text('System Global Hotkeys', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: AppUIConfig.rootFontSize)),
                        Container(
                          margin: const EdgeInsets.only(top: 4, bottom: 16),
                          padding: const EdgeInsets.all(8),
                          color: AppColors.windowBackground,
                          width: double.infinity,
                          child: const SelectableText('1. Set Macro Timing to "System".\n2. Click the Keyboard icon on the Macro item.\n3. Enter hotkey (e.g., ^+F10 for Ctrl+Shift+F10, or !A for Alt+A).\n4. The script will automatically wait in the background and execute whenever pressed natively across the OS.', style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
                        ),

                        Text('Window Positioning', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: AppUIConfig.rootFontSize)),
                        Container(
                          margin: const EdgeInsets.only(top: 4, bottom: 16),
                          padding: const EdgeInsets.all(8),
                          color: AppColors.windowBackground,
                          width: double.infinity,
                          child: const SelectableText('SaveWindowPosSize()\n# Do something here...\nRestoreWindowPosSize()', style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
                        ),
                        
                        Text('Simple Conditional', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: AppUIConfig.rootFontSize)),
                        Container(
                          margin: const EdgeInsets.only(top: 4, bottom: 16),
                          padding: const EdgeInsets.all(8),
                          color: AppColors.windowBackground,
                          width: double.infinity,
                          child: const SelectableText('if (PixelIs("#FFFFFF")) {\n  Log("Found white!")\n} else {\n  Log("Not white!")\n}', style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
                        ),
                        
                        Text('Evaluating and Routing', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: AppUIConfig.rootFontSize)),
                        Container(
                          margin: const EdgeInsets.only(top: 4, bottom: 16),
                          padding: const EdgeInsets.all(8),
                          color: AppColors.windowBackground,
                          width: double.infinity,
                          child: const SelectableText('if (PixelIsNot("#1A1A1A")) {\n  Run("SubMacro_Fallback")\n}\nSend("^v")', style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
                        ),
                        
                        Text('Checking Distance (Brightness/Proximity)', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: AppUIConfig.rootFontSize)),
                        Container(
                          margin: const EdgeInsets.only(top: 4, bottom: 16),
                          padding: const EdgeInsets.all(8),
                          color: AppColors.windowBackground,
                          width: double.infinity,
                          child: const SelectableText('// Is it further than 15 color units away from pure black? (i.e. is it lit up?)\nif (PixelMoreThan("#000000", 15)) {\n  Log("Button is active!")\n}', style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
                        ),
                        
                        Text('AI Bridge Mode Conditional', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: AppUIConfig.rootFontSize)),
                        Container(
                          margin: const EdgeInsets.only(top: 4, bottom: 16),
                          padding: const EdgeInsets.all(8),
                          color: AppColors.windowBackground,
                          width: double.infinity,
                          child: const SelectableText('var bridgeMode = GetBridgeMode()\nif (bridgeMode == "desktop") {\n  Log("Running inside Desktop (Windows) integration mode!")\n} else {\n  Log("Active mode: \$bridgeMode")\n}', style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
                        ),

                        Text('Looping and Variables', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: AppUIConfig.rootFontSize)),
                        Container(
                          margin: const EdgeInsets.only(top: 4, bottom: 16),
                          padding: const EdgeInsets.all(8),
                          color: AppColors.windowBackground,
                          width: double.infinity,
                          child: const SelectableText('var count = 5\nfor (var i = 0; i < count; i++) {\n  Log("Iteration: " + i)\n  WaitMs(100)\n}', style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
                        ),
                      ]
                    ),
                  ),
                  SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: IntrinsicColumnWidth(),
                        1: FlexColumnWidth(),
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        [ 'var x = value', 'Translated to PowerShell variable (\$x = value)' ],
                        [ 'x == y', 'Translated to PowerShell equality check (\$x -eq \$y)' ],
                        [ 'x != y', 'Translated to PowerShell inequality check (\$x -ne \$y)' ],
                        [ 'x < y / x > y', 'Translated to PowerShell comparisons (\$x -lt \$y / \$x -gt \$y)' ],
                        [ 'x + y', 'Grouped as native expression parentheses e.g. (\$x + \$y)' ],
                        [ '\$var = "Hello"', 'Declare and assign variables' ],
                        [ 'if (\$a -eq "Hello") { }', 'Standard PowerShell comparison (-eq, -ne, -gt, -lt)' ],
                        [ 'Start-Process "notepad.exe"', 'Launch an external application or executable' ],
                        [ 'Stop-Process -Name "notepad"', 'Terminate a running process by name' ],
                        [ 'Get-Process | Where Name -eq "chrome"', 'Find and filter active background processes' ],
                        [ 'Start-Sleep -Seconds 2', 'Native PowerShell sleep/pause' ],
                        [ 'Write-Host "Message"', 'Print text natively to standard output' ],
                        [ 'try { ... } catch { ... }', 'Error handling and try/catch blocks' ],
                        [ 'for (\\\$i=0; \\\$i -lt 10; \\\$i++) { }', 'Standard iterative for loops' ],
                        [ 'Add-Type -AssemblyName ...', 'Load standard .NET assemblies and C# libraries' ],
                      ].map((row) => TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.only(right: 16, bottom: 8), child: SelectableText(row[0], style: const TextStyle(color: Colors.amberAccent, fontFamily: 'monospace'))),
                          Padding(padding: EdgeInsets.only(bottom: 8), child: Text(row[1], style: TextStyle(color: AppColors.panelTextSecondary))),
                        ]
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


