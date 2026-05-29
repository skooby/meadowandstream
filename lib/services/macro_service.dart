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
    _startFileWatcher();
    _initExcludedPids();
  }

  final List<int> _excludedPids = [pid];
  
  void _initExcludedPids() {
    try {
      Process.run('powershell', [
        '-Command',
        'try { \$curr = $pid; while (\$curr) { \$parent = (Get-CimInstance Win32_Process -Filter "ProcessId = \$curr" -ErrorAction SilentlyContinue).ParentProcessId; if (\$parent -and \$parent -ne 0) { Write-Output \$parent; \$curr = \$parent } else { break } } } catch {}'
      ]).then((result) {
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().split('\n');
          for (var line in lines) {
            final p = int.tryParse(line.trim());
            if (p != null && p != 0 && !_excludedPids.contains(p)) {
              _excludedPids.add(p);
            }
          }
          debugPrint('[MacroService] Resolved excluded parent PIDs: $_excludedPids');
        }
      }).catchError((e) {
        debugPrint('[MacroService] Failed to resolve parent PIDs: $e');
      });
    } catch (e) {
      debugPrint('[MacroService] Error starting parent PID resolution: $e');
    }
  }

  Future<void> _initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    debugMode = prefs.getBool('macro_debug_mode') ?? false;
    notifyListeners();
  }

  final String _filePath = '.ai_bridge/macros.json';
  List<Macro> _macros = [];
  List<Macro> get macros => _macros;

  StreamSubscription<FileSystemEvent>? _fileWatchSubscription;
  DateTime? _lastModified;
  bool _isWriting = false;

  void _startFileWatcher() {
    try {
      final file = File(_filePath);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      
      _fileWatchSubscription = file.parent.watch().listen((event) {
        if (event.path.replaceAll('\\', '/').endsWith('macros.json')) {
          if (event.type == FileSystemEvent.modify) {
            _onFileChanged();
          }
        }
      });
    } catch (e) {
      debugPrint('[MacroService] Failed to start file watcher: $e');
    }
  }

  void _onFileChanged() {
    if (_isWriting) return;
    
    try {
      final file = File(_filePath);
      if (file.existsSync()) {
        final stat = file.statSync();
        if (_lastModified == stat.modified) return;
        _lastModified = stat.modified;
        
        final content = file.readAsStringSync();
        final List dynamicList = jsonDecode(content);
        final newMacros = dynamicList.map((e) => Macro.fromJson(e)).toList();
        
        if (_areMacrosEqual(_macros, newMacros)) return;
        
        _macros = newMacros;
        notifyListeners();
        debugPrint('[MacroService] Macros reloaded from disk.');
      }
    } catch (e) {
      debugPrint('[MacroService] Error reloading macros from disk: $e');
    }
  }

  bool _areMacrosEqual(List<Macro> a, List<Macro> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].name != b[i].name ||
          a[i].script != b[i].script ||
          a[i].description != b[i].description ||
          a[i].executionTiming != b[i].executionTiming ||
          a[i].parentId != b[i].parentId ||
          a[i].isFolder != b[i].isFolder ||
          a[i].isExpanded != b[i].isExpanded ||
          a[i].hotkey != b[i].hotkey ||
          a[i].isEnabled != b[i].isEnabled) {
        return false;
      }
    }
    return true;
  }
  
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
          playMacro(m.id, wait: false);
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
    _isWriting = true;
    try {
      final file = File(_filePath);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync(jsonEncode(_macros.map((e) => e.toJson()).toList()));
      _lastModified = file.statSync().modified;
    } finally {
      Future.delayed(const Duration(milliseconds: 100), () {
        _isWriting = false;
      });
    }
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

  @visibleForTesting
  String preprocess(String scr, [List<String> visited = const []]) {
    var p = scr.replaceAll(RegExp(r'/\*'), '<#').replaceAll(RegExp(r'\*/'), '#>');
    
    // Preprocess variables and operators
    final stringRegex = RegExp(r'"[^"\\]*(?:\\.[^"\\]*)*"|' + r"'[^'\\]*(?:\\.[^'\\]*)*'");
    final declaredVars = <String>{};
    final varDeclRegex = RegExp(r'\bvar\s+([a-zA-Z_][a-zA-Z0-9_]*)');
    p.splitMapJoin(
      stringRegex,
      onMatch: (m) => m.group(0)!,
      onNonMatch: (nonMatch) {
        for (final match in varDeclRegex.allMatches(nonMatch)) {
          if (match.group(1) != null) {
            declaredVars.add(match.group(1)!);
          }
        }
        return nonMatch;
      },
    );
    
    p = p.splitMapJoin(
      stringRegex,
      onMatch: (m) => m.group(0)!,
      onNonMatch: (nonMatch) {
        var processed = nonMatch;
        processed = processed.replaceAllMapped(RegExp(r'\bvar\s+([a-zA-Z_][a-zA-Z0-9_]*)'), (m) => '\$${m.group(1)}');
        for (final varName in declaredVars) {
          processed = processed.replaceAllMapped(RegExp('(?<!\\\$)\\b$varName\\b'), (m) => '\$$varName');
        }
        processed = processed.replaceAll('==', ' -eq ');
        processed = processed.replaceAll('!=', ' -ne ');
        processed = processed.replaceAll('>=', ' -ge ');
        processed = processed.replaceAll('<=', ' -le ');
        processed = processed.replaceAllMapped(RegExp(r'(?<![-=<>#])>(?![=-])'), (m) => ' -gt ');
        processed = processed.replaceAllMapped(RegExp(r'(?<![-=<>#])<(?![=#-])'), (m) => ' -lt ');
        return processed;
      },
    );

    final knownCommands = [
      'Run', 'WaitMs', 'SwitchWindow', 'ReturnToApp', 'SendText', 'Send', 'Log', 'LogPixelColor', 
      'PixelIs', 'PixelIsNot', 'PixelMoreThan', 'RelativeMouseMove', 'LeftClick', 
      'RightClick', 'LeftDoubleClick', 'MiddleClick', 'MoveMouse', 'BlockInput', 'WinMove',
      'AppendClipboard', 'SetClipboard', 'NextClipboard', 'GetBridgeMode',
      'ScreenShot', 'ActiveWindowScreenShot', 'ActivateWindow',
      'RunOcr', 'OcrSearch', 'OcrHitTest', 'OcrGetText', 'OcrMoveTo',
    ];
    bool changed = true;
    int depth = 0;
    while (changed && depth < 10) {
      changed = false;
      String prevP = p;

      bool cmdChanged = true;
      int cmdDepth = 0;
      final startPattern = RegExp(r'\b(' + knownCommands.join('|') + r')\s*\(');
      while (cmdChanged && cmdDepth < 50) {
        cmdChanged = false;
        final match = startPattern.firstMatch(p);
        if (match != null) {
          final start = match.start;
          final cmd = match.group(1)!;
          final openParenIndex = match.end - 1; // index of the '('
          
          int parenDepth = 1;
          bool inString = false;
          String stringChar = '';
          int closeParenIndex = -1;
          
          for (int i = openParenIndex + 1; i < p.length; i++) {
            final c = p[i];
            if (c == '\\' && inString) {
              i++; // skip next char
              continue;
            }
            if (c == '"' || c == "'") {
              if (inString) {
                if (c == stringChar) {
                  inString = false;
                }
              } else {
                inString = true;
                stringChar = c;
              }
            } else if (!inString) {
              if (c == '(') {
                parenDepth++;
              } else if (c == ')') {
                parenDepth--;
                if (parenDepth == 0) {
                  closeParenIndex = i;
                  break;
                }
              }
            }
          }
          
          if (closeParenIndex != -1) {
            final argsStr = p.substring(openParenIndex + 1, closeParenIndex);
            List<String> args = [];
            if (argsStr.trim().isNotEmpty) {
              String currentArg = '';
              bool argInString = false;
              String argStringChar = '';
              for (int i = 0; i < argsStr.length; i++) {
                final c = argsStr[i];
                if (c == '\\' && argInString) {
                  currentArg += c;
                  if (i + 1 < argsStr.length) {
                    currentArg += argsStr[i + 1];
                    i++;
                  }
                  continue;
                }
                if (c == '"' || c == "'") {
                  if (argInString) {
                    if (c == argStringChar) {
                      argInString = false;
                    }
                  } else {
                    argInString = true;
                    argStringChar = c;
                  }
                  currentArg += c;
                } else if (c == ',' && !argInString) {
                  args.add(currentArg.trim());
                  currentArg = '';
                } else {
                  currentArg += c;
                }
              }
              if (currentArg.trim().isNotEmpty) {
                args.add(currentArg.trim());
              }
            }
            
            // Wrap argument in parentheses if it contains '+' operator
            final processedArgs = args.map((arg) {
              if (arg.contains('+')) {
                final stripped = arg.replaceAll(stringRegex, '');
                if (stripped.contains('+')) {
                  return '($arg)';
                }
              }
              return arg;
            }).toList();
            
            final replacement = processedArgs.isEmpty ? cmd : "$cmd ${processedArgs.join(' ')}";
            
            p = p.replaceRange(start, closeParenIndex + 1, replacement);
            cmdChanged = true;
          } else {
            break;
          }
        }
        cmdDepth++;
      }

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
             if (visited.contains(mName)) {
                return "# Circular dependency detected for macro: $mName";
             }
             return preprocess(targetList.first.script, [...visited, mName]);
          }
          return "# Could not find macro: $mName";
      });
      
      if (prevP != p) changed = true;
      depth++;
    }
    return p;
  }

  Future<void> playMacro(String id, {bool wait = false}) async {
    final idx = _macros.indexWhere((element) => element.id == id);
    if (idx != -1) {
      final macro = _macros[idx];
      final bool effectiveWait = macro.executionTiming == 'System' ? false : wait;
      if (macro.script.trim().isNotEmpty) {
        final parsedScript = preprocess(macro.script);
        final file = File('.ai_bridge/temp_macro_${macro.id}.ps1');
        if (!file.parent.existsSync()) {
          file.parent.createSync(recursive: true);
        }

        const psHeader = r'''
Add-Type -AssemblyName System.Windows.Forms
# Force stdout to UTF-8 so Dart's utf8.decoder never receives OEM/CP850 bytes.
# Process.start spawns non-interactive PowerShell where Console.OutputEncoding
# defaults to the system OEM code page (CP850/CP437), corrupting any non-ASCII
# characters in OCR text, window titles, file paths, etc.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding             = [System.Text.Encoding]::UTF8
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
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern IntPtr SetFocus(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")]
    public static extern bool LockSetForegroundWindow(uint uLockCode);
    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern bool GetKeyboardState(byte[] lpKeyState);
    [DllImport("user32.dll")]
    public static extern bool SetKeyboardState(byte[] lpKeyState);
    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
    [DllImport("user32.dll")]
    public static extern bool ScreenToClient(IntPtr hWnd, ref POINT lpPoint);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetWindowTextLength(IntPtr hWnd);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    
    public static string GetVisibleWindows() {
        var sb = new System.Text.StringBuilder();
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            if (IsWindowVisible(hWnd)) {
                int length = GetWindowTextLength(hWnd);
                if (length > 0) {
                    var titleSb = new System.Text.StringBuilder(length + 1);
                    GetWindowText(hWnd, titleSb, titleSb.Capacity);
                    sb.Append(hWnd.ToInt64().ToString() + "|" + titleSb.ToString() + "\n");
                }
            }
            return true;
        }, IntPtr.Zero);
        return sb.ToString();
    }
    
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }
}
"@
$global:SavedWindowRect = $null
$global:SavedWindowHwnd = $null
$global:BackgroundTargetHwnd = [IntPtr]::Zero
$global:MacroOcrResult = $null
$global:MacroScreenshotOriginX = 0
$global:MacroScreenshotOriginY = 0

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

function _BgClick {
    # Internal helper: sends mouse down+up messages to a background window.
    # $hwnd        - target HWND (from $global:BackgroundTargetHwnd)
    # $downMsg     - WM_*BUTTONDOWN constant
    # $upMsg       - WM_*BUTTONUP   constant
    # $repeatTimes - 1 for single click, 2 for double click
    param([IntPtr]$hwnd, [uint32]$downMsg, [uint32]$upMsg, [int]$repeatTimes = 1)
    # Convert current cursor screen position → window client coordinates.
    $cursor = [Win32+POINT]::new()
    $cursor.X = [System.Windows.Forms.Cursor]::Position.X
    $cursor.Y = [System.Windows.Forms.Cursor]::Position.Y
    [Win32]::ScreenToClient($hwnd, [ref]$cursor) | Out-Null
    # lParam encodes client (x, y): low word = x, high word = y
    $lParam = [IntPtr](([int]$cursor.Y -shl 16) -bor ([int]$cursor.X -band 0xFFFF))
    for ($i = 0; $i -lt $repeatTimes; $i++) {
        [Win32]::PostMessage($hwnd, $downMsg, [IntPtr]::Zero, $lParam) | Out-Null
        [Win32]::PostMessage($hwnd, $upMsg,   [IntPtr]::Zero, $lParam) | Out-Null
        if ($repeatTimes -gt 1 -and $i -lt $repeatTimes - 1) { Start-Sleep -Milliseconds 10 }
    }
}

function LeftClick {
    [System.Diagnostics.DebuggerHidden()]
    param()
    $hwnd = $global:BackgroundTargetHwnd
    if ($hwnd -and $hwnd -ne [IntPtr]::Zero) {
        _BgClick $hwnd 0x0201 0x0202   # WM_LBUTTONDOWN / WM_LBUTTONUP
    } else {
        [Win32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
        [Win32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    }
}

function RightClick {
    [System.Diagnostics.DebuggerHidden()]
    param()
    $hwnd = $global:BackgroundTargetHwnd
    if ($hwnd -and $hwnd -ne [IntPtr]::Zero) {
        _BgClick $hwnd 0x0204 0x0205   # WM_RBUTTONDOWN / WM_RBUTTONUP
    } else {
        [Win32]::mouse_event(0x0008, 0, 0, 0, [UIntPtr]::Zero)
        [Win32]::mouse_event(0x0010, 0, 0, 0, [UIntPtr]::Zero)
    }
}

function LeftDoubleClick {
    [System.Diagnostics.DebuggerHidden()]
    param()
    $hwnd = $global:BackgroundTargetHwnd
    if ($hwnd -and $hwnd -ne [IntPtr]::Zero) {
        _BgClick $hwnd 0x0201 0x0202 2  # WM_LBUTTONDOWN / WM_LBUTTONUP x2
    } else {
        [Win32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
        [Win32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 10
        [Win32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
        [Win32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    }
}

function MiddleClick {
    [System.Diagnostics.DebuggerHidden()]
    param()
    $hwnd = $global:BackgroundTargetHwnd
    if ($hwnd -and $hwnd -ne [IntPtr]::Zero) {
        _BgClick $hwnd 0x0207 0x0208   # WM_MBUTTONDOWN / WM_MBUTTONUP
    } else {
        [Win32]::mouse_event(0x0020, 0, 0, 0, [UIntPtr]::Zero)
        [Win32]::mouse_event(0x0040, 0, 0, 0, [UIntPtr]::Zero)
    }
}

function WaitMs {
    [System.Diagnostics.DebuggerHidden()]
    param([int]$ms)
    Start-Sleep -Milliseconds $ms
}

function SwitchWindow {
    [System.Diagnostics.DebuggerHidden()]
    param([string]$title)
    # Switching to a foreground window ends background-input mode
    $global:BackgroundTargetHwnd = [IntPtr]::Zero
    $wshell = New-Object -ComObject wscript.shell
    
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Host "MACRO_LOG|SwitchWindow: Starting switch for '$title'..."
    
    # 1. Get the list of process IDs to exclude (current macro process and all its parent processes)
    $excludePids = @($PID)
    if ($global:MacroExcludedPids) {
        $excludePids += $global:MacroExcludedPids
    } else {
        # Fallback to query process hierarchy if the pre-computed variable is missing
        $currentPid = $PID
        try {
            $allProcs = Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId -ErrorAction SilentlyContinue
            if (-not $allProcs) {
                $allProcs = Get-WmiObject Win32_Process -Property ProcessId, ParentProcessId -ErrorAction SilentlyContinue
            }
            if ($allProcs) {
                $parentMap = @{}
                foreach ($bp in $allProcs) {
                    if ($bp.ProcessId -and $bp.ParentProcessId) {
                        $parentMap[[int]$bp.ProcessId] = [int]$bp.ParentProcessId
                    }
                }
                while ($currentPid -and $parentMap.ContainsKey($currentPid)) {
                    $parent = $parentMap[$currentPid]
                    if ($parent -and $parent -ne 0 -and $excludePids -notcontains $parent) {
                        $excludePids += $parent
                        $currentPid = $parent
                    } else {
                        break
                    }
                }
            }
        } catch {
            $currentPid = $PID
            while ($currentPid) {
                $p = $null
                try {
                    $p = Get-CimInstance Win32_Process -Filter "ProcessId = $currentPid" -ErrorAction SilentlyContinue | Select-Object -First 1
                } catch {
                    $p = Get-WmiObject Win32_Process -Filter "ProcessId = $currentPid" -ErrorAction SilentlyContinue | Select-Object -First 1
                }
                if ($p -and $p.ParentProcessId -and $p.ParentProcessId -ne 0 -and $excludePids -notcontains $p.ParentProcessId) {
                    $currentPid = $p.ParentProcessId
                    $excludePids += $currentPid
                } else {
                    $currentPid = $null
                }
            }
        }
    }
    
    Write-Host "MACRO_LOG|SwitchWindow: Step 1 (Parent exclusion) took $($sw.ElapsedMilliseconds) ms. Excluded PIDs: $($excludePids -join ',')"
    $step1Time = $sw.ElapsedMilliseconds
    
    # 2. Enumerate all visible windows to find a match by title (regex or substring)
    $windowsText = [Win32]::GetVisibleWindows()
    $windows = $windowsText -split "`n" | Where-Object { $_ } | ForEach-Object {
        $parts = $_ -split '\|', 2
        if ($parts.Length -eq 2) {
            [PSCustomObject]@{
                Hwnd = [IntPtr][int64]$parts[0]
                Title = $parts[1]
            }
        }
    }
    
    Write-Host "MACRO_LOG|SwitchWindow: Step 2a (GetVisibleWindows) took $($sw.ElapsedMilliseconds - $step1Time) ms. Count: $($windows.Count)"
    $step2aTime = $sw.ElapsedMilliseconds
    
    # Pre-fetch all running processes in a single call to avoid heavy sequential Get-Process calls
    $procMap = @{}
    try {
        $procs = Get-Process -ErrorAction SilentlyContinue
        if ($procs) {
            foreach ($p in $procs) {
                $procMap[$p.Id] = $p
            }
        }
    } catch {}
    
    Write-Host "MACRO_LOG|SwitchWindow: Step 2b (Pre-fetch Get-Process) took $($sw.ElapsedMilliseconds - $step2aTime) ms. Map size: $($procMap.Count)"
    $step2bTime = $sw.ElapsedMilliseconds

    $match = $null
    if ($windows) {
        $match = $windows | Where-Object {
            # Check the direct name first
            if ($_.Title -match $title) {
                $winHwnd = $_.Hwnd
                $winPid = 0
                [Win32]::GetWindowThreadProcessId($winHwnd, [ref]$winPid) | Out-Null
                if ($excludePids -contains $winPid) {
                    if ($title -match 'antigravity|ai bridge|music_app|agentic|desktop') {
                        return $true
                    } else {
                        return $false
                    }
                }
                return $true
            }
            
            # If the title didn't match directly, fall back to process checks
            $winHwnd = $_.Hwnd
            $winPid = 0
            [Win32]::GetWindowThreadProcessId($winHwnd, [ref]$winPid) | Out-Null
            if ($excludePids -contains $winPid) {
                # Skip windows belonging to our process tree, unless explicitly targeted
                if ($title -match 'antigravity|ai bridge|music_app|agentic|desktop') {
                    # Continue checks below
                } else {
                    return $false
                }
            }
            if ($winPid -ne 0) {
                if ($procMap.ContainsKey($winPid)) {
                    $proc = $procMap[$winPid]
                    if ($proc.ProcessName -match $title) { return $true }
                    if ($proc.Description -match $title) { return $true }
                    if ($proc.Product -match $title) { return $true }
                }
            }
            return $false
        } | Select-Object -First 1
    }
    
    Write-Host "MACRO_LOG|SwitchWindow: Step 2c (Match loop) took $($sw.ElapsedMilliseconds - $step2bTime) ms. Match found: $($match -ne $null)"
    $step2cTime = $sw.ElapsedMilliseconds
    
    # 3. Fuzzy fallback matching for terminal/console windows if no direct match is found
    if (-not $match -and ($title -match 'powershell|pwsh|cmd|terminal|antigravity|cli')) {
        Write-Host "MACRO_LOG|SwitchWindow: Match not found for '$title', attempting fuzzy match for terminal..."
        if ($windows) {
            $match = $windows | Where-Object {
                # Check the direct name first for fuzzy terminals
                if ($_.Title -match 'powershell|pwsh|cmd|command prompt|terminal') {
                    $winHwnd = $_.Hwnd
                    $winPid = 0
                    [Win32]::GetWindowThreadProcessId($winHwnd, [ref]$winPid) | Out-Null
                    if ($excludePids -contains $winPid) {
                        if ($title -match 'antigravity|ai bridge|music_app|agentic|desktop') {
                            return $true
                        } else {
                            return $false
                        }
                    }
                    return $true
                }
                
                # Fallback to process checks for fuzzy terminals
                $winHwnd = $_.Hwnd
                $winPid = 0
                [Win32]::GetWindowThreadProcessId($winHwnd, [ref]$winPid) | Out-Null
                if ($excludePids -contains $winPid) {
                    if ($title -match 'antigravity|ai bridge|music_app|agentic|desktop') {
                        # Allow it
                    } else {
                        return $false
                    }
                }
                if ($winPid -ne 0) {
                    if ($procMap.ContainsKey($winPid)) {
                        $proc = $procMap[$winPid]
                        if ($proc.ProcessName -match 'powershell|pwsh|cmd|terminal') { return $true }
                        if ($proc.Description -match 'powershell|pwsh|cmd|terminal') { return $true }
                    }
                }
                return $false
            } | Select-Object -First 1
        }
        Write-Host "MACRO_LOG|SwitchWindow: Step 3 (Fuzzy fallback) took $($sw.ElapsedMilliseconds - $step2cTime) ms. Match found: $($match -ne $null)"
    }
    
    $step3Time = $sw.ElapsedMilliseconds
    
    # 4. Activate the window
    if ($match) {
        $targetPid = 0
        [Win32]::GetWindowThreadProcessId($match.Hwnd, [ref]$targetPid) | Out-Null
        Write-Host "MACRO_LOG|SwitchWindow: Found matching window '$($match.Title)' (HWND: $($match.Hwnd), PID: $targetPid)"
        
        # Restore if minimized
        [Win32]::ShowWindow($match.Hwnd, 9) | Out-Null
        
        # Set foreground window natively
        [Win32]::SetForegroundWindow($match.Hwnd) | Out-Null
        
        # Also attempt wshell AppActivate using process ID (handles terminal focus-stealing issues)
        if ($targetPid -ne 0) {
            $wshell.AppActivate($targetPid) | Out-Null
        } else {
            $wshell.AppActivate($match.Title) | Out-Null
        }
        
        # Wait up to 500ms for activation
        $timeout = 50
        while ($timeout -gt 0) {
            $fgHwnd = [Win32]::GetForegroundWindow()
            $fgPid = 0
            [Win32]::GetWindowThreadProcessId($fgHwnd, [ref]$fgPid) | Out-Null
            if ($fgPid -eq $targetPid -or $fgHwnd -eq $match.Hwnd) {
                break
            }
            Start-Sleep -Milliseconds 10
            $timeout--
        }
        $finalForeground = [Win32]::GetForegroundWindow()
        Write-Host "MACRO_LOG|SwitchWindow: Finished wait. Final HWND: $finalForeground, Timeout left: $timeout"
    } else {
        Write-Host "MACRO_LOG|SwitchWindow: Could not find any matching window for '$title'. Falling back to AppActivate string."
        $wshell.AppActivate($title) | Out-Null
        Start-Sleep -Milliseconds 200
    }
    
    Write-Host "MACRO_LOG|SwitchWindow: Step 4 (Window activation) took $($sw.ElapsedMilliseconds - $step3Time) ms. Total SwitchWindow duration: $($sw.ElapsedMilliseconds) ms."
}

function ReturnToApp {
    [System.Diagnostics.DebuggerHidden()]
    param()
    SwitchWindow "music_app"
}

function Invoke-BackgroundSend {
    # Routes a SendKeys-format string to $hwnd without needing the window in
    # the foreground. Two-mode design to avoid the double-character trap:
    #
    # Plain chars   -> PostMessage(WM_CHAR) only.
    #                  No WM_KEYDOWN, so TranslateMessage in the target app's
    #                  message loop never fires and no extra WM_CHAR is produced.
    #
    # Key events    -> AttachThreadInput + SetKeyboardState + SendMessage(WM_KEYDOWN/UP).
    #   (Ctrl/Alt,    SendMessage is SYNCHRONOUS and dispatches directly to WndProc,
    #    special keys) bypassing the message pump entirely, so TranslateMessage is
    #                  never called. SetKeyboardState spoofs the modifier bits in the
    #                  shared thread key state so GetKeyState() in the WndProc sees
    #                  the correct modifiers (real keyboard state does not reflect
    #                  our posted/sent messages otherwise).
    param([IntPtr]$hwnd, [string]$keys)
    $WM_KEYDOWN = [uint32]0x0100
    $WM_KEYUP   = [uint32]0x0101
    $WM_CHAR    = [uint32]0x0102
    $vkMap = @{
        'ENTER'=0x0D;'RETURN'=0x0D;'TAB'=0x09;'BACKSPACE'=0x08;'BS'=0x08;'BKSP'=0x08
        'DELETE'=0x2E;'DEL'=0x2E;'ESC'=0x1B;'ESCAPE'=0x1B
        'UP'=0x26;'DOWN'=0x28;'LEFT'=0x25;'RIGHT'=0x27
        'HOME'=0x24;'END'=0x23;'PGUP'=0x21;'PGDN'=0x22
        'F1'=0x70;'F2'=0x71;'F3'=0x72;'F4'=0x73;'F5'=0x74;'F6'=0x75
        'F7'=0x76;'F8'=0x77;'F9'=0x78;'F10'=0x79;'F11'=0x7A;'F12'=0x7B
    }
    # Sends WM_KEYDOWN + WM_KEYUP to $hwnd via SendMessage (synchronous, no
    # TranslateMessage side-effect). Spoofs modifier bits via SetKeyboardState
    # so the target WndProc sees the correct modifier state via GetKeyState.
    function SendKey($vk, $useCtrl, $useShift, $useAlt) {
        $kPid = 0
        $kThread = [Win32]::GetWindowThreadProcessId($hwnd, [ref]$kPid)
        $kCurThread = [Win32]::GetCurrentThreadId()
        [Win32]::AttachThreadInput($kCurThread, $kThread, $true) | Out-Null
        $ks = New-Object byte[] 256
        [Win32]::GetKeyboardState($ks) | Out-Null
        $ksSaved = $ks.Clone()
        if ($useCtrl)  { $ks[0x11] = 0x80 }  # VK_CONTROL
        if ($useShift) { $ks[0x10] = 0x80 }  # VK_SHIFT
        if ($useAlt)   { $ks[0x12] = 0x80 }  # VK_MENU
        [Win32]::SetKeyboardState($ks) | Out-Null
        [Win32]::SendMessage($hwnd, $WM_KEYDOWN, [IntPtr]$vk, [IntPtr]0x00000001) | Out-Null
        [Win32]::SendMessage($hwnd, $WM_KEYUP,   [IntPtr]$vk, [IntPtr]([int64]0xC0000001)) | Out-Null
        [Win32]::SetKeyboardState($ksSaved) | Out-Null
        [Win32]::AttachThreadInput($kCurThread, $kThread, $false) | Out-Null
    }
    function PostChar($c) {
        [Win32]::PostMessage($hwnd, $WM_CHAR, [IntPtr][int][char]$c, [IntPtr]0x00000001) | Out-Null
    }
    $ctrl = $false; $shift = $false; $alt = $false
    $i = 0
    while ($i -lt $keys.Length) {
        $c = $keys[$i]
        switch -CaseSensitive ($c) {
            '^'  { $ctrl  = $true; $i++; continue }
            '+'  { $shift = $true; $i++; continue }
            '%'  { $alt   = $true; $i++; continue }
            '('  { $i++; continue }
            ')'  { $ctrl=$false;$shift=$false;$alt=$false; $i++; continue }
            '{' {
                $close = $keys.IndexOf('}', $i)
                if ($close -gt $i) {
                    $token = $keys.Substring($i+1, $close-$i-1).ToUpper()
                    $vk = if ($vkMap.ContainsKey($token)) { $vkMap[$token] } else { 0 }
                    if ($vk -ne 0) { SendKey $vk $ctrl $shift $alt }
                    $ctrl=$false;$shift=$false;$alt=$false
                    $i = $close + 1
                } else { $i++ }
                continue
            }
            default {
                if ($ctrl -or $alt) {
                    # Modified key: SendMessage + SetKeyboardState so WndProc
                    # sees correct modifier in GetKeyState
                    SendKey ([int][char]::ToUpper($c)) $ctrl $shift $alt
                } else {
                    # Plain or Shift+char: WM_CHAR only, no WM_KEYDOWN
                    $out = if ($shift) { [char]::ToUpper($c) } else { $c }
                    PostChar $out
                }
                $ctrl=$false;$shift=$false;$alt=$false
                $i++
                continue
            }
        }
    }
}


function SendText {
    [System.Diagnostics.DebuggerHidden()]
    param([string]$text)
    if ($global:BackgroundTargetHwnd -ne $null -and $global:BackgroundTargetHwnd -ne [IntPtr]::Zero) {
        Invoke-BackgroundSend $global:BackgroundTargetHwnd $text
    } else {
        Add-Type -AssemblyName System.Windows.Forms
        $escaped = $text -replace '([+^%~()])', '{$1}'
        [System.Windows.Forms.SendKeys]::SendWait($escaped)
    }
}

function Send {
    [System.Diagnostics.DebuggerHidden()]
    param([string]$keys)
    if ($global:BackgroundTargetHwnd -ne $null -and $global:BackgroundTargetHwnd -ne [IntPtr]::Zero) {
        Invoke-BackgroundSend $global:BackgroundTargetHwnd $keys
    } else {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.SendKeys]::SendWait($keys)
    }
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

function GetBridgeMode {
    [System.Diagnostics.DebuggerHidden()]
    param()
    if ($global:MacroActiveBridgeMode) {
        return $global:MacroActiveBridgeMode
    }
    # Fallback if global variable is missing
    $searchDirs = @()
    if ($PSScriptRoot) {
        $searchDirs += $PSScriptRoot
    }
    $searchDirs += (Get-Location).Path
    
    foreach ($baseDir in $searchDirs) {
        $curr = $baseDir
        while ($curr) {
            $checkPath1 = Join-Path $curr "active_mode.txt"
            $checkPath2 = Join-Path $curr ".ai_bridge/active_mode.txt"
            
            if (Test-Path $checkPath1) {
                return (Get-Content $checkPath1).Trim()
            }
            if (Test-Path $checkPath2) {
                return (Get-Content $checkPath2).Trim()
            }
            
            $parent = Split-Path $curr -Parent
            if ($parent -eq $curr -or !$parent) {
                break
            }
            $curr = $parent
        }
    }
    return "sdk"
}

function ActivateWindow {
    # Routes keyboard focus to the target window WITHOUT raising it to the foreground.
    # Uses AttachThreadInput + SetFocus so the window receives keystrokes while
    # staying behind the current foreground window.
    # Mouse clicks still work normally as long as SetCursorPos targets the window.
    [System.Diagnostics.DebuggerHidden()]
    param([string]$title)
    Write-Host "MACRO_LOG|ActivateWindow: Searching for '$title'..."

    # Enumerate visible windows
    $windowsText = [Win32]::GetVisibleWindows()
    $windows = $windowsText -split "`n" | Where-Object { $_ } | ForEach-Object {
        $parts = $_ -split '\|', 2
        if ($parts.Length -eq 2) {
            [PSCustomObject]@{ Hwnd = [IntPtr][int64]$parts[0]; Title = $parts[1] }
        }
    }

    $match = $windows | Where-Object { $_.Title -match $title } | Select-Object -First 1

    if (-not $match) {
        Write-Host "MACRO_LOG|ActivateWindow: No window matched '$title'."
        return
    }

    $targetHwnd = $match.Hwnd
    Write-Host "MACRO_LOG|ActivateWindow: Found '$($match.Title)' (HWND: $targetHwnd)"

    # Get thread IDs
    $targetPid   = 0
    $targetThread = [Win32]::GetWindowThreadProcessId($targetHwnd, [ref]$targetPid)
    $currentThread = [Win32]::GetCurrentThreadId()

    # Lock foreground changes BEFORE attaching focus so the target app cannot
    # call SetForegroundWindow on itself in its WM_SETFOCUS handler.
    # LSFW_LOCK = 1, LSFW_UNLOCK = 2
    [Win32]::LockSetForegroundWindow(1) | Out-Null

    # Attach our thread's input queue to the target's - lets SetFocus work cross-thread
    $attached = [Win32]::AttachThreadInput($currentThread, $targetThread, $true)
    [Win32]::SetFocus($targetHwnd) | Out-Null
    if ($attached) {
        [Win32]::AttachThreadInput($currentThread, $targetThread, $false) | Out-Null
    }

    # Unlock foreground changes now that focus is set
    [Win32]::LockSetForegroundWindow(2) | Out-Null

    # Store the HWND so Send/SendText route via PostMessage to this background window
    $global:BackgroundTargetHwnd = $targetHwnd

    Write-Host "MACRO_LOG|ActivateWindow: Focus set (thread attach: $attached). Window stays in background."
}

function ScreenShot {

    [System.Diagnostics.DebuggerHidden()]
    param([string]$fileName = "")
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    # Expand to cover all virtual screens (multi-monitor)
    $left   = [System.Windows.Forms.SystemInformation]::VirtualScreen.Left
    $top    = [System.Windows.Forms.SystemInformation]::VirtualScreen.Top
    $width  = [System.Windows.Forms.SystemInformation]::VirtualScreen.Width
    $height = [System.Windows.Forms.SystemInformation]::VirtualScreen.Height
    $bmp = New-Object System.Drawing.Bitmap($width, $height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($left, $top, 0, 0, [System.Drawing.Size]::new($width, $height))
    $g.Dispose()
    $dir = ".ai_bridge/screenshots"
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not $fileName) { $fileName = "screenshot_$(Get-Date -Format 'yyyyMMdd_HHmmss').png" }
    $path = Join-Path (Get-Location) "$dir/$fileName"
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "MACRO_CMD|SCREENSHOT_ORIGIN|$left|$top"
    $global:MacroScreenshotOriginX = $left
    $global:MacroScreenshotOriginY = $top
    Write-Host "MACRO_CMD|SCREENSHOT|$path"
    Write-Host "MACRO_LOG|ScreenShot: Saved full-screen capture to $path ($($width)x$($height)) origin($left,$top)"
}

function ActiveWindowScreenShot {
    [System.Diagnostics.DebuggerHidden()]
    param([string]$fileName = "")
    Add-Type -AssemblyName System.Drawing
    # Prefer the background-activated window (set by ActivateWindow) over the
    # real foreground window, since ActivateWindow keeps the target behind.
    $hwnd = if ($global:BackgroundTargetHwnd -ne $null -and $global:BackgroundTargetHwnd -ne [IntPtr]::Zero) {
        $global:BackgroundTargetHwnd
    } else {
        [Win32]::GetForegroundWindow()
    }
    $rect = New-Object Win32+RECT
    [Win32]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
    $left   = $rect.Left
    $top    = $rect.Top
    $width  = $rect.Right  - $rect.Left
    $height = $rect.Bottom - $rect.Top
    if ($width -le 0 -or $height -le 0) {
        Write-Host "MACRO_LOG|ActiveWindowScreenShot: Invalid window bounds ($width x $height), aborting."
        return
    }
    $bmp = New-Object System.Drawing.Bitmap($width, $height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    # PrintWindow renders the window into the bitmap even when it is behind other
    # windows. PW_RENDERFULLCONTENT (2) works for DWM/DirectComposition windows
    # (Flutter, Electron, etc.) that would otherwise produce a blank bitmap.
    $hdc = $g.GetHdc()
    $ok = [Win32]::PrintWindow($hwnd, $hdc, 2)
    $g.ReleaseHdc($hdc)
    $g.Dispose()
    if (-not $ok) {
        Write-Host "MACRO_LOG|ActiveWindowScreenShot: PrintWindow failed, falling back to CopyFromScreen."
        $gFallback = [System.Drawing.Graphics]::FromImage($bmp)
        $gFallback.CopyFromScreen($left, $top, 0, 0, [System.Drawing.Size]::new($width, $height))
        $gFallback.Dispose()
    }
    $dir = ".ai_bridge/screenshots"
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not $fileName) { $fileName = "active_window_$(Get-Date -Format 'yyyyMMdd_HHmmss').png" }
    $path = Join-Path (Get-Location) "$dir/$fileName"
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "MACRO_CMD|SCREENSHOT_ORIGIN|$left|$top"
    $global:MacroScreenshotOriginX = $left
    $global:MacroScreenshotOriginY = $top
    Write-Host "MACRO_CMD|SCREENSHOT|$path"
    Write-Host "MACRO_LOG|ActiveWindowScreenShot: Saved active-window capture to $path ($($width)x$($height)) origin($left,$top)"
}


function RunOcr {
    # Runs Tesseract OCR on the last captured screenshot (or a specified image path).
    # Stores the structured result in $global:MacroOcrResult for subsequent OCR commands,
    # and emits MACRO_CMD|OCR|<json> so Dart persists it to .ai_bridge/last_ocr_result.json.
    # Requires Tesseract 5.x: https://github.com/UB-Mannheim/tesseract/wiki
    [System.Diagnostics.DebuggerHidden()]
    param([string]$imagePath = "", [string]$language = "eng")
    if (-not $imagePath) {
        $refFile = ".ai_bridge/last_screenshot.txt"
        if (-not (Test-Path $refFile)) {
            Write-Host "MACRO_LOG|RunOcr: No screenshot found. Run ScreenShot() or ActiveWindowScreenShot() first."
            return
        }
        $imagePath = (Get-Content $refFile -Raw).Trim()
    }
    if (-not $imagePath -or -not (Test-Path $imagePath)) {
        Write-Host "MACRO_LOG|RunOcr: Image file not found: '$imagePath'"
        return
    }
    # Resolve Tesseract executable — Flutter's Process.run does not inherit the
    # full user interactive PATH, so bare 'tesseract' often fails even when
    # Tesseract is installed. Check PATH first, then fall back to known install locations.
    $tessExe = $null
    if (Get-Command "tesseract" -ErrorAction SilentlyContinue) {
        $tessExe = "tesseract"
    } else {
        $candidates = @(
            "$env:ProgramFiles\Tesseract-OCR\tesseract.exe",
            "${env:ProgramFiles(x86)}\Tesseract-OCR\tesseract.exe",
            "$env:LOCALAPPDATA\Programs\Tesseract-OCR\tesseract.exe",
            "C:\Program Files\Tesseract-OCR\tesseract.exe",
            "C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"
        )
        foreach ($c in $candidates) {
            if (Test-Path $c) { $tessExe = $c; break }
        }
    }
    if (-not $tessExe) {
        Write-Host "MACRO_LOG|RunOcr: Tesseract not found. Install from https://github.com/UB-Mannheim/tesseract/wiki"
        return
    }
    Write-Host "MACRO_LOG|RunOcr: Using Tesseract at '$tessExe'"
    $tmpBase = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "ocr_$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())")
    Write-Host "MACRO_LOG|RunOcr: Processing '$imagePath' (lang=$language)..."
    & $tessExe $imagePath $tmpBase -l $language hocr 2>$null
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Host "MACRO_LOG|RunOcr: Tesseract exited $exitCode."
        return
    }
    $hocrPath = "$tmpBase.hocr"
    if (-not (Test-Path $hocrPath)) {
        Write-Host "MACRO_LOG|RunOcr: HOCR output not found at '$hocrPath'"
        return
    }
    $hocr = Get-Content $hocrPath -Raw -Encoding UTF8
    Remove-Item $hocrPath -ErrorAction SilentlyContinue

    $Singleline = [System.Text.RegularExpressions.RegexOptions]::Singleline
    $wordPat = [System.Text.RegularExpressions.Regex]::new("<span[^>]+class='ocrx_word'[^>]+title='([^']+)'[^>]*>(.*?)</span>", $Singleline)
    $bboxPat = [regex]"bbox\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)"
    $confPat = [regex]"x_wconf\s+(\d+)"
    $tagPat  = [regex]"<[^>]+>"
    $words   = [System.Collections.Generic.List[object]]::new()
    foreach ($m in $wordPat.Matches($hocr)) {
        $title = $m.Groups[1].Value
        $inner = $m.Groups[2].Value
        $bm = $bboxPat.Match($title)
        if (-not $bm.Success) { continue }
        $cm = $confPat.Match($title)
        $text = $tagPat.Replace($inner, "") -replace '&amp;','&' -replace '&lt;','<' -replace '&gt;','>' -replace '&quot;','"' -replace "&#39;","'" -replace '\s+',' '
        $text = $text.Trim()
        if ($text) {
            $words.Add([PSCustomObject]@{
                text       = $text
                left       = [int]$bm.Groups[1].Value
                top        = [int]$bm.Groups[2].Value
                right      = [int]$bm.Groups[3].Value
                bottom     = [int]$bm.Groups[4].Value
                confidence = if ($cm.Success) { [double]$cm.Groups[1].Value } else { -1.0 }
            })
        }
    }
    $linePat = [System.Text.RegularExpressions.Regex]::new("<span[^>]+class='ocr_line'[^>]*>(.*?)</span>", $Singleline)
    $lines   = [System.Collections.Generic.List[string]]::new()
    foreach ($m in $linePat.Matches($hocr)) {
        $lt = $tagPat.Replace($m.Groups[1].Value, "") -replace '\s+',' '
        $lt = $lt.Trim()
        if ($lt) { $lines.Add($lt) }
    }
    $fullText = ($lines -join "`n")
    # Resolve the screenshot origin. When RunOcr and ActiveWindowScreenShot run
    # in the same macro script the globals are already set. When they run in
    # separate macros (separate PowerShell processes) the globals are 0, so we
    # fall back to the file that Dart persists from MACRO_CMD|SCREENSHOT_ORIGIN|.
    $originX = $global:MacroScreenshotOriginX
    $originY = $global:MacroScreenshotOriginY
    if ($originX -eq 0 -and $originY -eq 0) {
        $originFile = ".ai_bridge/last_screenshot_origin.txt"
        if (Test-Path $originFile) {
            $parts = (Get-Content $originFile -Raw).Trim().Split(',')
            if ($parts.Count -ge 2) {
                $originX = [int]$parts[0]
                $originY = [int]$parts[1]
            }
        }
    }
    Write-Host "MACRO_LOG|RunOcr: Screenshot origin = ($originX,$originY) — image coords will be offset by this to reach screen space"
    $global:MacroOcrResult = [PSCustomObject]@{
        imagePath = $imagePath
        originX   = $originX
        originY   = $originY
        fullText  = $fullText
        words     = $words.ToArray()
        wordCount = $words.Count
    }
    $json = $global:MacroOcrResult | ConvertTo-Json -Depth 4 -Compress
    Write-Host "MACRO_CMD|OCR|$json"
    Write-Host "MACRO_LOG|RunOcr: Complete. $($words.Count) word(s) recognized."
}

function OcrSearch {
    # Searches the last RunOcr result for words containing [query].
    # Logs each match with image bounding box and screen-space center.
    [System.Diagnostics.DebuggerHidden()]
    param([string]$query, [switch]$caseSensitive)
    if ($null -eq $global:MacroOcrResult) {
        Write-Host "MACRO_LOG|OcrSearch: No OCR result. Run RunOcr() first."
        return
    }
    $ox = $global:MacroOcrResult.originX
    $oy = $global:MacroOcrResult.originY
    $hits = @($global:MacroOcrResult.words | Where-Object {
        $t = if ($caseSensitive) { $_.text } else { $_.text.ToLower() }
        $q = if ($caseSensitive) { $query } else { $query.ToLower() }
        $t.Contains($q)
    })
    if ($hits.Count -eq 0) {
        Write-Host "MACRO_LOG|OcrSearch: No matches for '$query'"
    } else {
        Write-Host "MACRO_LOG|OcrSearch: $($hits.Count) match(es) for '$query':"
        foreach ($h in $hits) {
            $cx = $h.left + [int](($h.right  - $h.left) / 2)
            $cy = $h.top  + [int](($h.bottom - $h.top)  / 2)
            Write-Host "MACRO_LOG|OcrSearch:  '$($h.text)' img($($h.left),$($h.top))-($($h.right),$($h.bottom)) screen($($ox+$cx),$($oy+$cy)) conf:$($h.confidence)%"
        }
    }
}

function OcrHitTest {
    # Returns the word at image-space coordinates (x, y).
    [System.Diagnostics.DebuggerHidden()]
    param([int]$x, [int]$y)
    if ($null -eq $global:MacroOcrResult) {
        Write-Host "MACRO_LOG|OcrHitTest: No OCR result. Run RunOcr() first."
        return
    }
    foreach ($w in $global:MacroOcrResult.words) {
        if ($x -ge $w.left -and $x -le $w.right -and $y -ge $w.top -and $y -le $w.bottom) {
            Write-Host "MACRO_LOG|OcrHitTest: Hit '$($w.text)' bbox($($w.left),$($w.top),$($w.right),$($w.bottom)) conf:$($w.confidence)%"
            return
        }
    }
    Write-Host "MACRO_LOG|OcrHitTest: No word at image coords ($x,$y)"
}

function OcrGetText {
    # Logs the full plain text from the last RunOcr result.
    [System.Diagnostics.DebuggerHidden()]
    param()
    if ($null -eq $global:MacroOcrResult) {
        Write-Host "MACRO_LOG|OcrGetText: No OCR result. Run RunOcr() first."
        return
    }
    Write-Host "MACRO_LOG|OcrGetText: --- BEGIN OCR TEXT ---"
    Write-Host $global:MacroOcrResult.fullText
    Write-Host "MACRO_LOG|OcrGetText: --- END OCR TEXT ($($global:MacroOcrResult.wordCount) words) ---"
}

function OcrMoveTo {
    # Moves the mouse to the screen-space center of the first word matching [query].
    # Converts image-space bounding box center to screen coords using the stored origin.
    [System.Diagnostics.DebuggerHidden()]
    param([string]$query, [switch]$caseSensitive)
    if ($null -eq $global:MacroOcrResult) {
        Write-Host "MACRO_LOG|OcrMoveTo: No OCR result. Run RunOcr() first."
        return
    }
    $match = $global:MacroOcrResult.words | Where-Object {
        $t = if ($caseSensitive) { $_.text } else { $_.text.ToLower() }
        $q = if ($caseSensitive) { $query } else { $query.ToLower() }
        $t.Contains($q)
    } | Select-Object -First 1
    if ($null -eq $match) {
        Write-Host "MACRO_LOG|OcrMoveTo: No match for '$query'"
        return
    }
    $imgCx   = $match.left + [int](($match.right  - $match.left) / 2)
    $imgCy   = $match.top  + [int](($match.bottom - $match.top)  / 2)
    $screenX = $global:MacroOcrResult.originX + $imgCx
    $screenY = $global:MacroOcrResult.originY + $imgCy
    [Win32]::SetCursorPos($screenX, $screenY) | Out-Null
    Write-Host "MACRO_LOG|OcrMoveTo: Moved to '$($match.text)' screen($screenX,$screenY)"
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
               scriptPrefix = 'while (\$true) {\n    if ($conditions) {\n        while (([Win32]::GetAsyncKeyState(0x11) -band 0x8000) -or ([Win32]::GetAsyncKeyState(0x12) -band 0x8000) -or ([Win32]::GetAsyncKeyState(0x10) -band 0x8000) -or ([Win32]::GetAsyncKeyState(0x5B) -band 0x8000) -or ([Win32]::GetAsyncKeyState(0x5C) -band 0x8000) -or ([Win32]::GetAsyncKeyState($vk) -band 0x8000)) {\n            Start-Sleep -Milliseconds 10\n        }\n${debugMode ? '        Set-PSDebug -Trace 1\n' : ''}';
               scriptSuffix = '${debugMode ? '        Set-PSDebug -Trace 0\n' : ''}        Start-Sleep -Milliseconds 100\n    }\n    Start-Sleep -Milliseconds 50\n}\n';
           } else {
               SystemLogsService.instance.addLog('Invalid Hotkey binding for "${macro.name}": "${macro.hotkey}" (Could not parse a valid base key). Disabling macro.', category: LogCategory.ERROR);
               macro.isEnabled = false;
               Future.microtask(() => updateMacro(macro));
               return; // Abort execution if hotkey is invalid
           }
        }

        String activeMode = 'sdk';
        try {
          final modeFile = File('.ai_bridge/active_mode.txt');
          if (modeFile.existsSync()) {
            activeMode = modeFile.readAsStringSync().trim();
          }
        } catch (_) {}

        final pidsCsv = _excludedPids.join(', ');
        final String globalsHeader = '\$global:MacroExcludedPids = @($pidsCsv)\n\$global:MacroActiveBridgeMode = "$activeMode"';

        String manualWait = '';
        if (macro.executionTiming != 'System') {
           manualWait = 'while (([Win32]::GetAsyncKeyState(1) -band 0x8000) -or ([Win32]::GetAsyncKeyState(2) -band 0x8000) -or ([Win32]::GetAsyncKeyState(0x11) -band 0x8000) -or ([Win32]::GetAsyncKeyState(0x10) -band 0x8000) -or ([Win32]::GetAsyncKeyState(0x12) -band 0x8000)) {\n    Start-Sleep -Milliseconds 10\n}\n';
        }

        String debugCmd = (debugMode && scriptPrefix.isEmpty) ? 'Set-PSDebug -Trace 1\n' : '';
        final scriptContent = '$globalsHeader\n$psHeader\n$manualWait$debugCmd$scriptPrefix$parsedScript\n$scriptSuffix';
        // Write with UTF-8 BOM so PowerShell reads non-ASCII chars correctly
        // regardless of the system OEM code page (cp437/cp850 etc.).
        file.writeAsBytesSync([0xEF, 0xBB, 0xBF, ...utf8.encode(scriptContent)]);
        void processLogs(String data) {
          int headerLines = globalsHeader.split('\n').length + psHeader.split('\n').length + (manualWait.isNotEmpty ? manualWait.split('\n').length - 1 : 0) + (debugCmd.isNotEmpty ? 1 : 0) + (scriptPrefix.isNotEmpty ? scriptPrefix.split('\n').length - 1 : 0);
          for (var line in data.split('\n')) {
            if (line.trim().startsWith('MACRO_LOG|')) {
              SystemLogsService.instance.addLog('[Macro: ${macro.name.trim()}] ${line.trim().substring(10)}', category: LogCategory.MACRO);
            } else if (line.trim() == 'MACRO_CMD|RELOAD') {
              SystemLogsService.instance.addLog('[Macro Command: ${macro.name.trim()}] Triggering Hot Reload natively...', category: LogCategory.MACRO);
              VisualEditorScreen.triggerHotReload?.call();
            } else if (line.trim() == 'MACRO_CMD|RESTART') {
              SystemLogsService.instance.addLog('[Macro Command: ${macro.name.trim()}] Triggering Hot Restart natively...', category: LogCategory.MACRO);
              VisualEditorScreen.triggerHotRestart?.call();
            } else if (line.trim().startsWith('MACRO_CMD|SCREENSHOT_ORIGIN|')) {
              // Emitted by ScreenShot / ActiveWindowScreenShot to record the top-left
              // screen coordinate of the captured image for OcrMoveTo coordinate mapping.
              final originParts = line.trim().substring('MACRO_CMD|SCREENSHOT_ORIGIN|'.length).split('|');
              if (originParts.length >= 2) {
                try {
                  File('.ai_bridge/last_screenshot_origin.txt')
                      .writeAsStringSync('${originParts[0]},${originParts[1]}');
                } catch (_) {}
              }
            } else if (line.trim().startsWith('MACRO_CMD|OCR|')) {
              // Emitted by RunOcr with a JSON payload containing fullText, words, and bounding boxes.
              final ocrJson = line.trim().substring('MACRO_CMD|OCR|'.length).trim();
              try {
                final wordCountMatch = RegExp(r'"wordCount":(\d+)').firstMatch(ocrJson);
                final wordCount = wordCountMatch?.group(1) ?? '?';
                SystemLogsService.instance.addLog(
                  '[Macro Command: ${macro.name.trim()}] OCR result: $wordCount word(s) — saved to last_ocr_result.json',
                  category: LogCategory.MACRO,
                );
                File('.ai_bridge/last_ocr_result.json').writeAsStringSync(ocrJson);
              } catch (_) {}
            } else if (line.trim().startsWith('MACRO_CMD|SCREENSHOT|')) {
              final screenshotPath = line.trim().substring('MACRO_CMD|SCREENSHOT|'.length).trim();
              SystemLogsService.instance.addLog('[Macro Command: ${macro.name.trim()}] Screenshot saved: $screenshotPath', category: LogCategory.MACRO);
              try {
                File('.ai_bridge/last_screenshot.txt').writeAsStringSync(screenshotPath);
              } catch (_) {}
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
          int headerLines = globalsHeader.split('\n').length + psHeader.split('\n').length + (manualWait.isNotEmpty ? manualWait.split('\n').length - 1 : 0) + (debugCmd.isNotEmpty ? 1 : 0) + (scriptPrefix.isNotEmpty ? scriptPrefix.split('\n').length - 1 : 0);
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

        final stopwatch = Stopwatch()..start();
        final process = await Process.start('powershell', ['-ExecutionPolicy', 'Bypass', '-File', '.ai_bridge/temp_macro_${macro.id}.ps1']);
        
        if (macro.executionTiming == 'System') {
           _runningSystemProcesses[macro.id] = process;
        }
        
        process.stdout.transform(const Utf8Decoder(allowMalformed: true)).listen((data) => processLogs(data));
        process.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((data) => processErrors(data));

        if (effectiveWait) {
          int code = await process.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
            process.kill();
            stopwatch.stop();
            SystemLogsService.instance.addLog('⚠ Macro timed out after 5 seconds: ${macro.name.trim()} (took ${stopwatch.elapsedMilliseconds} ms)', category: LogCategory.ERROR);
            return -1;
          });
          stopwatch.stop();
          if (code == 0) {
             SystemLogsService.instance.addLog('✔ Macro Completed: ${macro.name.trim()} (took ${stopwatch.elapsedMilliseconds} ms)', category: LogCategory.MACRO);
          } else if (code != -1) {
             SystemLogsService.instance.addLog('✖ Macro Failed: ${macro.name.trim()} (took ${stopwatch.elapsedMilliseconds} ms)', category: LogCategory.ERROR);
          }
        } else {
          process.exitCode.then((code) {
             stopwatch.stop();
             if (macro.executionTiming == 'System') {
               _runningSystemProcesses.remove(macro.id);
               _runningSystemMacros.remove(macro.id);
             }
             if (code == 0) {
                 SystemLogsService.instance.addLog('✔ Macro Completed: ${macro.name.trim()} (took ${stopwatch.elapsedMilliseconds} ms)', category: LogCategory.MACRO);
             } else {
                 SystemLogsService.instance.addLog('✖ Macro Failed: ${macro.name.trim()} (took ${stopwatch.elapsedMilliseconds} ms)', category: LogCategory.ERROR);
             }
          });
        }
      }
    }
  }
}
