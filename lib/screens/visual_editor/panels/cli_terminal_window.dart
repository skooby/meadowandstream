import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../visual_editor_screen.dart';
import '../../../services/ai_bridge_service.dart';
import '../../../utils/ai_command_parser.dart';
import '../../../constants.dart';

final ValueNotifier<bool> showCliTerminalNotifier = ValueNotifier(false);

void hideCliTerminalWindow() => showCliTerminalNotifier.value = false;

void showCliTerminalWindow(BuildContext context) => showCliTerminalNotifier.value = true;

void toggleCliTerminalWindow() => showCliTerminalNotifier.value = !showCliTerminalNotifier.value;

class CliTerminalWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback? onClose;
  final VoidCallback? onFocus;

  const CliTerminalWindow({super.key, required this.isDocked, this.onClose, this.onFocus});

  @override
  State<CliTerminalWindow> createState() => _CliTerminalWindowState();
}
class _CliTerminalWindowState extends State<CliTerminalWindow> {

  Offset _position = const Offset(150, 150);
  double _width = 800;
  double _height = 600;
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _loadState();
    VisualEditorScreen.currentWorkspace.addListener(_loadState);
  }

  @override
  void dispose() {
    VisualEditorScreen.currentWorkspace.removeListener(_loadState);
    super.dispose();
  }

  void _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _position = Offset(
          prefs.getDouble(VisualEditorScreen.getPrefKey('cli_float_x')) ?? 150,
          prefs.getDouble(VisualEditorScreen.getPrefKey('cli_float_y')) ?? 150,
        );
        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('cli_float_w')) ?? 800;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('cli_float_h')) ?? 600;
        _isCollapsed = prefs.getBool(VisualEditorScreen.getPrefKey('cli_float_collapsed')) ?? false;
      });
    }
  }

  void _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('cli_float_x'), _position.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('cli_float_y'), _position.dy);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('cli_float_w'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('cli_float_h'), _height);
    await prefs.setBool(VisualEditorScreen.getPrefKey('cli_float_collapsed'), _isCollapsed);
  }
  @override
  Widget build(BuildContext context) {

    if (widget.isDocked) {
      return Material(
        color: AppColors.windowBackground,
        child: Column(
          children: [
            Container(
              height: AppUIConfig.titleBarHeight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: AppColors.panelBackground,
              child: Row(
                children: [
                  Icon(AppToolWindows.getDef('cli_terminal').icon, size: 16, color: AppToolWindows.getDef('cli_terminal').color),
                  const SizedBox(width: 8),
                  Text(AppUIConfig.formatWindowTitle(AppToolWindows.getDef('cli_terminal').name), style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.windowTitleFontSize, fontWeight: AppUIConfig.windowTitleFontWeight)),
                  const Spacer(),
                  if (widget.onClose != null)
                    InkWell(
                      onTap: widget.onClose,
                      child: Icon(Icons.close, color: AppColors.panelTextSecondary, size: 16),
                    )
                ],
              ),
            ),
            Expanded(child: CliTerminalPanel()),
          ],
        ),
      );
    }

    final mq = MediaQuery.of(context).size;
    final w = _width.clamp(300.0, mq.width);
    final h = _height.clamp(200.0, mq.height);

    final dx = _position.dx.clamp(0.0, (mq.width - w).clamp(0.0, double.infinity));
    final dy = _position.dy.clamp(0.0, (mq.height - (_isCollapsed ? 40.0 : h)).clamp(0.0, double.infinity));

    Widget rz({
      double? t, double? b, double? l, double? r, double? dw, double? dh,
      required SystemMouseCursor cursor,
      required void Function(DragUpdateDetails) pan,
    }) => Positioned(
      top: t, bottom: b, left: l, right: r, width: dw, height: dh,
      child: MouseRegion(cursor: cursor, child: GestureDetector(behavior: HitTestBehavior.opaque, onPanDown: (_) => widget.onFocus?.call(), onPanUpdate: pan, onPanEnd: (_) => _saveState(), child: Container(color: Colors.transparent)))
    );

    return Positioned(
      left: dx,
      top: dy,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: w,
            height: _isCollapsed ? null : h,
            child: Material(
              color: AppColors.windowBackground,
              elevation: 8,
              borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanDown: (_) => widget.onFocus?.call(),
                    onPanUpdate: (d) => setState(() => _position += d.delta),
                    onPanEnd: (_) => _saveState(),
                    onDoubleTap: () => setState(() {
                      _isCollapsed = !_isCollapsed;
                      _saveState();
                    }),
                    child: Container(
                      height: 40,
                      color: AppColors.panelBackground,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.code, color: Colors.greenAccent, size: 16),
                          const SizedBox(width: 8),
                          Text(AppUIConfig.formatWindowTitle(AppToolWindows.getDef('cli_terminal').name), style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.windowTitleFontSize, fontWeight: AppUIConfig.windowTitleFontWeight)),
                          const Spacer(),
                          IconButton(
                            icon: Icon(_isCollapsed ? Icons.expand_more : Icons.expand_less, color: AppColors.panelTextSecondary, size: 16),
                            onPressed: () => setState(() {
                              _isCollapsed = !_isCollapsed;
                              _saveState();
                            }),
                          ),
                          if (widget.onClose != null)
                            IconButton(
                              icon: Icon(Icons.close, color: AppColors.titleBarTextSecondary, size: 16),
                              onPressed: widget.onClose,
                            )
                        ],
                      ),
                    ),
                  ),
                  if (!_isCollapsed)
                    Expanded(
                      child: GestureDetector(
                         behavior: HitTestBehavior.translucent,
                         onTapDown: (_) => widget.onFocus?.call(),
                         child: const CliTerminalPanel()
                      )
                    ),
                ],
              ),
            ),
          ),
          if (!_isCollapsed) ...[
            rz(r: -5, b: -5, dw: 15, dh: 15, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){ double nW = _width + d.delta.dx; double nH = _height + d.delta.dy; if(nW > 300) _width = nW; if(nH > 200) _height = nH; })),
            rz(l: -5, b: -5, dw: 15, dh: 15, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){ double nW = _width - d.delta.dx; double nH = _height + d.delta.dy; if(nW > 300) { _width = nW; _position += Offset(d.delta.dx, 0); } if(nH > 200) _height = nH; })),
            rz(r: -5, t: -5, dw: 15, dh: 15, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){ double nW = _width + d.delta.dx; double nH = _height - d.delta.dy; if(nW > 300) _width = nW; if(nH > 200) { _height = nH; _position += Offset(0, d.delta.dy); } })),
            rz(l: -5, t: -5, dw: 15, dh: 15, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){ double nW = _width - d.delta.dx; double nH = _height - d.delta.dy; if(nW > 300) { _width = nW; _position += Offset(d.delta.dx, 0); } if(nH > 200) { _height = nH; _position += Offset(0, d.delta.dy); } })),
            rz(r: -5, t: 10, b: 10, dw: 10, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){ double nW = _width + d.delta.dx; if(nW > 300) _width = nW; })),
            rz(l: -5, t: 10, b: 10, dw: 10, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){ double nW = _width - d.delta.dx; if(nW > 300) { _width = nW; _position += Offset(d.delta.dx, 0); } })),
            rz(b: -5, l: 10, r: 10, dh: 10, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){ double nH = _height + d.delta.dy; if(nH > 200) _height = nH; })),
            rz(t: -5, l: 10, r: 10, dh: 10, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){ double nH = _height - d.delta.dy; if(nH > 200) { _height = nH; _position += Offset(0, d.delta.dy); } }))
          ]
        ],
      )
    );
  }
}

class CliTerminalPanel extends StatefulWidget {
  const CliTerminalPanel({super.key});
  @override
  State<CliTerminalPanel> createState() => _CliTerminalPanelState();
}

class _CliTerminalPanelState extends State<CliTerminalPanel> {
  final TextEditingController cliCtrl = TextEditingController();
  final ScrollController scrollCtrl = ScrollController();
  List<String> outputLogs = [];
  bool isProcessing = false;

  void _executeCommand() async {
    if (cliCtrl.text.trim().isEmpty) return;
    setState(() {
      isProcessing = true;
      outputLogs.add('> EXEC \${DateTime.now().toIso8601String()}');
    });
    final logs = await AiCommandParser.executeBatch(cliCtrl.text, context);
    if (mounted) {
      setState(() {
        outputLogs.addAll(logs);
        outputLogs.add('> BATCH COMPLETED');
        isProcessing = false;
      });
      Future.delayed(const Duration(milliseconds: 100), () => scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (outputLogs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.greenAccent, size: 20),
                  tooltip: 'Copy Output Logs',
                  padding: const EdgeInsets.only(right: 8),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: outputLogs.join('\n')));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terminal output copied to clipboard!')));
                  }
                ),
                const Spacer(),
                TextButton.icon(
                  icon: Icon(Icons.delete_sweep, color: AppColors.panelTextSecondary, size: 18),
                  label: Text('Clear', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
                  onPressed: () => setState(() => outputLogs.clear())
                )
            ],
          ),
          Divider(color: AppColors.borderSubtle, height: 16),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(12),
              clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'cli_terminal' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) : null,color: Colors.black, borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius)),
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: outputLogs.length,
                itemBuilder: (_, i) => Text(outputLogs[i], style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: AppUIConfig.rootFontSize)),
              )
            ),
          ),
          const SizedBox(height: 16),
          Text('COMMAND PAYLOAD:', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: cliCtrl,
              maxLines: null,
              expands: true,
              style: TextStyle(color: AppColors.panelTextPrimary, fontFamily: 'monospace', fontSize: AppUIConfig.rootFontSize),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF2D2D30),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius), borderSide: BorderSide.none),
                hintText: 'tag create "Inspirational" --folder "Mood" --color "#FFAA55"\\nfolder create "Genres"\\nasset bind "TheBionicMan.mp3" "tag.genres.pop"',
                hintStyle: TextStyle(color: AppColors.borderSubtle)
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
              onPressed: isProcessing ? null : _executeCommand,
              icon: isProcessing ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.panelTextPrimary)) : Icon(Icons.play_arrow, color: AppColors.panelTextPrimary),
              label: Text(isProcessing ? 'Processing Batch...' : 'Execute Payload', style: TextStyle(color: AppColors.panelTextPrimary, fontWeight: FontWeight.bold)),
            )
          )
        ],
      )
    );
  }
}



