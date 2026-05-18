import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:highlight/languages/powershell.dart';
import '../../../services/macro_service.dart';
import '../../../services/system_logs_service.dart';
import '../visual_editor_screen.dart';
import 'macro_guide_window.dart';
import '../../../constants.dart';

final ValueNotifier<bool> showMacroNotifier = ValueNotifier(false);

void showMacroWindow(BuildContext context) {
  if (showMacroNotifier.value) return;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showMacro'), true));
  showMacroNotifier.value = true;
}

void hideMacroWindow() {
  showMacroNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showMacro'), false));
}

class MacroManagerPanel extends StatefulWidget {
  final bool isDocked;
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  const MacroManagerPanel({super.key, required this.onClose, this.onFocus, this.isDocked = false});

  @override
  State<MacroManagerPanel> createState() => _MacroManagerPanelState();
}
class _MacroManagerPanelState extends State<MacroManagerPanel> {
  bool _isLoaded = false;

  final TextEditingController _nameController = TextEditingController();
  double _width = 600;
  double _height = 500;
  double _bgOpacity = 0.4;
  Offset _offset = const Offset(200, 200);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    VisualEditorScreen.currentWorkspace.addListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.addListener(_loadPreferences);
  }

  @override
  void dispose() {
    VisualEditorScreen.currentWorkspace.removeListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.removeListener(_loadPreferences);
    _nameController.dispose();
    super.dispose();
  }
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isLoaded = true;

        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('macro_width')) ?? 600;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('macro_height')) ?? 500;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.4;
        double dx = prefs.getDouble(VisualEditorScreen.getPrefKey('macro_dx')) ?? 200;
        double dy = prefs.getDouble(VisualEditorScreen.getPrefKey('macro_dy')) ?? 200;
        _offset = Offset(dx, dy);
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('macro_width'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('macro_height'), _height);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('macro_dx'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('macro_dy'), _offset.dy);
  }

  void _fetchSmartSnippet(BuildContext context, String captureMode) async {
    if (['SendText', 'Send', 'WaitMs', 'LeftClick', 'RightClick', 'LeftDoubleClick', 'MiddleClick', 'ReturnToApp', 'Log', 'SaveWindowPosSize', 'RestoreWindowPosSize', 'PixelMoreThan', 'WinMove', 'BlockInput', 'AppendClipboard', 'SetClipboard', 'NextClipboard'].contains(captureMode)) {
       String snip = captureMode;
       if (captureMode == 'SendText') snip = 'SendText("Sample")';
       if (captureMode == 'Send') snip = 'Send("^v")';
       if (captureMode == 'WaitMs') snip = 'WaitMs(500)';
       if (captureMode == 'Log') snip = 'Log("Custom message here")';
       if (captureMode == 'SaveWindowPosSize') snip = 'SaveWindowPosSize()';
       if (captureMode == 'RestoreWindowPosSize') snip = 'RestoreWindowPosSize()';
       if (captureMode == 'PixelMoreThan') snip = 'PixelMoreThan("#080808", 10)';
       if (captureMode == 'WinMove') snip = 'WinMove(0, 0, 800, 600)';
       if (captureMode == 'BlockInput') snip = 'BlockInput(true)';
       if (captureMode == 'AppendClipboard') snip = 'AppendClipboard("String")';
       if (captureMode == 'SetClipboard') snip = 'SetClipboard()';
       if (captureMode == 'NextClipboard') snip = 'NextClipboard()';
       
       Clipboard.setData(ClipboardData(text: '$snip\nWaitMs(200)'));
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           content: Text('$captureMode helper snippet copied!', style: const TextStyle(color: Colors.green)),
       ));
       return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Switch to target app and point mouse. Capturing in 5 seconds...', style: TextStyle(color: AppColors.folder)),
      duration: Duration(seconds: 4),
    ));
    await Future.delayed(const Duration(seconds: 5));

    const script = r'''
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT lpPoint);
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }
    
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern IntPtr GetDC(IntPtr hwnd);
    [DllImport("user32.dll")]
    public static extern int ReleaseDC(IntPtr hwnd, IntPtr hdc);
    [DllImport("gdi32.dll")]
    public static extern uint GetPixel(IntPtr hdc, int nXPos, int nYPos);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

$point = New-Object Win32+POINT
[Win32]::GetCursorPos([ref]$point) | Out-Null

$hdc = [Win32]::GetDC([IntPtr]::Zero)
$pixel = [Win32]::GetPixel($hdc, $point.X, $point.Y)
[Win32]::ReleaseDC([IntPtr]::Zero, $hdc) | Out-Null
$r =  $pixel -band 0xFF
$g = ($pixel -shr 8) -band 0xFF
$b = ($pixel -shr 16) -band 0xFF
$hex = "#{0:X2}{1:X2}{2:X2}" -f $r, $g, $b

$hwnd = [Win32]::GetForegroundWindow()
$rect = New-Object Win32+RECT
[Win32]::GetWindowRect($hwnd, [ref]$rect) | Out-Null

$hwnd = [Win32]::GetForegroundWindow()
$sb = New-Object System.Text.StringBuilder 256
[Win32]::GetWindowText($hwnd, $sb, $sb.Capacity) | Out-Null
$title = $sb.ToString()

Write-Output "$($point.X),$($point.Y),$($rect.Left),$($rect.Top),$($rect.Right),$($rect.Bottom),$hex|$title"
''';

    final tempFile = File('.ai_bridge/capture.ps1');
    tempFile.writeAsStringSync(script);
    final result = await Process.run('powershell', ['-ExecutionPolicy', 'Bypass', '-File', '.ai_bridge/capture.ps1']);
    final out = result.stdout.toString().trim();
    if (out.isNotEmpty && out.contains('|')) {
      final parts = out.split('|');
      if (parts.length == 2) {
        final coords = parts[0].split(',');
        final title = parts[1];
        if (coords.length >= 6 && mounted) {
           final x = int.tryParse(coords[0]) ?? 0;
           final y = int.tryParse(coords[1]) ?? 0;
           final sLeft = int.tryParse(coords[2]) ?? 0;
           final sTop = int.tryParse(coords[3]) ?? 0;
           final sRight = int.tryParse(coords[4]) ?? 0;
           final sBottom = int.tryParse(coords[5]) ?? 0;
           final hex = coords.length == 7 ? coords[6] : '#FFFFFF';
           
           String snippet = '';
           if (captureMode == 'ClickAt') {
               snippet = 'SwitchWindow("$title")\nMoveMouse($x, $y)\nLeftClick()\nWaitMs(100)\nReturnToApp()';
           } else if (captureMode == 'TopLeft') {
               snippet = 'SwitchWindow("$title")\nRelativeMouseMove("TopLeft", ${(x - sLeft).abs()}, ${(y - sTop).abs()})\nLeftClick()\nWaitMs(100)\nReturnToApp()';
           } else if (captureMode == 'TopRight') {
               snippet = 'SwitchWindow("$title")\nRelativeMouseMove("TopRight", ${(sRight - x).abs()}, ${(y - sTop).abs()})\nLeftClick()\nWaitMs(100)\nReturnToApp()';
           } else if (captureMode == 'BottomLeft') {
               snippet = 'SwitchWindow("$title")\nRelativeMouseMove("BottomLeft", ${(x - sLeft).abs()}, ${(sBottom - y).abs()})\nLeftClick()\nWaitMs(100)\nReturnToApp()';
           } else if (captureMode == 'BottomRight') {
               snippet = 'SwitchWindow("$title")\nRelativeMouseMove("BottomRight", ${(sRight - x).abs()}, ${(sBottom - y).abs()})\nLeftClick()\nWaitMs(100)\nReturnToApp()';
           } else if (captureMode == 'WindowName') {
               snippet = 'SwitchWindow("$title")\nWaitMs(100)';
           } else if (captureMode == 'PixelIs') {
               snippet = 'PixelIs("$hex")';
           } else if (captureMode == 'PixelMoreThan') {
               snippet = 'PixelMoreThan("$hex", 10)';
           } else if (captureMode == 'SendText') {
               snippet = 'SendText("Target text here")';
           } else if (captureMode == 'Send') {
               snippet = 'Send("{ENTER}")';
           } else if (captureMode == 'WaitMs') {
               snippet = 'WaitMs(500)';
           } else if (captureMode == 'LeftClick') {
               snippet = 'LeftClick()';
           } else if (captureMode == 'RightClick') {
               snippet = 'RightClick()';
           } else if (captureMode == 'LeftDoubleClick') {
               snippet = 'LeftDoubleClick()';
           } else if (captureMode == 'MiddleClick') {
               snippet = 'MiddleClick()';
           } else if (captureMode == 'ReturnToApp') {
               snippet = 'ReturnToApp()';
           } else if (captureMode == 'Log') {
               snippet = 'Log("Action completed!")';
           }
           
           Clipboard.setData(ClipboardData(text: snippet));
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
               content: Text('Dynamic Helper Snippet successfully mapped to clipboard!', style: TextStyle(color: Colors.green)),
           ));
        }
      }
    }
  }



  void _showHotkeyDialog(Macro macro) {
    final ctrl = TextEditingController(text: macro.hotkey);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.panelBackground,
      title: Text('Set Global Hotkey', style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text('Format follows AutoHotkey (e.g., ^!p for Ctrl+Alt+P).', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
           const SizedBox(height: 16),
           TextField(
             controller: ctrl,
             style: TextStyle(color: AppColors.panelTextPrimary),
             decoration: InputDecoration(
               labelText: 'Hotkey Binding',
               labelStyle: TextStyle(color: AppColors.panelTextSecondary),
               border: OutlineInputBorder(),
             ),
           ),
        ]
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
        TextButton(onPressed: () {
          macro.hotkey = ctrl.text.trim();
          MacroService.instance.updateMacro(macro);
          Navigator.pop(ctx);
        }, child: Text('Save')),
      ]
    ));
  }

  void _editFolderName(Macro macro) {
    final ctrl = TextEditingController(text: macro.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panelBackground,
        title: Text('Edit Folder Name', style: TextStyle(color: AppColors.panelTextPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppColors.panelTextPrimary),
          decoration: InputDecoration(
             filled: true,
             fillColor: AppColors.overlaySubtle,
             border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            if (ctrl.text.trim().isNotEmpty) {
              macro.name = ctrl.text.trim();
              MacroService.instance.updateMacro(macro);
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                macro.name = ctrl.text.trim();
                MacroService.instance.updateMacro(macro);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ]
      )
    );
  }

  void _editMacro(Macro macro) {
    String selectedMode = 'ClickAt';
    
    MacroService.instance.setEditing(macro.id, true);

    showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = CodeController(
          text: macro.script.replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
          language: powershell,
          params: const EditorParams(tabSpaces: 4),
          modifiers: const [],
        );
        ctrl.autocompleter.setCustomWords([
          'ClickAt', 'TopLeft', 'TopRight', 'BottomLeft', 'BottomRight', 
          'PixelIs', 'PixelIsNot', 'PixelMoreThan', 'WindowName', 'SendText', 'Send', 
          'WaitMs', 'LeftClick', 'RightClick', 'LeftDoubleClick', 
          'MiddleClick', 'ReturnToApp', 'Log', 'SaveWindowPosSize', 
          'RestoreWindowPosSize', 'MoveMouse', 'RelativeMouseMove', 
          'SwitchWindow', 'Run', 'if', 'else', 'WinMove', 'BlockInput',
          'AppendClipboard', 'SetClipboard', 'NextClipboard'
        ]);
        
        final List<TextEditingValue> history = [ctrl.value];
        int historyIndex = 0;
        bool isUndoing = false;
        int lastEditTime = 0;

        ctrl.addListener(() {
          if (isUndoing) return;
          if (historyIndex >= 0 && historyIndex < history.length) {
            final currentState = ctrl.value;
            final lastState = history[historyIndex];
            if (lastState.text != currentState.text) {
               int now = DateTime.now().millisecondsSinceEpoch;
               if (historyIndex < history.length - 1) {
                  history.removeRange(historyIndex + 1, history.length);
               }
               int lenDiff = (currentState.text.length - lastState.text.length).abs();
               if (now - lastEditTime < 1000 && lenDiff <= 1 && historyIndex > 0) {
                  history[historyIndex] = currentState;
               } else {
                  history.add(currentState);
                  if (history.length > 300) history.removeAt(0);
                  historyIndex = history.length - 1;
               }
               lastEditTime = now;
            } else if (lastState.selection != currentState.selection) {
               history[historyIndex] = currentState;
            }
          }
        });

        void performUndo() {
          if (historyIndex > 0) {
            isUndoing = true;
            historyIndex--;
            ctrl.value = history[historyIndex];
            isUndoing = false;
          }
        }

        void performRedo() {
          if (historyIndex < history.length - 1) {
            isUndoing = true;
            historyIndex++;
            ctrl.value = history[historyIndex];
            isUndoing = false;
          }
        }

        final focusNode = FocusNode(
          onKeyEvent: (node, event) {
            if (HardwareKeyboard.instance.isControlPressed) {
               if (event.logicalKey == LogicalKeyboardKey.keyZ) {
                   if (event is KeyDownEvent || event is KeyRepeatEvent) {
                       if (HardwareKeyboard.instance.isShiftPressed) {
                          performRedo();
                       } else {
                          performUndo();
                       }
                   }
                   return KeyEventResult.handled;
               }
               if (event.logicalKey == LogicalKeyboardKey.keyY) {
                   if (event is KeyDownEvent || event is KeyRepeatEvent) {
                       performRedo();
                   }
                   return KeyEventResult.handled;
               }
            }
            return KeyEventResult.ignored;
          }
        );

        final descCtrl = TextEditingController(text: macro.description);
        final nameCtrl = TextEditingController(text: macro.name);
        final scrollCtrl = ScrollController();
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            return AlertDialog(
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              backgroundColor: AppColors.windowBackground,
              title: Row(
                children: [
                  Text('Edit Macro', style: TextStyle(color: AppColors.panelTextPrimary)),
                  const Spacer(),
                  DropdownButton<String>(
                    value: selectedMode,
                    dropdownColor: AppColors.panelBackground,
                    style: TextStyle(color: AppColors.panelTextPrimary),
                    underline: const SizedBox(),
                    items: ['ClickAt', 'TopLeft', 'TopRight', 'BottomLeft', 'BottomRight', 'PixelIs', 'PixelMoreThan', 'WindowName', 'SendText', 'Send', 'WaitMs', 'LeftClick', 'RightClick', 'LeftDoubleClick', 'MiddleClick', 'ReturnToApp', 'Log', 'SaveWindowPosSize', 'RestoreWindowPosSize', 'WinMove', 'BlockInput', 'AppendClipboard', 'SetClipboard', 'NextClipboard']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e == 'ClickAt' ? 'Absolute' : (e.startsWith('Top') || e.startsWith('Bottom') ? 'Rel: $e' : e))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateBuilder(() => selectedMode = val);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _fetchSmartSnippet(context, selectedMode),
                    icon: Icon(AppToolWindows.getDef('macro').icon, size: 16, color: AppToolWindows.getDef('macro').color),
                      label: Text('Capture Snippet', style: TextStyle(color: AppColors.panelTextPrimary)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.overlaySubtle),
                  ),
                ],
              ),
              content: SizedBox(
                width: 700,
                height: 600,
                child: Column(
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Macro Name...',
                        hintStyle: TextStyle(color: AppColors.panelTextSecondary),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (val) {
                         macro.name = val;
                         MacroService.instance.updateMacro(macro);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize),
                      decoration: InputDecoration(
                        hintText: 'Macro Description (optional)...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (val) {
                         macro.description = val;
                         MacroService.instance.updateMacro(macro);
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(border: Border.all(color: AppColors.borderSubtle)),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Scrollbar(
                                controller: scrollCtrl,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: scrollCtrl,
                                  child: TextField(
                                    controller: ctrl,
                                    focusNode: focusNode,
                                    maxLines: null,
                                    keyboardType: TextInputType.multiline,
                                    style: TextStyle(fontFamily: 'monospace', fontSize: AppUIConfig.rootFontSize, color: AppColors.panelTextPrimary),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.all(8),
                                    ),
                                    onChanged: (val) {
                                       macro.script = val.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
                                       MacroService.instance.updateMacro(macro);
                                    },
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 24,
                              child: IconButton(
                                icon: Icon(Icons.help_outline, size: 20, color: AppColors.folder),
                                tooltip: 'Coding Guide',
                                onPressed: () => showMacroGuideWindow(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                     MacroService.instance.playMacro(macro.id);
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       Icon(Icons.play_arrow, color: Colors.green, size: 16),
                       SizedBox(width: 4),
                       Text('Test Macro', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ]
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Close', style: TextStyle(color: AppColors.panelTextSecondary)),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      MacroService.instance.setEditing(macro.id, false);
    });
  }

  Widget _buildMacroContent() { return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
Expanded(
  child: ListenableBuilder(
                          listenable: MacroService.instance,
                          builder: (context, _) {
                            final macros = MacroService.instance.displayMacros;
                            return Container(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        style: TextStyle(color: AppColors.panelTextPrimary),
                        decoration: InputDecoration(
                          hintText: 'New Macro Name...',
                          hintStyle: TextStyle(color: AppColors.panelTextSecondary),
                          fillColor: AppColors.panelBackground,
                          filled: true,
                          border: OutlineInputBorder(borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_nameController.text.trim().isNotEmpty) {
                          MacroService.instance.addMacro(Macro(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            name: _nameController.text.trim(),
                            script: '',
                          ));
                          _nameController.clear();
                        }
                      },
                      icon: const Icon(Icons.add, color: Colors.green),
                        label: Text('Add Macro', style: TextStyle(color: AppColors.panelTextPrimary)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.overlaySubtle),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_nameController.text.trim().isNotEmpty) {
                          MacroService.instance.addFolder(_nameController.text.trim());
                          _nameController.clear();
                        }
                      },
                      icon: Icon(Icons.folder_open, color: AppColors.folder),
                        label: Text('Add Folder', style: TextStyle(color: AppColors.panelTextPrimary)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.overlaySubtle),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Divider(color: AppColors.borderSubtle),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SAVED MACROS', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Text('Trace Execution', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
                      Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          value: MacroService.instance.debugMode,
                          onChanged: MacroService.instance.toggleDebugMode,
                          activeThumbColor: AppColors.folder,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: macros.isEmpty
                    ? Center(child: Text('No macros recorded yet.', style: TextStyle(color: AppColors.panelTextSecondary)))
                    : ListView.builder(
                        itemCount: macros.length + 1,
                        itemBuilder: (context, index) {
                          if (index == macros.length) {
                            return DragTarget<String>(
                              onAcceptWithDetails: (d) => MacroService.instance.moveMacro(d.data, ''),
                              builder: (ctx, cand, _) => Container(
                                height: 60,
                                color: cand.isNotEmpty ? AppColors.folder.withOpacity(0.1) : Colors.transparent,
                              )
                            );
                          }
                          final macro = macros[index];
                          int depth = 0;
                          String pId = macro.parentId;
                          while (pId.isNotEmpty) {
                            depth++;
                            final p = MacroService.instance.macros.where((m) => m.id == pId).firstOrNull;
                            if (p == null) break;
                            pId = p.parentId;
                          }

                          Widget finalContent;
                          if (macro.isFolder) {
                            finalContent = DragTarget<String>(
                              onWillAcceptWithDetails: (d) => d.data != macro.id,
                              onAcceptWithDetails: (d) => MacroService.instance.moveMacro(d.data, macro.id),
                              builder: (ctx, cand, _) => Container(
                                color: cand.isNotEmpty ? AppColors.folder.withOpacity(0.2) : AppColors.panelBackground,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Row(
                                  children: [
                                    MouseRegion(
                                      cursor: SystemMouseCursors.grab,
                                      child: Icon(Icons.drag_handle, color: AppColors.borderSubtle, size: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => MacroService.instance.toggleFolder(macro.id),
                                        behavior: HitTestBehavior.opaque,
                                        child: Row(
                                          children: [
                                            Icon(
                                              macro.isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                                              color: AppColors.folder,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              macro.isExpanded ? Icons.folder_open : Icons.folder,
                                              color: AppColors.folder,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(macro.name, style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.edit, color: AppColors.accent, size: 14),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      splashRadius: 16,
                                      onPressed: () => _editFolderName(macro),
                                      tooltip: 'Edit Folder Name',
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(Icons.delete, color: AppColors.error, size: 14),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      splashRadius: 16,
                                      onPressed: () => MacroService.instance.deleteMacro(macro.id),
                                      tooltip: 'Delete Folder',
                                    ),
                                    const SizedBox(width: 24),
                                  ],
                                ),
                              ),
                            );
                          } else {
                            finalContent = Container(
                              color: Colors.transparent,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    MouseRegion(
                                      cursor: SystemMouseCursors.grab,
                                      child: Icon(Icons.drag_handle, color: AppColors.borderSubtle, size: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(macro.name, style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          Text(macro.description.isNotEmpty ? macro.description : "${macro.script.split('\n').length} Lines", style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.smallFontSize), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    if (macro.hotkey.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Text('[${macro.hotkey}]', style: TextStyle(color: AppColors.note, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold)),
                                      ),
                                    IconButton(
                                      icon: Icon(Icons.keyboard, color: AppColors.note, size: 14),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      splashRadius: 16,
                                      onPressed: () {
                                        if (macro.executionTiming != 'System') {
                                          SystemLogsService.instance.addLog('Error: Global hotkeys can only be assigned to System macros.', category: LogCategory.SYSTEM);
                                        } else {
                                          _showHotkeyDialog(macro);
                                        }
                                      },
                                      tooltip: 'Set Global Hotkey',
                                    ),
                                    const SizedBox(width: 8),
                                    DropdownButton<String>(
                                      value: macro.executionTiming,
                                      isDense: true,
                                      dropdownColor: AppColors.panelBackground,
                                      style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize),
                                      underline: const SizedBox(),
                                      items: ['Manual', 'System', 'BeforeReload', 'AfterReload', 'BridgeConnect']
                                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          macro.executionTiming = val;
                                          MacroService.instance.updateMacro(macro);
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.play_arrow, color: Colors.green, size: 14),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      splashRadius: 16,
                                      onPressed: () => MacroService.instance.playMacro(macro.id),
                                      tooltip: 'Run Macro',
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(Icons.edit, color: AppColors.accent, size: 14),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      splashRadius: 16,
                                      onPressed: () => _editMacro(macro),
                                      tooltip: 'Edit Macro',
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(Icons.copy, color: AppColors.panelTextSecondary, size: 14),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      splashRadius: 16,
                                      onPressed: () => MacroService.instance.duplicateMacro(macro.id),
                                      tooltip: 'Duplicate Macro',
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(Icons.delete, color: AppColors.error, size: 14),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      splashRadius: 16,
                                      onPressed: () => MacroService.instance.deleteMacro(macro.id),
                                      tooltip: 'Delete Macro',
                                    ),
                                    const SizedBox(width: 24),
                                  ],
                                ),
                              ),
                            );
                          }

                          return Row(
                            key: ValueKey(macro.id),
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Builder(builder: (ctx) {
                                bool effectivelyEnabled = MacroService.instance.isMacroEffectivelyEnabled(macro.id);
                                Color iconColor = macro.isEnabled 
                                    ? (effectivelyEnabled ? AppColors.accent : AppColors.accent.withOpacity(0.3)) 
                                    : AppColors.panelTextSecondary;
                                return IconButton(
                                  icon: Icon(macro.isEnabled ? Icons.visibility : Icons.visibility_off, color: iconColor, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  splashRadius: 16,
                                  onPressed: () {
                                    macro.isEnabled = !macro.isEnabled;
                                    MacroService.instance.updateMacro(macro);
                                  },
                                  tooltip: macro.isEnabled 
                                      ? (effectivelyEnabled ? 'Macro Enabled' : 'Macro Enabled (Disabled by Parent)') 
                                      : 'Macro Disabled',
                                );
                              }),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(left: depth * 16.0),
                                  child: LongPressDraggable<String>(
                                    delay: const Duration(milliseconds: 250),
                                    data: macro.id,
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: Opacity(
                                        opacity: 0.8,
                                        child: SizedBox(width: 450, child: finalContent),
                                      ),
                                    ),
                                    childWhenDragging: Opacity(opacity: 0.3, child: finalContent),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        DragTarget<String>(
                                          onWillAcceptWithDetails: (d) => d.data != macro.id,
                                          onAcceptWithDetails: (d) => MacroService.instance.reorderBefore(d.data, macro.id),
                                          builder: (ctx, cand, _) => Container(
                                            height: 6,
                                            color: cand.isNotEmpty ? AppColors.accent : Colors.transparent,
                                          ),
                                        ),
                                        finalContent,
                                        DragTarget<String>(
                                          onWillAcceptWithDetails: (d) => d.data != macro.id,
                                          onAcceptWithDetails: (d) => MacroService.instance.reorderAfter(d.data, macro.id),
                                          builder: (ctx, cand, _) => Container(
                                            height: 6,
                                            color: cand.isNotEmpty ? AppColors.accent : Colors.transparent,
                                          ),
                                        ),
                                      ],
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
              );
            },
          )
)
]); }
  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    if (widget.isDocked) return Material(color: Colors.transparent, child: _buildMacroContent());
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
          return Transform.scale(scale: 1.0, alignment: Alignment.topLeft,
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
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: AppColors.controlBorder, width: AppUIConfig.windowBorderWidth) : null,
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
                              borderRadius: BorderRadius.vertical(top: Radius.circular(AppUIConfig.windowBorderRadius))),
                          child: Row(
                            children: [
                              Icon(Icons.smart_button, size: 16, color: AppColors.accent),
                              const SizedBox(width: 8),
                              Text(AppUIConfig.formatWindowTitle(AppToolWindows.getDef('macro').name), style: TextStyle(color: AppColors.titleBarTextPrimary, fontSize: AppUIConfig.windowTitleFontSize, fontWeight: AppUIConfig.windowTitleFontWeight)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.help_outline, size: 16, color: AppColors.folder),
                                tooltip: 'Coding Guide',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => showMacroGuideWindow(context),
                              ),
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
                      Expanded(
                        child: _buildMacroContent()
                      )
                    ])
                  ),
                ),
              ), // end Listener & Material
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
              ], // end Stack children
            ), // end Stack
          );
        },
      ),
    );
  }
}

