import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'system_logs_service.dart';
import '../screens/visual_editor/visual_editor_screen.dart';

enum MacroCommandType { keyPress, mouseClick, windowSwitch, delay }

class MacroCommand {
  final MacroCommandType type;
  final String? key;
  final int? x;
  final int? y;
  final String? windowName;
  final int? delayMs;
  final bool relativeToBottomRight;

  MacroCommand({
    required this.type,
    this.key,
    this.x,
    this.y,
    this.windowName,
    this.delayMs,
    this.relativeToBottomRight = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (key != null) 'key': key,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (windowName != null) 'windowName': windowName,
      if (delayMs != null) 'delayMs': delayMs,
      if (relativeToBottomRight) 'relativeToBottomRight': relativeToBottomRight,
    };
  }

  factory MacroCommand.fromJson(Map<String, dynamic> json) {
    return MacroCommand(
      type: MacroCommandType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MacroCommandType.delay,
      ),
      key: json['key'],
      x: json['x'],
      y: json['y'],
      windowName: json['windowName'],
      delayMs: json['delayMs'],
      relativeToBottomRight: json['relativeToBottomRight'] ?? false,
    );
  }
}

class Macro {
  String id;
  String name;
  String script;
  String description;
  String executionTiming;
  String parentId;
  bool isFolder;
  bool isExpanded;
  String hotkey;
  bool isEnabled;

  Macro({
    required this.id,
    required this.name,
    this.script = '',
    this.description = '',
    this.executionTiming = 'Manual',
    this.parentId = '',
    this.isFolder = false,
    this.isExpanded = true,
    this.hotkey = '',
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'script': script,
      'description': description,
      'executionTiming': executionTiming,
      'parentId': parentId,
      'isFolder': isFolder,
      'isExpanded': isExpanded,
      'hotkey': hotkey,
      'isEnabled': isEnabled,
    };
  }

  factory Macro.fromJson(Map<String, dynamic> json) {
    return Macro(
      id: json['id'],
      name: json['name'],
      script: json['script'] ?? '',
      description: json['description'] ?? '',
      executionTiming: json['executionTiming'] ?? 'Manual',
      parentId: json['parentId'] ?? '',
      isFolder: json['isFolder'] ?? false,
      isExpanded: json['isExpanded'] ?? true,
      hotkey: json['hotkey'] ?? '',
      isEnabled: json['isEnabled'] ?? true,
    );
  }
}

class MacroService extends ChangeNotifier {
  static final MacroService instance = MacroService._internal();

  MacroService._internal() {
    _loadMacros();
    _startSystemLoop();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    debugMode = prefs.getBool('macro_debug_mode') ?? false;
    notifyListeners();
  }

  final String _filePath = '.ai_bridge/macros.json';
  List<Macro> _macros = [];
  List<Macro> get macros => _macros;
  
  Timer? _systemTimer;
  final Set<String> _runningSystemMacros = {};
  final Map<String, Process> _runningSystemProcesses = {};
  final Set<String> _editingMacros = {};

  void setEditing(String id, bool editing) {
    if (editing) {
      _editingMacros.add(id);
      killMacroProcess(id); // Pause execution
    } else {
      _editingMacros.remove(id);
    }
  }

  bool isMacroEffectivelyEnabled(String id) {
    String currentId = id;
    while (currentId.isNotEmpty) {
      final idx = _macros.indexWhere((e) => e.id == currentId);
      if (idx == -1) break;
      final m = _macros[idx];
      if (!m.isEnabled) return false;
      currentId = m.parentId;
    }
    return true;
  }

  void _startSystemLoop() {
    _systemTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final shouldBeRunning = _macros
          .where((e) => e.executionTiming == 'System' && isMacroEffectivelyEnabled(e.id) && !_editingMacros.contains(e.id) && e.hotkey.trim().isNotEmpty)
          .map((e) => e.id)
          .toSet();

      final toKill = _runningSystemMacros.where((id) => !shouldBeRunning.contains(id)).toList();
      for (var id in toKill) {
        killMacroProcess(id);
      }

      for (var m in _macros.where((e) => shouldBeRunning.contains(e.id))) {
        if (!_runningSystemMacros.contains(m.id)) {
          _runningSystemMacros.add(m.id);
          playMacro(m.id, wait: true).whenComplete(() {
            _runningSystemMacros.remove(m.id);
          });
        }
      }
    });
  }
  
  bool debugMode = false;
  void toggleDebugMode(bool val) async {
    debugMode = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('macro_debug_mode', val);
  }

  void _loadMacros() {
    final file = File(_filePath);
    if (file.existsSync()) {
      try {
        final content = file.readAsStringSync();
        final List dynamicList = jsonDecode(content);
        _macros = dynamicList.map((e) => Macro.fromJson(e)).toList();
        notifyListeners();
      } catch (e) {
        debugPrint('Failed to load macros: \$e');
      }
    }
  }

  void _saveMacros() {
    final file = File(_filePath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    file.writeAsStringSync(jsonEncode(_macros.map((e) => e.toJson()).toList()));
  }

  void addMacro(Macro macro) {
    _macros.add(macro);
    _saveMacros();
    notifyListeners();
  }

  void duplicateMacro(String id) {
    int idx = _macros.indexWhere((element) => element.id == id);
    if (idx != -1) {
      final source = _macros[idx];
      List<Macro> newItems = [];
      
      void duplicateRecursive(Macro m, String newParentId, String suffix) {
        String childNewId = '${DateTime.now().microsecondsSinceEpoch}_${newItems.length}';
        final copy = Macro(
          id: childNewId,
          name: m.name + suffix,
          description: m.description,
          script: m.script,
          executionTiming: m.executionTiming,
          parentId: newParentId,
          isFolder: m.isFolder,
          isExpanded: m.isExpanded,
          hotkey: m.hotkey, // Keep hotkey to prevent endless polling loops
          isEnabled: false, // Default to disabled to prevent duplicate overlap execution

        );
        newItems.add(copy);
        
        if (m.isFolder) {
          final children = _macros.where((c) => c.parentId == m.id).toList();
          for (var child in children) {
            duplicateRecursive(child, childNewId, '');
          }
        }
      }
      
      duplicateRecursive(source, source.parentId, ' (Copy)');
      
      int lastDescendantIdx = idx;
      void findLastDescendant(String parentId) {
        for (int i = 0; i < _macros.length; i++) {
          if (_macros[i].parentId == parentId) {
            if (i > lastDescendantIdx) lastDescendantIdx = i;
            if (_macros[i].isFolder) {
              findLastDescendant(_macros[i].id);
            }
          }
        }
      }
      findLastDescendant(source.id);
      
      _macros.insertAll(lastDescendantIdx + 1, newItems);
      _saveMacros();
      notifyListeners();
    }
  }

  void addFolder(String name) {
    _macros.add(Macro(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      isFolder: true,
      isExpanded: true,
    ));
    _saveMacros();
    notifyListeners();
  }

  void toggleFolder(String id) {
    final macro = _macros.firstWhere((m) => m.id == id);
    if (macro.isFolder) {
      macro.isExpanded = !macro.isExpanded;
      _saveMacros();
      notifyListeners();
    }
  }

  void killMacroProcess(String id) {
    if (_runningSystemProcesses.containsKey(id)) {
      _runningSystemProcesses[id]?.kill();
      _runningSystemProcesses.remove(id);
      _runningSystemMacros.remove(id);
    }
  }

  void deleteMacro(String id) {
    killMacroProcess(id);
    _macros.removeWhere((element) => element.id == id);
    _saveMacros();
    notifyListeners();
  }

  void updateMacro(Macro macro) {
    killMacroProcess(macro.id);
    int idx = _macros.indexWhere((element) => element.id == macro.id);
    if (idx != -1) {
      _macros[idx] = macro;
      _saveMacros();
      notifyListeners();
    }
  }

  List<Macro> get displayMacros {
    final result = <Macro>[];
    void traverse(String parentId) {
      for (var m in _macros.where((x) => x.parentId == parentId)) {
        result.add(m);
        if (m.isFolder && m.isExpanded) {
          traverse(m.id);
        }
      }
    }
    traverse('');
    return result;
  }

  bool _isDescendant(String childId, String ancestorId) {
    String currentId = childId;
    while (currentId.isNotEmpty) {
      if (currentId == ancestorId) return true;
      final parent = _macros.where((m) => m.id == currentId).firstOrNull;
      if (parent == null) break;
      currentId = parent.parentId;
    }
    return false;
  }

  void moveMacro(String macroId, String targetParentId) {
    if (macroId == targetParentId || _isDescendant(targetParentId, macroId)) return;
    final idx = _macros.indexWhere((m) => m.id == macroId);
    if (idx == -1) return;
    final item = _macros.removeAt(idx);
    item.parentId = targetParentId;
    _macros.add(item);
    _saveMacros();
    notifyListeners();
  }

  void reorderBefore(String draggedId, String targetId) {
    final dIdx = _macros.indexWhere((m) => m.id == draggedId);
    final tIdx = _macros.indexWhere((m) => m.id == targetId);
    if (dIdx == -1 || tIdx == -1 || dIdx == tIdx) return;
    
    final targetItem = _macros[tIdx];
    if (draggedId == targetItem.parentId || _isDescendant(targetItem.parentId, draggedId)) return;

    final item = _macros.removeAt(dIdx);
    
    final newTIdx = _macros.indexWhere((m) => m.id == targetId);
    item.parentId = targetItem.parentId;
    
    _macros.insert(newTIdx, item);
    _saveMacros();
    notifyListeners();
  }

  void reorderAfter(String draggedId, String targetId) {
    final dIdx = _macros.indexWhere((m) => m.id == draggedId);
    final tIdx = _macros.indexWhere((m) => m.id == targetId);
    if (dIdx == -1 || tIdx == -1 || dIdx == tIdx) return;
    
    final targetItem = _macros[tIdx];
    if (draggedId == targetItem.parentId || _isDescendant(targetItem.parentId, draggedId)) return;

    final item = _macros.removeAt(dIdx);
    
    final newTIdx = _macros.indexWhere((m) => m.id == targetId);
    item.parentId = targetItem.parentId;
    
    _macros.insert(newTIdx + 1, item);
    _saveMacros();
    notifyListeners();
  }

  Future<void> executeTrigger(String timing) async {
    for (var m in _macros.where((e) => e.executionTiming == timing && isMacroEffectivelyEnabled(e.id))) {
      await playMacro(m.id, wait: true);
    }
  }

  Future<void> playMacro(String id, {bool wait = false}) async {
    final idx = _macros.indexWhere((element) => element.id == id);
    String preprocess(String scr) {
      var p = scr.replaceAll(RegExp(r'/\*'), '<#').replaceAll(RegExp(r'\*/'), '#>');
      
      final knownCommands = [
        'Run', 'WaitMs', 'SwitchWindow', 'ReturnToApp', 'SendText', 'Send', 'Log', 'LogPixelColor', 
        'PixelIs', 'PixelIsNot', 'PixelMoreThan', 'RelativeMouseMove', 'LeftClick', 
        'RightClick', 'LeftDoubleClick', 'MiddleClick', 'MoveMouse', 'BlockInput', 'WinMove',
        'AppendClipboard', 'SetClipboard', 'NextClipboard'
      ];
      bool changed = true;
      int depth = 0;
      while (changed && depth < 10) {
        changed = false;
        String prevP = p;

        final pattern = r'\b(' + knownCommands.join('|') + r')\s*\((.*?)\)';
        p = p.replaceAllMapped(RegExp(pattern, dotAll: true), (match) {
          String cmd = match.group(1)!;
          String argsStr = match.group(2) ?? '';
          if (argsStr.trim().isEmpty) return cmd;
          List<String> args = [];
          String currentArg = '';
          bool inString = false;
          String stringChar = '';
          for (int i = 0; i < argsStr.length; i++) {
            String c = argsStr[i];
            if ((c == '"' || c == "'") && (i == 0 || argsStr[i-1] != '\\')) {
              if (!inString) {
                inString = true;
                stringChar = c;
              } else if (stringChar == c) {
                inString = false;
              }
            }
            if (c == ',' && !inString) {
              args.add(currentArg.trim());
              currentArg = '';
            } else {
              currentArg += c;
            }
          }
          if (currentArg.trim().isNotEmpty) args.add(currentArg.trim());
          return "$cmd ${args.join(' ')}".trim();
        });

        p = p.replaceAll(RegExp(r'^\s*//', multiLine: true), '#');
        p = p.replaceAllMapped(RegExp(r'^[\s]*(PixelIs(?:Not)?)\s+#([0-9a-fA-F]{6})\s*\{', multiLine: true), (m) => 'if (${m[1]} "#${m[2]}") {');
        p = p.replaceAllMapped(RegExp(r'^[\s]*(PixelIs(?:Not)?)\s+#([0-9a-fA-F]{6})\s*$', multiLine: true), (m) => 'if (-not (${m[1]} "#${m[2]}")) { Write-Error "Macro aborted dynamically! Expected underlying pixel state to evaluate TRUE for: ${m[1]} #${m[2]}"; exit 1 }');
        p = p.replaceAllMapped(RegExp(r'(PixelIs(?:Not)?)\s+#([0-9a-fA-F]{6})'), (m) => '${m[1]} "#${m[2]}"');
        
        p = p.replaceAllMapped(RegExp(r'^[\s]*(PixelMoreThan)\s+#([0-9a-fA-F]{6})\s+([0-9]+)\s*\{', multiLine: true), (m) => 'if (${m[1]} "#${m[2]}" ${m[3]}) {');
        p = p.replaceAllMapped(RegExp(r'^[\s]*(PixelMoreThan)\s+#([0-9a-fA-F]{6})\s+([0-9]+)\s*$', multiLine: true), (m) => 'if (-not (${m[1]} "#${m[2]}" ${m[3]})) { Write-Error "Macro aborted dynamically! Expected underlying pixel state to evaluate TRUE for: ${m[1]} #${m[2]} ${m[3]}"; exit 1 }');
        p = p.replaceAllMapped(RegExp(r'(PixelMoreThan)\s+#([0-9a-fA-F]{6})\s+([0-9]+)'), (m) => '${m[1]} "#${m[2]}" ${m[3]}');

        p = p.replaceAllMapped(RegExp(r'^[ \t]*Run[ \t]+("([^"]+)"|([^\s\{]+))(?:[ \t]+("([^"]+)"|([^\s\{]+)))?', multiLine: true), (match) {
            String mName = match.group(2) ?? match.group(3) ?? "";
            String mArg = match.group(5) ?? match.group(6) ?? "";
            
            String lower = mName.toLowerCase();
            if (lower == 'notepad') return 'Start-Process notepad';
            if (lower == 'reload') {
               return 'Write-Host "MACRO_CMD|RELOAD"';
            }
            if (lower == 'restart') {
               return 'Write-Host "MACRO_CMD|RESTART"';
            }
            if (lower == 'msgbox') {
               String msg = mArg.isNotEmpty ? mArg : "Execution Paused";
               return '[System.Windows.Forms.MessageBox]::Show("$msg", "Macro Message")';
            }

            var targetList = _macros.where((m) => m.name == mName);
            if (targetList.isNotEmpty) {
               return targetList.first.script;
            }
            return "# Could not find macro: $mName";
        });
        
        if (prevP != p) changed = true;
        depth++;
      }
      return p;
    }

    if (idx != -1) {
      final macro = _macros[idx];
      if (macro.script.trim().isNotEmpty) {
        final parsedScript = preprocess(macro.script);
        final file = File('.ai_bridge/temp_macro_${macro.id}.ps1');
        if (!file.parent.existsSync()) {
          file.parent.createSync(recursive: true);
        }

        const psHeader = r'''
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, int dx, int dy, uint cButtons, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")]
    public static extern IntPtr GetDC(IntPtr hwnd);
    [DllImport("user32.dll")]
    public static extern int ReleaseDC(IntPtr hwnd, IntPtr hdc);
    [DllImport("gdi32.dll")]
    public static extern uint GetPixel(IntPtr hdc, int nXPos, int nYPos);
    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT lpPoint);
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
    
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }
}
"@

$global:SavedWindowRect = $null
$global:SavedWindowHwnd = $null

function SaveWindowPosSize {
    [System.Diagnostics.DebuggerHidden()]
    param()
    $hwnd = [Win32]::GetForegroundWindow()
    $rect = New-Object Win32+RECT
    [Win32]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
    $global:SavedWindowRect = $rect
    $global:SavedWindowHwnd = $hwnd
}

function RestoreWindowPosSize {
    [System.Diagnostics.DebuggerHidden()]
    param()
    if ($global:SavedWindowRect -ne $null -and $global:SavedWindowHwnd -ne $null) {
        $width = $global:SavedWindowRect.Right - $global:SavedWindowRect.Left
        $height = $global:SavedWindowRect.Bottom - $global:SavedWindowRect.Top
        [Win32]::MoveWindow($global:SavedWindowHwnd, $global:SavedWindowRect.Left, $global:SavedWindowRect.Top, $width, $height, $true) | Out-Null
    }
}

function MoveMouse {
    [System.Diagnostics.DebuggerHidden()]
    param([int]$x, [int]$y)
    [Win32]::SetCursorPos($x, $y) | Out-Null
}

function PixelIs {
    [System.Diagnostics.DebuggerHidden()]
    param([string]$hexColor)
    $pt = New-Object Win32+POINT
    [Win32]::GetCursorPos([ref]$pt) | Out-Null
    $hdc = [Win32]::GetDC([IntPtr]::Zero)
    $pixel = [Win32]::GetPixel($hdc, $pt.X, $pt.Y)
    [Win32]::ReleaseDC([IntPtr]::Zero, $hdc) | Out-Null
    
    $r = $pixel -band 0xFF
    $g = ($pixel -shr 8) -band 0xFF
    $b = ($pixel -shr 16) -band 0xFF
    
    $hex = $hexColor.TrimStart('#')
    if ($hex.Length -eq 6) {
        $tr = [Convert]::ToInt32($hex.Substring(0,2), 16)
        $tg = [Convert]::ToInt32($hex.Substring(2,2), 16)
        $tb = [Convert]::ToInt32($hex.Substring(4,2), 16)
        
        if ($r -eq $tr -and $g -eq $tg -and $b -eq $tb) {
            return $true
        } else {
            return $false
        }
    }
    return $false
}

function PixelIsNot {
    [System.Diagnostics.DebuggerHidden()]
    param([string]$hexColor)
    $pt = New-Object Win32+POINT
    [Win32]::GetCursorPos([ref]$pt) | Out-Null
    $hdc = [Win32]::GetDC([IntPtr]::Zero)
    $pixel = [Win32]::GetPixel($hdc, $pt.X, $pt.Y)
    [Win32]::ReleaseDC([IntPtr]::Zero, $hdc) | Out-Null
    
    $r = $pixel -band 0xFF
    $g = ($pixel -shr 8) -band 0xFF
    $b = ($pixel -shr 16) -band 0xFF
    
    $hex = $hexColor.TrimStart('#')
    if ($hex.Length -eq 6) {
        $tr = [Convert]::ToInt32($hex.Substring(0,2), 16)
        $tg = [Convert]::ToInt32($hex.Substring(2,2), 16)
        $tb = [Convert]::ToInt32($hex.Substring(4,2), 16)
        
        if ($r -ne $tr -or $g -ne $tg -or $b -ne $tb) {
            return $true
        } else {
            return $false
        }
    }
    return $false
}

function PixelMoreThan {
    [System.Diagnostics.DebuggerHidden()]
    param([string]$hexColor, [int]$threshold)
    $pt = New-Object Win32+POINT
    [Win32]::GetCursorPos([ref]$pt) | Out-Null
    $hdc = [Win32]::GetDC([IntPtr]::Zero)
    $pixel = [Win32]::GetPixel($hdc, $pt.X, $pt.Y)
    [Win32]::ReleaseDC([IntPtr]::Zero, $hdc) | Out-Null
    
    $r = $pixel -band 0xFF
    $g = ($pixel -shr 8) -band 0xFF
    $b = ($pixel -shr 16) -band 0xFF
    
    $hex = $hexColor.TrimStart('#')
    if ($hex.Length -eq 6) {
        $tr = [Convert]::ToInt32($hex.Substring(0,2), 16)
        $tg = [Convert]::ToInt32($hex.Substring(2,2), 16)
        $tb = [Convert]::ToInt32($hex.Substring(4,2), 16)
        
        $dr = $r - $tr
        $dg = $g - $tg
        $db = $b - $tb
        $distance = [Math]::Sqrt($dr*$dr + $dg*$dg + $db*$db)
        if ($distance -gt $threshold) {
            return $true
        } else {
            return $false
        }
    }
    return $false
}

function RelativeMouseMove {
    [System.Diagnostics.DebuggerHidden()]
    param([string]$corner, [int]$dx, [int]$dy)
    $hwnd = [Win32]::GetForegroundWindow()
    $rect = New-Object Win32+RECT
    [Win32]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
    $x = 0; $y = 0
    if ($corner -eq "TopLeft") {
        $x = $rect.Left + $dx; $y = $rect.Top + $dy
    } elseif ($corner -eq "TopRight") {
        $x = $rect.Right - $dx; $y = $rect.Top + $dy
    } elseif ($corner -eq "BottomLeft") {
        $x = $rect.Left + $dx; $y = $rect.Bottom - $dy
    } elseif ($corner -eq "BottomRight") {
        $x = $rect.Right - $dx; $y = $rect.Bottom - $dy
    }
    Write-Host "MACRO_LOG|RelativeMouseMove: ForeWindow: $hwnd, Rect: ($([int]$rect.Left), $([int]$rect.Top), $([int]$rect.Right), $([int]$rect.Bottom)), Calculated Pos: ($x, $y)"
    [Win32]::SetCursorPos($x, $y) | Out-Null
}

function LeftClick {
    [System.Diagnostics.DebuggerHidden()]
    param()
    [Win32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    [Win32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

function RightClick {
    [System.Diagnostics.DebuggerHidden()]
    param()
    [Win32]::mouse_event(0x0008, 0, 0, 0, [UIntPtr]::Zero)
}

function LeftDoubleClick {
    [System.Diagnostics.DebuggerHidden()]
    param()
    [Win32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    [Win32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 10
    [Win32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    [Win32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

function MiddleClick {
    [System.Diagnostics.DebuggerHidden()]
    param()
    [Win32]::mouse_event(0x0020, 0, 0, 0, [UIntPtr]::Zero)
    [Win32]::mouse_event(0x0040, 0, 0, 0, [UIntPtr]::Zero)
}

function WaitMs {
    [System.Diagnostics.DebuggerHidden()]
    param([int]$ms)
    Start-Sleep -Milliseconds $ms
}

function SwitchWindow {
    [System.Diagnostics.DebuggerHidden()]
    param([string]$title)
    $wshell = New-Object -ComObject wscript.shell
    $process = Get-Process | Where-Object MainWindowTitle -match $title | Select-Object -First 1
    if ($process) {
        Write-Host "MACRO_LOG|SwitchWindow: Found process '$($process.Name)' with MainWindowTitle '$($process.MainWindowTitle)', HWND: $($process.MainWindowHandle)"
        $wshell.AppActivate($process.Id) | Out-Null
        $timeout = 50
        while ([Win32]::GetForegroundWindow() -ne $process.MainWindowHandle -and $timeout -gt 0) {
            Start-Sleep -Milliseconds 10
            $timeout--
        }
        $finalForeground = [Win32]::GetForegroundWindow()
        Write-Host "MACRO_LOG|SwitchWindow: Finished wait. Target HWND: $($process.MainWindowHandle), Final Foreground HWND: $finalForeground, Timeout left: $timeout"
    } else {
        Write-Host "MACRO_LOG|SwitchWindow: Could not find process matching '$title'. Falling back to AppActivate string."
        $wshell.AppActivate($title) | Out-Null
        Start-Sleep -Milliseconds 200
    }
}

function ReturnToApp {
    [System.Diagnostics.DebuggerHidden()]
    param()
    SwitchWindow "music_app"
}

function SendText {
    [System.Diagnostics.DebuggerHidden()]
    param([string]$text)
    Add-Type -AssemblyName System.Windows.Forms
    $escaped = $text -replace '([+^%~()])', '{$1}'
    [System.Windows.Forms.SendKeys]::SendWait($escaped)
}

function Send {
    [System.Diagnostics.DebuggerHidden()]
    param([string]$keys)
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait($keys)
}

function Log {
    [System.Diagnostics.DebuggerHidden()]
    param([string]$msg)
    Write-Host "MACRO_LOG|$msg"
}

function LogPixelColor {
    [System.Diagnostics.DebuggerHidden()]
    $pt = New-Object Win32+POINT
    [Win32]::GetCursorPos([ref]$pt) | Out-Null
    $hdc = [Win32]::GetDC([IntPtr]::Zero)
    $pixel = [Win32]::GetPixel($hdc, $pt.X, $pt.Y)
    [Win32]::ReleaseDC([IntPtr]::Zero, $hdc) | Out-Null
    
    $r = $pixel -band 0xFF
    $g = ($pixel -shr 8) -band 0xFF
    $b = ($pixel -shr 16) -band 0xFF
    
    $hex = "#{0:X2}{1:X2}{2:X2}" -f $r, $g, $b
    Log "Current Pixel Color is $hex"
}

function BlockInput {
    [System.Diagnostics.DebuggerHidden()]
    param($mode)
    $m = [string]$mode
    if ($m -match "(?i)^(true|on|\`$true|1)$") {
        [Win32]::BlockInput($true) | Out-Null
    } else {
        [Win32]::BlockInput($false) | Out-Null
    }
}

function WinMove {
    [System.Diagnostics.DebuggerHidden()]
    param([int]$x, [int]$y, [int]$width, [int]$height)
    $hwnd = [Win32]::GetForegroundWindow()
    [Win32]::MoveWindow($hwnd, $x, $y, $width, $height, $true) | Out-Null
}

$global:MacroClipboardQueue = @()
$global:MacroClipboardIndex = 0

function AppendClipboard {
    [System.Diagnostics.DebuggerHidden()]
    param([string]$text)
    $global:MacroClipboardQueue += $text
}

function SetClipboard {
    [System.Diagnostics.DebuggerHidden()]
    param()
    if ($global:MacroClipboardQueue.Length -gt 0) {
        $global:MacroClipboardIndex = 0
        Set-Clipboard -Value $global:MacroClipboardQueue[$global:MacroClipboardIndex]
    }
}

function NextClipboard {
    [System.Diagnostics.DebuggerHidden()]
    param()
    if ($global:MacroClipboardQueue.Length -gt 0) {
        $global:MacroClipboardIndex++
        if ($global:MacroClipboardIndex -ge $global:MacroClipboardQueue.Length) {
            $global:MacroClipboardIndex = 0
        }
        Set-Clipboard -Value $global:MacroClipboardQueue[$global:MacroClipboardIndex]
    }
}

# USER MACRO BEGINS HERE:
''';

        String scriptPrefix = '';
        String scriptSuffix = '';

        if (macro.executionTiming == 'System' && macro.hotkey.isNotEmpty) {
           String hk = macro.hotkey.toUpperCase().replaceAll(' ', '');
           bool hasCtrl = hk.contains('^') || hk.contains('CTRL');
           bool hasAlt = hk.contains('!') || hk.contains('ALT');
           bool hasShift = hk.contains('SHIFT');
           bool hasWin = hk.contains('#') || hk.contains('WIN');

           bool hasVerbose = hk.contains('CTRL') || hk.contains('ALT') || hk.contains('WIN') || hk.contains('SHIFT');
           if (!hasVerbose && hk.contains('+')) {
               hasShift = true;
           }

           String baseKey = hk
               .replaceAll('CTRL', '')
               .replaceAll('ALT', '')
               .replaceAll('SHIFT', '')
               .replaceAll('WIN', '')
               .replaceAll(RegExp(r'[\^\!\+\#\-]'), '');
           
           int vk = 0;
           if (baseKey.length == 1) {
             vk = baseKey.codeUnitAt(0);
           } else {
             switch(baseKey) {
               case 'F1': vk = 0x70; break;
               case 'F2': vk = 0x71; break;
               case 'F3': vk = 0x72; break;
               case 'F4': vk = 0x73; break;
               case 'F5': vk = 0x74; break;
               case 'F6': vk = 0x75; break;
               case 'F7': vk = 0x76; break;
               case 'F8': vk = 0x77; break;
               case 'F9': vk = 0x78; break;
               case 'F10': vk = 0x79; break;
               case 'F11': vk = 0x7A; break;
               case 'F12': vk = 0x7B; break;
               case 'ENTER': vk = 0x0D; break;
               case 'SPACE': vk = 0x20; break;
               case 'TAB': vk = 0x09; break;
               case 'ESC':
               case 'ESCAPE': vk = 0x1B; break;
             }
           }

           String conditions = '';
           if (hasCtrl) conditions += ' -and ([Win32]::GetAsyncKeyState(0x11) -band 0x8000)';
           if (hasAlt) conditions += ' -and ([Win32]::GetAsyncKeyState(0x12) -band 0x8000)';
           if (hasShift) conditions += ' -and ([Win32]::GetAsyncKeyState(0x10) -band 0x8000)';
           if (hasWin) conditions += ' -and (([Win32]::GetAsyncKeyState(0x5B) -band 0x8000) -or ([Win32]::GetAsyncKeyState(0x5C) -band 0x8000))';
           if (vk != 0) conditions += ' -and ([Win32]::GetAsyncKeyState($vk) -band 0x8000)';
           
           if (conditions.startsWith(' -and ')) conditions = conditions.substring(6);

           if (conditions.isNotEmpty && vk != 0) {
               scriptPrefix = 'while (\$true) {\n    if ($conditions) {\n        while (([Win32]::GetAsyncKeyState(0x11) -band 0x8000) -or ([Win32]::GetAsyncKeyState(0x12) -band 0x8000) -or ([Win32]::GetAsyncKeyState(0x10) -band 0x8000) -or ([Win32]::GetAsyncKeyState(0x5B) -band 0x8000) -or ([Win32]::GetAsyncKeyState(0x5C) -band 0x8000) -or ([Win32]::GetAsyncKeyState(\$vk) -band 0x8000)) {\n            Start-Sleep -Milliseconds 10\n        }\n${debugMode ? '        Set-PSDebug -Trace 1\n' : ''}';
               scriptSuffix = '${debugMode ? '        Set-PSDebug -Trace 0\n' : ''}        Start-Sleep -Milliseconds 100\n    }\n    Start-Sleep -Milliseconds 50\n}\n';
           } else {
               SystemLogsService.instance.addLog('Invalid Hotkey binding for "${macro.name}": "${macro.hotkey}" (Could not parse a valid base key). Disabling macro.', category: LogCategory.ERROR);
               macro.isEnabled = false;
               Future.microtask(() => updateMacro(macro));
               return; // Abort execution if hotkey is invalid
           }
        }

        String manualWait = '';
        if (macro.executionTiming != 'System') {
           manualWait = 'while (([Win32]::GetAsyncKeyState(1) -band 0x8000) -or ([Win32]::GetAsyncKeyState(2) -band 0x8000) -or ([Win32]::GetAsyncKeyState(0x11) -band 0x8000) -or ([Win32]::GetAsyncKeyState(0x10) -band 0x8000) -or ([Win32]::GetAsyncKeyState(0x12) -band 0x8000)) {\n    Start-Sleep -Milliseconds 10\n}\n';
        }

        String debugCmd = (debugMode && scriptPrefix.isEmpty) ? 'Set-PSDebug -Trace 1\n' : '';
        file.writeAsStringSync('$psHeader\n$manualWait$debugCmd$scriptPrefix$parsedScript\n$scriptSuffix');
        void processLogs(String data) {
          int headerLines = psHeader.split('\n').length + (manualWait.isNotEmpty ? manualWait.split('\n').length - 1 : 0) + (debugCmd.isNotEmpty ? 1 : 0) + (scriptPrefix.isNotEmpty ? scriptPrefix.split('\n').length - 1 : 0);
          for (var line in data.split('\n')) {
            if (line.trim().startsWith('MACRO_LOG|')) {
              SystemLogsService.instance.addLog('[Macro: ${macro.name.trim()}] ${line.trim().substring(10)}', category: LogCategory.MACRO);
            } else if (line.trim() == 'MACRO_CMD|RELOAD') {
              SystemLogsService.instance.addLog('[Macro Command: ${macro.name.trim()}] Triggering Hot Reload natively...', category: LogCategory.MACRO);
              VisualEditorScreen.triggerHotReload?.call();
            } else if (line.trim() == 'MACRO_CMD|RESTART') {
              SystemLogsService.instance.addLog('[Macro Command: ${macro.name.trim()}] Triggering Hot Restart natively...', category: LogCategory.MACRO);
              VisualEditorScreen.triggerHotRestart?.call();
            } else if (line.trim().startsWith('DEBUG:')) {
              var match = RegExp(r'DEBUG:\s+(\d+)\+.*>>>>(.*)').firstMatch(line);
              if (match != null) {
                 int psLine = int.tryParse(match.group(1) ?? '0') ?? 0;
                 int userLine = psLine - headerLines;
                 if (userLine > 0) {
                    SystemLogsService.instance.addLog('[Macro: ${macro.name.trim()}] [Line $userLine] -> ${match.group(2)!.trim()}', category: LogCategory.MACRO);
                 }
              }
            } else if (line.trim().isNotEmpty) {
              SystemLogsService.instance.addLog('[Macro Output: ${macro.name.trim()}] ${line.trim()}', category: LogCategory.MACRO);
            }
          }
        }

        void processErrors(String data) {
          int headerLines = psHeader.split('\n').length + (manualWait.isNotEmpty ? manualWait.split('\n').length - 1 : 0) + (debugCmd.isNotEmpty ? 1 : 0) + (scriptPrefix.isNotEmpty ? scriptPrefix.split('\n').length - 1 : 0);
          for (var line in data.split('\n')) {
            if (line.trim().isNotEmpty) {
              var match = RegExp(r'\.ps1:(\d+)').firstMatch(line);
              if (match != null) {
                int psLine = int.tryParse(match.group(1) ?? '0') ?? 0;
                int userLine = psLine - headerLines;
                if (userLine > 0) {
                  line = line.replaceFirst(match.group(0)!, 'Macro Line $userLine');
                } else {
                  line = line.replaceFirst(match.group(0)!, 'Native Preprocessor Line $psLine');
                }
              }
              SystemLogsService.instance.addLog('[Macro Failed: ${macro.name.trim()}] ${line.trim()}', category: LogCategory.ERROR);
            }
          }
        }

        SystemLogsService.instance.addLog('▶ Executing Macro: ${macro.name.trim()}...', category: LogCategory.MACRO);

        final process = await Process.start('powershell', ['-ExecutionPolicy', 'Bypass', '-File', '.ai_bridge/temp_macro_${macro.id}.ps1']);
        
        if (macro.executionTiming == 'System') {
           _runningSystemProcesses[macro.id] = process;
        }
        
        process.stdout.transform(utf8.decoder).listen((data) => processLogs(data));
        process.stderr.transform(utf8.decoder).listen((data) => processErrors(data));

        if (wait) {
          int code = await process.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
            process.kill();
            SystemLogsService.instance.addLog('⚠ Macro timed out after 5 seconds: ${macro.name.trim()}', category: LogCategory.ERROR);
            return -1;
          });
          if (code == 0) {
             SystemLogsService.instance.addLog('✔ Macro Completed: ${macro.name.trim()}', category: LogCategory.MACRO);
          }
        } else {
          process.exitCode.then((code) {
             if (code == 0) {
                 SystemLogsService.instance.addLog('✔ Macro Completed: ${macro.name.trim()}', category: LogCategory.MACRO);
             }
          });
        }
      }
    }
  }
}
