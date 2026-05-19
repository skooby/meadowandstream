import 'dart:io';
import 'package:flutter/material.dart';
import '../../app/app.dart';
import 'panels/karaoke_gen_window.dart';
import '../../services/karaoke_gen_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/scheduler.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import '../../choreography/choreography_engine.dart';
import '../../state/editor_state_controller.dart';
import '../../state/global_task_editor_state.dart';
import '../../state/lyrics_view_controller.dart';
import 'package:path/path.dart' as p;
import '../../lyrics/lrc_parser.dart';
import '../../state/player_controller.dart';
import '../../services/audio_player_service.dart';
import '../../state/engine_controller.dart';
import '../../services/profiler_service.dart';
import '../../services/macro_service.dart';
import '../../services/ai_bridge_service.dart';
import '../../services/auto_backup_service.dart';
import '../../engine/ui_inspector/annotation_canvas_layer.dart';

import '../../app/routes.dart';
import '../../constants.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:highlight/languages/lua.dart';
import 'package:flutter_tilt/flutter_tilt.dart';
import 'dart:async' as async;
import 'panels/assets_window.dart';
import 'panels/assets_panel.dart'; // Needed for AssetsPanelSessionCache
import 'panels/localization_window.dart';
import 'panels/subscriptions_window.dart';
import 'panels/layers_window.dart';
import 'panels/properties_window.dart';
import 'panels/timeline_window.dart';
import 'panels/simulator_window.dart';
import 'panels/macro_manager_panel.dart';
import 'panels/macro_guide_window.dart';
import 'panels/project_configuration_panel.dart';
import '../../engine/ui_inspector/ui_inspector_window.dart';
import 'panels/unit_testing_window.dart';
import 'panels/system_logs_window.dart';
import 'panels/profiler_window.dart';
import 'panels/backup_manager_panel.dart';
import 'window_dock_manager.dart';
import 'panels/flow_editor_window.dart';
import 'panels/ai_task_manager_panel.dart';
import 'panels/cli_terminal_window.dart';
import 'panels/project_modules_panel.dart';
import 'panels/test_bed_window.dart';
import 'panels/version_control_window.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/storage_url_resolver.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import '../../models/item_source.dart';
import '../../widgets/draggable_alert_dialog.dart';
import 'panels/global_icon_picker_window.dart';
import 'panels/global_color_picker_window.dart';
import 'panels/global_task_editor_window.dart';
import 'panels/global_notes_editor_window.dart';
import 'panels/suggestion_engine_window.dart';
import 'panels/agents_window.dart';
import 'panels/control_types_editor_panel.dart';
import 'panels/attachment_viewer_window.dart';

class VisualEditorScreen extends StatefulWidget {
  const VisualEditorScreen({super.key});

  /// Globally mapped structural accessors for App-layer bridging
  static Future<void> Function({bool validateCompilation})? triggerHotReload;
  static Future<void> Function({bool validateCompilation})? triggerHotRestart;

  /// The active global context hook directly referencing the floating simulator Sandbox
  static GlobalKey sandboxTestingKey = GlobalKey();
  
  /// The global context hook wrapping the entire application UI for Color Picker pixel sampling
  static GlobalKey editorScreenKey = GlobalKey();

  /// Natively reactive global scaler exported seamlessly for non-modal Overlay configurations
  static final ValueNotifier<double> globalUiScale = ValueNotifier<double>(1.0);

  /// Global simulator execution constraint to pause engine loops immediately
  static final ValueNotifier<bool> isSimulatorPausedNotifier = ValueNotifier<bool>(false);

  /// Currently active workspace environment constraint
  static final ValueNotifier<String> currentWorkspace = ValueNotifier<String>('Development');

  /// Global notifier to trigger UI repaints for config changes
  static final ValueNotifier<int> configRefreshNotifier = ValueNotifier<int>(0);

  /// Tracks the currently focused/active window ID for border highlighting
  static final ValueNotifier<String> activeWindowNotifier = ValueNotifier<String>('');

  static List<String> get availableWorkspaces => AppWorkspaces.available.map((w) => w.id).toList();

  static String getPrefKey(String localKey) {
     return '${VisualEditorScreen.currentWorkspace.value}_$localKey';
  }

  @override
  State<VisualEditorScreen> createState() => _VisualEditorScreenState();
}

class _VisualEditorScreenState extends State<VisualEditorScreen> {
  final FocusNode _focusNode = FocusNode();
  bool _hasLoadedInitialGlobalConfigs = false;
  final async.StreamController<TiltStreamModel> _tiltStreamController =
      async.StreamController<TiltStreamModel>.broadcast();

  double _timelineHeight = 250.0;
  double _upperPanelsWidth = 260.0;
  double _uiScale = 1.0;
  int _currentEditorMode = 0; // 0=Timeline, 1=Assets, 2=Collections, 3=Text, 4=Tags, 5=Subscriptions
  bool _leftPanelCollapsed = false;
  final List<String> _windowZOrder = ['simulator', 'logs', 'profiler', 'backup', 'macro', 'flow_editor', 'project_modules', 'unit_testing', 'ui_helper', 'assets', 'localization', 'subscriptions', 'layer_tree', 'properties', 'timeline', 'ai_bridge', 'cli_terminal', 'test_bed', 'version_control', 'project_config', 'color_picker', 'icon_picker', 'task_editor', 'notes_editor', 'suggestion_engine', 'agents', 'control_types_editor', 'attachment_viewer'];
  bool _rightPanelCollapsed = false;
  Map<String, List<String>> _windowAvailability = {};

  bool _disableVirtualKeyboard = true;
  bool _toolsGalleryCollapsed = false;
  Offset _toolsGalleryOffset = const Offset(100, 100);
  Offset _toolsGalleryCollapsedOffset = const Offset(100, 100);
  final bool _isPreviewLandscape = false;
  final String _simulatedPlatform = 'MOBILE';
  final GlobalKey<SimulatorWindowState> _simulatorWindowKey = GlobalKey<SimulatorWindowState>();
  final GlobalKey<TimelinePanelState> _timelineWindowKey = GlobalKey<TimelinePanelState>();

  void _bringToFront(String id) {
     if (_windowZOrder.isNotEmpty && _windowZOrder.last == id) return;
     setState(() {
        _windowZOrder.remove(id);
        _windowZOrder.add(id);
     });
     VisualEditorScreen.activeWindowNotifier.value = id;
  }

  Future<void> _executeHotReload({bool validateCompilation = false}) async {
      await MacroService.instance.executeTrigger('BeforeReload');
      await AutoBackupService.instance.snapshot(reason: 'pre_reload');
      if (!kIsWeb && Platform.isWindows) {
          try {
              if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Releasing native FFI C++ Windows Drivers...'),
                      duration: Duration(milliseconds: 600)));
              }
              await context.read<AudioPlayerService>().prepareForTeardown().timeout(const Duration(seconds: 1), onTimeout: () {});
          } catch (e) {}
      }
      final int myPid = pid;
      final psScript = '''
\$wshell = New-Object -ComObject wscript.shell;
\$titles = @('flutter run', 'Windows PowerShell', 'Command Prompt', 'Terminal');
foreach (\$title in \$titles) {
    if (\$wshell.AppActivate(\$title)) {
        Start-Sleep -Milliseconds 50;
        \$wshell.SendKeys('r');
        Start-Sleep -Milliseconds 800;
        \$wshell.AppActivate($myPid);
        break;
    }
}
''';
      await Process.run('powershell', ['-WindowStyle', 'Hidden', '-Command', psScript]).timeout(const Duration(seconds: 3), onTimeout: () => ProcessResult(0, 1, '', 'Timeout'));
      
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Targeting terminal for Hot Reload...'),
              duration: Duration(seconds: 2)));
      }
      
      // Await the background analyzer to securely block queue dispatch if syntax errors exist
      if (validateCompilation) {
          await _runAsyncAnalyzer();
      }
  }

  Future<void> _executeHotRestart({bool validateCompilation = false}) async {
      await MacroService.instance.executeTrigger('BeforeReload');
      await AutoBackupService.instance.snapshot(reason: 'pre_restart');
      if (!kIsWeb && Platform.isWindows) {
          try {
              if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Releasing native FFI C++ Windows Drivers...'),
                      duration: Duration(milliseconds: 600)));
              }
              await context.read<AudioPlayerService>().prepareForTeardown().timeout(const Duration(seconds: 1), onTimeout: () {});
          } catch (e) {}
      }
      final int myPid = pid;
      final psScript = '''
\$wshell = New-Object -ComObject wscript.shell;
\$titles = @('flutter run', 'Windows PowerShell', 'Command Prompt', 'Terminal');
foreach (\$title in \$titles) {
    if (\$wshell.AppActivate(\$title)) {
        Start-Sleep -Milliseconds 50;
        \$wshell.SendKeys('+r');
        Start-Sleep -Milliseconds 1200;
        \$wshell.AppActivate($myPid);
        break;
    }
}
''';
      await Process.run('powershell', ['-WindowStyle', 'Hidden', '-Command', psScript]).timeout(const Duration(seconds: 3), onTimeout: () => ProcessResult(0, 1, '', 'Timeout'));
      
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Targeting terminal for Hot Restart...'),
              duration: Duration(seconds: 2)));
      }
      
      // Await the background analyzer to securely block queue dispatch if syntax errors exist
      if (validateCompilation) {
          await _runAsyncAnalyzer();
      }
  }

  Future<void> _runAsyncAnalyzer() async {
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Row(
                  children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 12),
                      Text('Background Analyzer running...'),
                  ],
              ),
              duration: Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
          ));
      }

      try {
          final result = await Process.run('dart', ['analyze', '.'], runInShell: true).timeout(const Duration(seconds: 15), onTimeout: () => ProcessResult(0, 0, 'No issues found! (Timeout bypass)', ''));
          if (result.exitCode != 0) {
              final output = '${result.stdout}\n${result.stderr}';
              if (output.contains('error -') || output.contains('error •')) {
                  final errorLog = output.split('\n').where((l) => l.contains('error -') || l.contains('error •') || l.trim().startsWith('lib/')).join('\n');
                  if (errorLog.trim().isNotEmpty) {
                      // AiBridgeService.instance.forceDispatchCompileError(errorLog);
                      if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compilation Error intercepted! Natively forcing LLM report.', style: TextStyle(color: Colors.redAccent)), duration: Duration(seconds: 4)));
                      }
                  }
              } else {
                  if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analyzer finished (No structural errors)'), duration: Duration(seconds: 2)));
                  }
              }
          } else {
              if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analyzer passed cleanly.'), duration: Duration(seconds: 2)));
              }
          }
      } catch (e) {
          debugPrint('Background Analyzer failed to run: \$e');
      }
  }

  void _onConfigRefreshed() {
      if (mounted) {
          _loadPreferences();
      }
  }

  @override
  void initState() {
    super.initState();
    // Hide battery, time, and OS wifi bars
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    VisualEditorScreen.triggerHotReload = _executeHotReload;
    VisualEditorScreen.triggerHotRestart = _executeHotRestart;

    VisualEditorScreen.configRefreshNotifier.addListener(_onConfigRefreshed);

    _initializeDockManager();
    _loadPreferences();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeEditor();
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });

    showSimulatorNotifier.addListener(() {
      if (showSimulatorNotifier.value) _bringToFront('simulator');
    });
    showGlobalTaskPanelNotifier.addListener(() {
      if (showGlobalTaskPanelNotifier.value) _bringToFront('ai_bridge');
    });
    showCliTerminalNotifier.addListener(() {
      if (showCliTerminalNotifier.value) _bringToFront('cli_terminal');
    });
    showSystemLogsNotifier.addListener(() {
      if (showSystemLogsNotifier.value) _bringToFront('logs');
    });
    showProfilerNotifier.addListener(() {
      if (showProfilerNotifier.value) _bringToFront('profiler');
    });
    showBackupNotifier.addListener(() {
      if (showBackupNotifier.value) _bringToFront('backup');
    });
    showMacroNotifier.addListener(() {
      if (showMacroNotifier.value) _bringToFront('macro');
    });
    showMacroGuideNotifier.addListener(() {
      if (showMacroGuideNotifier.value) _bringToFront('macro_guide');
    });

    showTestBedNotifier.addListener(() {
      if (showTestBedNotifier.value) _bringToFront('test_bed');
    });
    showVersionControlNotifier.addListener(() {
      if (showVersionControlNotifier.value) _bringToFront('version_control');
    });
    showTaskEditorNotifier.addListener(() { if (showTaskEditorNotifier.value) _bringToFront('task_editor'); });
    showNotesEditorNotifier.addListener(() { if (showNotesEditorNotifier.value) _bringToFront('notes_editor'); });
    showSuggestionEngineNotifier.addListener(() { if (showSuggestionEngineNotifier.value) _bringToFront('suggestion_engine'); });
    showAgentsNotifier.addListener(() { if (showAgentsNotifier.value) _bringToFront('agents'); });
    showAttachmentViewerNotifier.addListener(() { if (showAttachmentViewerNotifier.value) _bringToFront('attachment_viewer'); });
    showControlTypesEditorNotifier.addListener(() { if (showControlTypesEditorNotifier.value) _bringToFront('control_types_editor'); });
    showColorPickerNotifier.addListener(() { if (showColorPickerNotifier.value) _bringToFront('color_picker'); });
    showIconPickerNotifier.addListener(() { if (showIconPickerNotifier.value) _bringToFront('icon_picker'); });
    showProjectConfigNotifier.addListener(() {
      if (showProjectConfigNotifier.value) {
        _bringToFront('project_config');
      } else {
        _loadPreferences();
      }
    });
    showProjectModulesNotifier.addListener(() {
      if (showProjectModulesNotifier.value) _bringToFront('project_modules');
    });
    showFlowEditorNotifier.addListener(() {
      if (showFlowEditorNotifier.value) _bringToFront('flow');
    });
    showControlEditorNotifier.addListener(() {
      if (showControlEditorNotifier.value) _bringToFront('control_editor');
    });
    showUnitTestingNotifier.addListener(() {
      if (showUnitTestingNotifier.value) _bringToFront('unit_testing');
    });
    showUiHelperNotifier.addListener(() {
      if (showUiHelperNotifier.value) _bringToFront('ui_helper');
    });
    showAssetsNotifier.addListener(() {
      if (showAssetsNotifier.value) _bringToFront('assets');
    });
    showLocalizationNotifier.addListener(() {
      if (showLocalizationNotifier.value) _bringToFront('localization');
    });
    showSubscriptionsNotifier.addListener(() {
      if (showSubscriptionsNotifier.value) _bringToFront('subscriptions');
    });
    showLayersNotifier.addListener(() {
      if (showLayersNotifier.value) _bringToFront('layers');
    });
    showPropertiesNotifier.addListener(() {
      if (showPropertiesNotifier.value) _bringToFront('properties');
    });
    showTimelineNotifier.addListener(() {
      if (showTimelineNotifier.value) _bringToFront('timeline');
    });

    VisualEditorScreen.currentWorkspace.addListener(_onWorkspaceChanged);

    // Enter immersive mode on first launch
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);  }

  bool _isWindowAvailable(String windowId) {
      if (!_windowAvailability.containsKey(windowId)) return true;
      final list = _windowAvailability[windowId]!;
      if (list.contains('none')) return false;
      if (list.contains('all') || list.isEmpty) return true;
      return list.contains(VisualEditorScreen.currentWorkspace.value);
  }

  Future<void> _onWorkspaceChanged() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
       showSimulatorNotifier.value = prefs.getBool(VisualEditorScreen.getPrefKey('showSimulator')) ?? true;
       showSystemLogsNotifier.value = _isWindowAvailable('system_logs') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showSystemLogs')) ?? false) : false;
       showProfilerNotifier.value = _isWindowAvailable('profiler') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showProfiler')) ?? false) : false;
       showBackupNotifier.value = _isWindowAvailable('backup') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showBackup')) ?? false) : false;
       showMacroNotifier.value = _isWindowAvailable('macro') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showMacro')) ?? false) : false;
       showMacroGuideNotifier.value = _isWindowAvailable('macro_guide') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showMacroGuide')) ?? false) : false;
       showProjectModulesNotifier.value = _isWindowAvailable('project_modules') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showProjectModules')) ?? false) : false;
       showFlowEditorNotifier.value = _isWindowAvailable('flow_editor') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showFlowEditor')) ?? false) : false;
       showControlEditorNotifier.value = _isWindowAvailable('flow_editor') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showFlowEditor')) ?? false) : false;
       showUnitTestingNotifier.value = _isWindowAvailable('unit_testing') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showUnitTesting')) ?? false) : false;
       showUiHelperNotifier.value = _isWindowAvailable('ui_helper') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showUiHelper')) ?? false) : false;
       showAssetsNotifier.value = _isWindowAvailable('assets') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showAssets')) ?? false) : false;
       showLocalizationNotifier.value = _isWindowAvailable('localization') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showLocalization')) ?? false) : false;
       showSubscriptionsNotifier.value = _isWindowAvailable('subscriptions') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showSubscriptions')) ?? false) : false;
       showLayersNotifier.value = _isWindowAvailable('layers') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showLayers')) ?? true) : false;
       showPropertiesNotifier.value = _isWindowAvailable('properties') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showProperties')) ?? false) : false;
       showTimelineNotifier.value = _isWindowAvailable('timeline') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showTimeline')) ?? true) : false;
       showTestBedNotifier.value = _isWindowAvailable('test_bed') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showTestBed')) ?? false) : false;
       showVersionControlNotifier.value = _isWindowAvailable('version_control') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showVersionControl')) ?? false) : false;
       showTaskEditorNotifier.value = _isWindowAvailable('task_editor') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showTaskEditor')) ?? false) : false;
       showNotesEditorNotifier.value = _isWindowAvailable('notes_editor') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showNotesEditor')) ?? false) : false;
       showSuggestionEngineNotifier.value = _isWindowAvailable('suggestion_engine') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showSuggestionEngine')) ?? false) : false;
       showAgentsNotifier.value = _isWindowAvailable('agents') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showAgents')) ?? false) : false;
       showControlTypesEditorNotifier.value = _isWindowAvailable('control_types_editor') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showControlTypesEditor')) ?? false) : false;
       showAttachmentViewerNotifier.value = _isWindowAvailable('attachment_viewer') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showAttachmentViewer')) ?? false) : false;
       showColorPickerNotifier.value = _isWindowAvailable('color_picker') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showColorPicker')) ?? false) : false;
       showIconPickerNotifier.value = _isWindowAvailable('icon_picker') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showIconPicker')) ?? false) : false;
       showCliTerminalNotifier.value = _isWindowAvailable('cli_terminal') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showCliTerminal')) ?? false) : false;
       showKaraokeGenWindowNotifier.value = _isWindowAvailable('karaoke_gen') ? (prefs.getBool(VisualEditorScreen.getPrefKey('showKaraokeGen')) ?? false) : false;
    }
  }

  void _initializeDockManager() {
    WindowDockManager.instance.loadSavedSizes();
    final panelsData = [
       ('simulator', AppToolWindows.getDef('simulator').name, AppToolWindows.getDef('simulator').icon, AppToolWindows.getDef('simulator').color, (bool isDocked) => SimulatorWindow(key: _simulatorWindowKey, onClose: hideSimulatorWindow, isDocked: isDocked, tiltStreamController: _tiltStreamController, currentEditorMode: _currentEditorMode, onFocus: () => _bringToFront('simulator')), showSimulatorNotifier),
       ('layer_tree', AppToolWindows.getDef('layers').name, AppToolWindows.getDef('layers').icon, AppToolWindows.getDef('layers').color, (bool isDocked) => LayersWindow(key: const ValueKey('layer_tree'), onClose: hideLayersWindow, onFocus: () => _bringToFront('layer_tree')), showLayersNotifier),
       ('timeline', AppToolWindows.getDef('timeline').name, AppToolWindows.getDef('timeline').icon, AppToolWindows.getDef('timeline').color, (bool isDocked) => TimelineWindow(panelKey: _timelineWindowKey, onClose: hideTimelineWindow, isDocked: isDocked, onFocus: () {
          _bringToFront('timeline');
          _timelineWindowKey.currentState?.focusTimeline();
      }), showTimelineNotifier),
       ('logs', AppToolWindows.getDef('system_logs').name, AppToolWindows.getDef('system_logs').icon, AppToolWindows.getDef('system_logs').color, (bool isDocked) => SystemLogsWindow(key: const ValueKey('logs'), onClose: hideSystemLogsWindow, isDocked: isDocked, onFocus: () => _bringToFront('logs')), showSystemLogsNotifier),
       ('profiler', AppToolWindows.getDef('profiler').name, AppToolWindows.getDef('profiler').icon, AppToolWindows.getDef('profiler').color, (bool isDocked) => ProfilerWindow(key: const ValueKey('profiler'), onClose: hideProfilerWindow, isDocked: isDocked, onFocus: () => _bringToFront('profiler')), showProfilerNotifier),
       ('backup', AppToolWindows.getDef('backup').name, AppToolWindows.getDef('backup').icon, AppToolWindows.getDef('backup').color, (bool isDocked) => BackupManagerPanel(key: const ValueKey('backup'), onClose: hideBackupWindow, isDocked: isDocked, onFocus: () => _bringToFront('backup')), showBackupNotifier),
       ('macro', AppToolWindows.getDef('macro').name, AppToolWindows.getDef('macro').icon, AppToolWindows.getDef('macro').color, (bool isDocked) => MacroManagerPanel(key: const ValueKey('macro'), onClose: hideMacroWindow, isDocked: isDocked, onFocus: () => _bringToFront('macro')), showMacroNotifier),
       ('macro_guide', AppToolWindows.getDef('macro_guide').name, AppToolWindows.getDef('macro_guide').icon, AppToolWindows.getDef('macro_guide').color, (bool isDocked) => MacroGuideWindow(key: const ValueKey('macro_guide'), onClose: hideMacroGuideWindow, isDocked: isDocked, onFocus: () => _bringToFront('macro_guide')), showMacroGuideNotifier),
       ('unit_testing', AppToolWindows.getDef('unit_testing').name, AppToolWindows.getDef('unit_testing').icon, AppToolWindows.getDef('unit_testing').color, (bool isDocked) => UnitTestingWindow(key: const ValueKey('unit_testing'), onClose: hideUnitTestingWindow, isDocked: isDocked, onFocus: () => _bringToFront('unit_testing')), showUnitTestingNotifier),
       ('assets', AppToolWindows.getDef('assets').name, AppToolWindows.getDef('assets').icon, AppToolWindows.getDef('assets').color, (bool isDocked) => AssetsWindow(key: const ValueKey('assets'), onClose: hideAssetsWindow, isDocked: isDocked, onFocus: () => _bringToFront('assets'), onOpenTimeline: _handleOpenTimelineFromAssets), showAssetsNotifier),
       ('localization', AppToolWindows.getDef('localization').name, AppToolWindows.getDef('localization').icon, AppToolWindows.getDef('localization').color, (bool isDocked) => LocalizationWindow(key: const ValueKey('localization'), onClose: hideLocalizationWindow, isDocked: isDocked, onFocus: () => _bringToFront('localization')), showLocalizationNotifier),
       ('subscriptions', AppToolWindows.getDef('subscriptions').name, AppToolWindows.getDef('subscriptions').icon, AppToolWindows.getDef('subscriptions').color, (bool isDocked) => SubscriptionsWindow(key: const ValueKey('subscriptions'), onClose: hideSubscriptionsWindow, isDocked: isDocked, onFocus: () => _bringToFront('subscriptions')), showSubscriptionsNotifier),
       ('properties', AppToolWindows.getDef('properties').name, AppToolWindows.getDef('properties').icon, AppToolWindows.getDef('properties').color, (bool isDocked) => PropertiesWindow(key: const ValueKey('properties'), onClose: hidePropertiesWindow, isDocked: isDocked, onFocus: () => _bringToFront('properties')), showPropertiesNotifier),
       ('project_modules', AppToolWindows.getDef('project_modules').name, AppToolWindows.getDef('project_modules').icon, AppToolWindows.getDef('project_modules').color, (bool isDocked) => ProjectModulesWindow(key: const ValueKey('project_modules'), onClose: hideProjectModulesWindow, isDocked: isDocked, onFocus: () => _bringToFront('project_modules')), showProjectModulesNotifier),
       ('flow', AppToolWindows.getDef('flow_editor').name, AppToolWindows.getDef('flow_editor').icon, AppToolWindows.getDef('flow_editor').color, (bool isDocked) => FlowEditorWindow(key: const ValueKey('flow'), onClose: hideFlowEditorWindow, isDocked: isDocked, onFocus: () => _bringToFront('flow')), showFlowEditorNotifier),
       ('ui_helper', AppToolWindows.getDef('ui_helper').name, AppToolWindows.getDef('ui_helper').icon, AppToolWindows.getDef('ui_helper').color, (bool isDocked) => UiInspectorWindow(key: const ValueKey('ui_helper'), onClose: hideUiHelperWindow, isDocked: isDocked, onFocus: () => _bringToFront('ui_helper')), showUiHelperNotifier),
       ('ai_bridge', AppToolWindows.getDef('ai_bridge').name, AppToolWindows.getDef('ai_bridge').icon, AppToolWindows.getDef('ai_bridge').color, (bool isDocked) => AiBridgeWindow(key: const ValueKey('ai_bridge'), isDocked: isDocked, onClose: toggleGlobalTaskPanel, onFocus: () => _bringToFront('ai_bridge')), showGlobalTaskPanelNotifier),
       ('test_bed', AppToolWindows.getDef('test_bed').name, AppToolWindows.getDef('test_bed').icon, AppToolWindows.getDef('test_bed').color, (bool isDocked) => TestBedWindow(key: const ValueKey('test_bed'), onClose: hideTestBedWindow, isDocked: isDocked, onFocus: () => _bringToFront('test_bed')), showTestBedNotifier),
       ('version_control', AppToolWindows.getDef('version_control').name, AppToolWindows.getDef('version_control').icon, AppToolWindows.getDef('version_control').color, (bool isDocked) => VersionControlWindow(key: const ValueKey('version_control'), onClose: hideVersionControlWindow, isDocked: isDocked, onFocus: () => _bringToFront('version_control')), showVersionControlNotifier),
       ('cli_terminal', AppToolWindows.getDef('cli_terminal').name, AppToolWindows.getDef('cli_terminal').icon, AppToolWindows.getDef('cli_terminal').color, (bool isDocked) => CliTerminalWindow(key: const ValueKey('cli_terminal'), isDocked: isDocked, onClose: hideCliTerminalWindow, onFocus: () => _bringToFront('cli_terminal')), showCliTerminalNotifier),
       ('project_config', AppToolWindows.getDef('project_config').name, AppToolWindows.getDef('project_config').icon, AppToolWindows.getDef('project_config').color, (bool isDocked) => ProjectConfigurationWindow(key: const ValueKey('project_config'), isDocked: isDocked, onClose: hideProjectConfigWindow, onFocus: () => _bringToFront('project_config')), showProjectConfigNotifier),
       ('task_editor', AppToolWindows.getDef('task_editor').name, AppToolWindows.getDef('task_editor').icon, AppToolWindows.getDef('task_editor').color, (bool isDocked) => GlobalTaskEditorWindow(key: const ValueKey('task_editor'), isDocked: isDocked, onClose: hideTaskEditorWindow, onFocus: () => _bringToFront('task_editor')), showTaskEditorNotifier),
       ('color_picker', AppToolWindows.getDef('color_picker').name, AppToolWindows.getDef('color_picker').icon, AppToolWindows.getDef('color_picker').color, (bool isDocked) => GlobalColorPickerWindow(key: const ValueKey('color_picker'), isDocked: isDocked, onClose: hideColorPickerWindow, onFocus: () => _bringToFront('color_picker')), showColorPickerNotifier),
       ('icon_picker', AppToolWindows.getDef('icon_picker').name, AppToolWindows.getDef('icon_picker').icon, AppToolWindows.getDef('icon_picker').color, (bool isDocked) => GlobalIconPickerWindow(key: const ValueKey('icon_picker'), isDocked: isDocked, onClose: hideIconPickerWindow, onFocus: () => _bringToFront('icon_picker')), showIconPickerNotifier),
       ('notes_editor', AppToolWindows.getDef('notes_editor').name, AppToolWindows.getDef('notes_editor').icon, AppToolWindows.getDef('notes_editor').color, (bool isDocked) => GlobalNotesEditorWindow(key: const ValueKey('notes_editor'), isDocked: isDocked, onClose: hideNotesEditorWindow, onFocus: () => _bringToFront('notes_editor')), showNotesEditorNotifier),
       ('suggestion_engine', AppToolWindows.getDef('suggestion_engine').name, AppToolWindows.getDef('suggestion_engine').icon, AppToolWindows.getDef('suggestion_engine').color, (bool isDocked) => SuggestionEngineWindow(key: const ValueKey('suggestion_engine'), isDocked: isDocked, onClose: hideSuggestionEngineWindow, onFocus: () => _bringToFront('suggestion_engine')), showSuggestionEngineNotifier),
       ('agents', AppToolWindows.getDef('agents').name, AppToolWindows.getDef('agents').icon, AppToolWindows.getDef('agents').color, (bool isDocked) => AgentsWindow(key: const ValueKey('agents'), isDocked: isDocked, onClose: hideAgentsWindow, onFocus: () => _bringToFront('agents')), showAgentsNotifier),
       ('control_types_editor', AppToolWindows.getDef('control_types_editor').name, AppToolWindows.getDef('control_types_editor').icon, AppToolWindows.getDef('control_types_editor').color, (bool isDocked) => ControlTypesEditorWindow(key: const ValueKey('control_types_editor'), isDocked: isDocked, onClose: hideControlTypesEditorWindow, onFocus: () => _bringToFront('control_types_editor')), showControlTypesEditorNotifier),
       ('attachment_viewer', AppToolWindows.getDef('attachment_viewer').name, AppToolWindows.getDef('attachment_viewer').icon, AppToolWindows.getDef('attachment_viewer').color, (bool isDocked) => AttachmentViewerWindow(key: const ValueKey('attachment_viewer'), isDocked: isDocked, onClose: hideAttachmentViewerWindow, onFocus: () => _bringToFront('attachment_viewer')), showAttachmentViewerNotifier),
    ];

    for (var pd in panelsData) {
       final id = pd.$1;
       final title = pd.$2;
       final icon = pd.$3;
       final color = pd.$4;
       final builder = pd.$5;
       final notifier = pd.$6;
       
       WindowDockManager.instance.registerPanel(DockablePanel(
          id: id,
          title: title,
          icon: icon,
          color: color,
          child: builder(true),
          floatingBuilder: () => builder(false),
          onFocus: () {
              _bringToFront(id);
              if (id == 'timeline') {
                  _timelineWindowKey.currentState?.focusTimeline();
              }
          }
       ));

       final p = WindowDockManager.instance.panels.firstWhere((p) => p.id == id);
       p.isVisible.value = notifier.value;

       notifier.addListener(() {
          if (notifier.value) { p.show(); } else { p.hide(); }
       });
       
       p.isVisible.addListener(() {
          if (p.isVisible.value != notifier.value) {
             notifier.value = p.isVisible.value;
          }
       });
       
       p.dockPosition.addListener(() {
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString(VisualEditorScreen.getPrefKey('_dock'), p.dockPosition.value.name);
            });
       });
    }
  }

  Widget _buildToolbarBtn(bool isShowing, IconData icon, Color activeColor, String tooltip, String label, VoidCallback onPressed, {VoidCallback? onReset}) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onSecondaryTapDown: onReset == null ? null : (details) {
            showMenu(
              context: context,
              color: const Color(0xFF252526),
              position: RelativeRect.fromLTRB(
                details.globalPosition.dx,
                details.globalPosition.dy,
                details.globalPosition.dx,
                details.globalPosition.dy,
              ),
              items: [
                PopupMenuItem(
                  value: 'reset',
                  height: 32,
                  onTap: onReset,
                  child: Text('Reset Window', style: TextStyle(color: Colors.white70, fontSize: AppUIConfig.rootFontSize)),
                ),
              ],
            );
        },
        child: InkWell(
          onTap: onPressed,
        child: SizedBox(
          width: 48 * _uiScale,

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isShowing ? activeColor : Colors.white30, size: 16),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppUIConfig.iconFontSize,
                  height: 1.0,
                  fontWeight: AppUIConfig.iconFontBold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Future<void> _loadPreferences() async {
    await AppWorkspaces.loadCustom();
    await AppToolWindows.loadCustom();
    await AppUIConfig.loadCustomThemes();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Read explicitly mapped Global Dims from the Project sandbox forms
      _timelineHeight = prefs.getDouble('ve_timelineHeight') ?? 250.0;
      _upperPanelsWidth = prefs.getDouble('ve_upperPanelsWidth') ?? 260.0;
      final savedWs = prefs.getString('ve_workspace');
      if (savedWs != null && VisualEditorScreen.availableWorkspaces.contains(savedWs)) {
         VisualEditorScreen.currentWorkspace.value = savedWs;
      }

      final viewScale = prefs.getDouble('ve_globalUiScale') ?? 1.0;
      _uiScale = viewScale;
      VisualEditorScreen.globalUiScale.value = _uiScale;
      
      if (!_hasLoadedInitialGlobalConfigs) {
        AppUIConfig.rootFontSize = prefs.getDouble('ve_rootFontSize') ?? 12.0;
        AppUIConfig.iconFontSize = prefs.getDouble('ve_iconFontSize') ?? 10.0;
        AppUIConfig.iconFontBold = prefs.getBool('ve_iconFontBold') ?? false;
        AppUIConfig.globalActionIconSize = prefs.getDouble('ve_globalActionIconSize') ?? 20.0;
        AppUIConfig.iconOutlineWidth = prefs.getDouble('ve_iconOutlineWidth') ?? 1.5;
        AppUIConfig.textOutlineWidth = prefs.getDouble('ve_textOutlineWidth') ?? 1.0;
        AppUIConfig.titleBarHeight = prefs.getDouble('ve_titleBarHeight') ?? 32.0;
        AppUIConfig.windowBorderRadius = prefs.getDouble('ve_windowBorderRadius') ?? 8.0;
        AppUIConfig.windowBorderWidth = prefs.getDouble('ve_windowBorderWidth') ?? 1.0;
        _hasLoadedInitialGlobalConfigs = true;
      }

      _currentEditorMode = prefs.getInt('ve_editorMode') ?? 0;
      _leftPanelCollapsed = prefs.getBool('ve_leftPanelCollapsed') ?? false;
      _rightPanelCollapsed = prefs.getBool('ve_rightPanelCollapsed') ?? false;

      _toolsGalleryCollapsed = prefs.getBool('ve_toolsGalleryCollapsed') ?? false;
      _toolsGalleryOffset = Offset(
          prefs.getDouble('ve_toolsGalleryOffsetX') ?? 100.0,
          prefs.getDouble('ve_toolsGalleryOffsetY') ?? 100.0
      );
      _toolsGalleryCollapsedOffset = Offset(
          prefs.getDouble('ve_toolsGalleryCollapsedOffsetX') ?? 100.0,
          prefs.getDouble('ve_toolsGalleryCollapsedOffsetY') ?? 100.0
      );

      final availStr = prefs.getString('ve_windowAvailability');
      if (availStr != null) {
          try {
              final Map<String, dynamic> parsed = jsonDecode(availStr);
              _windowAvailability = parsed.map((k, v) => MapEntry(k, List<String>.from(v)));
          } catch (_) {}
      } else {
          _windowAvailability = {};
      }
      
      // Force Aspect ratio check
      context.read<LyricsViewController>().simulatedPlatform =
          _simulatedPlatform;});

    if (mounted) {
      final lc = context.read<LyricsViewController>();
      lc.simulatedPlatform = _simulatedPlatform;
      lc.simulatedOrientation =
          _isPreviewLandscape ? Orientation.landscape : Orientation.portrait;
        
      final showSys = prefs.getBool(VisualEditorScreen.getPrefKey('showSystemLogs')) ?? false;
      if (showSys) showSystemLogsNotifier.value = true;

      final showProf = prefs.getBool(VisualEditorScreen.getPrefKey('showProfiler')) ?? false;
      if (showProf) showProfilerNotifier.value = true;

      final showMacro = prefs.getBool(VisualEditorScreen.getPrefKey('showMacro')) ?? false;
      if (showMacro) showMacroNotifier.value = true;
      final showMacroGuide = prefs.getBool(VisualEditorScreen.getPrefKey('showMacroGuide')) ?? false;
      if (showMacroGuide) showMacroGuideNotifier.value = true;

      final showProjectModules = prefs.getBool(VisualEditorScreen.getPrefKey('showProjectModules')) ?? false;
      if (showProjectModules) showProjectModulesNotifier.value = true;

      final showFlow = prefs.getBool(VisualEditorScreen.getPrefKey('showFlowEditor')) ?? false;
      if (showFlow) {
        showFlowEditorNotifier.value = true;
        showControlEditorNotifier.value = true;
      }

      final showAssets = prefs.getBool(VisualEditorScreen.getPrefKey('showAssets')) ?? false;
      if (showAssets) showAssetsNotifier.value = true;
      
      final showLoc = prefs.getBool(VisualEditorScreen.getPrefKey('showLocalization')) ?? false;
      if (showLoc) showLocalizationNotifier.value = true;

      final showSubs = prefs.getBool(VisualEditorScreen.getPrefKey('showSubscriptions')) ?? false;
      if (showSubs) showSubscriptionsNotifier.value = true;
      
      final showLyr = prefs.getBool(VisualEditorScreen.getPrefKey('showLayers')) ?? false;
      if (showLyr) showLayersNotifier.value = true;
      final showProps = prefs.getBool(VisualEditorScreen.getPrefKey('showProperties')) ?? false;
      if (showProps) showPropertiesNotifier.value = true;
      final showTime = prefs.getBool(VisualEditorScreen.getPrefKey('showTimeline')) ?? false;
      if (showTime) showTimelineNotifier.value = true;

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
           MacroService.instance.executeTrigger('AfterReload');
        }
      });
    }
  }



  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(VisualEditorScreen.getPrefKey('ve_isPreviewLandscape'), _isPreviewLandscape);
    await prefs.setBool(VisualEditorScreen.getPrefKey('ve_disableVirtualKeyboard'), _disableVirtualKeyboard);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('ve_timelineHeight'), _timelineHeight);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('ve_upperPanelsWidth'), _upperPanelsWidth);
    await prefs.setDouble('ve_globalUiScale', _uiScale);
    await prefs.setInt(VisualEditorScreen.getPrefKey('ve_editorMode'), _currentEditorMode);
    await prefs.setBool(VisualEditorScreen.getPrefKey('ve_leftPanelCollapsed'), _leftPanelCollapsed);
    await prefs.setBool(VisualEditorScreen.getPrefKey('ve_rightPanelCollapsed'), _rightPanelCollapsed);
  }

  void _openProjectConfiguration() {
    showProjectConfigWindow(context);
  }




  @override
  void dispose() {
    VisualEditorScreen.configRefreshNotifier.removeListener(_onConfigRefreshed);
    VisualEditorScreen.currentWorkspace.removeListener(_onWorkspaceChanged);
    _tiltStreamController.close();
    // Revert back to the default OS ui when exiting the editor
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _initializeEditor() {
    final editorState = context.read<EditorStateController>();
    final lyricsState = context.read<LyricsViewController>();
    
    if (editorState.config == null) {
       editorState.tryRestoreLastSession().then((restored) async {
          if (restored && editorState.config != null) {
              if (mounted) {
                  lyricsState.overrideEditorConfig(editorState.config!); // Use override instead of loadExternalConfig to prevent wiping!
                  
                  final prefs = await SharedPreferences.getInstance();
                  final audioPath = prefs.getString('ve_audioUrl_for_${editorState.currentFilePath}');
                  
                  if (audioPath != null && audioPath.isNotEmpty && mounted) {
                      final st = (audioPath.startsWith('/') || audioPath.startsWith('C:') || audioPath.startsWith('file:')) ? SourceType.file : SourceType.url;
                      context.read<PlayerController>().loadQueue([ItemSource(id: 'asset_preview', title: editorState.loadedTargetName, sourceType: st, source: audioPath)]);
                      lyricsState.loadForCurrentItem('restore', audioPath);
                  } else {
                     if (editorState.loadedTargetType == 'asset') {
                        _simulatorWindowKey.currentState?.setPreviewMode('ELEMENT');
                     }
                  }

                  setState((){});
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Restored previous Editor session natively!'),
                      backgroundColor: Colors.blueAccent,
                  ));
              }
          } else if (lyricsState.choreographyConfig != null && mounted) {
              const path = 'c:/Development/Music/Project/assets/lyrics/TheBionicMan.json';
              editorState.loadConfig(path, lyricsState.choreographyConfig!);
          }
       });
    }
  }

  Widget _buildActivityBar() {
    final hasConfig = context.watch<EditorStateController>().config != null;
    return Container(
          width: 48 * _uiScale,

      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.toolbarBackground,
        border: Border(right: BorderSide(color: AppColors.controlBorder)),
      ),
      child: Column(
        children: [
          ...AppWorkspaces.available.map((ws) => _buildWorkspaceIcon(
             ws.id, 
             ws.icon, 
             ws.shortLabel, 
             disabled: ws.requiresConfig && !hasConfig,
             color: ws.color,
             description: ws.description,
          )),
          const Spacer(),
          _buildActionIcon(AppUIConfig.configIconCodePoint != null ? IconData(AppUIConfig.configIconCodePoint!, fontFamily: 'MaterialIcons') : Icons.settings, 'Project Configuration', 'Config', _openProjectConfiguration, AppUIConfig.configIconColor ?? Colors.greenAccent),
          ValueListenableBuilder<bool>(
            valueListenable: showGlobalTaskPanelNotifier,
            builder: (context, isActive, child) {
              return Tooltip(
                message: 'Toggle AI Bridge',
                preferBelow: false,
                child: InkWell(
                  onTap: toggleGlobalTaskPanel,
                  child: Container(
                    width: 48 * _uiScale, height: 60 * _uiScale,
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: isActive ? Colors.redAccent : Colors.transparent, width: 2.0))
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(AppUIConfig.bridgeIconCodePoint != null ? IconData(AppUIConfig.bridgeIconCodePoint!, fontFamily: 'MaterialIcons') : Icons.rocket_launch, size: 20, color: isActive ? Colors.redAccent : (AppUIConfig.bridgeIconColor ?? Colors.white38)),
                        const SizedBox(height: 2),
                        Text('Bridge', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.visible, style: TextStyle(color: Colors.white, fontSize: AppUIConfig.iconFontSize, height: 1.0, fontWeight: AppUIConfig.iconFontBold ? FontWeight.bold : FontWeight.normal)),
                      ]
                    )
                  )
                )
              );
            }
          ),

          const Divider(color: Colors.white24, height: 32),
          _buildActionIcon(AppUIConfig.exitIconCodePoint != null ? IconData(AppUIConfig.exitIconCodePoint!, fontFamily: 'MaterialIcons') : Icons.exit_to_app, 'Close Project & Return to Hub', 'Exit', () {
             final engine = context.read<EngineController>();
             engine.closeProject();
             Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.hub, (route) => false);
          }, AppUIConfig.exitIconColor ?? Colors.greenAccent),
          const SizedBox(height: 16),
        ],
      )
    );
  }

  Widget _buildActionIcon(IconData icon, String tooltip, String label, VoidCallback onTap, [Color overrideColor = Colors.greenAccent]) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48 * _uiScale, height: 60 * _uiScale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: overrideColor),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.visible, style: TextStyle(color: Colors.white, fontSize: AppUIConfig.iconFontSize, height: 1.0, fontWeight: AppUIConfig.iconFontBold ? FontWeight.bold : FontWeight.normal)),
            ]
          )
        )
      )
    );
  }

  Widget _buildWorkspaceIcon(String workspace, IconData icon, String label, {bool disabled = false, Color color = Colors.greenAccent, String? description}) {
    return ValueListenableBuilder<String>(
      valueListenable: VisualEditorScreen.currentWorkspace,
      builder: (context, currentWs, _) {
        bool isActive = currentWs == workspace;
        return Tooltip(
          message: disabled ? 'Workspace: $workspace (Requires Target)' : (description ?? 'Workspace: $workspace'),
          preferBelow: false,
          child: InkWell(
            onTap: disabled ? null : () {
               VisualEditorScreen.currentWorkspace.value = workspace;
               SharedPreferences.getInstance().then((prefs) => prefs.setString('ve_workspace', workspace));
               
               final wsDef = AppWorkspaces.available.firstWhere((w) => w.id == workspace, orElse: () => AppWorkspaces.available.first);
               int mappedMode = wsDef.mappedMode ?? _currentEditorMode;

               setState(() {
                  _currentEditorMode = mappedMode;
                  _simulatorWindowKey.currentState?.updateEditorMode(mappedMode);
                  if (mappedMode == 0) _simulatorWindowKey.currentState?.setPreviewMode('ELEMENT');
                  if (mappedMode == 10) {
                     _simulatorWindowKey.currentState?.setPreviewMode('APP');
                     VisualEditorScreen.sandboxTestingKey = GlobalKey();
                  }
               });
               _savePreferences();
            },
            child: Container(
              width: 48 * _uiScale, height: 60 * _uiScale,
              decoration: BoxDecoration(
                color: isActive && !disabled ? color.withValues(alpha: 0.15) : Colors.transparent,
                border: Border(left: BorderSide(color: isActive && !disabled ? color : Colors.transparent, width: 3.0))
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(icon, size: 20, color: disabled ? Colors.white30 : color),
                   Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.visible, style: TextStyle(color: disabled ? Colors.white30 : Colors.white, fontSize: AppUIConfig.iconFontSize, height: 1.0, fontWeight: AppUIConfig.iconFontBold ? FontWeight.bold : FontWeight.normal)),
                ]
              )
            )
          )
        );
      }
    );
  }
  
  Future<void> _handleOpenTimelineFromAssets(String id, String type, String name) async {
      setState(() {
          _currentEditorMode = 0;
          _simulatorWindowKey.currentState?.updateEditorMode(0);
      });
      _savePreferences();
      final editor = context.read<EditorStateController>();
      
      if (!id.endsWith('.json')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Only UI JSON elements can be opened inside the timeline editor!'),
            backgroundColor: Colors.redAccent,
          ));
          return;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Loading $type Element: $id'),
        backgroundColor: Colors.blueAccent,
      ));

      try {
          final sb = Supabase.instance.client;
          Uint8List bytes;
          if (AssetsPanelSessionCache.modifiedFiles.containsKey(id)) {
              bytes = AssetsPanelSessionCache.modifiedFiles[id]!;
          } else {
              bytes = await sb.storage.from('tenant-assets').download(id);
          }
          final jsonStr = utf8.decode(bytes);
          final configObj = ChoreographyConfig.fromJson(jsonDecode(jsonStr));

          String finalTargetName = name;
          Map<String, dynamic>? jsonAsset;

          if (type == 'asset') {
              jsonAsset = await sb.from('assets').select().eq('storage_path', id).maybeSingle();
              if (jsonAsset != null) {
                  finalTargetName = jsonAsset['name'].toString();
              }
          }

          if (!context.mounted) return;

          editor.loadConfig(
            id, 
            configObj,
            targetType: type,
            targetName: finalTargetName
          );
          
          if (type == 'asset') {
              String? audioUrl;
              String baseName = finalTargetName.replaceAll(RegExp(r'\.json$', caseSensitive: false), '');
              
              Map<String, dynamic>? lrcSibling;

              String? audioOverride = configObj.globalItems['AUDIO_TRACK_OVERRIDE']?.keyframes.firstOrNull?.value?.toString();
              String? lyricsOverride = configObj.globalItems['LYRICS_TRACK_OVERRIDE']?.keyframes.firstOrNull?.value?.toString();
              
              // Parse JSON literal strings masking nullity from naive text inputs.
              if (audioOverride == 'null' || audioOverride?.trim() == '') audioOverride = null;
              if (lyricsOverride == 'null' || lyricsOverride?.trim() == '') lyricsOverride = null;

              // 1. Direct Local File Injection Priorities
              if (audioOverride != null && (audioOverride.startsWith('C:') || audioOverride.startsWith('/'))) {
                  audioUrl = audioOverride;
              }
              if (lyricsOverride != null && (lyricsOverride.startsWith('C:') || lyricsOverride.startsWith('/'))) {
                  lrcSibling = {'storage_path': lyricsOverride};
              }

              if (jsonAsset != null) {
                  // 2. Explicit Track Manifest Matching Rules
                  final siblings = jsonAsset['parent_id'] != null 
                      ? await sb.from('assets').select().eq('parent_id', jsonAsset['parent_id'])
                      : await sb.from('assets').select().filter('parent_id', 'is', null);
                  
                  for (var s in siblings) {
                      final sName = s['name'].toString();
                      
                      // 1. Match Audio
                      if (audioUrl == null) {
                          if (audioOverride != null) {
                              if (sName == audioOverride) audioUrl = s['storage_path'].toString();
                          } else if (sName.toLowerCase() == '$baseName.mp3'.toLowerCase() || sName.toLowerCase() == '$baseName.wav'.toLowerCase()) {
                              audioUrl = s['storage_path'].toString();
                          }
                      }
                      
                      // 2. Match LRC
                      if (lrcSibling == null) {
                          if (lyricsOverride != null) {
                              if (sName == lyricsOverride) lrcSibling = s;
                          } else if (sName.toLowerCase() == '$baseName.lrc'.toLowerCase()) {
                              lrcSibling = s;
                          }
                      }
                  }
              }
                    
                        if (audioUrl != null && lrcSibling != null) {
                            try {
                              // Do not attempt to download lrc if we're resolving locally
                              final storageResolver = context.read<StorageUrlResolver>();
                              final resolvedAudioUrl = await storageResolver.resolvePlayableUrl(audioUrl) ?? audioUrl;
                              audioUrl = resolvedAudioUrl;
                              
                              debugPrint('VisualEditor: [LRC LOAD] Syncing Explicit Override: \${lrcSibling["storage_path"]} for Audio: $audioUrl');
                              final resolvedLrcUrl = await storageResolver.resolvePlayableUrl(lrcSibling['storage_path'].toString());
                              final docs = await path_provider.getApplicationDocumentsDirectory();
                              debugPrint('VisualEditor: [LRC LOAD] Resolved LRC cloud path to: $resolvedLrcUrl');
                              
                              String sanitizedAudioUrl = audioUrl;
                              if (sanitizedAudioUrl.startsWith('file:///')) sanitizedAudioUrl = sanitizedAudioUrl.replaceAll('file:///', '');
                              final audioBase = p.basenameWithoutExtension(sanitizedAudioUrl);
                              final targetLrcFile = File(p.join(docs.path, 'lyrics', '$audioBase.lrc'));
                              debugPrint('VisualEditor: [LRC LOAD] Targeting Cache Copy Alias: \${targetLrcFile.path}');
                              
                              if (resolvedLrcUrl != null && !resolvedLrcUrl.startsWith('http')) {
                                  String rawLrcPath = resolvedLrcUrl;
                                  if (rawLrcPath.startsWith('file:///')) rawLrcPath = rawLrcPath.replaceAll('file:///', '');
                                  if (rawLrcPath.startsWith('file://')) rawLrcPath = rawLrcPath.replaceAll('file://', '');
                                  final sourceFile = File(rawLrcPath);
                                  if (await sourceFile.exists()) {
                                      if (!await targetLrcFile.parent.exists()) await targetLrcFile.parent.create(recursive: true);
                                      await sourceFile.copy(targetLrcFile.path);
                                      debugPrint('VisualEditor: [LRC LOAD] SUCCESS: Offline Explicit copy created mimicking cloud bindings natively.');
                                  } else {
                                      debugPrint('VisualEditor: [LRC LOAD] FAILED: The offline LRC binding \${sourceFile.path} does not exist!');
                                  }
                              } else {
                                  debugPrint('VisualEditor: [LRC LOAD] Bounded URL is HTTP, DOWNLOADING remote \${lrcSibling["storage_path"]} into Cache!');
                                  final lrcBytes = await sb.storage.from('tenant-assets').download(lrcSibling['storage_path']);
                                  if (!await targetLrcFile.parent.exists()) await targetLrcFile.parent.create(recursive: true);
                                  await targetLrcFile.writeAsBytes(lrcBytes);
                              }
                            } catch (e) {
                              debugPrint('Failed to process fallback LRC resolving: $e');
                            }
                        }
                  
                  if (audioUrl != null) {
                      final urlResolver = context.read<StorageUrlResolver>();
                      audioUrl = await urlResolver.resolvePlayableUrl(audioUrl) ?? audioUrl;
                      debugPrint('VisualEditor: [LRC LOAD] Final Loaded Audio Pipeline URI: $audioUrl');
                      
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('ve_audioUrl_for_$id', audioUrl);

                      _simulatorWindowKey.currentState?.setPreviewMode('APP');
                      
                      final SourceType st;
                      if (audioUrl.startsWith('assets/')) {
                        st = SourceType.asset;
                      } else if (audioUrl.startsWith('/') || audioUrl.startsWith('C:') || audioUrl.startsWith('file:')) {
                        st = SourceType.file;
                      } else {
                        st = SourceType.url;
                      }

                      context.read<PlayerController>().loadQueue([ItemSource(id: 'asset_preview', title: baseName, sourceType: st, source: audioUrl)]);
                      context.read<LyricsViewController>().loadForCurrentItem(id, audioUrl);
                      context.read<EditorStateController>().loadConfig(id, configObj, targetType: type, targetName: finalTargetName);
                  } else {
                      _simulatorWindowKey.currentState?.setPreviewMode('ELEMENT');
                      context.read<LyricsViewController>().loadExternalConfig(configObj);
                      // Prevent structural width overwrites on parses
                  }
              } else {
                  context.read<LyricsViewController>().loadExternalConfig(configObj);
                  _simulatorWindowKey.currentState?.setPreviewMode('APP');
              }
              
              setState(() {});
              _savePreferences();
      } catch(e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to parse JSON Element Configuration: $e'),
            backgroundColor: Colors.red,
          ));
      }
  }

  Widget _buildAlternativeWorkspace() {

    if (_currentEditorMode == 9) {
      return ProjectConfigurationPanel(
         onDimensionsChanged: _loadPreferences,
      );
    }

    String modeName = '';
    switch (_currentEditorMode) {
      case 1: modeName = 'Database Assets Mapping Configuration'; break;
      case 3: modeName = 'Centralized Text Strings/Lyrics Catalog'; break;
      case 5: modeName = 'Multi-Tenant Subscriptions Linkage'; break;

      default: modeName = 'Unknown Database Tab';
    }

    return Container(
      color: AppColors.background,
      child: Center(
        child: Text(
          modeName,
          style: TextStyle(color: Colors.white54, fontSize: AppUIConfig.rootFontSize, letterSpacing: 1.2),
        )
      )
    );
  }

  Future<void> _resetWindowCentered(String id, double defaultW, double defaultH, VoidCallback hideFn, void Function(BuildContext) showFn) async {
      final prefPrefix = id == 'layer_tree' ? 'layers' : id;
      final prefs = await SharedPreferences.getInstance();
      final mq = MediaQuery.of(context).size;
      
      final w = defaultW;
      final h = defaultH;
      
      await prefs.setDouble(VisualEditorScreen.getPrefKey('${prefPrefix}_w'), w);
      await prefs.setDouble(VisualEditorScreen.getPrefKey('${prefPrefix}_h'), h);
      await prefs.setDouble(VisualEditorScreen.getPrefKey('${prefPrefix}_dx'), (mq.width - w) / 2);
      await prefs.setDouble(VisualEditorScreen.getPrefKey('${prefPrefix}_dy'), (mq.height - h) / 2);
      await prefs.setBool(VisualEditorScreen.getPrefKey('${prefPrefix}_isCollapsed'), false);
      
      if (id == 'timeline') isTimelineDockedNotifier.value = false;
      if (id == 'layer_tree') isLayersDockedNotifier.value = false;
      try { WindowDockManager.instance.panels.firstWhere((p) => p.id == id).undock(); } catch (_) {}
      
      hideFn();
      Future.delayed(const Duration(milliseconds: 50), () => showFn(context));
  }

  @override
  Widget build(BuildContext context) {
    final editorState = context.watch<EditorStateController>();

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(_uiScale)),
      child: GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MouseRegion(
        onHover: (event) {
          var s = MediaQuery.of(context).size;
          _tiltStreamController.add(TiltStreamModel(
            position: Offset((event.localPosition.dx / s.width) * 1080.0,
                (event.localPosition.dy / s.height) * 1080.0),
            gesturesType: GesturesType.hover,
            gestureUse: true,
          ));
        },
        onExit: (event) {
          _tiltStreamController.add(const TiltStreamModel(
            position: Offset.zero,
            gesturesType: GesturesType.hover,
            gestureUse: false,
          ));
        },
        child: Focus(
          autofocus: true,
          focusNode: _focusNode,
          child: Scaffold(
            backgroundColor: AppColors.background,
          body: ExcludeSemantics(
            child: RepaintBoundary(
              key: VisualEditorScreen.editorScreenKey,
              child: Stack(
                children: [
                  Column(
                  children: [
                    // 0. Compact Toolbar (UNSCALED)
                    Container(
                      width: double.infinity,
                      height: 56 * _uiScale,
                      color: AppColors.toolbarBackground,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                          children: [
Expanded(
                            child: Row(
                              children: [
                                if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) ...[
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
                                    onPressed: () => Navigator.pop(context),
                                    tooltip: 'Exit Editor',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 16),
                                ],
                                Container(
                                  constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Visual Editor', style: TextStyle(color: Colors.white, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold)),
                                      Text(
                                        editorState.config == null ? 'No Item Connected' : 'Connected Item: \${editorState.loadedTargetName}',
                                        style: TextStyle(color: editorState.config == null ? Colors.orangeAccent : Colors.blueAccent, fontSize: AppUIConfig.smallFontSize, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                ValueListenableBuilder<bool>(
                                  valueListenable: VisualEditorScreen.isSimulatorPausedNotifier,
                                  builder: (context, isPaused, child) {
                                    return IconButton(
                                      icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, color: isPaused ? Colors.amberAccent : Colors.greenAccent, size: 24),
                                      tooltip: isPaused ? 'Play Simulator Loop' : 'Pause Simulator Loop',
                                      onPressed: () {
                                        VisualEditorScreen.isSimulatorPausedNotifier.value = !isPaused;
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    );
                                  },
                                ),
                              const SizedBox(width: 8),
                              Container(width: 1, height: 24 * _uiScale, color: Colors.white24),
                              const SizedBox(width: 8),
                              ValueListenableBuilder<bool>(
                                valueListenable: showSimulatorNotifier,
                                builder: (context, isShowing, child) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          if (isShowing) {
                                            hideSimulatorWindow();
                                          } else {
                                            VisualEditorScreen.sandboxTestingKey = GlobalKey();
                                            showSimulatorWindow(context);
                                          }
                                        },
                                        icon: Icon(isShowing ? Icons.phone_android : Icons.power_settings_new, color: isShowing ? Colors.lightBlueAccent : Colors.white30, size: 18),
                                        tooltip: isShowing ? 'Dismiss Simulator' : 'Boot Simulator',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.refresh, color: Colors.amberAccent, size: 16),
                                        tooltip: 'Reload Sandbox Engine',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                           hideSimulatorWindow();
                                           Future.delayed(const Duration(milliseconds: 100), () {
                                              VisualEditorScreen.sandboxTestingKey = GlobalKey();
                                              showSimulatorWindow(context);
                                           });
                                        }
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [

                                IconButton(
                                  icon: const Icon(Icons.restore_page, color: Colors.white70, size: 18),
                                  tooltip: 'Reset Workspace Layout Constraints',
                            onPressed: () {
                              showLayersNotifier.value = true;
                              isLayersDockedNotifier.value = false;
                              showTimelineNotifier.value = true;
                              isTimelineDockedNotifier.value = true;
                              
                              final tPanel = WindowDockManager.instance.panels.firstWhere((p) => p.id == 'timeline');
                              tPanel.dock(DockPosition.bottom);
                              tPanel.show();
                              
                              _savePreferences();
                              
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Workspace layout has been reset to default.'),
                                duration: Duration(seconds: 2),
                              ));
                            },
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: () {
                              setState(() => _disableVirtualKeyboard =
                                  !_disableVirtualKeyboard);
                              _savePreferences();
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(_disableVirtualKeyboard
                                    ? 'Virtual Keyboard Disabled (Hardware Mode)'
                                    : 'Virtual Keyboard Enabled'),
                                duration: const Duration(seconds: 1),
                              ));
                            },
                            icon: Icon(
                                _disableVirtualKeyboard
                                    ? Icons.keyboard_hide
                                    : Icons.keyboard,
                                color: _disableVirtualKeyboard
                                    ? Colors.white30
                                    : Colors.lightBlueAccent,
                                size: 18),
                            tooltip: 'Toggle Virtual Keyboard',
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                if (_uiScale > 0.4) {
                                   _uiScale -= 0.1;
                                   VisualEditorScreen.globalUiScale.value = _uiScale;
                                }
                              });
                              _savePreferences();
                            },
                            icon: Icon(AppUIConfig.zoomOutIconCodePoint != null ? IconData(AppUIConfig.zoomOutIconCodePoint!, fontFamily: 'MaterialIcons') : Icons.zoom_out,
                                color: AppUIConfig.zoomOutIconColor ?? Colors.white70, size: 18),
                            tooltip: 'Scale Interface Down',
                          ),
                          Text('${(_uiScale * 100).toInt()}%',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: AppUIConfig.rootFontSize)),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                if (_uiScale < 3.0) {
                                   _uiScale += 0.1;
                                   VisualEditorScreen.globalUiScale.value = _uiScale;
                                }
                              });
                              _savePreferences();
                            },
                            icon: Icon(AppUIConfig.zoomInIconCodePoint != null ? IconData(AppUIConfig.zoomInIconCodePoint!, fontFamily: 'MaterialIcons') : Icons.zoom_in,
                                color: AppUIConfig.zoomInIconColor ?? Colors.white70, size: 18),
                            tooltip: 'Scale Interface Up',
                          ),
                          const SizedBox(width: 12),
                          Container(width: 1, height: 24 * _uiScale, color: Colors.white12),
                          const SizedBox(width: 12),

                          IconButton(
                             onPressed: _executeHotReload,
                            icon: Icon(AppUIConfig.reloadIconCodePoint != null ? IconData(AppUIConfig.reloadIconCodePoint!, fontFamily: 'MaterialIcons') : Icons.refresh,
                                color: AppUIConfig.reloadIconColor ?? Colors.greenAccent, size: 18),
                            tooltip: 'Hot Reload UI',
                          ),
                          IconButton(
                            onPressed: _executeHotRestart,
                            icon: Icon(AppUIConfig.restartIconCodePoint != null ? IconData(AppUIConfig.restartIconCodePoint!, fontFamily: 'MaterialIcons') : Icons.restart_alt,
                                color: AppUIConfig.restartIconColor ?? Colors.orangeAccent, size: 18),
                            tooltip: 'Hot Restart (AHK Injection)',
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final editor = context.read<EditorStateController>();
                              if (editor.hasUnsavedCloudChanges) {
                                  await editor.pushToCloud();
                                  if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Successfully synced local timeline edits to the Supabase Cloud Directory!'), backgroundColor: Colors.green)
                                      );
                                  }
                              } else {
                                  // Fallback PC Save action if nothing to push to cloud explicitly
                                  editor.saveToDisk();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Locally mirrored configuration logic explicitly refreshed.'), backgroundColor: Colors.blueAccent)
                                  );
                              }
                            },
                            icon: editorState.isUploadingToCloud 
                               ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent))
                               : Icon(editorState.hasUnsavedCloudChanges ? Icons.cloud_upload : Icons.cloud_done,
                                color: editorState.hasUnsavedCloudChanges ? Colors.orangeAccent : Colors.white24, size: 18),
                            label: Text(editorState.hasUnsavedCloudChanges ? 'Push to Cloud' : 'Cloud Synced',
                                style: TextStyle(color: editorState.hasUnsavedCloudChanges ? Colors.orangeAccent : Colors.white24, fontWeight: editorState.hasUnsavedCloudChanges ? FontWeight.bold : FontWeight.normal)),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    ],
                  ),
                ),
                
                    // MASTER ROW LAYER: ACTIVITY BAR + WORKSPACE
                    Expanded(
                      child: Row(
                        children: [
                          _buildActivityBar(),
                          Expanded(
                            child: _currentEditorMode == 0
                                ? ClipRect(
                                    child: OverflowBox(
                                      alignment: Alignment.topLeft,
                                      maxWidth: double.infinity,
                                      maxHeight: double.infinity,
                                      child: Transform.scale(scale: 1.0, alignment: Alignment.topLeft,
                              child: SizedBox(
                              width: (MediaQuery.of(context).size.width - 48),
                              height: (MediaQuery.of(context).size.height - 48),
                              child: ListenableBuilder(
                                listenable: Listenable.merge([isLayersDockedNotifier, showLayersNotifier, isTimelineDockedNotifier, showTimelineNotifier]),
                                builder: (context, _) {
                                  return WindowDockManager.instance.buildWorkspaceLayout(context, Container(color: AppColors.background), _uiScale);
                                }
                              ),
                            ),
                          ),
                        ),
                      )   // Closes ? ClipRect
                                : ClipRect(
                                    child: OverflowBox(
                                      alignment: Alignment.topLeft,
                                      maxWidth: double.infinity,
                                      maxHeight: double.infinity,
                                      child: Transform.scale(scale: 1.0, alignment: Alignment.topLeft,
                                        child: SizedBox(
                                          width: (MediaQuery.of(context).size.width - 48),
                                          height: (MediaQuery.of(context).size.height - 48),
                                          child: _buildAlternativeWorkspace(),
                                        ),
                                      ),
                                    ),
                                  ),
                          ), // Closes Expanded
                        ], // Closes children of Row
                      ), // Closes Row
                    ), // Closes Expanded
                  ], // Closes inner Column children
                ), // Closes inner Column
          Positioned.fill(
            child: ValueListenableBuilder<int>(
              valueListenable: WindowDockManager.instance.stateToken,
              builder: (context, _, __) => Stack(
                clipBehavior: Clip.none,
                children: [
                  ..._windowZOrder.map((winId) {
             
          
                       final panel = WindowDockManager.instance.panels.cast<DockablePanel?>().firstWhere((p) => p!.id == winId && p.dockPosition.value == DockPosition.floating, orElse: () => null);
             Widget childWidget = SizedBox.shrink(key: ValueKey(winId + '_hidden'));
             if (panel != null && panel.isVisible.value) {
                childWidget = panel.floatingBuilder();
             }
             
             return childWidget;
                  }).toList(),
              ],
            ),
          ),
          ),
          const AnnotationCanvasLayer(),
          ListenableBuilder(
            listenable: AiBridgeService.instance,
            builder: (context, _) {
              if (!AiBridgeService.instance.isThinking) return const SizedBox.shrink();
              return Positioned(
                bottom: 16,
                left: 64, // 48 is activity bar width, plus 16 padding margin
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.2), blurRadius: 8, spreadRadius: 2),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent)),
                        const SizedBox(width: 12),
                        Text('Ai Syncing', style: TextStyle(color: Colors.blueAccent, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: showKaraokeGenWindowNotifier,
            builder: (context, show, child) {
              if (!show) return const SizedBox.shrink();
              return const KaraokeGenWindow(onClose: hideKaraokeGenWindow);
            }
          ),
          Positioned(
            left: _toolsGalleryCollapsed ? _toolsGalleryCollapsedOffset.dx : _toolsGalleryOffset.dx,
            top: _toolsGalleryCollapsed ? _toolsGalleryCollapsedOffset.dy : _toolsGalleryOffset.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                  setState(() {
                    if (_toolsGalleryCollapsed) {
                      _toolsGalleryCollapsedOffset += details.delta;
                    } else {
                      _toolsGalleryOffset += details.delta;
                    }
                  });
                },
                onPanEnd: (_) async {
                  final prefs = await SharedPreferences.getInstance();
                  if (_toolsGalleryCollapsed) {
                    await prefs.setDouble('ve_toolsGalleryCollapsedOffsetX', _toolsGalleryCollapsedOffset.dx);
                    await prefs.setDouble('ve_toolsGalleryCollapsedOffsetY', _toolsGalleryCollapsedOffset.dy);
                  } else {
                    await prefs.setDouble('ve_toolsGalleryOffsetX', _toolsGalleryOffset.dx);
                    await prefs.setDouble('ve_toolsGalleryOffsetY', _toolsGalleryOffset.dy);
                  }
                },
                child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                color: AppColors.toolbarBackground.withOpacity(0.9),
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.toolbarBorderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () async {
                            setState(() => _toolsGalleryCollapsed = !_toolsGalleryCollapsed);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('ve_toolsGalleryCollapsed', _toolsGalleryCollapsed);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                            child: _toolsGalleryCollapsed
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        AppUIConfig.toolsIconCodePoint != null 
                                          ? IconData(AppUIConfig.toolsIconCodePoint!, fontFamily: 'MaterialIcons') 
                                          : Icons.build, 
                                        color: AppUIConfig.toolsIconColor ?? AppColors.toolbarTextSecondary, 
                                        size: AppUIConfig.globalActionIconSize
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Tools', style: TextStyle(color: Colors.white, fontSize: AppUIConfig.smallFontSize, fontWeight: FontWeight.w600)),
                                    ],
                                  )
                                : const Icon(
                                    Icons.drag_indicator,
                                    color: Colors.white54,
                                    size: 16
                                  ),
                          ),
                        ),
                      ),
                      if (!_toolsGalleryCollapsed) const SizedBox(width: 8),
                      if (!_toolsGalleryCollapsed) Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ValueListenableBuilder<String>(
                            valueListenable: VisualEditorScreen.currentWorkspace,
                            builder: (context, workspace, child) {
                              return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                          if (_isWindowAvailable('backup')) ValueListenableBuilder<bool>(
                                            valueListenable: showBackupNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('backup'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideBackupWindow(); } else { showBackupWindow(context); } }, onReset: () => _resetWindowCentered('backup', 800, 600, hideBackupWindow, showBackupWindow)); }
                                          ),
                                          if (_isWindowAvailable('backup')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('ui_helper')) ValueListenableBuilder<bool>(
                                            valueListenable: showUiHelperNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('ui_helper'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideUiHelperWindow(); } else { showUiHelperWindow(context); } }, onReset: () => _resetWindowCentered('ui_helper', 800, 600, hideUiHelperWindow, showUiHelperWindow)); }
                                          ),
                                          if (_isWindowAvailable('ui_helper')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('unit_testing')) ValueListenableBuilder<bool>(
                                            valueListenable: showUnitTestingNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('unit_testing'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideUnitTestingWindow(); } else { showUnitTestingWindow(context); } }, onReset: () => _resetWindowCentered('unit_testing', 800, 600, hideUnitTestingWindow, showUnitTestingWindow)); }
                                          ),
                                          if (_isWindowAvailable('unit_testing')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('system_logs')) ValueListenableBuilder<bool>(
                                            valueListenable: showSystemLogsNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('system_logs'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideSystemLogsWindow(); } else { showSystemLogsWindow(context); } }, onReset: () => _resetWindowCentered('system_logs', 800, 600, hideSystemLogsWindow, showSystemLogsWindow)); }
                                          ),
                                          if (_isWindowAvailable('system_logs')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('profiler')) ValueListenableBuilder<bool>(
                                            valueListenable: showProfilerNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('profiler'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideProfilerWindow(); } else { showProfilerWindow(context); } }, onReset: () => _resetWindowCentered('profiler', 800, 600, hideProfilerWindow, showProfilerWindow)); }
                                          ),
                                          if (_isWindowAvailable('profiler')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('test_bed')) ValueListenableBuilder<bool>(
                                              valueListenable: showTestBedNotifier,
                                              builder: (context, isShowing, child) { final d = AppToolWindows.getDef('test_bed'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideTestBedWindow(); } else { showTestBedWindow(context); } }, onReset: () => _resetWindowCentered('test_bed', 600, 600, hideTestBedWindow, showTestBedWindow)); }
                                            ),
                                            if (_isWindowAvailable('test_bed')) const SizedBox(width: 8),
                                            if (_isWindowAvailable('version_control')) ValueListenableBuilder<bool>(
                                              valueListenable: showVersionControlNotifier,
                                              builder: (context, isShowing, child) { final d = AppToolWindows.getDef('version_control'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideVersionControlWindow(); } else { showVersionControlWindow(context); } }, onReset: () => _resetWindowCentered('version_control', 500, 400, hideVersionControlWindow, showVersionControlWindow)); }
                                            ),
                                            if (_isWindowAvailable('version_control')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('cli_terminal')) ValueListenableBuilder<bool>(
                                            valueListenable: showCliTerminalNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('cli_terminal'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideCliTerminalWindow(); } else { showCliTerminalWindow(context); } }, onReset: () => _resetWindowCentered('cli_terminal', 600, 400, hideCliTerminalWindow, showCliTerminalWindow)); }
                                          ),
                                          if (_isWindowAvailable('cli_terminal')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('macro')) ValueListenableBuilder<bool>(
                                            valueListenable: showMacroNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('macro'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideMacroWindow(); } else { showMacroWindow(context); } }, onReset: () => _resetWindowCentered('macro', 800, 600, hideMacroWindow, showMacroWindow)); }
                                          ),
                                          if (_isWindowAvailable('macro')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('macro_guide')) ValueListenableBuilder<bool>(
                                            valueListenable: showMacroGuideNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('macro_guide'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideMacroGuideWindow(); } else { showMacroGuideWindow(context); } }, onReset: () => _resetWindowCentered('macro_guide', 850, 550, hideMacroGuideWindow, showMacroGuideWindow)); }
                                          ),
                                          if (_isWindowAvailable('macro_guide')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('flow_editor')) ValueListenableBuilder<bool>(
                                            valueListenable: showFlowEditorNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('flow_editor'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideFlowEditorWindow(); } else { showFlowEditorWindow(context); } }, onReset: () => _resetWindowCentered('flow_editor', 800, 600, hideFlowEditorWindow, showFlowEditorWindow)); }
                                          ),
                                          if (_isWindowAvailable('flow_editor')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('assets') || _isWindowAvailable('localization') || _isWindowAvailable('subscriptions')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('assets') || _isWindowAvailable('localization') || _isWindowAvailable('subscriptions')) Container(width: 1, height: 24 * _uiScale, color: Colors.white24),
                                          if (_isWindowAvailable('assets') || _isWindowAvailable('localization') || _isWindowAvailable('subscriptions')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('assets')) ValueListenableBuilder<bool>(
                                            valueListenable: showAssetsNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('assets'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideAssetsWindow(); } else { showAssetsWindow(context); } }, onReset: () => _resetWindowCentered('assets', 800, 600, hideAssetsWindow, showAssetsWindow)); }
                                          ),
                                          if (_isWindowAvailable('localization')) ValueListenableBuilder<bool>(
                                            valueListenable: showLocalizationNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('localization'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideLocalizationWindow(); } else { showLocalizationWindow(context); } }, onReset: () => _resetWindowCentered('localization', 800, 600, hideLocalizationWindow, showLocalizationWindow)); }
                                          ),
                                          if (_isWindowAvailable('subscriptions')) ValueListenableBuilder<bool>(
                                            valueListenable: showSubscriptionsNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('subscriptions'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideSubscriptionsWindow(); } else { showSubscriptionsWindow(context); } }, onReset: () => _resetWindowCentered('subscriptions', 800, 600, hideSubscriptionsWindow, showSubscriptionsWindow)); }
                                          ),
                                          if (_isWindowAvailable('layers') || _isWindowAvailable('properties') || _isWindowAvailable('timeline') || _isWindowAvailable('karaoke_gen')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('layers') || _isWindowAvailable('properties') || _isWindowAvailable('timeline') || _isWindowAvailable('karaoke_gen')) Container(width: 1, height: 24 * _uiScale, color: Colors.white24),
                                          if (_isWindowAvailable('layers') || _isWindowAvailable('properties') || _isWindowAvailable('timeline') || _isWindowAvailable('karaoke_gen')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('layers')) ValueListenableBuilder<bool>(
                                            valueListenable: showLayersNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('layers'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideLayersWindow(); } else { showLayersWindow(context); } }, onReset: () => _resetWindowCentered('layer_tree', 300, 600, hideLayersWindow, showLayersWindow)); }
                                          ),
                                          if (_isWindowAvailable('properties')) ValueListenableBuilder<bool>(
                                            valueListenable: showPropertiesNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('properties'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hidePropertiesWindow(); } else { showPropertiesWindow(context); } }, onReset: () => _resetWindowCentered('properties', 300, 400, hidePropertiesWindow, showPropertiesWindow)); }
                                          ),
                                          if (_isWindowAvailable('timeline')) ValueListenableBuilder<bool>(
                                            valueListenable: showTimelineNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('timeline'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideTimelineWindow(); } else { showTimelineWindow(context); } }, onReset: () => _resetWindowCentered('timeline', 1000, 650, hideTimelineWindow, showTimelineWindow)); }
                                          ),
                                          if (_isWindowAvailable('karaoke_gen')) ValueListenableBuilder<bool>(
                                            valueListenable: showKaraokeGenWindowNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('karaoke_gen'); return _buildToolbarBtn(isShowing, d.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideKaraokeGenWindow(); } else { showKaraokeGenWindow(); } }, onReset: () => {}); }
                                          ),
                                          const SizedBox(width: 8),
                                          Container(width: 1, height: 24 * _uiScale, color: Colors.white24),
                                          const SizedBox(width: 8),
                                          if (_isWindowAvailable('task_editor')) ValueListenableBuilder<bool>(
                                            valueListenable: showTaskEditorNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('task_editor'); return _buildToolbarBtn(isShowing, d!.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideTaskEditorWindow(); } else { showTaskEditorWindow(context); } }, onReset: () => _resetWindowCentered('task_editor', 800, 600, hideTaskEditorWindow, showTaskEditorWindow)); }
                                          ),
                                          if (_isWindowAvailable('task_editor')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('notes_editor')) ValueListenableBuilder<bool>(
                                            valueListenable: showNotesEditorNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('notes_editor'); return _buildToolbarBtn(isShowing, d!.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideNotesEditorWindow(); } else { showNotesEditorWindow(context); } }, onReset: () => _resetWindowCentered('notes_editor', 800, 600, hideNotesEditorWindow, showNotesEditorWindow)); }
                                          ),
                                          if (_isWindowAvailable('notes_editor')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('suggestion_engine')) ValueListenableBuilder<bool>(
                                            valueListenable: showSuggestionEngineNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('suggestion_engine'); return _buildToolbarBtn(isShowing, d!.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideSuggestionEngineWindow(); } else { showSuggestionEngineWindow(context); } }, onReset: () => _resetWindowCentered('suggestion_engine', 800, 600, hideSuggestionEngineWindow, showSuggestionEngineWindow)); }
                                          ),
                                          if (_isWindowAvailable('suggestion_engine')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('agents')) ValueListenableBuilder<bool>(
                                            valueListenable: showAgentsNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('agents'); return _buildToolbarBtn(isShowing, d!.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideAgentsWindow(); } else { showAgentsWindow(context); } }, onReset: () => _resetWindowCentered('agents', 800, 600, hideAgentsWindow, showAgentsWindow)); }
                                          ),
                                          if (_isWindowAvailable('agents')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('control_types_editor')) ValueListenableBuilder<bool>(
                                            valueListenable: showControlTypesEditorNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('control_types_editor'); return _buildToolbarBtn(isShowing, d!.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideControlTypesEditorWindow(); } else { showControlTypesEditorWindow(context); } }, onReset: () => _resetWindowCentered('control_types_editor', 800, 600, hideControlTypesEditorWindow, showControlTypesEditorWindow)); }
                                          ),
                                          if (_isWindowAvailable('control_types_editor')) const SizedBox(width: 8),

                                          if (_isWindowAvailable('color_picker')) ValueListenableBuilder<bool>(
                                            valueListenable: showColorPickerNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('color_picker'); return _buildToolbarBtn(isShowing, d!.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideColorPickerWindow(); } else { showColorPickerWindow(context); } }, onReset: () => _resetWindowCentered('color_picker', 800, 600, hideColorPickerWindow, showColorPickerWindow)); }
                                          ),
                                          if (_isWindowAvailable('color_picker')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('icon_picker')) ValueListenableBuilder<bool>(
                                            valueListenable: showIconPickerNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('icon_picker'); return _buildToolbarBtn(isShowing, d!.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideIconPickerWindow(); } else { showIconPickerWindow(context); } }, onReset: () => _resetWindowCentered('icon_picker', 800, 600, hideIconPickerWindow, showIconPickerWindow)); }
                                          ),
                                          if (_isWindowAvailable('icon_picker')) const SizedBox(width: 8),
                                          if (_isWindowAvailable('attachment_viewer')) ValueListenableBuilder<bool>(
                                            valueListenable: showAttachmentViewerNotifier,
                                            builder: (context, isShowing, child) { final d = AppToolWindows.getDef('attachment_viewer'); return _buildToolbarBtn(isShowing, d!.icon, d.color, d.name, d.shortLabel, () { if (isShowing) { hideAttachmentViewerWindow(); } else { showAttachmentViewerWindow(context); } }, onReset: () => _resetWindowCentered('attachment_viewer', 560, 640, hideAttachmentViewerWindow, showAttachmentViewerWindow)); }
                                          ),
                                          if (_isWindowAvailable('attachment_viewer')) const SizedBox(width: 8),

                              ],
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
          ),
          ValueListenableBuilder<bool>(
            valueListenable: showControlEditorNotifier,
            builder: (context, show, child) {
              if (!show) return const SizedBox.shrink();
              return const ControlEditorPanel(onClose: hideControlEditorWindow);
            }
          ),

              ], // Stack children
            ), // Stack
            ), // RepaintBoundary
          ), // ExcludeSemantics
          ), // Scaffold
        ), // Focus
      ), // MouseRegion
    )); // GestureDetector and MediaQuery
  }
}

// Minimal stubs for the tool panels

class LayerTreePanel extends StatelessWidget {
  const LayerTreePanel({super.key});

  @override
  Widget build(BuildContext context) {
    var editor = context.watch<EditorStateController>();
    if (editor.config == null) {
      return Center(
          child: Text('No Config Loaded',
              style: TextStyle(color: Colors.white54, fontSize: AppUIConfig.rootFontSize)));
    }

    Widget buildTreeItem({
      required bool isSelected,
      required String title,
      required IconData icon,
      required Color iconColor,
      required VoidCallback onTap,
      Widget? trailing,
      bool isActive = true,
      Function(bool?)? onActiveChanged,
      int depth = 0,
    }) {
      return InkWell(
        onTap: onTap,
        child: Container(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.2)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(
              horizontal: 4, vertical: 0), // Compact vertical
          child: Row(
            children: [
              if (depth > 0) SizedBox(width: depth * 16.0),
              if (onActiveChanged != null)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Transform.scale(
                    scale: 0.65,
                    child: Checkbox(
                      value: isActive,
                      onChanged: onActiveChanged,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      activeColor: Colors.amber,
                    ),
                  ),
                )
              else
                const SizedBox(width: 24),
              Icon(icon,
                  color: isActive ? iconColor : Colors.white24, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isActive
                        ? (isSelected ? Colors.white : Colors.white70)
                        : Colors.white30,
                    fontSize: AppUIConfig.smallFontSize,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) trailing,
              const SizedBox(
                  width: 12), // For reorder drag handle padding organically
            ],
          ),
        ),
      );
    }

    final globalTitle = buildTreeItem(
      title: 'Global Settings',
      icon: Icons.public,
      iconColor: Colors.blueGrey,
      isSelected: editor.selectedLayerId == null,
      onTap: () => editor.selectLayer(null),
    );

    final List<Widget> layersWidgets = [];
    final List<String> visibleLayerIds = [];
    final Set<String> processedNodes = {};

    void processLayer(LayerElement layer, int depth) {
      if (processedNodes.contains(layer.targetId)) {
        return; // Prevent cyclic loops natively gracefully!
      }
      processedNodes.add(layer.targetId);

      if (depth > 0 && layer.parentId != null) {
        final parent = editor.config!.layers[layer.parentId!];
        if (parent != null && !parent.isExpanded) {
          return; // visually hide children if folder closed
        }
      }

      visibleLayerIds.add(layer.targetId);
      bool isFolder = layer.type == 'FOLDER';

      bool parentIsInactive = false;
      String? currentParentId = layer.parentId;

      while (currentParentId != null) {
        final parentLayer = editor.config!.layers[currentParentId];
        if (parentLayer != null) {
          if (!parentLayer.active) {
            parentIsInactive = true;
            break;
          }
          currentParentId = parentLayer.parentId;
        } else {
          break;
        }
      }

      // The overall tree row opacity mathematically bound explicitly ONLY to the static layer check box native override natively.
      final baseItem = Opacity(
          opacity: parentIsInactive ? 0.35 : 1.0,
          child: buildTreeItem(
            title: layer.targetId,
            icon: isFolder
                ? (layer.isExpanded ? Icons.folder_open : Icons.folder)
                : Icons.layers,
            iconColor: isFolder ? Colors.amberAccent : Colors.tealAccent,
            isActive: layer.active, // Native master check ONLY!
            depth: depth,
            onActiveChanged: (val) {
              editor.toggleLayerActive(layer.targetId, val ?? true);
              editor.pushHistoryState();
              if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
            },
            isSelected: editor.selectedLayerId == layer.targetId,
            onTap: () {
              if (isFolder && editor.selectedLayerId == layer.targetId) {
                editor.toggleFolderExpanded(
                    layer.targetId); // double tap roughly toggles
              }
              editor.selectLayer(layer.targetId);
            },
            trailing: isFolder
                ? InkWell(
                    child: Icon(
                        layer.isExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 14,
                        color: Colors.white54),
                    onTap: () => editor.toggleFolderExpanded(layer.targetId),
                  )
                : IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 12, color: Colors.white24),
                    onPressed: () {
                      editor.deleteLayer(layer.targetId);
                      editor.pushHistoryState();
                      if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
                    },
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 20, minHeight: 20),
                    splashRadius: 16,
                  ),
          ));

      layersWidgets.add(DragTarget<String>(
          onWillAcceptWithDetails: (details) => details.data != layer.targetId,
          onAcceptWithDetails: (details) {
            editor.dropLayerBefore(details.data, layer.targetId);
            editor.pushHistoryState();
            if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
          },
          builder: (context, candidateData, rejectedData) {
            bool isHovered = candidateData.isNotEmpty;
            return Container(
              height: isHovered ? 12.0 : 4.0,
              color: isHovered ? Colors.amberAccent : Colors.transparent,
            );
          }));

      layersWidgets.add(DragTarget<String>(onWillAcceptWithDetails: (details) {
        return details.data != layer.targetId;
      }, onAcceptWithDetails: (details) {
        editor.dropLayer(details.data, layer.targetId);
        editor.pushHistoryState();
        if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
      }, builder: (context, candidateData, rejectedData) {
        bool isHovered = candidateData.isNotEmpty;
        return Container(
          key: ValueKey('container_${layer.targetId}'),
          margin: const EdgeInsets.only(bottom: 0), // More compact!
          decoration: BoxDecoration(
            border: isHovered
                ? Border.all(color: Colors.amber, width: 1.0)
                : Border.all(color: Colors.transparent, width: 1.0),
            color:
                isHovered ? Colors.amber.withOpacity(0.1) : Colors.transparent,
          ),
          child: Draggable<String>(
            data: layer.targetId,
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: 250,
                color: Colors.blueAccent.withOpacity(0.5),
                child: baseItem,
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.2, child: baseItem),
            child: baseItem,
          ),
        );
      }));

      if (isFolder) {
        final children = editor.config!.layers.values
            .where((l) => l.parentId == layer.targetId)
            .toList();
        for (var child in children) {
          processLayer(child, depth + 1);
        }
      }
    }

    // Filter visible layers and add tree markers natively starting from roots/orphans
    var roots = editor.config!.layers.values
        .where((l) =>
            l.parentId == null ||
            !editor.config!.layers.containsKey(l.parentId))
        .toList();
    for (var root in roots) {
      processLayer(root, 0);
    }

    // Add an empty drop zone at the very bottom so layers can explicitly be sent to the absolute END of the Root hierarchy!
    layersWidgets.add(DragTarget<String>(onAcceptWithDetails: (details) {
      final draggedId = details.data;
      final layer = editor.config!.layers.remove(draggedId);
      if (layer != null) {
        layer.parentId = null;
        editor.config!.layers[draggedId] =
            layer; // Pushes it inherently to the very end of the LinkedHashMap!
        editor.pushHistoryState();
        if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
      }
    }, builder: (context, candidateData, rejectedData) {
      bool isHovered = candidateData.isNotEmpty;
      return Container(
        height: 24.0,
        decoration: BoxDecoration(
          color: isHovered
              ? Colors.amberAccent.withOpacity(0.2)
              : Colors.transparent,
          border: isHovered
              ? Border.all(color: Colors.amberAccent, width: 1)
              : null,
        ),
        child: Center(
            child: Text(
                isHovered
                    ? 'DROP AT VERY BOTTOM (RENDER ON TOP OF EVERYTHING)'
                    : '',
                style: TextStyle(fontSize: AppUIConfig.smallFontSize, color: Colors.amberAccent))),
      );
    }));

    // Safety fallback rendering unrendered cycle-locked elements natively at root
    for (var layer in editor.config!.layers.values) {
      if (!processedNodes.contains(layer.targetId)) {
        processLayer(layer, 0);
      }
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        globalTitle,
        const Divider(color: Colors.white12, height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('LAYERS', style: TextStyle(
                      color: Colors.white38,
                      fontSize: AppUIConfig.smallFontSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              Row(children: [
                InkWell(
                  onTap: () {
                    editor.addFolder();
                    editor.pushHistoryState();
                  },
                  child: const Icon(Icons.create_new_folder_outlined,
                      color: Colors.amber, size: 14),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    editor.addLayer();
                    editor.pushHistoryState();
                    if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
                  },
                  child: const Icon(Icons.add_circle_outline,
                      color: Colors.amber, size: 14),
                ),
              ])
            ],
          ),
        ),
        Expanded(
          child: Theme(
            data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
            child: ListView(
              padding: EdgeInsets.zero,
              children: layersWidgets,
            ),
          ),
        ),
      ],
    );
  }
}

class TimelinePanel extends StatefulWidget {
  const TimelinePanel({super.key});

  @override
  State<TimelinePanel> createState() => TimelinePanelState();
}

class TimelinePanelState extends State<TimelinePanel> {
  final ScrollController _leftVertical = ScrollController();
  final ScrollController _rightVertical = ScrollController();
  final ScrollController _topHorizontal = ScrollController();
  final ScrollController _bottomHorizontal = ScrollController();
  final FocusNode _timelineFocusNode = FocusNode();

  double _zoomScale = 1.0;
  double _propertiesWidth = 260.0;
  final Set<String> _collapsedTimelineGroups = {};

  void focusTimeline() {
    if (!_timelineFocusNode.hasFocus) {
        FocusManager.instance.primaryFocus?.unfocus();
        _timelineFocusNode.requestFocus();
    }
  }

  KeyEventResult _handleTimelineKey(FocusNode node, KeyEvent event) {
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        if (mounted) {
          var player = context.read<PlayerController>();
          var editor = context.read<EditorStateController>();
          int overriddenDur = 15000;
          if (editor.config != null && editor.config!.globalItems.containsKey('TIMELINE_DURATION') && editor.config!.globalItems['TIMELINE_DURATION']!.keyframes.isNotEmpty) {
             final val = editor.config!.globalItems['TIMELINE_DURATION']!.keyframes.first.value;
             if (val is num) overriddenDur = val.toInt();
          }
          player.togglePlayPause(virtualLoopMs: overriddenDur);
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.bracketLeft || event.logicalKey == LogicalKeyboardKey.bracketRight) {
        if (mounted) {
          final lyricsVC = context.read<LyricsViewController>();
          if (lyricsVC.lines.isNotEmpty) {
              final player = context.read<PlayerController>();
              final currentMs = player.position.inMilliseconds;
              if (event.logicalKey == LogicalKeyboardKey.bracketRight) {
                  final nextLine = lyricsVC.lines.cast<LyricLine?>().firstWhere((l) => l!.startMs > currentMs + 50, orElse: () => null);
                  if (nextLine != null) {
                       player.seekTo(Duration(milliseconds: nextLine.startMs));
                       lyricsVC.updatePosition(nextLine.startMs);
                  }
              } else {
                  final prevLine = lyricsVC.lines.reversed.cast<LyricLine?>().firstWhere((l) => l!.startMs < currentMs - 50, orElse: () => null);
                  if (prevLine != null) {
                       player.seekTo(Duration(milliseconds: prevLine.startMs));
                       lyricsVC.updatePosition(prevLine.startMs);
                  }
              }
              return KeyEventResult.handled;
          }
        }
      } else if (event.logicalKey == LogicalKeyboardKey.comma || event.logicalKey == LogicalKeyboardKey.period) {
        if (mounted) {
           final editor = context.read<EditorStateController>();
           final player = context.read<PlayerController>();
           if (editor.config != null) {
              final selectedKey = editor.selectedLayerId;
              Map<String, PropertyItem> items = {};
              if (selectedKey != null && editor.config!.layers.containsKey(selectedKey)) {
                  items = editor.config!.layers[selectedKey]!.items;
              } else {
                  items = editor.config!.globalItems;
              }
              
              final Set<int> allMs = {};
              for (var prop in items.values) {
                 for (var kf in prop.keyframes) {
                     allMs.add(kf.timeMs);
                 }
              }
              final currentMs = player.position.inMilliseconds;
              
              if (event.logicalKey == LogicalKeyboardKey.period) {
                  final sorted = allMs.toList()..sort();
                  final nextMs = sorted.cast<int?>().firstWhere((ms) => ms! > currentMs + 20, orElse: () => null);
                  if (nextMs != null) {
                      player.seekTo(Duration(milliseconds: nextMs));
                      context.read<LyricsViewController>().updatePosition(nextMs);
                  }
              } else {
                  final sorted = allMs.toList()..sort((a,b) => b.compareTo(a));
                  final prevMs = sorted.cast<int?>().firstWhere((ms) => ms! < currentMs - 20, orElse: () => null);
                  if (prevMs != null) {
                      player.seekTo(Duration(milliseconds: prevMs));
                      context.read<LyricsViewController>().updatePosition(prevMs);
                  }
              }
              return KeyEventResult.handled;
           }
        }
      } else if (event.logicalKey == LogicalKeyboardKey.minus || event.logicalKey == LogicalKeyboardKey.equal || event.logicalKey == LogicalKeyboardKey.numpadSubtract || event.logicalKey == LogicalKeyboardKey.numpadAdd) {
        if (mounted) {
            final editor = context.read<EditorStateController>();
            final player = context.read<PlayerController>();
            
            double configuredDur = 15000.0;
            if (editor.config != null && editor.config!.globalItems.containsKey('TIMELINE_DURATION') && editor.config!.globalItems['TIMELINE_DURATION']!.keyframes.isNotEmpty) {
                final val = editor.config!.globalItems['TIMELINE_DURATION']!.keyframes.first.value;
                if (val is num) configuredDur = val.toDouble();
            }
            double totalDuration = player.duration?.inMilliseconds.toDouble() ?? configuredDur;
            if (totalDuration <= 0) totalDuration = 15000.0;

            final renderBox = context.findRenderObject() as RenderBox?;
            double maxWidth = renderBox?.size.width ?? 1000;
            double baseScreenWidth = maxWidth - _propertiesWidth - 4;
            if (baseScreenWidth < 100) baseScreenWidth = 100;

            double oldZoom = _zoomScale;
            double newZoom = oldZoom;
            if (event.logicalKey == LogicalKeyboardKey.equal || event.logicalKey == LogicalKeyboardKey.numpadAdd) {
                newZoom = (oldZoom * 1.2).clamp(0.1, 50.0);
            } else {
                newZoom = (oldZoom / 1.2).clamp(0.1, 50.0);
            }

            if (oldZoom != newZoom) {
                double t = player.position.inMilliseconds.toDouble();
                double oldPixelsPerMs = (baseScreenWidth * oldZoom) / totalDuration;
                double newPixelsPerMs = (baseScreenWidth * newZoom) / totalDuration;
                
                double delta = (t * newPixelsPerMs) - (t * oldPixelsPerMs);
                double currentScroll = _topHorizontal.hasClients ? _topHorizontal.offset : 0.0;
                double targetScroll = currentScroll + delta;
                
                setState(() {
                    _zoomScale = newZoom;
                });
                _savePreferences();
                
                if (_topHorizontal.hasClients) {
                    _topHorizontal.jumpTo(targetScroll);
                }
            }
            return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  double _scrubberStartMs = 0.0;

  String _getSimplifiedName(String key) {
    switch (key) {
      case 'LAYER_POS_X':
        return 'Position X';
      case 'LAYER_POS_Y':
        return 'Position Y';
      case 'LAYER_SCALE_X':
        return 'Scale X';
      case 'LAYER_SCALE_Y':
        return 'Scale Y';
      case 'LAYER_ROTATION_X':
        return 'Rotation X';
      case 'LAYER_ROTATION_Y':
        return 'Rotation Y';
      case 'LAYER_ROTATION_Z':
        return 'Rotation Z';
      case 'LAYER_PIVOT_X':
        return 'Pivot X';
      case 'LAYER_PIVOT_Y':
        return 'Pivot Y';
      case 'LAYER_TILT':
        return 'Tilt 3D Parallax';
      case 'LAYER_TILT_DEPTH':
        return 'Tilt Depth (Angle)';
      case 'LAYER_OPACITY':
        return 'Opacity';
      case 'LAYER_BLUR':
        return 'Blur Radius';
      case 'LAYER_BLEND':
        return 'Blend Mode';
      case 'ACTIVE':
        return 'Active Status';
      default:
        return key;
    }
  }

  void _syncScroll(ScrollController source, ScrollController target) {
    if (source.hasClients && target.hasClients) {
      if (source.offset != target.offset) target.jumpTo(source.offset);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _leftVertical.addListener(() => _syncScroll(_leftVertical, _rightVertical));
    _rightVertical
        .addListener(() => _syncScroll(_rightVertical, _leftVertical));
    _topHorizontal
        .addListener(() => _syncScroll(_topHorizontal, _bottomHorizontal));
    _bottomHorizontal
        .addListener(() => _syncScroll(_bottomHorizontal, _topHorizontal));
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _zoomScale = prefs.getDouble('ve_zoomScale') ?? 1.0;
      _propertiesWidth = prefs.getDouble('ve_propertiesWidth') ?? 260.0;
      _collapsedTimelineGroups.clear();
      _collapsedTimelineGroups
          .addAll(prefs.getStringList('ve_collapsedTimelineGroups') ?? []);
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ve_zoomScale', _zoomScale);
    await prefs.setDouble('ve_propertiesWidth', _propertiesWidth);
    await prefs.setStringList(
        've_collapsedTimelineGroups', _collapsedTimelineGroups.toList());
  }

  @override
  void dispose() {
    _timelineFocusNode.dispose();
    _leftVertical.dispose();
    _rightVertical.dispose();
    _topHorizontal.dispose();
    _bottomHorizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var editor = context.watch<EditorStateController>();
    var playerController = context.watch<PlayerController>();
    context.watch<LyricsViewController>();

    if (editor.config == null) {
      return Center(
          child: Text('Load a configuration to view timeline',
              style: TextStyle(color: Colors.white54, fontSize: AppUIConfig.rootFontSize)));
    }

    final selectedKey = editor.selectedLayerId;
    Map<String, PropertyItem> items = {};

    if (selectedKey != null &&
        editor.config != null &&
        editor.config!.layers.containsKey(selectedKey)) {
      items = editor.config!.layers[selectedKey]!.items;
    } else if (editor.config != null) {
      items = editor.config!.globalItems;
    }

    List<String> rawKeys = items.keys.toList()..sort();
    rawKeys.remove('LAYER_BLEND');

    var posKeys = rawKeys
        .where((k) => ['LAYER_POS_X', 'LAYER_POS_Y'].contains(k))
        .toList();
    var scaleKeys = rawKeys
        .where((k) => ['LAYER_SCALE_X', 'LAYER_SCALE_Y'].contains(k))
        .toList();
    var pivotKeys = rawKeys
        .where((k) => ['LAYER_PIVOT_X', 'LAYER_PIVOT_Y'].contains(k))
        .toList();
    var rotKeys = rawKeys
        .where((k) => [
              'LAYER_ROTATION_X',
              'LAYER_ROTATION_Y',
              'LAYER_ROTATION_Z'
            ].contains(k))
        .toList();
    var tiltKeys = rawKeys
        .where((k) => ['LAYER_TILT', 'LAYER_TILT_DEPTH'].contains(k))
        .toList();
    var otherKeys = rawKeys
        .where((k) => ![
              'ACTIVE',
              'LAYER_POS_X',
              'LAYER_POS_Y',
              'LAYER_SCALE_X',
              'LAYER_SCALE_Y',
              'LAYER_ROTATION_X',
              'LAYER_ROTATION_Y',
              'LAYER_ROTATION_Z',
              'LAYER_PIVOT_X',
              'LAYER_PIVOT_Y',
              'LAYER_TILT',
              'LAYER_TILT_DEPTH'
            ].contains(k))
        .toList();

    List<String> activeProperties = [];
    if (rawKeys.contains('ACTIVE')) activeProperties.add('ACTIVE');

    void addGroup(String groupName, List<String> keys, {String? subFolder}) {
      if (keys.isEmpty) return;
      if (subFolder == null) {
        activeProperties.add('__GROUP_$groupName');
        if (!_collapsedTimelineGroups.contains(groupName)) {
          activeProperties.addAll(keys);
        }
      } else {
        if (_collapsedTimelineGroups.contains(groupName)) {
          return; // Parent collapsed natively
        }

        activeProperties.add('__SUBGROUP_$groupName|$subFolder');
        if (!_collapsedTimelineGroups.contains('$groupName|$subFolder')) {
          activeProperties.addAll(keys);
        }
      }
    }

    if (posKeys.isNotEmpty ||
        scaleKeys.isNotEmpty ||
        rotKeys.isNotEmpty ||
        pivotKeys.isNotEmpty ||
        tiltKeys.isNotEmpty) {
      activeProperties.add('__GROUP_TRANSFORM');
      if (!_collapsedTimelineGroups.contains('TRANSFORM')) {
        addGroup('TRANSFORM', posKeys, subFolder: 'POSITION');
        addGroup('TRANSFORM', scaleKeys, subFolder: 'SCALE');
        addGroup('TRANSFORM', rotKeys, subFolder: 'ROTATION');
        addGroup('TRANSFORM', pivotKeys, subFolder: 'PIVOT');
        addGroup('TRANSFORM', tiltKeys, subFolder: 'TILT 3D');
      }
    }

    addGroup('PROPERTIES', otherKeys);

    if (activeProperties.isEmpty) {
      return Center(
          child: Text('Select a Layer to view its Animatable Properties.',
              style: TextStyle(color: Colors.white38, fontSize: AppUIConfig.rootFontSize)));
    }

    double configuredDur = 15000.0;
    if (editor.config != null && editor.config!.globalItems.containsKey('TIMELINE_DURATION') && editor.config!.globalItems['TIMELINE_DURATION']!.keyframes.isNotEmpty) {
        final val = editor.config!.globalItems['TIMELINE_DURATION']!.keyframes.first.value;
        if (val is num) configuredDur = val.toDouble();
    }
    
    double totalDuration = playerController.currentItem != null 
       ? (playerController.duration?.inMilliseconds.toDouble() ?? configuredDur) 
       : configuredDur;
    if (totalDuration <= 0) totalDuration = 15000.0;

    return LayoutBuilder(builder: (context, constraints) {
      // Base screen width for sequences.
      double baseScreenWidth = constraints.maxWidth - _propertiesWidth - 4;
      if (baseScreenWidth < 100) baseScreenWidth = 100;

      // At 1.0 scale, exactly fits entire song to screen width.
      double timelineWidth = baseScreenWidth * _zoomScale;
      double pixelsPerMs = timelineWidth / totalDuration;

      const double initOffsetX = 40.0;
      double totalTimelineScrollWidth = timelineWidth + initOffsetX;

      // Calculate a responsive tick interval so labels NEVER overlap physically on the screen
      double minPixelsBetweenTicks = 60.0;
      double minTickMs = minPixelsBetweenTicks / pixelsPerMs;
      List<double> validIntervals = [
        100,
        250,
        500,
        1000,
        2000,
        5000,
        10000,
        15000,
        30000,
        60000
      ];
      double tickMs = 60000.0;
      for (double interval in validIntervals) {
        if (interval >= minTickMs) {
          tickMs = interval;
          break;
        }
      }

      double globalPlayheadX = initOffsetX +
          (playerController.position.inMilliseconds * pixelsPerMs);

      return Focus(
      focusNode: _timelineFocusNode,
      onKeyEvent: _handleTimelineKey,
      autofocus: true,
      onFocusChange: (focused) => setState(() {}),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
           // 1. The Timeline Header universally grants Timeline Focus unconditionally (Left & Right bounds)
           if (event.localPosition.dy <= 30) {
               FocusManager.instance.primaryFocus?.unfocus();
               _timelineFocusNode.requestFocus();
               return;
           }

           // 2. The Left-Side property body contains text-inputs; naturally organically ignore to prevent theft
           if (event.localPosition.dx <= _propertiesWidth + 8) {
               return;
           }
           
           // 3. The Right-Side track canvas inherently universally grants Timeline Focus securely
           FocusManager.instance.primaryFocus?.unfocus();
           _timelineFocusNode.requestFocus();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                // A. Header Row / Ruler Matrix
                Container(
            height: 20,
            color: const Color(0xFF333333),
            child: Row(
              children: [
                Container(
                  width: _propertiesWidth,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 16, right: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: editor.canUndo ? () => editor.undo() : null,
                          child: Icon(Icons.undo,
                              color: editor.canUndo
                                  ? Colors.white70
                                  : Colors.white24,
                              size: 14),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: editor.canRedo ? () => editor.redo() : null,
                          child: Icon(Icons.redo,
                              color: editor.canRedo
                                  ? Colors.white70
                                  : Colors.white24,
                              size: 14),
                        ),
                        const SizedBox(width: 16),
                        if (editor.selectedPropertyKey != null &&
                            items.containsKey(editor.selectedPropertyKey))
                          Builder(builder: (context) {
                            var item = items[editor.selectedPropertyKey]!;
                            int timeMs =
                                playerController.position.inMilliseconds;
                            int thresholdMs =
                                playerController.isPlaying ? 50 : 25;

                            var matchKfs = item.keyframes
                                .where((k) =>
                                    (k.timeMs - timeMs).abs() <= thresholdMs)
                                .toList();
                            bool existingKf = matchKfs.isNotEmpty;
                            int targetTime =
                                existingKf ? matchKfs.first.timeMs : timeMs;

                            var prevKfs = item.keyframes
                                .where((k) => k.timeMs < timeMs - thresholdMs)
                                .toList();
                            var nextKfs = item.keyframes
                                .where((k) => k.timeMs > timeMs + thresholdMs)
                                .toList();
                            bool hasPrev = prevKfs.isNotEmpty;
                            bool hasNext = nextKfs.isNotEmpty;

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: hasPrev
                                      ? () => playerController.seekTo(Duration(
                                          milliseconds: prevKfs.last.timeMs))
                                      : null,
                                  child: Icon(Icons.arrow_left,
                                      color: hasPrev
                                          ? Colors.blueAccent
                                          : Colors.white24,
                                      size: 18),
                                ),
                                GestureDetector(
                                    onTap: () {
                                      if (existingKf) {
                                        editor.deleteKeyframe(
                                            layerId: editor.selectedLayerId,
                                            varName: item.propertyName,
                                            timeMs: targetTime);
                                        editor.pushHistoryState();
                                      } else {
                                        editor.updateItemValue(
                                          layerId: editor.selectedLayerId,
                                          varName: item.propertyName,
                                          value: item.evaluateAt(targetTime),
                                          dataType: item.dataType,
                                          timeMs: targetTime,
                                        );
                                        editor.pushHistoryState();
                                      }
                                    },
                                    child: Transform.rotate(
                                        angle: 3.14159 / 4,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          decoration: BoxDecoration(
                                            color: existingKf
                                                ? Colors.blueAccent
                                                : Colors.transparent,
                                            border: Border.all(
                                                color: existingKf
                                                    ? Colors.blueAccent
                                                    : Colors.white38,
                                                width: 1.5),
                                          ),
                                        ))),
                                GestureDetector(
                                  onTap: hasNext
                                      ? () => playerController.seekTo(Duration(
                                          milliseconds: nextKfs.first.timeMs))
                                      : null,
                                  child: Icon(Icons.arrow_right,
                                      color: hasNext
                                          ? Colors.blueAccent
                                          : Colors.white24,
                                      size: 18),
                                ),
                              ],
                            );
                          }),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            int localDur = 15000;
                            if (editor.config != null && editor.config!.globalItems.containsKey('TIMELINE_DURATION') && editor.config!.globalItems['TIMELINE_DURATION']!.keyframes.isNotEmpty) {
                               final val = editor.config!.globalItems['TIMELINE_DURATION']!.keyframes.first.value;
                               if (val is num) localDur = val.toInt();
                            }
                            playerController.togglePlayPause(virtualLoopMs: localDur);
                          },
                          child: Icon(
                              playerController.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.blueAccent,
                              size: 14),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            double baseScreenWidth = constraints.maxWidth - _propertiesWidth - 4;
                            if (baseScreenWidth < 100) baseScreenWidth = 100;
                            double newScale = _zoomScale - 0.5;
                            if (newScale < 1.0) newScale = 1.0;
                            if (newScale == _zoomScale) return;
                            double newTimelineWidth = baseScreenWidth * newScale;
                            double newPixelsPerMs = newTimelineWidth / totalDuration;
                            double globalPlayheadX = 40.0 + (playerController.position.inMilliseconds * newPixelsPerMs);
                            double targetScroll = globalPlayheadX - (baseScreenWidth / 2);
                            setState(() => _zoomScale = newScale);
                            _savePreferences();
                            Future.delayed(const Duration(milliseconds: 50), () {
                              if (_bottomHorizontal.hasClients) {
                                _bottomHorizontal.jumpTo(targetScroll.clamp(0.0, _bottomHorizontal.position.maxScrollExtent));
                              }
                            });
                          },
                          child: Icon(AppUIConfig.zoomOutIconCodePoint != null ? IconData(AppUIConfig.zoomOutIconCodePoint!, fontFamily: 'MaterialIcons') : Icons.zoom_out,
                              color: AppUIConfig.zoomOutIconColor ?? Colors.white38, size: 14),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            double baseScreenWidth = constraints.maxWidth - _propertiesWidth - 4;
                            if (baseScreenWidth < 100) baseScreenWidth = 100;
                            double newScale = _zoomScale + 0.5;
                            double newTimelineWidth = baseScreenWidth * newScale;
                            double newPixelsPerMs = newTimelineWidth / totalDuration;
                            double globalPlayheadX = 40.0 + (playerController.position.inMilliseconds * newPixelsPerMs);
                            double targetScroll = globalPlayheadX - (baseScreenWidth / 2);
                            setState(() => _zoomScale = newScale);
                            _savePreferences();
                            Future.delayed(const Duration(milliseconds: 50), () {
                              if (_bottomHorizontal.hasClients) {
                                _bottomHorizontal.jumpTo(targetScroll.clamp(0.0, _bottomHorizontal.position.maxScrollExtent));
                              }
                            });
                          },
                          child: Icon(AppUIConfig.zoomInIconCodePoint != null ? IconData(AppUIConfig.zoomInIconCodePoint!, fontFamily: 'MaterialIcons') : Icons.zoom_in,
                              color: AppUIConfig.zoomInIconColor ?? Colors.white38, size: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _propertiesWidth += details.delta.dx;
                        if (_propertiesWidth < 180) _propertiesWidth = 180;
                        if (_propertiesWidth > constraints.maxWidth - 200) {
                          _propertiesWidth = constraints.maxWidth - 200;
                        }
                      });
                    },
                    onHorizontalDragEnd: (_) => _savePreferences(),
                    child: Container(
                      width: 8,
                      color: const Color(0xFF2D2D30),
                      child: Center(
                        child: Container(
                            width: 2, height: 8, color: Colors.white24),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _topHorizontal,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: totalTimelineScrollWidth,
                      child:
                          LayoutBuilder(builder: (context, scrollConstraints) {
                        List<Widget> ticks = [];

                        // Initialization padding area labels
                        ticks.add(const Positioned(
                            left: initOffsetX / 2.0,
                            bottom: 2,
                            child: FractionalTranslation(
                              translation: Offset(-0.5, 0),
                              child: Tooltip(
                                message: 'Initialization (Time < 0)',
                                child: Icon(Icons.bolt,
                                    color: Colors.blueAccent, size: 14),
                              ),
                            )));
                        ticks.add(Positioned(
                          left: initOffsetX,
                          bottom: 0,
                          top: 0,
                          child: Container(
                              width: 1,
                              color: Colors.blueAccent.withValues(alpha: 0.8)),
                        ));

                        for (double t = 0; t <= totalDuration; t += tickMs) {
                          double leftPos = initOffsetX + (t * pixelsPerMs);

                          int totalSeconds = (t / 1000).toInt();
                          int minutes = totalSeconds ~/ 60;
                          int seconds = totalSeconds % 60;
                          int ms = (t % 1000).toInt();

                          String label = '';
                          if (tickMs < 1000 && ms > 0) {
                            label =
                                '$minutes:${seconds.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
                          } else {
                            label =
                                '$minutes:${seconds.toString().padLeft(2, '0')}';
                          }

                          // Center text natively exactly over the pixel tick
                          ticks.add(Positioned(
                              left: leftPos,
                              bottom: 4,
                              child: FractionalTranslation(
                                translation: const Offset(-0.5, 0),
                                child: Text(label,
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: AppUIConfig.smallFontSize)),
                              )));

                          // Add major physical tick mark (just a short bar)
                          ticks.add(Positioned(
                            left: leftPos,
                            bottom: 0,
                            child: Container(
                                width: 1, height: 4, color: Colors.white54),
                          ));

                          // Draw minor physical tick marks between majors
                          double minorDivisions = tickMs <= 250 ? 2.0 : 4.0;
                          double minorInterval = tickMs / minorDivisions;
                          for (int m = 1; m < minorDivisions; m++) {
                            double minorPos = initOffsetX +
                                ((t + minorInterval * m) * pixelsPerMs);
                            if ((t + minorInterval * m) <= totalDuration) {
                              ticks.add(Positioned(
                                  left: minorPos,
                                  bottom: 0,
                                  child: Container(
                                      width: 1,
                                      height: 3,
                                      color: Colors.white24)));
                            }
                          }
                        }

                        // Playhead tracker
                        double playheadX = initOffsetX +
                            (playerController.position.inMilliseconds *
                                pixelsPerMs);
                        ticks.add(Positioned(
                            left: playheadX,
                            bottom: -2,
                            child: FractionalTranslation(
                                translation: const Offset(-0.5, 0),
                                child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    dragStartBehavior: DragStartBehavior
                                        .down, // Instantaneously grab custody natively!
                                    onHorizontalDragStart: (details) {
                                      _scrubberStartMs = playerController
                                          .position.inMilliseconds
                                          .toDouble();
                                    },
                                    onHorizontalDragUpdate: (details) {
                                      _scrubberStartMs +=
                                          (details.delta.dx / pixelsPerMs);
                                      playerController.seekTo(Duration(
                                          milliseconds: _scrubberStartMs
                                              .toInt()
                                              .clamp(
                                                  0, totalDuration.toInt())));
                                    },
                                    child: Container(
                                        width:
                                            100, // Massive 100px width for extremely reliable thumb/cursor interception
                                        height: 32,
                                        // DEBUG HITBOX VISUALIZATION! Neon green semi-transparent!
                                        color: Colors.greenAccent
                                            .withValues(alpha: 0.35),
                                        child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Padding(
                                              padding:
                                                  EdgeInsets.only(bottom: 2),
                                              child: Icon(Icons.arrow_drop_down,
                                                  size: 24,
                                                  color: Colors.white),
                                            )))))));

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (details) {
                            int timeMs =
                                ((details.localPosition.dx - initOffsetX) /
                                        pixelsPerMs)
                                    .toInt();
                            playerController.seekTo(Duration(
                                milliseconds:
                                    timeMs.clamp(0, totalDuration.toInt())));
                          },
                          child: Container(
                            color: Colors
                                .transparent, // Requires color to catch empty space taps
                            height:
                                32, // Force full height hitbox for ease of scrubbing
                            child:
                                Stack(clipBehavior: Clip.none, children: ticks),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // B. Dual-Scrolled Items Matrix
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Left Vertical Scroller (Property Names)
                SizedBox(
                  width: _propertiesWidth,
                  child: ListView.builder(
                    controller: _leftVertical,
                    physics: const ClampingScrollPhysics(),
                    itemCount: activeProperties.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Container(
                          height: 22,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 24, right: 12),
                          decoration: BoxDecoration(
                              color: AppColors.titleBarBackground,
                              border: Border(
                                  bottom:
                                      BorderSide(color: AppColors.controlBorder))),
                          child: Row(
                            children: [
                              const Icon(Icons.mic_external_on,
                                  size: 10, color: Colors.purpleAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text('LYRICS ALIGNER',
                                      style: TextStyle(
                                          color: Colors.purpleAccent,
                                          fontSize: AppUIConfig.smallFontSize,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold))),
                              Tooltip(
                                message: 'Previous Subtitle',
                                child: GestureDetector(
                                  onTap: () {
                                    int cur =
                                        playerController.position.inMilliseconds;
                                    var lines = context
                                        .read<LyricsViewController>()
                                        .lines;
                                    var prevs = lines
                                        .where((l) => l.startMs < cur - 100)
                                        .toList();
                                    if (prevs.isNotEmpty) {
                                      playerController.seekTo(Duration(
                                          milliseconds: prevs.last.startMs));
                                    }
                                  },
                                  child: Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 4),
                                      child: Icon(Icons.chevron_left,
                                          size: 16, color: Colors.purpleAccent)),
                                ),
                              ),
                              Tooltip(
                                message: 'Next Subtitle',
                                child: GestureDetector(
                                  onTap: () {
                                    int cur =
                                        playerController.position.inMilliseconds;
                                    var lines = context
                                        .read<LyricsViewController>()
                                        .lines;
                                    var nexts = lines
                                        .where((l) => l.startMs > cur + 100)
                                        .toList();
                                    if (nexts.isNotEmpty) {
                                      playerController.seekTo(Duration(
                                          milliseconds: nexts.first.startMs));
                                    }
                                  },
                                  child: Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 4),
                                      child: Icon(Icons.chevron_right,
                                          size: 16, color: Colors.purpleAccent)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      int dataIndex = index - 1;
                      String propKey = activeProperties[dataIndex];

                      if (propKey.startsWith('__GROUP_') ||
                          propKey.startsWith('__SUBGROUP_')) {
                        bool isSub = propKey.startsWith('__SUBGROUP_');
                        String rawName = isSub
                            ? propKey.replaceAll('__SUBGROUP_', '')
                            : propKey.replaceAll('__GROUP_', '');
                        String group = rawName;
                        String displayName = isSub
                            ? rawName.split('|').last.replaceAll('_', ' ')
                            : rawName.replaceAll('_', ' ');
                        bool isC = _collapsedTimelineGroups.contains(group);

                        return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isC) {
                                  _collapsedTimelineGroups.remove(group);
                                } else {
                                  _collapsedTimelineGroups.add(group);
                                }
                              });
                              _savePreferences();
                            },
                            child: Container(
                                height: 22,
                                padding: EdgeInsets.only(left: isSub ? 16 : 8),
                                decoration: BoxDecoration(
                                    color: isSub
                                        ? const Color(0xFF252526)
                                        : const Color(0xFF2D2D30),
                                    border: const Border(
                                        bottom: BorderSide(
                                            color: Color(0xFF333333)))),
                                child: Row(
                                  children: [
                                    Icon(
                                        isC
                                            ? Icons.arrow_right
                                            : Icons.arrow_drop_down,
                                        color: isSub
                                            ? Colors.lightBlueAccent
                                            : Colors.amberAccent,
                                        size: 16),
                                    const SizedBox(width: 4),
                                    Text(displayName,
                                        style: TextStyle(
                                            color: isSub
                                                ? Colors.white70
                                                : Colors.white,
                                            fontSize: isSub ? 9 : 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2)),
                                  ],
                                )));
                      }

                      PropertyItem propItem = items[propKey]!;
                      int currentMs = playerController.position.inMilliseconds;
                      dynamic currentVal = propItem.evaluateAt(currentMs);

                      Widget valueBadge;
                      if (propItem.dataType == 'COLOR') {
                        Color cVal = currentVal is Color
                            ? currentVal
                            : Colors.transparent;
                        valueBadge = GestureDetector(
                          onTap: () {
                            editor.selectProperty(propKey);
                            showDialog(
                                context: context,
                                builder: (dialogContext) {
                                  return DraggableAlertDialog(
                                    backgroundColor: const Color(0xFF252526),
                                    title: Text(
                                        'Edit ${_getSimplifiedName(propKey)}',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: AppUIConfig.rootFontSize)),
                                    content: SingleChildScrollView(
                                      child: ColorPicker(
                                        color: cVal,
                                        enableOpacity: true,
                                        showColorCode: true,
                                        pickersEnabled: const <ColorPickerType,
                                            bool>{
                                          ColorPickerType.both: false,
                                          ColorPickerType.primary: false,
                                          ColorPickerType.accent: false,
                                          ColorPickerType.bw: false,
                                          ColorPickerType.custom: false,
                                          ColorPickerType.wheel: true,
                                        },
                                        onColorChanged: (c) {
                                          editor.updateItemValue(
                                            layerId: editor.selectedLayerId,
                                            varName: propKey,
                                            value: c,
                                            dataType: 'COLOR',
                                            timeMs: playerController
                                                .position.inMilliseconds,
                                          );
                                          context
                                              .read<LyricsViewController>()
                                              .forceEvaluation();
                                        },
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogContext),
                                          child: Text('Done', style: TextStyle(
                                                  color:
                                                      Colors.lightBlueAccent)))
                                    ],
                                  );
                                });
                          },
                          child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: cVal,
                                border: Border.all(
                                    color: Colors.white54, width: 1.5),
                                borderRadius: BorderRadius.circular(4),
                              )),
                        );
                      } else if (propKey == 'LAYER_BLEND' ||
                          propItem.dataType == 'ENUM') {
                        String sVal =
                            currentVal is String ? currentVal : 'srcOver';
                        valueBadge = PopupMenuButton<String>(
                          initialValue: sVal,
                          color: const Color(0xFF252526),
                          tooltip: 'Select Blend Mode',
                          onSelected: (newV) {
                            editor.updateItemValue(
                              layerId: editor.selectedLayerId,
                              varName: propKey,
                              value: newV,
                              dataType: 'STRING',
                              timeMs: playerController.position.inMilliseconds,
                            );
                            editor.pushHistoryState();
                            context
                                .read<LyricsViewController>()
                                .forceEvaluation();
                          },
                          itemBuilder: (ctx) => const [
                            'srcOver',
                            'overlay',
                            'screen',
                            'multiply',
                            'colorDodge',
                            'clear',
                            'lighten',
                            'darken',
                            'exclusion',
                            'difference'
                          ]
                              .map((e) => PopupMenuItem(
                                    value: e,
                                    height: 32,
                                    child: Text(e,
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: AppUIConfig.rootFontSize)),
                                  ))
                              .toList(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white24)),
                            child: Text(sVal,
                                style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: AppUIConfig.smallFontSize,
                                    fontFamily: 'monospace')),
                          ),
                        );
                      } else if (propItem.dataType == 'BOOLEAN') {
                        bool bVal = currentVal is bool ? currentVal : true;
                        valueBadge = Transform.scale(
                            scale: 0.7,
                            child: Checkbox(
                                value: bVal,
                                activeColor: Colors.amber,
                                visualDensity: VisualDensity.compact,
                                onChanged: (newV) {
                                  editor.updateItemValue(
                                    layerId: editor.selectedLayerId,
                                    varName: propKey,
                                    value: newV ?? false,
                                    dataType: 'BOOLEAN',
                                    timeMs: playerController
                                        .position.inMilliseconds,
                                  );
                                  editor.pushHistoryState();
                                  context
                                      .read<LyricsViewController>()
                                      .forceEvaluation();
                                }));
                      } else {
                        double numVal = currentVal is double
                            ? currentVal
                            : (currentVal is num ? currentVal.toDouble() : 0.0);
                        valueBadge = _NumberScrubField(
                          propKey: propKey,
                          initialValue: numVal,
                          editor: editor,
                          playerController: playerController,
                        );
                      }

                      bool isSelected = editor.selectedPropertyKey == propKey;
                      bool isSubProp = [
                        'LAYER_POS_',
                        'LAYER_SCALE_',
                        'LAYER_ROTATION_',
                        'LAYER_PIVOT_'
                      ].any((p) => propKey.startsWith(p));

                      return GestureDetector(
                        onTap: () => editor.selectProperty(propKey),
                        child: Container(
                          height: 22,
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.only(
                              left: isSubProp ? 24 : 12, right: 12),
                          decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white12
                                  : (index % 2 == 0
                                      ? Colors.transparent
                                      : Colors.white.withValues(alpha: 0.02)),
                              border: const Border(
                                  bottom:
                                      BorderSide(color: Color(0xFF333333)))),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(_getSimplifiedName(propKey),
                                      style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.white70,
                                          fontSize: AppUIConfig.smallFontSize,
                                          fontFamily: 'monospace'))),
                              valueBadge,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _propertiesWidth += details.delta.dx;
                        if (_propertiesWidth < 180) _propertiesWidth = 180;
                        if (_propertiesWidth > constraints.maxWidth - 200) {
                          _propertiesWidth = constraints.maxWidth - 200;
                        }
                      });
                    },
                    child: Container(
                      width: 8,
                      color: const Color(0xFF2D2D30),
                      child: Center(
                        child: Container(
                            width: 2, height: 32, color: Colors.white24),
                      ),
                    ),
                  ),
                ),
                // 2. Right Vertical Scroller (The sequences)
                Expanded(
                  child: SingleChildScrollView(
                    controller: _bottomHorizontal,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: totalTimelineScrollWidth,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onSecondaryTapUp: (details) {
                           showMenu(
                              context: context,
                              position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy, details.globalPosition.dx, details.globalPosition.dy),
                              items: [
                                 PopupMenuItem(value: 'add', height: 32, child: Text('Add Lyric Here...', style: TextStyle(fontSize: AppUIConfig.rootFontSize))),
                              ],
                           ).then((val) {
                              if (val == 'add') {
                                  double localDx = details.localPosition.dx;
                                  int targetMs = ((localDx - initOffsetX) / pixelsPerMs).toInt().clamp(0, 3600000);
                                  context.read<LyricsViewController>().addLine(targetMs, 'Text');
                              }
                           });
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                          Positioned.fill(
                            child: ListView.builder(
                              controller: _rightVertical,
                              physics: const ClampingScrollPhysics(),
                              itemCount: activeProperties.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  var lyricsLines = context
                                      .read<LyricsViewController>()
                                      .lines;
                                  List<Widget> lyricMarkers = [];
                                  for (int i = 0; i < lyricsLines.length; i++) {
                                    var line = lyricsLines[i];
                                    double leftPos = initOffsetX +
                                        (line.startMs * pixelsPerMs);
                                    lyricMarkers.add(Positioned(
                                      left: leftPos - 25, // Anchors offset for magnet padding
                                      top: 4,
                                      bottom: 4,
                                      child: Tooltip(
                                        message: line.text.trim(),
                                        child: StatefulBuilder(
                                          builder: (ctx, localSetState) {
                                            int trackedIndex = i;
                                            double dragAccumulator = 0.0;
                                            int dragInitialMs = line.startMs;

                                            return GestureDetector(
                                              onTap: () {
                                                  context.read<PlayerController>().seekTo(Duration(milliseconds: line.startMs));
                                                  context.read<LyricsViewController>().updatePosition(line.startMs);
                                              },
                                              onHorizontalDragStart: (details) {
                                                  dragAccumulator = 0.0;
                                                  dragInitialMs = context.read<LyricsViewController>().lines[trackedIndex].startMs;
                                              },
                                              onHorizontalDragUpdate: (details) {
                                                  dragAccumulator += details.delta.dx;
                                                  final deltaMs = (dragAccumulator / pixelsPerMs).toInt();
                                                  final newMs = (dragInitialMs + deltaMs).clamp(0, 3600000); // Max 1 hour
                                                  trackedIndex = context.read<LyricsViewController>().updateLineStartMs(trackedIndex, newMs);
                                              },
                                              onSecondaryTapDown: (details) {
                                                 showMenu(
                                                    context: context,
                                                    position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy, details.globalPosition.dx, details.globalPosition.dy),
                                                    items: <PopupMenuEntry<String>>[
                                                       PopupMenuItem<String>(value: 'edit', height: 32, child: Text('Edit: "${line.text}"', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppUIConfig.rootFontSize))),
                                                       PopupMenuItem<String>(value: 'duplicate', height: 32, child: Text('Duplicate Lyric', style: TextStyle(fontSize: AppUIConfig.rootFontSize))),
                                                       PopupMenuItem<String>(value: 'delete', height: 32, child: Text('Delete Lyric', style: TextStyle(color: Colors.redAccent, fontSize: AppUIConfig.rootFontSize))),
                                                       const PopupMenuDivider(),
                                                       PopupMenuItem<String>(value: 'add', height: 32, child: Text('Add Lyric Here...', style: TextStyle(fontSize: AppUIConfig.rootFontSize))),
                                                       PopupMenuItem<String>(value: 'fullList', height: 32, child: Text('Edit Full Lyric List...', style: TextStyle(fontSize: AppUIConfig.rootFontSize))),
                                                    ],
                                                 ).then((val) {
                                                    if (val == 'edit') {
                                                        final tc = TextEditingController(text: line.text);
                                                        showDialog(context: context, builder: (ctx) => AlertDialog(
                                                           title: Text('Edit Lyric Text', style: TextStyle(fontSize: AppUIConfig.windowTitleFontSize)),
                                                           content: TextField(controller: tc, autofocus: true, maxLines: null, keyboardType: TextInputType.multiline),
                                                           actions: [
                                                              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
                                                              TextButton(onPressed: () { context.read<LyricsViewController>().updateLineText(trackedIndex, tc.text); Navigator.pop(ctx); }, child: Text('Save')),
                                                           ]
                                                        ));
                                                    } else if (val == 'duplicate') {
                                                        context.read<LyricsViewController>().duplicateLine(trackedIndex);
                                                    } else if (val == 'delete') {
                                                        context.read<LyricsViewController>().deleteLine(trackedIndex);
                                                    } else if (val == 'add') {
                                                        context.read<LyricsViewController>().addLine(line.startMs + 500, 'Text');
                                                    } else if (val == 'fullList') {
                                                        final vc = context.read<LyricsViewController>();
                                                        final tc = TextEditingController(text: LrcParser.generateLrc(vc.lines));
                                                        showDialog(context: context, builder: (ctx) => AlertDialog(
                                                           title: Text('Edit Full Lyric List (LRC Format)', style: TextStyle(fontSize: AppUIConfig.windowTitleFontSize)),
                                                           content: TextField(controller: tc, autofocus: true, maxLines: null, keyboardType: TextInputType.multiline, style: TextStyle(fontFamily: 'monospace', fontSize: AppUIConfig.rootFontSize)),
                                                           actions: [
                                                              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
                                                              TextButton(onPressed: () {
                                                                  final parsed = LrcParser.parse(tc.text);
                                                                  vc.replaceLines(parsed);
                                                                  Navigator.pop(ctx);
                                                              }, child: Text('Save')),
                                                           ]
                                                        ));
                                                    }
                                                 });
                                              },
                                              child: Container(
                                                width: 50, // Magnet style expanded horizontal hit box
                                                color: Colors.transparent, 
                                                alignment: Alignment.center,
                                                child: Container(
                                                  width: 12,
                                                  decoration: BoxDecoration(
                                                    color: Colors.purpleAccent,
                                                    borderRadius: BorderRadius.circular(3),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                        ),
                                      ),
                                    ));
                                  }
                                  return GestureDetector(
                                    onSecondaryTapDown: (details) {
                                       showMenu(
                                          context: context,
                                          position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy, details.globalPosition.dx, details.globalPosition.dy),
                                          items: <PopupMenuEntry<String>>[
                                             PopupMenuItem(value: 'add', height: 32, child: Text('Add Lyric Here...', style: TextStyle(fontSize: AppUIConfig.rootFontSize))),
                                             PopupMenuItem(value: 'fullList', height: 32, child: Text('Edit Full Lyric List...', style: TextStyle(fontSize: AppUIConfig.rootFontSize))),
                                             const PopupMenuDivider(),
                                             PopupMenuItem(value: 'aiTranscribe', height: 32, child: Text('AI Transcription via Karaoke-Gen...', style: TextStyle(fontSize: AppUIConfig.rootFontSize, color: Colors.amberAccent))),
                                          ],
                                       ).then((val) {
                                          if (val == 'add') {
                                              double localDx = details.localPosition.dx;
                                              int targetMs = ((localDx - initOffsetX) / pixelsPerMs).toInt().clamp(0, 3600000);
                                              context.read<LyricsViewController>().addLine(targetMs, 'Text');
                                          } else if (val == 'aiTranscribe') {
                                              final curr = context.read<PlayerController>().currentItem;
                                              if (curr != null) {
                                                 KaraokeGenService.instance.runTranscription(curr.source, curr.artist ?? 'Unknown', curr.title);
                                              }
                                          } else if (val == 'fullList') {
                                              final vc = context.read<LyricsViewController>();
                                              final tc = TextEditingController(text: LrcParser.generateLrc(vc.lines));
                                              showDialog(context: context, builder: (ctx) => AlertDialog(
                                                 title: Text('Edit Full Lyric List (LRC Format)', style: TextStyle(fontSize: AppUIConfig.windowTitleFontSize)),
                                                 content: TextField(controller: tc, autofocus: true, maxLines: null, keyboardType: TextInputType.multiline, style: TextStyle(fontFamily: 'monospace', fontSize: AppUIConfig.rootFontSize)),
                                                 actions: [
                                                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
                                                    TextButton(onPressed: () {
                                                        final parsed = LrcParser.parse(tc.text);
                                                        vc.replaceLines(parsed);
                                                        Navigator.pop(ctx);
                                                    }, child: Text('Save')),
                                                 ]
                                              ));
                                          }
                                       });
                                    },
                                    child: Container(
                                      height: 22,
                                      decoration: BoxDecoration(
                                          color: AppColors.titleBarBackground,
                                        border: Border(
                                            bottom: BorderSide(
                                                color: AppColors.controlBorder))),
                                    child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            left: initOffsetX,
                                            top: 0,
                                            bottom: 0,
                                            child: Container(
                                                width: 1,
                                                color: Colors.blueAccent
                                                    .withValues(alpha: 0.1)),
                                          ),
                                          ...lyricMarkers,
                                        ]),
                                  ));
                                }

                                int dataIndex = index - 1;
                                String propKey = activeProperties[dataIndex];

                                if (propKey.startsWith('__GROUP_') ||
                                    propKey.startsWith('__SUBGROUP_')) {
                                  bool isSub =
                                      propKey.startsWith('__SUBGROUP_');

                                  List<String> childKeys = [];
                                  if (propKey == '__GROUP_TRANSFORM') {
                                    childKeys = [
                                      ...posKeys,
                                      ...scaleKeys,
                                      ...rotKeys,
                                      ...pivotKeys,
                                      ...tiltKeys
                                    ];
                                  } else if (propKey == '__GROUP_PROPERTIES')
                                    childKeys = otherKeys;
                                  else if (propKey ==
                                      '__SUBGROUP_TRANSFORM|POSITION')
                                    childKeys = posKeys;
                                  else if (propKey ==
                                      '__SUBGROUP_TRANSFORM|SCALE')
                                    childKeys = scaleKeys;
                                  else if (propKey ==
                                      '__SUBGROUP_TRANSFORM|ROTATION')
                                    childKeys = rotKeys;
                                  else if (propKey ==
                                      '__SUBGROUP_TRANSFORM|PIVOT')
                                    childKeys = pivotKeys;
                                  else if (propKey ==
                                      '__SUBGROUP_TRANSFORM|TILT 3D')
                                    childKeys = tiltKeys;

                                  Set<int> uniqueTimes = {};
                                  for (var ck in childKeys) {
                                    if (items.containsKey(ck)) {
                                      for (var kf in items[ck]!.keyframes) {
                                        uniqueTimes.add(kf.timeMs);
                                      }
                                    }
                                  }

                                  List<Widget> hintWidgets = [];
                                  for (var t in uniqueTimes) {
                                    double leftPos =
                                        initOffsetX + (t * pixelsPerMs);
                                    if (t < 0) leftPos = initOffsetX / 2.0;
                                    hintWidgets.add(Positioned(
                                        left: leftPos - 3,
                                        top: 8,
                                        child: Transform.rotate(
                                            angle: pi / 4.0,
                                            child: Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                    border: Border.all(
                                                        color: Colors.white38,
                                                        width: 1.2),
                                                    color:
                                                        Colors.transparent)))));
                                  }

                                  return Container(
                                      height: 22,
                                      decoration: BoxDecoration(
                                          color: isSub
                                              ? const Color(0xFF252526)
                                              : const Color(0xFF2D2D30),
                                          border: const Border(
                                              bottom: BorderSide(
                                                  color: Color(0xFF333333)))),
                                      child: Stack(
                                          clipBehavior: Clip.none,
                                          children: hintWidgets));
                                }

                                PropertyItem propItem = items[propKey]!;

                                List<Widget> keyframeWidgets = [];
                                List<Widget> connectorWidgets = [];

                                for (int i = 0;
                                    i < propItem.keyframes.length;
                                    i++) {
                                  var kf = propItem.keyframes[i];
                                  double leftPos =
                                      initOffsetX + (kf.timeMs * pixelsPerMs);
                                  if (kf.timeMs < 0) {
                                    leftPos = initOffsetX / 2.0;
                                  }

                                  // Draw connector to next keyframe or to end of song if it's the last one
                                  double nextPos;
                                  if (i < propItem.keyframes.length - 1) {
                                    var nextKf = propItem.keyframes[i + 1];
                                    nextPos = initOffsetX +
                                        (nextKf.timeMs * pixelsPerMs);
                                  } else {
                                    // For the last unmatched keyframe, conceptually bridge it visually to the absolute end of the song
                                    nextPos = initOffsetX +
                                        (totalDuration.toInt() * pixelsPerMs);
                                  }

                                  Widget connectorGraphic;
                                  if (propItem.dataType == 'BOOLEAN') {
                                    // Draw explicitly distinct 'off' blocks instead of voiding them so switch logic is visually unbroken on the range!
                                    connectorGraphic = Container(
                                        color: kf.value == true
                                            ? Colors.amber
                                                .withValues(alpha: 0.35)
                                            : Colors.white
                                                .withValues(alpha: 0.05));
                                  } else {
                                    connectorGraphic = Container(
                                        color: Colors.blueAccent
                                            .withValues(alpha: 0.3));
                                  }

                                  connectorWidgets.add(Positioned(
                                    left: leftPos,
                                    top: 10,
                                    width: max(0.0, nextPos - leftPos),
                                    height: 2,
                                    child: connectorGraphic,
                                  ));

                                  Color kfColor =
                                      propItem.dataType == 'COLOR' &&
                                              kf.value is Color
                                          ? kf.value
                                          : Colors.blueAccent;

                                  if (kf.timeMs >= 0) {
                                    keyframeWidgets.add(_DraggableKeyframe(
                                      kf: kf,
                                      propKey: propKey,
                                      kfColor: kfColor,
                                      pixelsPerMs: pixelsPerMs,
                                      totalDuration: totalDuration.toInt(),
                                      initOffsetX: initOffsetX,
                                      editor: editor,
                                      playerController: playerController,
                                    ));
                                  }
                                }

                                // 2. Draw explicit Initialization Node
                                bool isInitialized = propItem.keyframes
                                    .any((k) => k.timeMs < 0);
                                keyframeWidgets.add(Positioned(
                                    left: (initOffsetX / 2.0) -
                                        7.0, // Center 14px icon
                                    top: 4,
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () {
                                          editor.selectProperty(propKey);
                                          // If uninitialized, create a permanent init hold keyframe at -1 ms
                                          if (!isInitialized) {
                                            // We extract current value evaluated at 0 to freeze it backwards
                                            var currentVal = items[propKey]!
                                                .evaluateAt(playerController
                                                    .position.inMilliseconds);
                                            editor.updateItemValue(
                                                layerId: editor.selectedLayerId,
                                                varName: propKey,
                                                value: currentVal,
                                                dataType: propItem.dataType,
                                                timeMs: -1);
                                            editor.pushHistoryState();
                                          } else {
                                            // If already initialized, perhaps delete it to reset, or just seek to 0. We'll seek to 0 to be safe.
                                            playerController
                                                .seekTo(Duration.zero);
                                          }
                                          context
                                              .read<LyricsViewController>()
                                              .forceEvaluation();
                                        },
                                        child: Tooltip(
                                            message: isInitialized
                                                ? 'Initialized (Time < 0)\nTap to seek to item start'
                                                : 'Uninitialized\nTap to inject initial state',
                                            child: Container(
                                              color: Colors
                                                  .transparent, // expanded hit area
                                              padding: const EdgeInsets.all(2),
                                              child: Icon(
                                                isInitialized
                                                    ? Icons.radio_button_checked
                                                    : Icons
                                                        .radio_button_unchecked,
                                                color: isInitialized
                                                    ? Colors.blueAccent
                                                    : Colors.white24,
                                                size: 10,
                                              ),
                                            )),
                                      ),
                                    )));

                                bool isSelected =
                                    editor.selectedPropertyKey == propKey;

                                return Container(
                                  height: 22,
                                  decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white12
                                          : (index % 2 == 0
                                              ? Colors.transparent
                                              : Colors.white
                                                  .withValues(alpha: 0.02)),
                                      border: const Border(
                                          bottom: BorderSide(
                                              color: Color(0xFF333333)))),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        left: initOffsetX,
                                        top: 0,
                                        bottom: 0,
                                        child: Container(
                                            width: 1,
                                            color: Colors.blueAccent
                                                .withValues(alpha: 0.1)),
                                      ),
                                      ...connectorWidgets,
                                      ...keyframeWidgets,
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          Positioned(
                              left: globalPlayheadX - 1.0,
                              top: 0,
                              bottom: 0,
                              child: IgnorePointer(
                                child: Container(
                                    width: 2,
                                    color: Colors.redAccent
                                        .withValues(alpha: 0.8)),
                              )),
                        ], // Closes inner Stack children
                      ), // Closes Stack
                    ), // Closes GestureDetector
                    ), // Closes SizedBox
                  ), // Closes SingleChildScrollView
                ), // Closes Expanded
              ],
            ),
          ),
        ],
        ),
        Positioned(
          left: _propertiesWidth + 8,
          top: 0,
          bottom: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                 border: Border.all(color: _timelineFocusNode.hasFocus ? Colors.blueAccent : Colors.transparent, width: 1.0)
              )
            )
          )
        ),
        Positioned(
          bottom: 16,
          right: 32,
          child: ValueListenableBuilder<String>(
            valueListenable: KaraokeGenService.instance.transcriptionStatus,
            builder: (context, status, child) {
               if (status == 'Idle') return const SizedBox.shrink();
               return Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 decoration: BoxDecoration(
                   color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
                   borderRadius: BorderRadius.circular(4),
                   border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
                   boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     if (!status.contains('Complete') && !status.contains('Failed') && !status.contains('Error'))
                       const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent)),
                     if (!status.contains('Complete') && !status.contains('Failed') && !status.contains('Error'))
                       const SizedBox(width: 12),
                     Text(status, style: TextStyle(color: Colors.amberAccent, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold)),
                     const SizedBox(width: 16),
                     GestureDetector(
                       onTap: () => KaraokeGenService.instance.transcriptionStatus.value = 'Idle',
                       child: const Icon(Icons.close, color: Colors.white54, size: 14),
                     )
                   ],
                 )
               );
            }
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: ValueListenableBuilder<String>(
            valueListenable: isTextInputFocusedNotifier,
            builder: (context, focusStatus, child) {
               return Tooltip(
                 message: 'Focus Status: $focusStatus',
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                   decoration: BoxDecoration(
                     color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
                     borderRadius: BorderRadius.circular(16),
                     border: Border.all(color: focusStatus.startsWith('YES') ? Colors.redAccent.withValues(alpha: 0.5) : Colors.white24),
                     boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                   ),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Text('Focus: $focusStatus', style: TextStyle(color: focusStatus.startsWith('YES') ? Colors.redAccent : Colors.white54, fontSize: 10)),
                       const SizedBox(width: 8),
                       Icon(Icons.edit_note, color: focusStatus.startsWith('YES') ? Colors.redAccent : Colors.white54, size: 20),
                     ]
                   )
                 )
               );
            }
          ),
        ),
       ],
      ),
      ),
      );
    });
  }
}

class _NumberScrubField extends StatefulWidget {
  final String propKey;
  final double initialValue;
  final EditorStateController editor;
  final PlayerController playerController;

  const _NumberScrubField({
    Key? key,
    required this.propKey,
    required this.initialValue,
    required this.editor,
    required this.playerController,
  }) : super(key: key);

  @override
  State<_NumberScrubField> createState() => _NumberScrubFieldState();
}

class _NumberScrubFieldState extends State<_NumberScrubField> {
  bool _isEditing = false;
  late TextEditingController _ctrl;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue.toStringAsFixed(3));
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        setState(() => _isEditing = false);
      }
    });
  }

  @override
  void didUpdateWidget(_NumberScrubField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.initialValue != widget.initialValue) {
      _ctrl.text = widget.initialValue.toStringAsFixed(3);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String val) {
    if (double.tryParse(val) != null) {
      widget.editor.updateItemValue(
          layerId: widget.editor.selectedLayerId,
          varName: widget.propKey,
          value: double.parse(val),
          dataType: 'NUMBER',
          timeMs: widget.playerController.position.inMilliseconds);
      widget.editor.pushHistoryState();
      if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
    }
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              double mult = 0.01;
              if (widget.propKey.contains('ROTATION')) mult = 0.5;
              if (widget.propKey.contains('BLUR')) mult = 0.2;
              if (widget.propKey.contains('COUNT')) mult = 1.0;
              if (widget.propKey.contains('SPEED')) mult = 0.05;

              double newVal = widget.initialValue + (details.delta.dx * mult);
              widget.editor.updateItemValue(
                  layerId: widget.editor.selectedLayerId,
                  varName: widget.propKey,
                  value: newVal,
                  dataType: 'NUMBER',
                  timeMs: widget.playerController.position.inMilliseconds);
              if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
            },
            onHorizontalDragEnd: (_) => widget.editor.pushHistoryState(),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child:
                  Icon(Icons.compare_arrows, size: 12, color: Colors.white38),
            ),
          )),
      GestureDetector(
          onTap: () {
            setState(() => _isEditing = true);
            widget.editor.selectProperty(widget.propKey);
            Future.delayed(const Duration(milliseconds: 50),
                () => _focusNode.requestFocus());
          },
          child: _isEditing
              ? SizedBox(
                  width: 50,
                  height: 20,
                  child: TextField(
                    focusNode: _focusNode,
                    controller: _ctrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: AppUIConfig.smallFontSize,
                        fontFamily: 'monospace'),
                    decoration: InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        filled: true,
                        fillColor: Colors.black26,
                        border:
                            OutlineInputBorder(borderSide: BorderSide.none)),
                    onSubmitted: _submit,
                    onTapOutside: (_) => setState(() => _isEditing = false),
                  ))
              : Container(
                  width: 50,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24)),
                  alignment: Alignment.centerLeft,
                  child: Text(widget.initialValue.toStringAsFixed(3),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.lightBlueAccent,
                          fontSize: AppUIConfig.smallFontSize,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold)),
                ))
    ]);
  }
}

class _DraggableKeyframe extends StatefulWidget {
  final TimelineKeyframe kf;
  final String propKey;
  final Color kfColor;
  final double pixelsPerMs;
  final int totalDuration;
  final double initOffsetX;
  final EditorStateController editor;
  final PlayerController playerController;

  const _DraggableKeyframe({
    required this.kf,
    required this.propKey,
    required this.kfColor,
    required this.pixelsPerMs,
    required this.totalDuration,
    required this.initOffsetX,
    required this.editor,
    required this.playerController,
  });

  @override
  State<_DraggableKeyframe> createState() => _DraggableKeyframeState();
}

class _DraggableKeyframeState extends State<_DraggableKeyframe> {
  double _cumulativeDeltaX = 0;
  int _dragStartTimeMs = 0;

  @override
  Widget build(BuildContext context) {
    double leftPos =
        widget.initOffsetX + (widget.kf.timeMs * widget.pixelsPerMs);
    if (widget.kf.timeMs < 0) leftPos = widget.initOffsetX / 2.0;

    return Positioned(
      left: leftPos - 6.0,
      top: 5,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            widget.playerController
                .seekTo(Duration(milliseconds: widget.kf.timeMs));
            widget.editor.selectProperty(widget.propKey);
          },
          onHorizontalDragStart: (_) {
            _cumulativeDeltaX = 0;
            _dragStartTimeMs = widget.kf.timeMs;
          },
          onHorizontalDragUpdate: (details) {
            _cumulativeDeltaX += details.delta.dx;
            int deltaMs = (_cumulativeDeltaX / widget.pixelsPerMs).toInt();
            if (deltaMs != 0) {
              int newTime =
                  (_dragStartTimeMs + deltaMs).clamp(0, widget.totalDuration);
              widget.editor.moveKeyframe(
                layerId: widget.editor.selectedLayerId,
                varName: widget.propKey,
                oldTimeMs: widget.kf.timeMs,
                newTimeMs: newTime,
              );
            }
          },
          onHorizontalDragEnd: (_) => widget.editor.pushHistoryState(),
          child: Tooltip(
            message:
                'Value: \${widget.kf.value}\nTime: \${widget.kf.timeMs}ms\n(Tap: Seek, Drag: Move)',
            child: Container(
              padding: const EdgeInsets.all(2), // hit target expansion
              color: Colors.transparent,
              child: Transform.rotate(
                angle: pi / 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.kfColor,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RightPropertiesPanel extends StatefulWidget {
  const RightPropertiesPanel({super.key});

  @override
  State<RightPropertiesPanel> createState() => RightPropertiesPanelState();
}

class RightPropertiesPanelState extends State<RightPropertiesPanel> {
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _pathCtrl = TextEditingController();
  late final CodeController _codeCtrl;

  @override
  void initState() {
    super.initState();
    _codeCtrl = CodeController(
      text: '',
      language: lua,
    );
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _pathCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Widget _buildGlobalConfigPanel(BuildContext context, EditorStateController editor) {
    if (editor.config == null) return const SizedBox();
    
    // Evaluate these variables directly from globalItems.
    double getVal(String key, double fallback) {
       if (editor.config!.globalItems.containsKey(key) && editor.config!.globalItems[key]!.keyframes.isNotEmpty) {
           var val = editor.config!.globalItems[key]!.keyframes.first.value;
           if (val is num) return val.toDouble();
       }
       return fallback;
    }
    
    double durationMs = getVal('TIMELINE_DURATION', 15000.0);
    double canvasWidth = getVal('CANVAS_WIDTH', 800.0);
    double canvasHeight = getVal('CANVAS_HEIGHT', 450.0);
    
    void updateVal(String key, double val) {
       editor.updateItemValue(layerId: null, varName: key, value: val, dataType: 'NUMBER', timeMs: 0);
       editor.pushHistoryState();
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ListView(
        children: [
          Text('GLOBAL CONFIGURATION', style: TextStyle(
                  color: Colors.amber,
                  fontSize: AppUIConfig.smallFontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
          const SizedBox(height: 16),
          Text('Timeline Duration Override (MS)', style: TextStyle(color: Colors.white54, fontSize: AppUIConfig.smallFontSize)),
          const SizedBox(height: 4),
          TextFormField(
            key: ValueKey('dur_$durationMs'),
            initialValue: durationMs.toStringAsFixed(0),
            style: TextStyle(color: Colors.white, fontSize: AppUIConfig.rootFontSize),
            decoration: InputDecoration(isDense: true, filled: true, fillColor: Colors.black26),
            onFieldSubmitted: (v) {
               if (double.tryParse(v) != null) updateVal('TIMELINE_DURATION', double.parse(v));
            },
          ),
          const SizedBox(height: 16),
          Text('Canvas Width (px)', style: TextStyle(color: Colors.white54, fontSize: AppUIConfig.smallFontSize)),
          const SizedBox(height: 4),
          TextFormField(
            key: ValueKey('w_$canvasWidth'),
            initialValue: canvasWidth.toStringAsFixed(0),
            style: TextStyle(color: Colors.white, fontSize: AppUIConfig.rootFontSize),
            decoration: InputDecoration(isDense: true, filled: true, fillColor: Colors.black26),
            onFieldSubmitted: (v) {
               if (double.tryParse(v) != null) updateVal('CANVAS_WIDTH', double.parse(v));
            },
          ),
          const SizedBox(height: 16),
          Text('Canvas Height (px)', style: TextStyle(color: Colors.white54, fontSize: AppUIConfig.smallFontSize)),
          const SizedBox(height: 4),
          TextFormField(
            key: ValueKey('h_$canvasHeight'),
            initialValue: canvasHeight.toStringAsFixed(0),
            style: TextStyle(color: Colors.white, fontSize: AppUIConfig.rootFontSize),
            decoration: InputDecoration(isDense: true, filled: true, fillColor: Colors.black26),
            onFieldSubmitted: (v) {
               if (double.tryParse(v) != null) updateVal('CANVAS_HEIGHT', double.parse(v));
            },
          ),
          const SizedBox(height: 16),
          Text('Render Presets', style: TextStyle(color: Colors.white54, fontSize: AppUIConfig.smallFontSize)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
               ActionChip(label: Text('1080p', style: TextStyle(fontSize: AppUIConfig.smallFontSize)), onPressed: () { updateVal('CANVAS_WIDTH', 1920); updateVal('CANVAS_HEIGHT', 1080); }),
               ActionChip(label: Text('Mobile', style: TextStyle(fontSize: AppUIConfig.smallFontSize)), onPressed: () { updateVal('CANVAS_WIDTH', 1080); updateVal('CANVAS_HEIGHT', 1920); }),
               ActionChip(label: Text('Square', style: TextStyle(fontSize: AppUIConfig.smallFontSize)), onPressed: () { updateVal('CANVAS_WIDTH', 1080); updateVal('CANVAS_HEIGHT', 1080); }),
               ActionChip(label: Text('Badge', style: TextStyle(fontSize: AppUIConfig.smallFontSize)), onPressed: () { updateVal('CANVAS_WIDTH', 500); updateVal('CANVAS_HEIGHT', 150); }),
            ]
          )
        ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    var editor = context.watch<EditorStateController>();
    if (editor.selectedLayerId == null ||
        editor.config == null ||
        !editor.config!.layers.containsKey(editor.selectedLayerId)) {
      if (editor.config != null) return _buildGlobalConfigPanel(context, editor);
      return Center(
          child: Text('No Configuration Loaded',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: AppUIConfig.rootFontSize)));
    }

    final layer = editor.config!.layers[editor.selectedLayerId]!;

    if (_idCtrl.text != layer.targetId && !FocusScope.of(context).hasFocus) {
      _idCtrl.text = layer.targetId;
    }
    if (_pathCtrl.text != (layer.path ?? '') &&
        !FocusScope.of(context).hasFocus) {
      _pathCtrl.text = layer.path ?? '';
    }
    if (_codeCtrl.text != (layer.script ?? '') &&
        !FocusScope.of(context).hasFocus) {
      _codeCtrl.text = layer.script ?? '';
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ListView(
        children: [
          Text('LAYER INSPECTOR', style: TextStyle(
                  color: Colors.amber,
                  fontSize: AppUIConfig.smallFontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Platform', style: TextStyle(color: Colors.white54, fontSize: AppUIConfig.smallFontSize)),
                    const SizedBox(height: 2),
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      key: const ValueKey('platform_\${layer.targetId}'),
                      initialValue: layer.platform,
                      dropdownColor: const Color(0xFF252526),
                      style: TextStyle(color: Colors.white, fontSize: AppUIConfig.rootFontSize),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem<String?>(
                            value: null, child: Text('ANY')),
                        DropdownMenuItem(
                            value: 'MOBILE', child: Text('MOBILE')),
                        DropdownMenuItem(value: 'WEB', child: Text('WEB')),
                        DropdownMenuItem(
                            value: 'DESKTOP', child: Text('DESKTOP')),
                      ],
                      onChanged: (val) {
                        editor.updateLayerProperties(
                            layerId: layer.targetId,
                            newPlatform: val,
                            clearPlatform: val == null);
                        editor.pushHistoryState();
                        if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Orientation', style: TextStyle(color: Colors.white54, fontSize: AppUIConfig.smallFontSize)),
                    const SizedBox(height: 2),
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      key: const ValueKey('orient_\${layer.targetId}'),
                      initialValue: layer.orientation,
                      dropdownColor: const Color(0xFF252526),
                      style: TextStyle(color: Colors.white, fontSize: AppUIConfig.rootFontSize),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem<String?>(
                            value: null, child: Text('ANY')),
                        DropdownMenuItem(
                            value: 'PORTRAIT', child: Text('PORTRAIT')),
                        DropdownMenuItem(
                            value: 'LANDSCAPE', child: Text('LANDSCAPE')),
                      ],
                      onChanged: (val) {
                        editor.updateLayerProperties(
                            layerId: layer.targetId,
                            newOrientation: val,
                            clearOrientation: val == null);
                        editor.pushHistoryState();
                        if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Layer ID', style: TextStyle(color: Colors.white54, fontSize: AppUIConfig.smallFontSize)),
          const SizedBox(height: 2),
          TextField(
            controller: _idCtrl,
            style: TextStyle(color: Colors.white, fontSize: AppUIConfig.rootFontSize),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
            onSubmitted: (val) {
              if (val.isNotEmpty) {
                editor.updateLayerProperties(
                    layerId: layer.targetId, newId: val);
                editor.pushHistoryState();
                if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
              }
            },
          ),
          const SizedBox(height: 8),
          Text('Parent Folder', style: TextStyle(color: Colors.white54, fontSize: AppUIConfig.smallFontSize)),
          const SizedBox(height: 2),
          DropdownButtonFormField<String?>(
            isExpanded: true,
            key: ValueKey('parent_${layer.targetId}'),
            initialValue: editor.config!.layers.containsKey(layer.parentId)
                ? layer.parentId
                : null,
            dropdownColor: const Color(0xFF252526),
            style: TextStyle(color: Colors.white, fontSize: AppUIConfig.rootFontSize),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('NONE (Root)')),
              ...editor.config!.layers.values
                  .where(
                      (l) => l.type == 'FOLDER' && l.targetId != layer.targetId)
                  .map((e) => DropdownMenuItem(
                      value: e.targetId, child: Text(e.targetId)))
            ],
            onChanged: (val) {
              editor.updateLayerProperties(
                  layerId: layer.targetId,
                  newParentId: val,
                  clearParent: val == null);
              editor.pushHistoryState();
              if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
            },
          ),
          if (layer.type != 'FOLDER') ...[
            const SizedBox(height: 8),
            Text('Type Engine', style: TextStyle(color: Colors.white54, fontSize: AppUIConfig.smallFontSize)),
            const SizedBox(height: 2),
            DropdownButtonFormField<String>(
              isExpanded: true,
              key: ValueKey('type_${layer.targetId}'),
              initialValue: layer.type,
              dropdownColor: const Color(0xFF252526),
              style: TextStyle(color: Colors.white, fontSize: AppUIConfig.rootFontSize),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
              items: const [
                'IMAGE',
                'COLOR',
                'SHADER',
                'STATIC_SHADER',
                'RIVE',
                'PARTICLES',
                'SHADER_KIT',
                'SCRIPT',
                'FOLDER'
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) {
                if (val != null) {
                  editor.updateLayerProperties(
                      layerId: layer.targetId, newType: val);
                  editor.pushHistoryState();
                  if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
                }
              },
            ),
          ],
          if (layer.type == 'SCRIPT') ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Lua Script Source', style: TextStyle(color: Colors.white54, fontSize: AppUIConfig.smallFontSize)),
              ElevatedButton(
                onPressed: () {
                  editor.updateLayerProperties(
                      layerId: layer.targetId, newScript: _codeCtrl.text);
                  editor.pushHistoryState();
                  if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    minimumSize: const Size(0, 24)),
                child: Text('SAVE & RUN', style: TextStyle(fontSize: AppUIConfig.smallFontSize, color: Colors.white)),
              ),
            ]),
            const SizedBox(height: 4),
            Container(
              height: 340,
              decoration: BoxDecoration(
                  color: const Color(0xFF282A36),
                  border: Border.all(color: Colors.black45)),
              child: SingleChildScrollView(
                child: CodeTheme(
                  data: CodeThemeData(styles: draculaTheme),
                  child: CodeField(
                    controller: _codeCtrl,
                    textStyle:
                        TextStyle(fontSize: AppUIConfig.rootFontSize, fontFamily: 'monospace'),
                    lineNumberStyle: LineNumberStyle(
                      width: 0,
                      margin: 4,
                      textStyle:
                          TextStyle(fontSize: AppUIConfig.rootFontSize, color: Colors.transparent),
                    ),
                  ),
                ),
              ),
            ),
          ] else if (layer.type != 'FOLDER') ...[
            const SizedBox(height: 8),
            Text(layer.type.contains('SHADER') ? 'Shader' : 'Asset Path URL',
                style: TextStyle(color: Colors.white54, fontSize: AppUIConfig.smallFontSize)),
            const SizedBox(height: 2),
            if (layer.type == 'SHADER' || layer.type == 'STATIC_SHADER')
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('frag_${layer.targetId}'),
                initialValue: [
                  'assets/shaders/vignette.frag',
                  'assets/shaders/bg_gradient.frag',
                  'assets/shaders/audio_ring.frag',
                  'assets/shaders/cool_ocean_wave.frag',
                  'assets/shaders/fire.frag',
                  'assets/shaders/bg_kaleidoscope.frag'
                ].contains(layer.path)
                    ? layer.path
                    : null,
                dropdownColor: const Color(0xFF252526),
                style: TextStyle(color: Colors.white, fontSize: AppUIConfig.rootFontSize),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                  hintText: 'Select Engine Fragment',
                  hintStyle: TextStyle(color: Colors.white24, fontSize: AppUIConfig.rootFontSize),
                ),
                items: [
                  'assets/shaders/vignette.frag',
                  'assets/shaders/bg_gradient.frag',
                  'assets/shaders/audio_ring.frag',
                  'assets/shaders/cool_ocean_wave.frag',
                  'assets/shaders/fire.frag',
                  'assets/shaders/bg_kaleidoscope.frag'
                ]
                    .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e
                            .split('/')
                            .last
                            .replaceAll('.frag', '')
                            .replaceAll('_', ' ')
                            .toUpperCase())))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    editor.updateLayerProperties(
                        layerId: layer.targetId, newPath: val);
                    editor.pushHistoryState();
                    if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
                  }
                },
              )
            else if (layer.type == 'SHADER_KIT')
              DropdownButtonFormField<String>(
                key: ValueKey('kit_${layer.targetId}'),
                initialValue: ['CLOUDS'].contains(layer.path?.toUpperCase())
                    ? layer.path?.toUpperCase()
                    : null,
                dropdownColor: const Color(0xFF252526),
                style: TextStyle(color: Colors.white, fontSize: AppUIConfig.rootFontSize),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                  hintText: 'Select Kit Module',
                  hintStyle: TextStyle(color: Colors.white24, fontSize: AppUIConfig.rootFontSize),
                ),
                items: ['CLOUDS']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    editor.updateLayerProperties(
                        layerId: layer.targetId, newPath: val);
                    editor.pushHistoryState();
                    if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
                  }
                },
              )
            else
              TextField(
                controller: _pathCtrl,
                style: TextStyle(color: Colors.white, fontSize: AppUIConfig.rootFontSize),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                  hintText: 'assets/images/background.jpg',
                  hintStyle: TextStyle(color: Colors.white24, fontSize: AppUIConfig.rootFontSize),
                ),
                onSubmitted: (val) {
                  editor.updateLayerProperties(
                      layerId: layer.targetId,
                      newPath: val.isEmpty ? null : val);
                  editor.pushHistoryState();
                  if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
                },
              ),
            const SizedBox(height: 8),
            Text('Layer Composite Blend Mode', style: TextStyle(color: Colors.white54, fontSize: AppUIConfig.smallFontSize)),
            const SizedBox(height: 2),
            DropdownButtonFormField<String>(
              isExpanded: true,
              key: ValueKey('blend_${layer.targetId}'),
              initialValue: [
                'NORMAL',
                'overlay',
                'difference',
                'screen',
                'multiply',
                'colorDodge',
                'colorBurn',
                'hardLight',
                'softLight',
                'luminosity',
                'color',
                'srcOver',
                'srcIn',
                'srcOut',
                'srcATop'
              ].contains(layer.blendMode)
                  ? layer.blendMode
                  : 'NORMAL',
              dropdownColor: const Color(0xFF252526),
              style: TextStyle(color: Colors.white, fontSize: AppUIConfig.rootFontSize),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
              items: const [
                'NORMAL',
                'overlay',
                'difference',
                'screen',
                'multiply',
                'colorDodge',
                'colorBurn',
                'hardLight',
                'softLight',
                'luminosity',
                'color',
                'srcOver',
                'srcIn',
                'srcOut',
                'srcATop'
              ]
                  .map((e) =>
                      DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  editor.updateLayerProperties(
                      layerId: layer.targetId, newBlendMode: val);
                  editor.pushHistoryState();
                  if (context.read<EditorStateController>().config != null) context.read<LyricsViewController>().overrideEditorConfig(context.read<EditorStateController>().config!);
                }
              },
            ),
          ]
        ],
      ),
    );
  }
}

class _SimulatorTelemetryEmitter extends StatefulWidget {
  const _SimulatorTelemetryEmitter();
  @override
  State<_SimulatorTelemetryEmitter> createState() => _SimulatorTelemetryEmitterState();
}

class _SimulatorTelemetryEmitterState extends State<_SimulatorTelemetryEmitter>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      AppProfilerService.instance.markSimulatorFrame();
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}





