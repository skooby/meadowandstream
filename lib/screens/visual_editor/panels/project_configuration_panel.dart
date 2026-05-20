import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../state/global_picker_state.dart';
import 'package:cyclop/cyclop.dart' show EyedropperButton;
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../db/daos/assets_dao.dart';
import '../../../db/daos/i18n_dao.dart';
import '../../../db/app_database.dart';
import 'package:dio/dio.dart';
import '../../../services/backend_process_manager.dart';
import '../../../services/ai_bridge_service.dart';
import 'package:antigravity_sdk/antigravity_sdk.dart';
import '../visual_editor_screen.dart';
import '../../../constants.dart';
import '../../../services/version_control_service.dart';
import 'custom_tool_windows_editor.dart';
import 'dart:async';
import '../../../widgets/resizable_draggable_window.dart';
import 'global_icon_picker_window.dart';
import 'global_color_picker_window.dart';

final ValueNotifier<bool> showProjectConfigNotifier = ValueNotifier(false);

void showProjectConfigWindow(BuildContext context) {
  if (showProjectConfigNotifier.value) return;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showProjectConfig'), true));
  showProjectConfigNotifier.value = true;
}

void hideProjectConfigWindow() {
  showProjectConfigNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showProjectConfig'), false));
}


class ProjectConfigurationWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  const ProjectConfigurationWindow({super.key, required this.onClose, this.onFocus, this.isDocked = false});

  @override
  State<ProjectConfigurationWindow> createState() => _ProjectConfigurationWindowState();
}
class _ProjectConfigurationWindowState extends State<ProjectConfigurationWindow> {
  final GlobalKey _panelKey = GlobalKey();
  bool _isLoaded = false;

  double _width = 800;
  double _height = 600;
  double _bgOpacity = 0.8;
  Offset _offset = const Offset(100, 100);

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

        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('config_width')) ?? 800;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('config_height')) ?? 600;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.8;
        double dx = prefs.getDouble(VisualEditorScreen.getPrefKey('config_dx')) ?? 100;
        double dy = prefs.getDouble(VisualEditorScreen.getPrefKey('config_dy')) ?? 100;
        _offset = Offset(dx, dy);
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('config_width'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('config_height'), _height);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('config_dx'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('config_dy'), _offset.dy);
  }


  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    if (widget.isDocked) return Material(color: Colors.transparent, child: ProjectConfigurationPanel(key: _panelKey, onDimensionsChanged: widget.onClose));
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
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'project_config' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) : null,
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
                              Icon(Icons.settings,
                                  size: 16, color: AppColors.accent),
                              const SizedBox(width: 8),
                              Text(AppUIConfig.formatWindowTitle('Project Configuration'), style: TextStyle(
                                      color: AppColors.titleBarTextPrimary,
                                      fontSize: AppUIConfig.windowTitleFontSize,
                                      fontWeight: AppUIConfig.windowTitleFontWeight)),
                              const Spacer(),
                              IconButton(
                                icon: Icon(Icons.close,
                                    size: 18, color: AppColors.titleBarTextSecondary),
                                onPressed: widget.onClose,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              )
                            ],
                          ),
                        ),
                      ),
                      Expanded(child: ProjectConfigurationPanel(key: _panelKey, onDimensionsChanged: widget.onClose)),
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
          );
        },
      ),
    );
  }
}

class ProjectConfigurationPanel extends StatefulWidget {
  final VoidCallback? onDimensionsChanged;
  const ProjectConfigurationPanel({super.key, this.onDimensionsChanged});

  @override
  State<ProjectConfigurationPanel> createState() => _ProjectConfigurationPanelState();
}

class _ProjectConfigurationPanelState extends State<ProjectConfigurationPanel> {
  static int _savedTabIndex = 5;
  final _formKey = GlobalKey<FormBuilderState>();
  final _themeNameController = TextEditingController();
  bool _isLoading = true;
  String? _primaryStorageUrl;
  String? _localRepositoryPath;
  String? _backupDirectoryPath;
  List<int> _albumFolderIds = [];
  int? _tagsFolderId;
  int? _languagesFolderId;
  double _simulatorWidth = 1920.0;
  double _simulatorHeight = 1080.0;
  double _previewWidth = 1920.0;
  double _previewHeight = 1080.0;
  String _previewAspectRatio = 'FREE';
  String? _openAiApiKey;
  String? _githubToken;
  double _toolWindowOpacity = 0.8;
    int? _customDesktopColor;
  int? _customTitleBarColor;
  int? _customWindowColor;
  int? _customToolbarColor;
  int? _customPanelColor;
  int? _customAccentColor;
  double _rootFontSize = 12.0;
  double _iconFontSize = 10.0;
  double _globalActionIconSize = 20.0;
  double _titleBarHeight = 32.0;
  double _windowBorderRadius = 8.0;
  double _windowBorderWidth = 1.0;
  int? _customWindowBorderColor;
  int? _customControlBorderColor;
  int? _customActiveWindowBorderColor;
  int? _customActiveTaskHighlightColor;
  bool _iconFontBold = false;
  bool _windowTitleUppercase = true;
  bool _windowTitleBold = true;
  double _iconOutlineWidth = 1.5;
  double _textOutlineWidth = 1.0;
  int? _customOutlineColor;
  int? _customMarkupBackgroundColor;
  int? _customMarkupHeaderColor;
  int? _customMarkupBlockBackgroundColor;
  int? _customMarkupInlineCodeColor;
  int? _customMarkupCodeBlockBackgroundColor;
  int? _customMarkupBlockTextColor;
  int? _customMarkupInlineTextColor;
  int? _customMarkupCodeBlockTextColor;
  Map<String, List<String>> _windowAvailability = {};
  int _queueClearCompletedMinutes = -1;
  String? _agentRules;
  String? _antigravityBaseUrl;
  String? _antigravityInvokeEndpoint;
  String? _antigravityPromptEndpoint;
  String? _antigravityStartupCommand;
  String? _antigravityModel;
  String? _antigravityApiKey;
  Future<List<AntigravityModel>>? _modelsFuture;
  String? _versionControlRepoUrl;
  String? _ollamaBaseUrl;
  String? _ollamaModel;
  int _ollamaTimeoutMs = 120000;

  bool _isTestingAntigravity = false;
  bool _isSyncing = false;
  int _syncTotal = 0;
  int _syncProgress = 0;
  String _syncCurrentFile = '';
  
  Timer? _debounceTimer;

  void _onFormChanged() {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) {
              _saveConfiguration();
          }
      });
  }

  @override
  void dispose() {
      
      _debounceTimer?.cancel();
      super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    await AppToolWindows.loadCustom();
    final prefs = await SharedPreferences.getInstance();
    final albumStr = prefs.getStringList('project_album_folder_ids') ?? [];
    final tagsFolderStr = prefs.getString('project_tags_folder_id');
    final languagesFolderStr = prefs.getString('project_languages_folder_id');
    final simW = prefs.getDouble('project_simulator_width');
    final simH = prefs.getDouble('project_simulator_height');
      String? extractedKey;
      String? extractedGithubKey;
      final desktopLight = prefs.getInt('ve_desktop_light');
      final desktopDark = prefs.getInt('ve_desktop_dark');
      final desktopDracula = prefs.getInt('ve_desktop_dracula');
      final titlebarLight = prefs.getInt('ve_titlebar_light');
      final titlebarDark = prefs.getInt('ve_titlebar_dark');
      final titlebarDracula = prefs.getInt('ve_titlebar_dracula');
      final windowLight = prefs.getInt('ve_window_light');
      final windowDark = prefs.getInt('ve_window_dark');
      final windowDracula = prefs.getInt('ve_window_dracula');
      final panelLight = prefs.getInt('ve_panel_light');
      final panelDark = prefs.getInt('ve_panel_dark');
      final panelDracula = prefs.getInt('ve_panel_dracula');

      final envFile = File('.env');
      if (await envFile.exists()) {
          final lines = await envFile.readAsLines();
          for (var line in lines) {
              if (line.trim().startsWith('OPENAI_API_KEY=')) {
                  extractedKey = line.substring(line.indexOf('=') + 1).trim();
              }
              if (line.trim().startsWith('GITHUB_TOKEN=')) {
                  extractedGithubKey = line.substring(line.indexOf('=') + 1).trim();
              }
          }
      } else {
          extractedKey = dotenv.env['OPENAI_API_KEY'];
          extractedGithubKey = dotenv.env['GITHUB_TOKEN'];
      }

    setState(() {
      _primaryStorageUrl = prefs.getString('project_primary_storage_url');
      _localRepositoryPath = prefs.getString('project_local_repository_path');
      _backupDirectoryPath = prefs.getString('project_backup_directory_path');
      _albumFolderIds = albumStr.map(int.parse).toList();
      _tagsFolderId = tagsFolderStr != null ? int.tryParse(tagsFolderStr) : null;
      _languagesFolderId = languagesFolderStr != null ? int.tryParse(languagesFolderStr) : null;
      if (simW != null) _simulatorWidth = simW;
      if (simH != null) _simulatorHeight = simH;
      
      final pW = prefs.getDouble('ve_previewWidth');
      final pH = prefs.getDouble('ve_previewHeight');
      final pAR = prefs.getString('ve_previewAspectRatio');
      if (pW != null) _previewWidth = pW;
      if (pH != null) _previewHeight = pH;
      if (pAR != null) _previewAspectRatio = pAR;

      _openAiApiKey = extractedKey;
      _githubToken = extractedGithubKey;
      _toolWindowOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.8;

      _rootFontSize = prefs.getDouble('ve_rootFontSize') ?? 12.0;
      _iconFontSize = prefs.getDouble('ve_iconFontSize') ?? 10.0;
      _globalActionIconSize = prefs.getDouble('ve_globalActionIconSize') ?? 20.0;
      _iconFontBold = prefs.getBool('ve_iconFontBold') ?? false;
      _windowTitleUppercase = prefs.getBool('ve_windowTitleUppercase') ?? true;
      _windowTitleBold = prefs.getBool('ve_windowTitleBold') ?? true;
      _iconOutlineWidth = prefs.getDouble('ve_iconOutlineWidth') ?? 1.5;
      _textOutlineWidth = prefs.getDouble('ve_textOutlineWidth') ?? 1.0;

      _titleBarHeight = prefs.getDouble('ve_titleBarHeight') ?? 32.0;
      _windowBorderRadius = prefs.getDouble('ve_windowBorderRadius') ?? 8.0;
      _windowBorderWidth = prefs.getDouble('ve_windowBorderWidth') ?? 1.0;
      _customWindowBorderColor = prefs.getInt('ve_windowBorderColor');
      _customControlBorderColor = prefs.getInt('ve_controlBorderColor');
      _customActiveWindowBorderColor = prefs.getInt('ve_activeWindowBorderColor');
      _customActiveTaskHighlightColor = prefs.getInt('ve_activeTaskHighlightColor');
      _queueClearCompletedMinutes = prefs.getInt('queueClearCompletedMinutes') ?? -1;
      _agentRules = prefs.getString('project_agent_rules');
      _antigravityBaseUrl = prefs.getString('antigravity_base_url');
      _antigravityInvokeEndpoint = prefs.getString('antigravity_invoke_endpoint');
      _antigravityPromptEndpoint = prefs.getString('antigravity_prompt_endpoint');
      _antigravityStartupCommand = prefs.getString('antigravity_startup_command');
      _antigravityApiKey = prefs.getString('antigravity_api_key');
      final savedModel = prefs.getString('antigravity_model') ?? 'gemini-2.0-flash';
      if (savedModel == 'flash_lite') {
        _antigravityModel = 'gemini-2.0-flash-lite';
      } else if (savedModel == 'flash') {
        _antigravityModel = 'gemini-2.0-flash';
      } else if (savedModel == 'pro') {
        _antigravityModel = 'gemini-2.0-pro';
      } else {
        _antigravityModel = savedModel;
      }
      _versionControlRepoUrl = prefs.getString('project_version_control_repo_url');
      _ollamaBaseUrl = prefs.getString('ollamaBaseUrl');
      _ollamaModel = prefs.getString('ollamaModel');
      _ollamaTimeoutMs = prefs.getInt('ollamaTimeoutMs') ?? 120000;

      final availStr = prefs.getString('ve_windowAvailability');
      if (availStr != null) {
          try {
              final Map<String, dynamic> parsed = jsonDecode(availStr);
              _windowAvailability = parsed.map((k, v) => MapEntry(k, List<String>.from(v)));
          } catch (_) {}
      }

      _isLoading = false;
      if (AppUIConfig.activeTheme != null) {
          _applyTheme(AppUIConfig.activeTheme!);
      }
      _modelsFuture = AntigravityClient().models.list();
    });
  }






  Future<void> _updateActiveThemeAndSave() async {
      final baseTheme = AppUIConfig.activeTheme ?? CustomColorTheme(
        id: 'custom_runtime',
        name: 'Custom Theme',
      );
      final newTheme = baseTheme.copyWith(
         desktopColor: _customDesktopColor,
         titleBarColor: _customTitleBarColor,
         windowColor: _customWindowColor,
         toolbarColor: _customToolbarColor,
         panelColor: _customPanelColor,
         accentColor: _customAccentColor,
         rootFontSize: _rootFontSize,
         iconFontSize: _iconFontSize,
         globalActionIconSize: _globalActionIconSize,
         iconFontBold: _iconFontBold,
         windowTitleUppercase: _windowTitleUppercase,
         windowTitleBold: _windowTitleBold,
         toolWindowOpacity: _toolWindowOpacity,
         iconOutlineWidth: _iconOutlineWidth,
         textOutlineWidth: _textOutlineWidth,
         outlineColor: _customOutlineColor,
         markupBackgroundColor: _customMarkupBackgroundColor,
         markupHeaderColor: _customMarkupHeaderColor,
         markupBlockBackgroundColor: _customMarkupBlockBackgroundColor,
         markupInlineCodeColor: _customMarkupInlineCodeColor,
         markupCodeBlockBackgroundColor: _customMarkupCodeBlockBackgroundColor,
         markupBlockTextColor: _customMarkupBlockTextColor,
         markupInlineTextColor: _customMarkupInlineTextColor,
         markupCodeBlockTextColor: _customMarkupCodeBlockTextColor,
         titleBarHeight: _titleBarHeight,
         windowBorderRadius: _windowBorderRadius,
         windowBorderWidth: _windowBorderWidth,
         windowBorderColor: _customWindowBorderColor,
         controlBorderColor: _customControlBorderColor,
         activeWindowBorderColor: _customActiveWindowBorderColor,
         activeTaskHighlightColor: _customActiveTaskHighlightColor,
      );
      
      AppUIConfig.activeTheme = newTheme;
      
      AppUIConfig.rootFontSize = _rootFontSize;
      AppUIConfig.iconFontSize = _iconFontSize;
      AppUIConfig.globalActionIconSize = _globalActionIconSize;
      AppUIConfig.iconFontBold = _iconFontBold;
      AppUIConfig.iconOutlineWidth = _iconOutlineWidth;
      AppUIConfig.textOutlineWidth = _textOutlineWidth;
      AppUIConfig.titleBarHeight = _titleBarHeight;
      AppUIConfig.windowBorderRadius = _windowBorderRadius;
      AppUIConfig.windowBorderWidth = _windowBorderWidth;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ve_activeThemeId', newTheme.id);
      await prefs.setDouble('ve_rootFontSize', _rootFontSize);
      await prefs.setDouble('ve_iconFontSize', _iconFontSize);
      await prefs.setDouble('ve_globalActionIconSize', _globalActionIconSize);
      await prefs.setBool('ve_iconFontBold', _iconFontBold);
      await prefs.setBool('ve_windowTitleUppercase', _windowTitleUppercase);
      await prefs.setBool('ve_windowTitleBold', _windowTitleBold);
      await prefs.setDouble('ve_iconOutlineWidth', _iconOutlineWidth);
      await prefs.setDouble('ve_textOutlineWidth', _textOutlineWidth);
      await prefs.setDouble('toolWindowOpacity', _toolWindowOpacity);
      await prefs.setDouble('ve_titleBarHeight', _titleBarHeight);
      await prefs.setDouble('ve_windowBorderRadius', _windowBorderRadius);
      await prefs.setDouble('ve_windowBorderWidth', _windowBorderWidth);
      if (_customWindowBorderColor != null) {
          await prefs.setInt('ve_windowBorderColor', _customWindowBorderColor!);
      } else {
          await prefs.remove('ve_windowBorderColor');
      }
      if (_customControlBorderColor != null) {
          await prefs.setInt('ve_controlBorderColor', _customControlBorderColor!);
      } else {
          await prefs.remove('ve_controlBorderColor');
      }
      if (_customActiveWindowBorderColor != null) {
          await prefs.setInt('ve_activeWindowBorderColor', _customActiveWindowBorderColor!);
      } else {
          await prefs.remove('ve_activeWindowBorderColor');
      }
      if (_customActiveTaskHighlightColor != null) {
          await prefs.setInt('ve_activeTaskHighlightColor', _customActiveTaskHighlightColor!);
      } else {
          await prefs.remove('ve_activeTaskHighlightColor');
      }
      
      final idx = AppUIConfig.savedThemes.indexWhere((t) => t.id == newTheme.id);
      if (idx >= 0) {
          AppUIConfig.savedThemes[idx] = newTheme;
      } else {
          AppUIConfig.savedThemes.add(newTheme);
      }
      await AppUIConfig.saveCustomThemes();
      VisualEditorScreen.configRefreshNotifier.value++;
  }

  Future<void> _applyTheme(CustomColorTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    
    AppUIConfig.activeTheme = theme;
    await prefs.setString('ve_activeThemeId', theme.id);
    _themeNameController.text = theme.name;

    _customDesktopColor = theme.desktopColor;
    _customTitleBarColor = theme.titleBarColor;
    _customWindowColor = theme.windowColor;
    _customToolbarColor = theme.toolbarColor;
    _customPanelColor = theme.panelColor;
    _customAccentColor = theme.accentColor;
    _customOutlineColor = theme.outlineColor;
    _customMarkupBackgroundColor = theme.markupBackgroundColor;
    _customMarkupHeaderColor = theme.markupHeaderColor;
    _customMarkupBlockBackgroundColor = theme.markupBlockBackgroundColor;
    _customMarkupInlineCodeColor = theme.markupInlineCodeColor;
    _customMarkupCodeBlockBackgroundColor = theme.markupCodeBlockBackgroundColor;
    _customMarkupBlockTextColor = theme.markupBlockTextColor;
    _customMarkupInlineTextColor = theme.markupInlineTextColor;
    _customMarkupCodeBlockTextColor = theme.markupCodeBlockTextColor;

    if (theme.rootFontSize != null) {
      _rootFontSize = theme.rootFontSize!;
      AppUIConfig.rootFontSize = _rootFontSize;
      await prefs.setDouble('ve_rootFontSize', _rootFontSize);
    }
    if (theme.iconFontSize != null) {
      _iconFontSize = theme.iconFontSize!;
      await prefs.setDouble('ve_iconFontSize', _iconFontSize);
      await prefs.setDouble('ve_globalActionIconSize', _globalActionIconSize);
    }
    if (theme.iconFontBold != null) {
      _iconFontBold = theme.iconFontBold!;
      await prefs.setBool('ve_iconFontBold', _iconFontBold);
    }
    if (theme.windowTitleUppercase != null) {
      _windowTitleUppercase = theme.windowTitleUppercase!;
      await prefs.setBool('ve_windowTitleUppercase', _windowTitleUppercase);
    }
    if (theme.windowTitleBold != null) {
      _windowTitleBold = theme.windowTitleBold!;
      await prefs.setBool('ve_windowTitleBold', _windowTitleBold);
    }
    if (theme.windowBorderRadius != null) {
      _windowBorderRadius = theme.windowBorderRadius!;
      AppUIConfig.windowBorderRadius = theme.windowBorderRadius!;
      await prefs.setDouble('ve_windowBorderRadius', theme.windowBorderRadius!);
    }
    if (theme.windowBorderWidth != null) {
      _windowBorderWidth = theme.windowBorderWidth!;
      AppUIConfig.windowBorderWidth = theme.windowBorderWidth!;
      await prefs.setDouble('ve_windowBorderWidth', theme.windowBorderWidth!);
    }
    _customWindowBorderColor = theme.windowBorderColor;
    if (_customWindowBorderColor != null) {
      await prefs.setInt('ve_windowBorderColor', _customWindowBorderColor!);
    } else {
      await prefs.remove('ve_windowBorderColor');
    }
    if (theme.toolWindowOpacity != null) {
      _toolWindowOpacity = theme.toolWindowOpacity!;
      await prefs.setDouble('toolWindowOpacity', _toolWindowOpacity);
    }
    _customControlBorderColor = theme.controlBorderColor;
    if (_customControlBorderColor != null) {
      await prefs.setInt('ve_controlBorderColor', _customControlBorderColor!);
    } else {
      await prefs.remove('ve_controlBorderColor');
    }
    _customActiveWindowBorderColor = theme.activeWindowBorderColor;
    if (_customActiveWindowBorderColor != null) {
      await prefs.setInt('ve_activeWindowBorderColor', _customActiveWindowBorderColor!);
    } else {
      await prefs.remove('ve_activeWindowBorderColor');
    }
    _customActiveTaskHighlightColor = theme.activeTaskHighlightColor;
    if (_customActiveTaskHighlightColor != null) {
      await prefs.setInt('ve_activeTaskHighlightColor', _customActiveTaskHighlightColor!);
    } else {
      await prefs.remove('ve_activeTaskHighlightColor');
    }
    if (theme.iconOutlineWidth != null) {
      _iconOutlineWidth = theme.iconOutlineWidth!;
      AppUIConfig.iconOutlineWidth = _iconOutlineWidth;
      await prefs.setDouble('ve_iconOutlineWidth', _iconOutlineWidth);
    }
    if (theme.textOutlineWidth != null) {
      _textOutlineWidth = theme.textOutlineWidth!;
      AppUIConfig.textOutlineWidth = _textOutlineWidth;
      await prefs.setDouble('ve_textOutlineWidth', _textOutlineWidth);
    }
    if (theme.outlineColor != null) {
      _customOutlineColor = theme.outlineColor!;
    }
    if (theme.titleBarHeight != null) {
      _titleBarHeight = theme.titleBarHeight!;
      AppUIConfig.titleBarHeight = _titleBarHeight;
      await prefs.setDouble('ve_titleBarHeight', _titleBarHeight);
    }

    if (mounted) {
      setState(() {});
      VisualEditorScreen.configRefreshNotifier.value++;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Applied theme: '), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
    }
  }

  Future<void> _saveConfiguration() async {

    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState!.value;
      final newUrl = values.containsKey('primaryStorageUrl') ? values['primaryStorageUrl'] as String? : _primaryStorageUrl;
      final newLocalRepo = values.containsKey('localRepositoryPath') ? values['localRepositoryPath'] as String? : _localRepositoryPath;
      final newBackupDir = values.containsKey('backupDirectoryPath') ? values['backupDirectoryPath'] as String? : _backupDirectoryPath;
      final newSimWidth = double.tryParse((values['simulatorWidth'] ?? _simulatorWidth).toString()) ?? _simulatorWidth;
      final newSimHeight = double.tryParse((values['simulatorHeight'] ?? _simulatorHeight).toString()) ?? _simulatorHeight;
      final newPreviewWidth = double.tryParse((values['previewWidth'] ?? _previewWidth).toString()) ?? _previewWidth;
      final newPreviewHeight = double.tryParse((values['previewHeight'] ?? _previewHeight).toString()) ?? _previewHeight;
      final newPreviewAspectRatio = values.containsKey('previewAspectRatio') ? values['previewAspectRatio'] as String? ?? 'FREE' : _previewAspectRatio;
      final newOpacity = double.tryParse((values['toolWindowOpacity'] ?? _toolWindowOpacity).toString()) ?? _toolWindowOpacity;

        final newBorderRadius = double.tryParse((values['windowBorderRadius'] ?? AppUIConfig.windowBorderRadius).toString()) ?? AppUIConfig.windowBorderRadius;
        final newBorderWidth = double.tryParse((values['windowBorderWidth'] ?? AppUIConfig.windowBorderWidth).toString()) ?? AppUIConfig.windowBorderWidth;
      final newRootFontSize = double.tryParse((values['rootFontSize'] ?? _rootFontSize).toString()) ?? _rootFontSize;
      final newIconFontSize = double.tryParse((values['iconFontSize'] ?? _iconFontSize).toString()) ?? _iconFontSize;
      final newGlobalActionIconSize = double.tryParse((values['globalActionIconSize'] ?? _globalActionIconSize).toString()) ?? _globalActionIconSize;
      final newIconFontBold = values.containsKey('iconFontBold') ? values['iconFontBold'] == true : _iconFontBold;
      final newWindowTitleUppercase = values.containsKey('windowTitleUppercase') ? values['windowTitleUppercase'] == true : _windowTitleUppercase;
      final newWindowTitleBold = values.containsKey('windowTitleBold') ? values['windowTitleBold'] == true : _windowTitleBold;
      final newIconOutlineWidth = double.tryParse((values['iconOutlineWidth'] ?? _iconOutlineWidth).toString()) ?? _iconOutlineWidth;
      final newTextOutlineWidth = double.tryParse((values['textOutlineWidth'] ?? _textOutlineWidth).toString()) ?? _textOutlineWidth;
      final newTitleBarHeight = double.tryParse((values['titleBarHeight'] ?? _titleBarHeight).toString()) ?? _titleBarHeight;
      final newClearCompleted = int.tryParse((values['queueClearCompletedMinutes'] ?? _queueClearCompletedMinutes).toString()) ?? _queueClearCompletedMinutes;
      // Note: albumIds are captured via FormField onSaved.

      final prefs = await SharedPreferences.getInstance();
      final oldLocalRepo = prefs.getString('project_local_repository_path') ?? '';

      final newOpenAIApiKey = values.containsKey('openAiApiKey') ? values['openAiApiKey'] as String? : _openAiApiKey;
      final newGithubToken = values.containsKey('githubToken') ? values['githubToken'] as String? : _githubToken;
      final newVersionControlRepoUrl = values.containsKey('versionControlRepoUrl') ? values['versionControlRepoUrl'] as String? : _versionControlRepoUrl;
      final newOllamaBaseUrl = values.containsKey('ollamaBaseUrl') ? values['ollamaBaseUrl'] as String? : _ollamaBaseUrl;
      final newOllamaModel = values.containsKey('ollamaModel') ? values['ollamaModel'] as String? : _ollamaModel;
      final newOllamaTimeoutMs = int.tryParse((values['ollamaTimeoutMs'] ?? _ollamaTimeoutMs).toString()) ?? _ollamaTimeoutMs;
      
      final desktopLight = prefs.getInt('ve_desktop_light');
      final desktopDark = prefs.getInt('ve_desktop_dark');
      final desktopDracula = prefs.getInt('ve_desktop_dracula');
      final titlebarLight = prefs.getInt('ve_titlebar_light');
      final titlebarDark = prefs.getInt('ve_titlebar_dark');
      final titlebarDracula = prefs.getInt('ve_titlebar_dracula');
      final windowLight = prefs.getInt('ve_window_light');
      final windowDark = prefs.getInt('ve_window_dark');
      final windowDracula = prefs.getInt('ve_window_dracula');
      final panelLight = prefs.getInt('ve_panel_light');
      final panelDark = prefs.getInt('ve_panel_dark');
      final panelDracula = prefs.getInt('ve_panel_dracula');

      final envFile = File('.env');
      if (await envFile.exists()) {
          final lines = await envFile.readAsLines();
          final updatedLines = <String>[];
          bool foundOpenAi = false;
          bool foundGithub = false;
          for (var line in lines) {
              if (line.startsWith('OPENAI_API_KEY=')) {
                  if (newOpenAIApiKey != null && newOpenAIApiKey.trim().isNotEmpty) {
                      updatedLines.add('OPENAI_API_KEY=${newOpenAIApiKey.trim()}');
                  }
                  foundOpenAi = true;
              } else if (line.startsWith('GITHUB_TOKEN=')) {
                  if (newGithubToken != null && newGithubToken.trim().isNotEmpty) {
                      updatedLines.add('GITHUB_TOKEN=${newGithubToken.trim()}');
                  }
                  foundGithub = true;
              } else {
                  updatedLines.add(line);
              }
          }
          if (!foundOpenAi && newOpenAIApiKey != null && newOpenAIApiKey.trim().isNotEmpty) {
              updatedLines.add('OPENAI_API_KEY=${newOpenAIApiKey.trim()}');
          }
          if (!foundGithub && newGithubToken != null && newGithubToken.trim().isNotEmpty) {
              updatedLines.add('GITHUB_TOKEN=${newGithubToken.trim()}');
          }
          await envFile.writeAsString(updatedLines.join('\n'));
          dotenv.clean();
          await dotenv.load(fileName: '.env');
      }

      if (newUrl != null && newUrl.trim().isNotEmpty) {
         // Standardize by ensuring it ends with a trailing slash
         String storedUrl = newUrl.trim();
         if (!storedUrl.endsWith('/')) storedUrl += '/';
         await prefs.setString('project_primary_storage_url', storedUrl);
      } else {
         await prefs.remove('project_primary_storage_url');
      }

      if (newLocalRepo != null && newLocalRepo.trim().isNotEmpty) {
         final cleanNewPath = newLocalRepo.trim();
         // If path literally changed, migrate files
         if (oldLocalRepo != cleanNewPath) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Migrating repository...')));
             await _moveLocalRepository(oldLocalRepo, cleanNewPath);
         }
         await prefs.setString('project_local_repository_path', cleanNewPath);
      } else {
         await prefs.remove('project_local_repository_path');
      }

      if (newVersionControlRepoUrl != null && newVersionControlRepoUrl.trim().isNotEmpty) {
         await prefs.setString('project_version_control_repo_url', newVersionControlRepoUrl.trim());
      } else {
         await prefs.remove('project_version_control_repo_url');
      }

      if (newOllamaBaseUrl != null && newOllamaBaseUrl.trim().isNotEmpty) {
         await prefs.setString('ollamaBaseUrl', newOllamaBaseUrl.trim());
      } else {
         await prefs.remove('ollamaBaseUrl');
      }
      if (newOllamaModel != null && newOllamaModel.trim().isNotEmpty) {
         await prefs.setString('ollamaModel', newOllamaModel.trim());
      } else {
         await prefs.remove('ollamaModel');
      }
      await prefs.setInt('ollamaTimeoutMs', newOllamaTimeoutMs);

      if (newBackupDir != null && newBackupDir.trim().isNotEmpty) {
         await prefs.setString('project_backup_directory_path', newBackupDir.trim());
      } else {
         await prefs.remove('project_backup_directory_path');
      }

      await prefs.setStringList('project_album_folder_ids', _albumFolderIds.map((e) => e.toString()).toList());
      if (_tagsFolderId != null) {
          await prefs.setString('project_tags_folder_id', _tagsFolderId.toString());
      } else {
          await prefs.remove('project_tags_folder_id');
      }

      if (_languagesFolderId != null) {
          await prefs.setString('project_languages_folder_id', _languagesFolderId.toString());
      } else {
          await prefs.remove('project_languages_folder_id');
      }

      await prefs.setDouble('project_simulator_width', newSimWidth);
      await prefs.setDouble('project_simulator_height', newSimHeight);
      
      await prefs.setDouble('ve_previewWidth', newPreviewWidth);
      await prefs.setDouble('ve_previewHeight', newPreviewHeight);
      await prefs.setString('ve_previewAspectRatio', newPreviewAspectRatio);
      await prefs.setDouble('ve_toolWindowOpacity', newOpacity);

      await prefs.setDouble('ve_windowBorderRadius', newBorderRadius);
      await prefs.setDouble('ve_windowBorderWidth', newBorderWidth);
      await prefs.setDouble('ve_rootFontSize', newRootFontSize);
      await prefs.setDouble('ve_iconFontSize', newIconFontSize);
      await prefs.setDouble('ve_globalActionIconSize', newGlobalActionIconSize);
      await prefs.setBool('ve_iconFontBold', newIconFontBold);
      await prefs.setBool('ve_windowTitleUppercase', newWindowTitleUppercase);
      await prefs.setBool('ve_windowTitleBold', newWindowTitleBold);
      await prefs.setDouble('ve_iconOutlineWidth', newIconOutlineWidth);
      await prefs.setDouble('ve_textOutlineWidth', newTextOutlineWidth);
      await prefs.setDouble('ve_titleBarHeight', newTitleBarHeight);

      await prefs.setString('ve_windowAvailability', jsonEncode(_windowAvailability));
      await prefs.setInt('queueClearCompletedMinutes', newClearCompleted);

      final newAgentRules = values.containsKey('agentRules') ? values['agentRules'] as String? : _agentRules;
      if (newAgentRules != null && newAgentRules.trim().isNotEmpty) {
          await prefs.setString('project_agent_rules', newAgentRules.trim());
      } else {
          await prefs.remove('project_agent_rules');
      }

      final newAntigravityBaseUrl = values.containsKey('antigravityBaseUrl') ? values['antigravityBaseUrl'] as String? : _antigravityBaseUrl;
      if (newAntigravityBaseUrl != null && newAntigravityBaseUrl.trim().isNotEmpty) {
          await prefs.setString('antigravity_base_url', newAntigravityBaseUrl.trim());
      } else {
          await prefs.remove('antigravity_base_url');
      }

      final newAntigravityInvokeEndpoint = values.containsKey('antigravityInvokeEndpoint') ? values['antigravityInvokeEndpoint'] as String? : _antigravityInvokeEndpoint;
      if (newAntigravityInvokeEndpoint != null && newAntigravityInvokeEndpoint.trim().isNotEmpty) {
          await prefs.setString('antigravity_invoke_endpoint', newAntigravityInvokeEndpoint.trim());
      } else {
          await prefs.remove('antigravity_invoke_endpoint');
      }

      final newAntigravityPromptEndpoint = values.containsKey('antigravityPromptEndpoint') ? values['antigravityPromptEndpoint'] as String? : _antigravityPromptEndpoint;
      if (newAntigravityPromptEndpoint != null && newAntigravityPromptEndpoint.trim().isNotEmpty) {
          await prefs.setString('antigravity_prompt_endpoint', newAntigravityPromptEndpoint.trim());
      } else {
          await prefs.remove('antigravity_prompt_endpoint');
      }

      final newAntigravityStartupCommand = values.containsKey('antigravityStartupCommand') ? values['antigravityStartupCommand'] as String? : _antigravityStartupCommand;
      if (newAntigravityStartupCommand != null && newAntigravityStartupCommand.trim().isNotEmpty) {
          await prefs.setString('antigravity_startup_command', newAntigravityStartupCommand.trim());
      } else {
          await prefs.remove('antigravity_startup_command');
      }

      final newAntigravityApiKey = values.containsKey('antigravityApiKey') ? values['antigravityApiKey'] as String? : _antigravityApiKey;
      if (newAntigravityApiKey != null && newAntigravityApiKey.trim().isNotEmpty) {
          await prefs.setString('antigravity_api_key', newAntigravityApiKey.trim());
      } else {
          await prefs.remove('antigravity_api_key');
      }

      final newAntigravityModel = values.containsKey('antigravityModel') ? values['antigravityModel'] as String? : _antigravityModel;
      if (newAntigravityModel != null && newAntigravityModel.trim().isNotEmpty) {
          await prefs.setString('antigravity_model', newAntigravityModel.trim());
      } else {
          await prefs.remove('antigravity_model');
      }

      if (mounted) {
         setState(() {
            _primaryStorageUrl = newUrl;
            _localRepositoryPath = newLocalRepo;
            _backupDirectoryPath = newBackupDir;
            _simulatorWidth = newSimWidth;
            _simulatorHeight = newSimHeight;
            _previewWidth = newPreviewWidth;
            _previewHeight = newPreviewHeight;
            _previewAspectRatio = newPreviewAspectRatio;
            _openAiApiKey = newOpenAIApiKey;
            _githubToken = newGithubToken;
            _toolWindowOpacity = newOpacity;






            _rootFontSize = newRootFontSize;
            _iconFontSize = newIconFontSize;
            _globalActionIconSize = newGlobalActionIconSize;
            _iconFontBold = newIconFontBold;
            _windowTitleUppercase = newWindowTitleUppercase;
            _windowTitleBold = newWindowTitleBold;
            _iconOutlineWidth = newIconOutlineWidth;
            _textOutlineWidth = newTextOutlineWidth;
            _titleBarHeight = newTitleBarHeight;
            _windowBorderRadius = newBorderRadius;
            _windowBorderWidth = newBorderWidth;
            AppUIConfig.iconOutlineWidth = newIconOutlineWidth;
            AppUIConfig.textOutlineWidth = newTextOutlineWidth;
            AppUIConfig.titleBarHeight = newTitleBarHeight;
            AppUIConfig.windowBorderRadius = newBorderRadius;
            AppUIConfig.windowBorderWidth = newBorderWidth;
            _queueClearCompletedMinutes = newClearCompleted;
            _agentRules = newAgentRules;
            _antigravityBaseUrl = newAntigravityBaseUrl;
            _antigravityInvokeEndpoint = newAntigravityInvokeEndpoint;
            _antigravityPromptEndpoint = newAntigravityPromptEndpoint;
            _antigravityStartupCommand = newAntigravityStartupCommand;
            _antigravityModel = newAntigravityModel;
            _antigravityApiKey = newAntigravityApiKey;
            _versionControlRepoUrl = newVersionControlRepoUrl;
            _ollamaBaseUrl = newOllamaBaseUrl;
            _ollamaModel = newOllamaModel;
            _ollamaTimeoutMs = newOllamaTimeoutMs;
            // _albumFolderIds, _tagsFolderId, _languagesFolderId remain synchronously updated.
         });
         
          await _updateActiveThemeAndSave();
          try {
            await AiBridgeService.instance.updateAntigravityConfig();
            setState(() {
              _modelsFuture = AntigravityClient().models.list();
            });
          } catch (e) {
            debugPrint('[ProjectConfigurationPanel] Error updating active Antigravity config: $e');
          }

         // Trigger the global notifier so all tool windows instantly repaint with new opacity
         VisualEditorScreen.configRefreshNotifier.value++;

         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project configuration auto-saved'), backgroundColor: Colors.green, duration: Duration(seconds: 1))
         );
      }
    }
  }

  Future<void> _moveLocalRepository(String oldPath, String newPath) async {
     try {
        final srcDir = Directory(oldPath);
        final destDir = Directory(newPath);

        if (!await srcDir.exists()) return;
        if (srcDir.absolute.path == destDir.absolute.path) return;
        
        // CRITICAL SAFETY GUARD: Never allow the internal Flutter assets directory to be moved
        final normalizedSrcPath = srcDir.absolute.path.replaceAll('\\', '/');
        if (normalizedSrcPath.endsWith('Project/assets') || normalizedSrcPath.endsWith('Project/assets/')) {
            debugPrint('Safety guard prevented migration of internal Flutter assets directory.');
            return;
        }

        if (!await destDir.parent.exists()) {
           await destDir.parent.create(recursive: true);
        }

        try {
           // If destination was freshly created or exists emptied, rename will fail if it literally exists as a folder on Windows.
           if (await destDir.exists()) await destDir.delete(recursive: true);
           await srcDir.rename(destDir.path);
        } catch (_) {
           // Cross-device link fallback via explicit recursive copy
           await _copyDirectory(srcDir, destDir);
           await srcDir.delete(recursive: true);
        }
     } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to migrate repository files: $e'), backgroundColor: Colors.red));
     }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
      if (!await destination.exists()) await destination.create(recursive: true);
      
      await for (var entity in source.list(recursive: false)) {
          final itemName = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
          final newPath = '${destination.absolute.path}${Platform.pathSeparator}$itemName';
          
          if (entity is Directory) {
             var newDirectory = Directory(newPath);
             await newDirectory.create(recursive: true);
             await _copyDirectory(entity, newDirectory);
          } else if (entity is File) {
             await entity.copy(newPath);
          }
      }
  }

  Future<void> _syncLocalRepository() async {
      final currentValues = _formKey.currentState?.value ?? {};
      String baseDir = currentValues['localRepositoryPath'] as String? ?? '';
      if (baseDir.trim().isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          baseDir = prefs.getString('project_local_repository_path') ?? '';
      }
      baseDir = baseDir.trim();
      if (baseDir.endsWith('/') || baseDir.endsWith('\\')) baseDir = baseDir.substring(0, baseDir.length - 1);

      setState(() {
          _isSyncing = true;
          _syncProgress = 0;
          _syncTotal = 0;
          _syncCurrentFile = 'Initializing...';
      });

      try {
          final dao = context.read<AssetsDao>();
          final allAssets = await dao.select(dao.assets).get();
          
          final Map<int, Asset> mapById = { for(var a in allAssets) a.id : a };
          final filesToSync = allAssets.where((a) => a.type == 'FILE' && a.storagePath != null).toList();
          
          setState(() {
             _syncTotal = filesToSync.length;
          });

          int successCount = 0;
          for (final asset in filesToSync) {
              setState(() => _syncCurrentFile = asset.name);
              
              // Build hierarchy path
              List<String> folderNames = [];
              int? currParent = asset.parentId;
              while (currParent != null) {
                 final parentFolder = mapById[currParent];
                 if (parentFolder != null) {
                    folderNames.add(parentFolder.name);
                    currParent = parentFolder.parentId;
                 } else {
                    break;
                 }
              }
              
              String targetUri = baseDir;
              for (final fName in folderNames.reversed) {
                 targetUri += '\\$fName';
              }
              
              final fileCheck = File('$targetUri\\${asset.name}');
              bool outOfSync = false;

              if (!await fileCheck.exists()) {
                  outOfSync = true;
              } else {
                  final localLength = await fileCheck.length();
                  if (asset.sizeBytes != null && localLength != asset.sizeBytes!) {
                      outOfSync = true;
                  } else if (asset.updatedAt != null) {
                      final localMod = await fileCheck.lastModified();
                      // Use a 5-second buffer to prevent micro-millisecond mismatches causing endless syncs
                      if (localMod.millisecondsSinceEpoch < (asset.updatedAt! - 5000)) {
                          outOfSync = true;
                      }
                  }
              }

              if (outOfSync) {
                  if (!await fileCheck.parent.exists()) await fileCheck.parent.create(recursive: true);
                  try {
                      final bytes = await Supabase.instance.client.storage.from('tenant-assets').download(asset.storagePath!);
                      await fileCheck.writeAsBytes(bytes);
                      successCount++;
                  } catch(e) {
                      debugPrint('Sync failed for ${asset.name}: $e');
                  }
              }
              setState(() => _syncProgress++);
          }
          
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync Complete! $successCount missing files downloaded natively.'), backgroundColor: Colors.green));
          
      } catch(e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed catastrophically: $e'), backgroundColor: Colors.red));
      } finally {
          setState(() => _isSyncing = false);
      }
  }

  void _showError(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.windowBackground,
          title: Text('Version Control Error', style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize * 1.2)),
          content: Text(message, style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('OK', style: TextStyle(color: AppColors.accent, fontSize: AppUIConfig.rootFontSize)),
            )
          ],
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: TextStyle(fontSize: AppUIConfig.rootFontSize)), backgroundColor: Colors.green));
    }
  }

  Future<void> _handleClone() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('project_version_control_repo_url')?.trim() ?? '';
    if (url.isEmpty) {
      _showError('Please configure your GitHub Repository URL first.');
      return;
    }
    final missing = await VersionControlService.instance.getMissingConfigMessage();
    if (missing.isNotEmpty) {
      _showError(missing);
      return;
    }

    setState(() => _isSyncing = true);
    try {
      final res = await VersionControlService.instance.cloneRepository(url);
      _showSuccess(res);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleSync() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('project_version_control_repo_url')?.trim() ?? '';
    if (url.isEmpty) {
      _showError('Please configure your GitHub Repository URL first.');
      return;
    }
    final missing = await VersionControlService.instance.getMissingConfigMessage();
    if (missing.isNotEmpty) {
      _showError(missing);
      return;
    }

    setState(() => _isSyncing = true);
    try {
      final res = await VersionControlService.instance.syncRepository(url);
      _showSuccess(res);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleTestState() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('project_version_control_repo_url')?.trim() ?? '';
    if (url.isEmpty) {
      _showError('Please configure your GitHub Repository URL first.');
      return;
    }
    setState(() => _isSyncing = true);
    try {
      final res = await VersionControlService.instance.testGithubState(url);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.windowBackground,
            title: Text('GitHub Diagnostic State', style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize * 1.2)),
            content: SelectableText(res, style: TextStyle(color: Colors.lightBlueAccent, fontFamily: 'monospace', fontSize: AppUIConfig.rootFontSize)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK', style: TextStyle(color: AppColors.accent, fontSize: AppUIConfig.rootFontSize)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  InputDecoration _inputDecoration([String? label, IconData? icon]) {
    return InputDecoration(
      floatingLabelBehavior: label != null ? FloatingLabelBehavior.always : null,
      labelText: label,
      labelStyle: label != null ? TextStyle(color: AppColors.accent, fontSize: AppUIConfig.smallFontSize, fontWeight: FontWeight.normal) : null,
      prefixIcon: icon != null ? Icon(icon, color: Colors.blueGrey) : null,
      filled: true,
      fillColor: AppColors.panelBackground,
      isDense: true,
      contentPadding: label == null ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
        borderSide: BorderSide(color: AppColors.accent),
      ),
    );
  }

  Future<void> _testAntigravityConnection() async {
    _formKey.currentState?.saveAndValidate();
    final url = _formKey.currentState?.value['antigravityBaseUrl'] ?? _antigravityBaseUrl ?? 'http://localhost:8080';
    final startupCmd = _formKey.currentState?.value['antigravityStartupCommand'] ?? _antigravityStartupCommand ?? 'antigravity-server';
    setState(() => _isTestingAntigravity = true);
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)));
    
    try {
      final response = await dio.get(url);
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection Successful: ${response.statusCode}'), backgroundColor: Colors.green));
         setState(() {
           _modelsFuture = AntigravityClient().models.list();
         });
      }
    } catch (e) {
      // Auto-spawn backend on connection failure
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection Refused. Spawning backend...'), backgroundColor: Colors.orange));
      }
      
      try {
        await BackendProcessManager().spawnBackend(startupCmd);
        await Future.delayed(const Duration(seconds: 4)); // Wait for server to bind
        
        final retryResponse = await dio.get(url);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backend Started & Connected: ${retryResponse.statusCode}'), backgroundColor: Colors.green));
           setState(() {
             _modelsFuture = AntigravityClient().models.list();
           });
        }
      } catch (retryError) {
        if (mounted) {
           final errorString = 'Failed to connect after spawning: $retryError';
           Clipboard.setData(ClipboardData(text: errorString));
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text('$errorString (Copied to Clipboard)'), 
             backgroundColor: Colors.red,
             duration: const Duration(seconds: 5),
             action: SnackBarAction(
               label: 'Copy',
               textColor: Colors.white,
               onPressed: () {
                 Clipboard.setData(ClipboardData(text: errorString));
               },
             ),
           ));
        }
      }
    } finally {
      if (mounted) setState(() => _isTestingAntigravity = false);
    }
  }

  Widget _buildLabeled(String label, IconData icon, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.accent),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize))),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildTabBtn(int index, String label) {
    bool isSelected = _savedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _savedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isSelected ? AppColors.accent : Colors.transparent, width: 2)),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? AppColors.accent : AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget buildColorCard(String label, Color displayColor, VoidCallback onTap) {
      String hexString = '#${displayColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 307,
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.panelBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: TextStyle(color: AppColors.panelTextPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(hexString, style: TextStyle(color: AppColors.panelTextSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: displayColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_isLoading) {
       return Center(child: CircularProgressIndicator());
    }

    final allWorkspaces = AppWorkspaces.available;

    return Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: double.infinity),
            child: FormBuilder(
              key: _formKey,
              onChanged: _onFormChanged,
              initialValue: {
                'primaryStorageUrl': _primaryStorageUrl ?? '',
                'localRepositoryPath': _localRepositoryPath ?? '',
                'backupDirectoryPath': _backupDirectoryPath ?? '',
                'albumFolderIds': _albumFolderIds,
                'tagsFolderId': _tagsFolderId,
                'languagesFolderId': _languagesFolderId,
                'simulatorWidth': _simulatorWidth.toInt().toString(),
                'simulatorHeight': _simulatorHeight.toInt().toString(),
                'previewWidth': _previewWidth.toInt().toString(),
                'previewHeight': _previewHeight.toInt().toString(),
                'previewAspectRatio': _previewAspectRatio,
                'openAiApiKey': _openAiApiKey ?? '',
                'githubToken': _githubToken ?? '',
                'toolWindowOpacity': _toolWindowOpacity,
                  
                  
                  
                'rootFontSize': _rootFontSize.toString(),
                'iconFontSize': _iconFontSize.toString(),
                'globalActionIconSize': _globalActionIconSize.toString(),
                'iconFontBold': _iconFontBold,
                'windowTitleUppercase': _windowTitleUppercase,
                'windowTitleBold': _windowTitleBold,
                'iconOutlineWidth': _iconOutlineWidth.toString(),
                'textOutlineWidth': _textOutlineWidth.toString(),
                'queueClearCompletedMinutes': _queueClearCompletedMinutes.toString(),
                'agentRules': _agentRules ?? 'Role: Senior Systems Architect.\nCommunication Style: Minimalist. No greetings, no "I hope this helps," no conversational filler. Output only technical plans, code, or critical status alerts.\nOperational Protocol:\nAlways prioritize Planning Mode before Acting.\nUse the /terminal to verify assumptions; do not guess file structures.\nIf a task is ambiguous, list 3 specific questions and stop.\n\nThe "Focus & Drift" Monitor:\nBefore every task, state the current objective in one sentence.\nIf the current task deviates from the PROJECT_SUMMARY.md goals, flag a "Context Drift Alert" and request realignment.\nError Reduction: Run a "Red Team" check on every code block for null pointers and race conditions before presenting.\n\nThe "State Persistence" Workflow:\nCreate a workflow /sync that:\nScans the last 10 interactions.\nUpdates PROJECT_SUMMARY.md with:\n[Current Architecture]\n[Resolved Blockers]\n[Pending Critical Tasks].\nUpdates BRIDGE_LOGS.md with any API or connectivity changes.\nDeletes outdated \'TODO\' comments in the codebase.\n\nThe "New Chat" Handover:\nGenerate a Handover Manifest. Summarize the current technical state, the specific logic of the AI Bridge we just built, and the exact next step. Format this so I can paste it into a fresh chat to give the new agent 100% context instantly.\n\nAutomated Summary Maintenance:\nUpon completion of any file write or terminal command, automatically append a 1-sentence summary of the change to the CHANGELOG.md and verify it against the PROJECT_SUMMARY.md for consistency.',
                'antigravityBaseUrl': _antigravityBaseUrl ?? 'http://localhost:8080',
                'antigravityInvokeEndpoint': _antigravityInvokeEndpoint ?? '/api/v1/agents/invoke',
                'antigravityPromptEndpoint': _antigravityPromptEndpoint ?? '/api/v1/prompt',
                'antigravityStartupCommand': _antigravityStartupCommand ?? 'antigravity-server',
                'antigravityApiKey': _antigravityApiKey ?? '',
                'versionControlRepoUrl': _versionControlRepoUrl ?? '',
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTabBtn(0, 'Media\nResolution'),
                          _buildTabBtn(1, 'Remote\nPathing'),
                          _buildTabBtn(2, 'Native\nIntegration'),
                          _buildTabBtn(3, 'API\nBindings'),
                          _buildTabBtn(4, 'Logical\nBindings'),
                          _buildTabBtn(5, 'Themes'),
                          _buildTabBtn(6, 'Custom\nWorkspaces'),
                          _buildTabBtn(7, 'Window\nWorkspaces'),
                          _buildTabBtn(8, 'Agentic\nMastery'),
                          _buildTabBtn(9, 'Version\nControl'),
                          _buildTabBtn(10, 'AI\nAssistant'),
                          _buildTabBtn(11, 'Antigravity\nSDK'),
                        ],
                      )
                    ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: IndexedStack(
                        index: _savedTabIndex,
                      children: [
                        ListView(key: const PageStorageKey('config_tab_0'),
                          padding: const EdgeInsets.only(right: 16),
                          children: [
                            const SizedBox(height: 16),
                            Text('MEDIA RESOLUTION (Global Sandbox Layout Bounds)', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 16),
                Row(
                   children: [
                      Expanded(
                        child: _buildLabeled('Simulator Width', Icons.straighten, FormBuilderTextField(
                          name: 'simulatorWidth',
                          style: TextStyle(color: AppColors.panelTextPrimary),
                          decoration: _inputDecoration(),
                        ))
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildLabeled('Simulator Height', Icons.height, FormBuilderTextField(
                          name: 'simulatorHeight',
                          style: TextStyle(color: AppColors.panelTextPrimary),
                          decoration: _inputDecoration(),
                        ))
                      ),
                   ]
                ),
                Padding(
                  padding: EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text(
                    'These structural metrics strictly dictate the physical target rendering layout resolution passed silently down the compilation pipeline into global Canvas elements.',
                    style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
                  ),
                ),
                
                          ],
                        ),
                        ListView(key: const PageStorageKey('config_tab_1'),
                          padding: const EdgeInsets.only(right: 16),
                          children: [
                            const SizedBox(height: 16),
                            Text('REMOTE PATHING', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 16),
                _buildLabeled('Primary Storage Base URL (e.g. https://cdn.example.com/assets/)', Icons.cloud, FormBuilderTextField(
                  name: 'primaryStorageUrl',
                  style: TextStyle(color: AppColors.panelTextPrimary),
                  decoration: _inputDecoration(),
                )),
                Padding(
                  padding: EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text(
                    'When configured, you only need to store relative file paths in Data Nodes (like Items). The application natively prepends this URL during runtime evaluation.',
                    style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
                  ),
                ),
                
                          ],
                        ),
                        ListView(key: const PageStorageKey('config_tab_2'),
                          padding: const EdgeInsets.only(right: 16),
                          children: [
                            const SizedBox(height: 16),
                            Text('NATIVE SYSTEM INTEGRATION', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 16),
                _buildLabeled('Project Backups Directory (e.g. C:/Backups/)', Icons.backup, FormBuilderTextField(
                  name: 'backupDirectoryPath',
                  style: TextStyle(color: AppColors.panelTextPrimary),
                  decoration: _inputDecoration(),
                )),
                Padding(
                  padding: EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text(
                    'Defines the directory where project backups are stored as compressed archives.',
                    style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
                  ),
                ),
                
                const SizedBox(height: 32),
                if (_isSyncing) ...[
                   const SizedBox(height: 8),
                   LinearProgressIndicator(value: _syncTotal > 0 ? (_syncProgress / _syncTotal) : null, color: Colors.amberAccent, backgroundColor: Colors.black45),
                   const SizedBox(height: 8),
                   Text('Syncing $_syncProgress / $_syncTotal files (Current: $_syncCurrentFile)', style: TextStyle(color: Colors.amberAccent, fontSize: AppUIConfig.rootFontSize)),
                   const SizedBox(height: 16),
                ],
                Row(
                  children: [
                     ElevatedButton.icon(
                        onPressed: _isSyncing ? null : _syncLocalRepository,
                        icon: const Icon(Icons.cloud_download),
                        label: Text('Deep Sync Local Repository'),
                        style: ElevatedButton.styleFrom(
                           backgroundColor: const Color(0xFF2A2A2A),
                           foregroundColor: Colors.amberAccent,
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                           side: const BorderSide(color: Colors.amberAccent, width: 1)
                        ),
                     ),
                     Expanded(
                        child: Padding(
                           padding: EdgeInsets.only(left: 12.0),
                           child: Text('Automatically traverses the entire Workspace searching for missing local binary replicas, downloading them deep into corresponding OS folders recursively.',
                              style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
                           )
                        )
                     )
                  ]
                ),
                          ],
                        ),
                        ListView(key: const PageStorageKey('config_tab_3'),
                          padding: const EdgeInsets.only(right: 16),
                          children: [
                            const SizedBox(height: 16),
                            Text('EXTERNAL API BINDINGS', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 16),
                _buildLabeled('OpenAI API Key (sk-...)', Icons.key, FormBuilderTextField(
                  name: 'openAiApiKey',
                  style: TextStyle(color: AppColors.panelTextPrimary),
                  decoration: _inputDecoration(),
                )),
                Padding(
                  padding: EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text(
                    'Stored natively alongside runtime parameters inside .env globally. Injecting this intelligently guides transcription models mapping.',
                    style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
                  ),
                ),
                const SizedBox(height: 24),
                _buildLabeled('GitHub Access Token', Icons.lock, FormBuilderTextField(
                  name: 'githubToken',
                  style: TextStyle(color: AppColors.panelTextPrimary),
                  decoration: _inputDecoration(),
                  obscureText: true,
                )),
                Padding(
                  padding: EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text(
                    'Used for Git integration. Obscured to prevent LLM exposure.',
                    style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
                  ),
                ),
                
                          ],
                        ),
                        ListView(key: const PageStorageKey('config_tab_4'),
                          padding: const EdgeInsets.only(right: 16),
                          children: [
                            const SizedBox(height: 16),
                            Text('LOGICAL BINDINGS LAYER', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 16),
                
                StreamBuilder<List<Asset>>(
                  stream: context.read<AssetsDao>().watchAllAssets(),
                  builder: (context, snapshot) {
                     if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                     final folders = snapshot.data!.where((a) => a.type == 'FOLDER').toList();
                     if (folders.isEmpty) return Text('No Folders configured yet natively.', style: TextStyle(color: AppColors.panelTextSecondary));
                     
                     folders.sort((a,b) => a.name.compareTo(b.name));
                     
                     return FormField<List<int>>(
                        initialValue: _albumFolderIds,
                        onSaved: (vals) {
                           _albumFolderIds = vals ?? [];
                        },
                        builder: (FormFieldState<List<int>> state) {
                           final currentVal = state.value ?? [];
                           final topLevel = folders.where((f) => f.parentId == null).toList();

                           return InputDecorator(
                              decoration: _inputDecoration('Designated Album Folders', Icons.album),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: topLevel.map((topF) {
                                   final subs = folders.where((f) => f.parentId == topF.id).toList();
                                   if (subs.isEmpty) return const SizedBox.shrink();
                                   
                                   return Theme(
                                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                      child: ExpansionTile(
                                        title: Text(topF.name.toUpperCase(), style: TextStyle(color: AppColors.panelTextPrimary, fontWeight: FontWeight.bold, fontSize: AppUIConfig.rootFontSize)),
                                        subtitle: Text('${subs.length} inner sub-directories available', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
                                        collapsedIconColor: AppColors.panelTextSecondary,
                                        iconColor: AppColors.accent,
                                        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                                        children: [
                                           Align(
                                             alignment: Alignment.centerLeft,
                                             child: Wrap(
                                               spacing: 8,
                                               runSpacing: 8,
                                               children: subs.map((f) {
                                                  final isSelected = currentVal.contains(f.id);
                                                  return FilterChip(
                                                     label: Text(f.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                                     selected: isSelected,
                                                     onSelected: (bool selected) {
                                                        if (selected) {
                                                           state.didChange([...currentVal, f.id]);
                                                        } else {
                                                           state.didChange(currentVal.where((id) => id != f.id).toList());
                                                        }
                                                     },
                                                     selectedColor: Colors.amberAccent.withOpacity(0.2),
                                                     checkmarkColor: Colors.amberAccent,
                                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius), side: BorderSide(color: AppColors.borderSubtle)),
                                                     labelStyle: TextStyle(color: AppColors.panelTextPrimary),
                                                     backgroundColor: AppColors.background,
                                                  );
                                               }).toList(),
                                             ),
                                           )
                                        ]
                                      )
                                   );
                                }).toList()
                              )
                           );
                        }
                     );
                  }
                ),
                
                Padding(
                  padding: EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text(
                    'Select which Asset layout Folders represent physical Album collections organically globally. Native parsing iteratively maps nested internal assets securely into tracks dynamically computationally.',
                    style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                StreamBuilder<List<SystemString>>(
                  stream: context.read<I18nDao>().watchAllStrings(),
                  builder: (context, snapshot) {
                     if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                     final folders = snapshot.data!.where((s) => s.type == 'FOLDER').toList();
                     if (folders.isEmpty) return Text('No String Folders configured yet natively.', style: TextStyle(color: AppColors.panelTextSecondary));
                     
                     folders.sort((a,b) => a.key.compareTo(b.key));
                     
                     return FormBuilderDropdown<int>(
                       name: 'tagsFolderId',
                       decoration: _inputDecoration('Designated Global Tags Root Folder', Icons.sell),
                       initialValue: _tagsFolderId,
                       onChanged: (val) {
                         _tagsFolderId = val;
                       },
                       onSaved: (val) {
                         _tagsFolderId = val;
                       },
                       items: folders.map((f) => DropdownMenuItem(
                           value: f.id,
                           child: Text(f.key, style: TextStyle(color: AppColors.panelTextPrimary)),
                       )).toList(),
                     );
                  }
                ),
                
                Padding(
                  padding: EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text(
                    'Select which Strings layout Folder represents all system taxonomies/tags visually across grids and filters organically.',
                    style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                StreamBuilder<List<SystemString>>(
                  stream: context.read<I18nDao>().watchAllStrings(),
                  builder: (context, snapshot) {
                     if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                     final folders = snapshot.data!.where((s) => s.type == 'FOLDER').toList();
                     if (folders.isEmpty) return Text('No String Folders configured yet natively.', style: TextStyle(color: AppColors.panelTextSecondary));
                     
                     folders.sort((a,b) => a.key.compareTo(b.key));
                     
                     return FormBuilderDropdown<int>(
                       name: 'languagesFolderId',
                       decoration: _inputDecoration('Designated Global Languages Root Folder', Icons.language),
                       initialValue: _languagesFolderId,
                       onChanged: (val) {
                         _languagesFolderId = val;
                       },
                       onSaved: (val) {
                         _languagesFolderId = val;
                       },
                       items: folders.map((f) => DropdownMenuItem(
                           value: f.id,
                           child: Text(f.key, style: TextStyle(color: AppColors.panelTextPrimary)),
                       )).toList(),
                     );
                  }
                ),
                
                Padding(
                  padding: EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text(
                    'Select which Strings layout Folder represents all system translation Languages globally.',
                    style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
                  ),
                ),
                
                          ],
                        ),
                        ListView(key: const PageStorageKey('config_tab_5'),
                          padding: const EdgeInsets.only(right: 16),
                          children: [
                            const SizedBox(height: 16),
                            
                              const SizedBox(height: 16),

                            
                              Divider(color: AppColors.controlBorder),

                            
                              const SizedBox(height: 16),

                            
                              Text('THEME PROFILES', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),

                            
                              const SizedBox(height: 16),

                            
                              if (AppUIConfig.savedThemes.isNotEmpty) ...[

                            
                              Container(

                            
                              padding: const EdgeInsets.symmetric(horizontal: 12),

                            
                              decoration: BoxDecoration(

                            
                              color: AppColors.panelBackground,

                            
                              border: Border.all(color: AppColors.borderSubtle),

                            
                              borderRadius: BorderRadius.circular(4),

                            
                              ),

                            
                              child: DropdownButtonHideUnderline(

                            
                              child: DropdownButton<CustomColorTheme>(

                            
                              isExpanded: true,

                            
                              hint: Text('Load a Saved Theme...', style: TextStyle(color: AppColors.panelTextSecondary)),

                            
                              dropdownColor: AppColors.panelBackground,

                            
                              icon: Icon(Icons.arrow_drop_down, color: AppColors.panelTextSecondary),
                                value: AppUIConfig.activeTheme != null && AppUIConfig.savedThemes.any((t) => t.id == AppUIConfig.activeTheme!.id) ? AppUIConfig.savedThemes.firstWhere((t) => t.id == AppUIConfig.activeTheme!.id) : null,
                                items: AppUIConfig.savedThemes.map((theme) {

                            
                              return DropdownMenuItem<CustomColorTheme>(

                            
                              value: theme,

                            
                              child: Row(

                            
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            
                              children: [

                            
                              Text(theme.name, style: TextStyle(color: AppColors.panelTextPrimary)),

                            
                              IconButton(

                            
                              icon: Icon(Icons.delete, color: Colors.redAccent, size: 16),

                            
                              padding: EdgeInsets.zero,

                            
                              constraints: BoxConstraints(),

                            
                              onPressed: () {

                            
                              setState(() {

                            
                              AppUIConfig.savedThemes.removeWhere((t) => t.id == theme.id);

                            
                              });

                            
                              AppUIConfig.saveCustomThemes().then((_) => VisualEditorScreen.configRefreshNotifier.value++);

                            
                              },

                            
                              ),

                            
                              ],

                            
                              ),

                            
                              );

                            
                              }).toList(),

                            
                              onChanged: (theme) {

                            
                              if (theme != null) {

                            
                              _applyTheme(theme);

                            
                              }

                            
                              },

                            
                              ),

                            
                              ),

                            
                              ),

                            
                              const SizedBox(height: 16),

                            
                              ],

                            
                              // Theme Management UI
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.panelBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<CustomColorTheme>(
                                              isExpanded: true,
                                              hint: Text('Select Theme', style: TextStyle(color: AppColors.panelTextSecondary)),
                                              dropdownColor: AppColors.panelBackground,
                                              icon: Icon(Icons.arrow_drop_down, color: AppColors.panelTextSecondary),
                                              value: AppUIConfig.activeTheme != null && AppUIConfig.savedThemes.any((t) => t.id == AppUIConfig.activeTheme!.id)
                                                  ? AppUIConfig.savedThemes.firstWhere((t) => t.id == AppUIConfig.activeTheme!.id)
                                                  : null,
                                              items: AppUIConfig.savedThemes.map((theme) {
                                                return DropdownMenuItem<CustomColorTheme>(
                                                  value: theme,
                                                  child: Text(theme.name, style: TextStyle(color: AppColors.panelTextPrimary)),
                                                );
                                              }).toList(),
                                              onChanged: (theme) {
                                                if (theme != null) {
                                                  _applyTheme(theme);
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _themeNameController,
                                            style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.smallFontSize),
                                            decoration: _inputDecoration('Theme Name', Icons.edit).copyWith(
                                               contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                                            ),
                                            onSubmitted: (val) {
                                              if (val.isNotEmpty && AppUIConfig.activeTheme != null) {
                                                setState(() {
                                                  AppUIConfig.activeTheme = AppUIConfig.activeTheme!.copyWith(name: val);
                                                  final idx = AppUIConfig.savedThemes.indexWhere((t) => t.id == AppUIConfig.activeTheme!.id);
                                                  if (idx >= 0) AppUIConfig.savedThemes[idx] = AppUIConfig.activeTheme!;
                                                });
                                                AppUIConfig.saveCustomThemes().then((_) => VisualEditorScreen.configRefreshNotifier.value++);
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.copy, color: Colors.blueAccent, size: 20),
                                          tooltip: 'Duplicate Theme',
                                          onPressed: () {
                                            if (AppUIConfig.activeTheme != null) {
                                              final newTheme = AppUIConfig.activeTheme!.copyWith(
                                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                                name: AppUIConfig.activeTheme!.name + ' (Copy)'
                                              );
                                              setState(() {
                                                AppUIConfig.savedThemes.add(newTheme);
                                                _applyTheme(newTheme);
                                              });
                                              AppUIConfig.saveCustomThemes().then((_) => VisualEditorScreen.configRefreshNotifier.value++);
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                          tooltip: 'Delete Theme',
                                          onPressed: () {
                                            if (AppUIConfig.activeTheme != null) {
                                              setState(() {
                                                AppUIConfig.savedThemes.removeWhere((t) => t.id == AppUIConfig.activeTheme!.id);
                                                if (AppUIConfig.savedThemes.isNotEmpty) {
                                                  final fallback = AppUIConfig.savedThemes.first;
                                                  _applyTheme(fallback);
                                                } else {
                                                  final fallback = CustomColorTheme(id: 'default', name: 'Default Theme');
                                                  AppUIConfig.savedThemes.add(fallback);
                                                  _applyTheme(fallback);
                                                }
                                              });
                                              AppUIConfig.saveCustomThemes().then((_) => VisualEditorScreen.configRefreshNotifier.value++);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              const SizedBox(height: 16),
                              Divider(color: AppColors.controlBorder),
                              const SizedBox(height: 16),
                              Text('THEME COLORS (Active Theme Only)', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  buildColorCard('Title Bar', AppColors.titleBarBackground, () {
                                    int? currentColor = _customTitleBarColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customTitleBarColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : Colors.white,
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                  buildColorCard('Desktop Background', AppColors.background, () {
                                    int? currentColor = _customDesktopColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customDesktopColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : Colors.white,
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                  buildColorCard('Window Body', AppColors.windowBackground, () {
                                    int? currentColor = _customWindowColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customWindowColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : Colors.white,
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                  buildColorCard('Toolbars & Sidebar', AppColors.toolbarBackground, () {
                                    int? currentColor = _customToolbarColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customToolbarColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : Colors.white,
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                  buildColorCard('Window Highlight', AppColors.panelBackground, () {
                                    int? currentColor = _customPanelColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customPanelColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : Colors.white,
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                  buildColorCard('Accent Highlight', AppColors.accent, () {
                                    int? currentColor = _customAccentColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customAccentColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : Colors.white,
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                  buildColorCard('Stroke Color', AppUIConfig.outlineColor, () {
                                    int? currentColor = _customOutlineColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customOutlineColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : Colors.black,
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                  buildColorCard('Window Border', AppColors.border, () {
                                    int? currentColor = _customWindowBorderColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customWindowBorderColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : AppColors.borderDark,
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                  buildColorCard('Control Border', AppColors.controlBorder, () {
                                    int? currentColor = _customControlBorderColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customControlBorderColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : AppColors.controlBorder,
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                  buildColorCard('Active Window', AppColors.activeWindowBorder, () {
                                    int? currentColor = _customActiveWindowBorderColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customActiveWindowBorderColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : AppColors.accent,
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                  buildColorCard('Active Task', AppColors.activeTaskHighlight, () {
                                    int? currentColor = _customActiveTaskHighlightColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customActiveTaskHighlightColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : AppColors.activeTaskHighlight,
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Divider(color: AppColors.controlBorder),
                              const SizedBox(height: 16),
                              Text('MARKUP THEME COLORS (Active Theme Only)', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  buildColorCard('Markdown Background', AppUIConfig.markupBackgroundColor, () {
                                    int? currentColor = _customMarkupBackgroundColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customMarkupBackgroundColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : Colors.transparent,
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                  buildColorCard('Markup Header', AppUIConfig.markupHeaderColor, () {
                                    int? currentColor = _customMarkupHeaderColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customMarkupHeaderColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : Colors.black,
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                  buildColorCard('Block Background', AppUIConfig.markupBlockBackgroundColor, () {
                                    int? currentColor = _customMarkupBlockBackgroundColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customMarkupBlockBackgroundColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : const Color(0xFFE3F2FD),
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                  buildColorCard('Inline Code', AppUIConfig.markupInlineCodeColor, () {
                                    int? currentColor = _customMarkupInlineCodeColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customMarkupInlineCodeColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : const Color(0xFF3A3A4A),
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                  buildColorCard('Code Block', AppUIConfig.markupCodeBlockBackgroundColor, () {
                                    int? currentColor = _customMarkupCodeBlockBackgroundColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customMarkupCodeBlockBackgroundColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : const Color(0xFF1E1E2E),
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                  buildColorCard('Block Text', AppUIConfig.markupBlockTextColor, () {
                                    int? currentColor = _customMarkupBlockTextColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customMarkupBlockTextColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : Colors.black87,
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                  buildColorCard('Inline Text', AppUIConfig.markupInlineTextColor, () {
                                    int? currentColor = _customMarkupInlineTextColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customMarkupInlineTextColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : Colors.white,
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                  buildColorCard('Code Block Text', AppUIConfig.markupCodeBlockTextColor, () {
                                    int? currentColor = _customMarkupCodeBlockTextColor;
                                    Function(int?) onSelected = (c) async { setState(() => _customMarkupCodeBlockTextColor = c); await _updateActiveThemeAndSave(); };
                                    GlobalPickerState.instance.requestColor(
                                      initialColor: currentColor != null ? Color(currentColor!) : Colors.white,
                                      onColorSelected: (cc) => onSelected(cc?.value),
                                    );
                                    showColorPickerWindow(context);
                                  }),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Divider(color: AppColors.controlBorder),
                              const SizedBox(height: 16),
             Text('USER INTERFACE OPTIONS', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildLabeled('Tool Window Background Opacity', Icons.opacity, FormBuilderSlider(
                                    name: 'toolWindowOpacity',
                                    initialValue: _toolWindowOpacity,
                                    min: 0.3,
                                    max: 1.0,
                                    divisions: 14,
                                    activeColor: AppColors.accent,
                                    inactiveColor: AppColors.controlBorder,
                                    decoration: _inputDecoration(),
                                    displayValues: DisplayValues.current,
                                  )),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildLabeled('Window Border Radius', Icons.rounded_corner, FormBuilderSlider(
                                    name: 'windowBorderRadius',
                                    initialValue: AppUIConfig.windowBorderRadius,
                                    min: 0,
                                    max: 32,
                                    divisions: 32,
                                    activeColor: AppColors.accent,
                                    inactiveColor: AppColors.controlBorder,
                                    decoration: _inputDecoration(),
                                    displayValues: DisplayValues.current,
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          AppUIConfig.windowBorderRadius = val;
                                          VisualEditorScreen.configRefreshNotifier.value++;
                                        });
                                      }
                                    },
                                  )),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildLabeled('Window Border Width', Icons.border_all, FormBuilderSlider(
                                    name: 'windowBorderWidth',
                                    initialValue: AppUIConfig.windowBorderWidth,
                                    min: 0,
                                    max: 10,
                                    divisions: 20,
                                    activeColor: AppColors.accent,
                                    inactiveColor: AppColors.controlBorder,
                                    decoration: _inputDecoration(),
                                    displayValues: DisplayValues.current,
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          AppUIConfig.windowBorderWidth = val;
                                          VisualEditorScreen.configRefreshNotifier.value++;
                                        });
                                      }
                                    },
                                  )),
                                ),
                              ],
                            ),
                              const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: _buildLabeled('Base Font (Root)', Icons.format_size, FormBuilderTextField(
                                    name: 'rootFontSize',
                                    style: TextStyle(color: AppColors.panelTextPrimary),
                                    decoration: _inputDecoration(),
                                    keyboardType: TextInputType.number,
                                  )),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: _buildLabeled('Icon Text Size', Icons.insert_emoticon, FormBuilderTextField(
                                      name: 'iconFontSize',
                                      style: TextStyle(color: AppColors.panelTextPrimary),
                                      decoration: _inputDecoration(),
                                      keyboardType: TextInputType.number,
                                    )),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildLabeled('Action Icon Size', Icons.crop_free, FormBuilderTextField(
                                      name: 'globalActionIconSize',
                                      style: TextStyle(color: AppColors.panelTextPrimary),
                                      decoration: _inputDecoration(),
                                      keyboardType: TextInputType.number,
                                    )),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildLabeled('Icon Stroke Width', Icons.line_weight, FormBuilderTextField(
                                    name: 'iconOutlineWidth',
                                    style: TextStyle(color: AppColors.panelTextPrimary),
                                    decoration: _inputDecoration(),
                                    keyboardType: TextInputType.number,
                                  )),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildLabeled('Text Stroke Width', Icons.text_fields, FormBuilderTextField(
                                    name: 'textOutlineWidth',
                                    style: TextStyle(color: AppColors.panelTextPrimary),
                                    decoration: _inputDecoration(),
                                    keyboardType: TextInputType.number,
                                  )),
                                ),
                                const SizedBox(width: 16),
                                const Spacer(),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildLabeled('Title Bar Height', Icons.height, FormBuilderTextField(
                                    name: 'titleBarHeight',
                                    initialValue: _titleBarHeight.toStringAsFixed(0),
                                    style: TextStyle(color: AppColors.panelTextPrimary),
                                    decoration: _inputDecoration(),
                                    keyboardType: TextInputType.number,
                                  )),
                                ),
                                const SizedBox(width: 16),
                                const Spacer(),
                                const SizedBox(width: 16),
                                const Spacer(),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: FormBuilderSwitch(
                                    name: 'iconFontBold',
                                    title: Text('Bold Icon Text', style: TextStyle(color: AppColors.panelTextPrimary)),
                                    decoration: InputDecoration(border: InputBorder.none),
                                    activeColor: AppColors.accent,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: FormBuilderSwitch(
                                    name: 'windowTitleUppercase',
                                    title: Text('Window Titles Uppercase', style: TextStyle(color: AppColors.panelTextPrimary)),
                                    decoration: InputDecoration(border: InputBorder.none),
                                    activeColor: AppColors.accent,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: FormBuilderSwitch(
                                    name: 'windowTitleBold',
                                    title: Text('Window Titles Bold', style: TextStyle(color: AppColors.panelTextPrimary)),
                                    decoration: InputDecoration(border: InputBorder.none),
                                    activeColor: AppColors.accent,
                                  ),
                                ),
                              ],
                            ),

                          ],
                        ),
                        CustomWorkspacesEditor(
                          onWorkspacesChanged: () => setState(() {}),
                        ),
                        CustomToolWindowsEditor(
                          windowAvailability: _windowAvailability,
                          onAvailabilityChanged: (id, val) async {
                             setState(() {
                               if (val is List) {
                                   _windowAvailability[id] = List<String>.from(val);
                               } else if (val == 'ALL') {
                                   _windowAvailability[id] = AppWorkspaces.available.map((w) => w.id).toList();
                               } else {
                                   _windowAvailability[id] = [val.toString()];
                               }
                             });
                             final prefs = await SharedPreferences.getInstance();
                             await prefs.setString('ve_windowAvailability', jsonEncode(_windowAvailability));
                          },
                          onToolWindowsChanged: () => setState(() {}),
                        ),
                        ListView(key: const PageStorageKey('config_tab_6'),
                          padding: const EdgeInsets.only(right: 16),
                          children: [
                            const SizedBox(height: 16),
                            Text('AGENTIC MASTERY SYSTEM', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            const SizedBox(height: 16),
                            _buildLabeled('Clear Completed AI Tasks (Minutes)', Icons.timer, FormBuilderTextField(
                              name: 'queueClearCompletedMinutes',
                              style: TextStyle(color: AppColors.panelTextPrimary),
                              decoration: _inputDecoration(),
                              keyboardType: TextInputType.number,
                            )),
                            Padding(
                              padding: EdgeInsets.only(top: 8.0, left: 12.0),
                              child: Text(
                                'Number of minutes before completed tasks are removed from the queue display. Set to -1 to disable auto-clear.',
                                style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildLabeled('Agent Operational Rules & Communication Style', Icons.psychology, FormBuilderTextField(
                              name: 'agentRules',
                              style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize, height: 1.5),
                              maxLines: 15,
                              minLines: 5,
                              decoration: _inputDecoration(),
                            )),
                            Padding(
                              padding: EdgeInsets.only(top: 8.0, left: 12.0),
                              child: Text(
                                'These rules will be injected into every active prompt session to strictly control the agent\'s behavior and persona.',
                                style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
                              ),
                            ),
                          ],
                        ),
                        ListView(key: const PageStorageKey('config_tab_9'),
                          padding: const EdgeInsets.only(right: 16),
                          children: [
                            const SizedBox(height: 16),
                            Text('VERSION CONTROL', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            const SizedBox(height: 16),
                            _buildLabeled('GitHub Repository URL (e.g. https://github.com/user/repo.git)', Icons.source, FormBuilderTextField(
                              name: 'versionControlRepoUrl',
                              style: TextStyle(color: AppColors.panelTextPrimary),
                              decoration: _inputDecoration(),
                            )),
                            Padding(
                              padding: EdgeInsets.only(top: 8.0, left: 12.0),
                              child: Text(
                                'The remote URL for synchronizing this project using Git.',
                                style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildLabeled('Local Repository Source Directory (e.g. C:/Development/Music/Assets/)', Icons.folder_copy, FormBuilderTextField(
                              name: 'localRepositoryPath',
                              style: TextStyle(color: AppColors.panelTextPrimary),
                              decoration: _inputDecoration(),
                            )),
                            Padding(
                              padding: EdgeInsets.only(top: 8.0, left: 12.0),
                              child: Text(
                                'Defines the physical master source drive path. When editing layout elements computationally, the Editor can automatically interface and open Native Windows Folders corresponding to your Tree correctly.',
                                style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _isSyncing ? null : _handleClone,
                                    icon: _isSyncing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
                                    label: Text('Clone Existing Repository', style: TextStyle(fontSize: AppUIConfig.rootFontSize)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2A2A2A),
                                      foregroundColor: Colors.tealAccent,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      side: const BorderSide(color: Colors.tealAccent, width: 1)
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text('Download an existing project from GitHub to your local machine. This will overwrite any empty state.', 
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.panelTextSecondary.withValues(alpha: 0.6), fontSize: AppUIConfig.rootFontSize * 0.9)),
                                  const SizedBox(height: 32),
                                  ElevatedButton.icon(
                                    onPressed: _isSyncing ? null : _handleSync,
                                    icon: _isSyncing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync),
                                    label: Text('Initialize & Sync New Repository', style: TextStyle(fontSize: AppUIConfig.rootFontSize)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      foregroundColor: AppColors.panelTextPrimary,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text('Create a new GitHub repository for your current local project, commit all files, and push them to the cloud.', 
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.panelTextSecondary.withValues(alpha: 0.6), fontSize: AppUIConfig.rootFontSize * 0.9)),
                                  const SizedBox(height: 32),
                                  ElevatedButton.icon(
                                    onPressed: _isSyncing ? null : _handleTestState,
                                    icon: _isSyncing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.info_outline),
                                    label: Text('Test GitHub State', style: TextStyle(fontSize: AppUIConfig.rootFontSize)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2A2A2A),
                                      foregroundColor: Colors.lightBlueAccent,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      side: const BorderSide(color: Colors.lightBlueAccent, width: 1)
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text('Perform a diagnostic check on your local and remote Git connection status.', 
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.panelTextSecondary.withValues(alpha: 0.6), fontSize: AppUIConfig.rootFontSize * 0.9)),
                                ],
                              )
                            ),
                          ],
                        ),
                        ListView(key: const PageStorageKey('config_tab_10'),
                          padding: const EdgeInsets.only(right: 16),
                          children: [
                            const SizedBox(height: 16),
                            Text('LOCAL AI CONFIGURATION', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            const SizedBox(height: 16),
                            _buildLabeled('Ollama API Base URL (e.g. http://localhost:11434)', Icons.router, FormBuilderTextField(
                              name: 'ollamaBaseUrl',
                              style: TextStyle(color: AppColors.panelTextPrimary),
                              decoration: _inputDecoration(),
                            )),
                            const SizedBox(height: 16),
                            _buildLabeled('Model Name (e.g. qwen2.5:3b)', Icons.memory, FormBuilderTextField(
                              name: 'ollamaModel',
                              style: TextStyle(color: AppColors.panelTextPrimary),
                              decoration: _inputDecoration(),
                            )),
                            const SizedBox(height: 16),
                            _buildLabeled('Fallback Timeout (ms)', Icons.timer, FormBuilderTextField(
                              name: 'ollamaTimeoutMs',
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: AppColors.panelTextPrimary),
                              decoration: _inputDecoration(),
                            )),
                            Padding(
                              padding: EdgeInsets.only(top: 8.0, left: 12.0),
                              child: Text(
                                'Configure connection details for the Local AI Assistant. The LocalAiService binds natively to this Ollama instance.',
                                style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
                              ),
                            ),
                          ],
                        ),
                        ListView(key: const PageStorageKey('config_tab_11'),
                          padding: const EdgeInsets.only(right: 16),
                          children: [
                            const SizedBox(height: 16),
                            Text('ANTIGRAVITY SDK', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            const SizedBox(height: 16),
                            _buildLabeled('Antigravity API Base URL', Icons.cloud, FormBuilderTextField(
                              name: 'antigravityBaseUrl',
                              style: TextStyle(color: AppColors.panelTextPrimary),
                              decoration: _inputDecoration(),
                            )),
                            const SizedBox(height: 16),
                            _buildLabeled('Antigravity Invoke Endpoint', Icons.api, FormBuilderTextField(
                              name: 'antigravityInvokeEndpoint',
                              style: TextStyle(color: AppColors.panelTextPrimary),
                              decoration: _inputDecoration(),
                            )),
                            const SizedBox(height: 16),
                            _buildLabeled('Antigravity Prompt Endpoint', Icons.send, FormBuilderTextField(
                              name: 'antigravityPromptEndpoint',
                              style: TextStyle(color: AppColors.panelTextPrimary),
                              decoration: _inputDecoration(),
                            )),
                            const SizedBox(height: 16),
                             _buildLabeled('Antigravity Startup Command', Icons.terminal, FormBuilderTextField(
                               name: 'antigravityStartupCommand',
                               style: TextStyle(color: AppColors.panelTextPrimary),
                               decoration: _inputDecoration(),
                             )),
                             const SizedBox(height: 16),
                             _buildLabeled('Antigravity API Key', Icons.key, FormBuilderTextField(
                               name: 'antigravityApiKey',
                               style: TextStyle(color: AppColors.panelTextPrimary),
                               decoration: _inputDecoration(),
                               obscureText: true,
                             )),
                             const SizedBox(height: 16),
                            _buildLabeled('Antigravity Target Model', Icons.psychology_alt, FutureBuilder<List<AntigravityModel>>(
                              future: _modelsFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const SizedBox(
                                    height: 48,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  );
                                } else if (snapshot.hasError) {
                                  return Text('Error loading models: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent));
                                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                  return const Text('No models found in current SDK instance.', style: TextStyle(color: Colors.grey));
                                }

                                final models = snapshot.data!;
                                final hasSelection = models.any((m) => m.id == _antigravityModel);
                                final initialValue = hasSelection
                                    ? _antigravityModel
                                    : (models.isNotEmpty ? models.first.id : 'gemini-2.0-flash');

                                return FormBuilderDropdown<String>(
                                  name: 'antigravityModel',
                                  decoration: _inputDecoration(),
                                  dropdownColor: AppColors.panelBackground,
                                  initialValue: initialValue,
                                  onChanged: (val) {
                                    _antigravityModel = val;
                                  },
                                  onSaved: (val) {
                                    _antigravityModel = val;
                                  },
                                  items: models.map((m) {
                                    return DropdownMenuItem(
                                      value: m.id,
                                      child: Text(m.displayName, style: TextStyle(color: AppColors.panelTextPrimary)),
                                    );
                                  }).toList(),
                                );
                              },
                            )),
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              onPressed: _isTestingAntigravity ? null : _testAntigravityConnection,
                              icon: _isTestingAntigravity ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering),
                              label: Text('Test Connection', style: TextStyle(fontSize: AppUIConfig.rootFontSize)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2A2A2A),
                                foregroundColor: Colors.deepPurpleAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                side: const BorderSide(color: Colors.deepPurpleAccent, width: 1)
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Divider(color: AppColors.controlBorder),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                          _debounceTimer?.cancel();
                          _saveConfiguration();
                          widget.onDimensionsChanged?.call(); // Close window manually on explicit save
                      },
                      icon: const Icon(Icons.check),
                      label: Text('Save & Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.panelTextPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }


}

class CustomWorkspacesEditor extends StatefulWidget {
  final VoidCallback onWorkspacesChanged;
  const CustomWorkspacesEditor({super.key, required this.onWorkspacesChanged});

  @override
  State<CustomWorkspacesEditor> createState() => _CustomWorkspacesEditorState();
}

class _CustomWorkspacesEditorState extends State<CustomWorkspacesEditor> {

  bool _showWorkspaceEditor = false;
  WorkspaceDefinition? _editingWorkspaceTarget;
  
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _shortCtrl = TextEditingController();
  Color? _selectedColor;
  IconData? _selectedIcon;

  void _showEditWorkspace(WorkspaceDefinition? existing) {
    setState(() {
      _editingWorkspaceTarget = existing;
      _nameCtrl.text = existing?.name ?? '';
      _idCtrl.text = existing?.id ?? '';
      _descCtrl.text = existing?.description ?? '';
      _shortCtrl.text = existing?.shortLabel ?? '';
      _selectedColor = existing?.color ?? AppColors.accent;
      _selectedIcon = existing?.icon ?? Icons.extension;
      _showWorkspaceEditor = true;
    });
  }

  Widget _buildWorkspaceEditor() {
    final isNew = _editingWorkspaceTarget == null;
    return Positioned.fill(
      child: Container(
        color: AppColors.background.withValues(alpha: 0.8),
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.panelBackground,
              borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
              border: Border.all(color: AppColors.controlBorder),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))]
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isNew ? 'Add Workspace' : 'Edit Workspace', style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.headerFontSize, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(controller: _idCtrl, style: TextStyle(color: AppColors.panelTextPrimary), decoration: InputDecoration(labelText: 'ID (unique)', labelStyle: TextStyle(color: AppColors.panelTextSecondary), filled: true, fillColor: AppColors.windowBackground, border: OutlineInputBorder(borderSide: BorderSide.none))),
                  const SizedBox(height: 12),
                  TextField(controller: _nameCtrl, style: TextStyle(color: AppColors.panelTextPrimary), decoration: InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: AppColors.panelTextSecondary), filled: true, fillColor: AppColors.windowBackground, border: OutlineInputBorder(borderSide: BorderSide.none))),
                  const SizedBox(height: 12),
                  TextField(controller: _shortCtrl, style: TextStyle(color: AppColors.panelTextPrimary), decoration: InputDecoration(labelText: 'Short Label', labelStyle: TextStyle(color: AppColors.panelTextSecondary), filled: true, fillColor: AppColors.windowBackground, border: OutlineInputBorder(borderSide: BorderSide.none))),
                  const SizedBox(height: 12),
                  TextField(controller: _descCtrl, style: TextStyle(color: AppColors.panelTextPrimary), decoration: InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: AppColors.panelTextSecondary), filled: true, fillColor: AppColors.windowBackground, border: OutlineInputBorder(borderSide: BorderSide.none))),
                  
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Color:', style: TextStyle(color: AppColors.panelTextSecondary)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                GlobalPickerState.instance.requestColor(
                                  initialColor: _selectedColor ?? AppColors.accent,
                                  onColorSelected: (c) => setState(() => _selectedColor = c)
                                );
                                showColorPickerWindow(context);
                              },
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.windowBackground,
                                  borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 20, height: 20,
                                      decoration: BoxDecoration(
                                        color: _selectedColor ?? Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.panelTextSecondary)
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(_selectedColor == null ? 'None' : 'Selected', style: TextStyle(color: AppColors.panelTextPrimary)),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Icon:', style: TextStyle(color: AppColors.panelTextSecondary)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                GlobalPickerState.instance.requestIcon(
                                  initialIcon: _selectedIcon,
                                  onIconSelected: (ic) => setState(() => _selectedIcon = ic)
                                );
                                showIconPickerWindow(context);
                              },
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.windowBackground,
                                  borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(_selectedIcon ?? Icons.block, color: AppColors.panelTextPrimary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(_selectedIcon == null ? 'None' : 'Selected', style: TextStyle(color: AppColors.panelTextPrimary)),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      )
                    ],
                  ),

                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _showWorkspaceEditor = false),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey),
                        child: Text('Cancel')
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.panelTextPrimary),
                        onPressed: () {
                          if (_idCtrl.text.isEmpty || _nameCtrl.text.isEmpty) return;
                          setState(() {
                            final newDef = WorkspaceDefinition(
                              id: _idCtrl.text,
                              name: _nameCtrl.text,
                              shortLabel: _shortCtrl.text,
                              icon: _selectedIcon ?? Icons.extension,
                              color: _selectedColor ?? AppColors.accent,
                              description: _descCtrl.text,
                              requiresConfig: _editingWorkspaceTarget?.requiresConfig ?? false,
                              mappedMode: _editingWorkspaceTarget?.mappedMode,
                            );
                            if (_editingWorkspaceTarget != null) {
                              final idx = AppWorkspaces.available.indexWhere((e) => e.id == _editingWorkspaceTarget!.id);
                              if (idx >= 0) {
                                AppWorkspaces.available[idx] = newDef;
                              } else {
                                AppWorkspaces.available.add(newDef);
                              }
                            } else {
                              AppWorkspaces.available.add(newDef);
                            }
                            _showWorkspaceEditor = false;
                          });
                          AppWorkspaces.saveCustom().then((_) => VisualEditorScreen.configRefreshNotifier.value++);
                          widget.onWorkspacesChanged();
                        }, 
                        child: Text('Save')
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainContent = Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 16, bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CUSTOM VIEWPORTS / WORKSPACES', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ElevatedButton.icon(
                icon: Icon(Icons.add, color: AppColors.panelTextPrimary),
                label: Text('Add Workspace', style: TextStyle(color: AppColors.panelTextPrimary)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: () => _showEditWorkspace(null),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView(key: const PageStorageKey('config_tab_7'),
            padding: const EdgeInsets.only(right: 16),
            buildDefaultDragHandles: false,
            proxyDecorator: (Widget child, int index, Animation<double> animation) {
              return Material(
                color: AppColors.controlBorder,
                elevation: 4.0,
                child: child,
              );
            },
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                final item = AppWorkspaces.available.removeAt(oldIndex);
                AppWorkspaces.available.insert(newIndex, item);
              });
              AppWorkspaces.saveCustom().then((_) => VisualEditorScreen.configRefreshNotifier.value++);
              widget.onWorkspacesChanged();
            },
            children: AppWorkspaces.available.asMap().entries.map((entry) {
              final idx = entry.key;
              final w = entry.value;
              return ListTile(
                key: ValueKey(w.id),
                leading: Icon(w.icon, color: w.color),
                title: Text(w.name.toUpperCase(), style: TextStyle(color: AppColors.panelTextPrimary)),
                subtitle: Text(w.description, style: TextStyle(color: AppColors.panelTextSecondary)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () {
                        setState(() {
                          AppWorkspaces.available.removeWhere((e) => e.id == w.id);
                        });
                        AppWorkspaces.saveCustom().then((_) => VisualEditorScreen.configRefreshNotifier.value++);
                        widget.onWorkspacesChanged();
                      },
                    ),
                    ReorderableDragStartListener(
                      index: idx,
                      child: Icon(Icons.drag_handle, color: AppColors.panelTextSecondary),
                    ),
                  ],
                ),
                onTap: () => _showEditWorkspace(w),
              );
            }).toList(),
          ),
        ),
        _buildGlobalActionIconsConfig(),
      ],
    );

    return Stack(
      children: [
        mainContent,
        if (_showWorkspaceEditor)
          _buildWorkspaceEditor(),
      ],
    );
  }





  Widget _buildGlobalActionConfig(String label, IconData defaultIcon, IconData? currentIcon, Color defaultColor, Color? currentColor, Function(IconData?) onIconChanged, Function(Color?) onColorChanged) {
      final actualIcon = currentIcon ?? defaultIcon;
      final actualColor = currentColor ?? defaultColor;
      return Column(
          children: [
              Text(label, style: TextStyle(color: Colors.white, fontSize: AppUIConfig.smallFontSize)),
              const SizedBox(height: 8),
              Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Tooltip(
                     message: 'Change Icon',
                     child: InkWell(
                        onTap: () {
                          GlobalPickerState.instance.requestIcon(
  initialIcon: null,
  onIconSelected: (ic) {
                                if (ic != null) onIconChanged(ic);
                              },
);
showIconPickerWindow(context);
                        },
                        child: Container(
                           width: 40, height: 40,
                           decoration: BoxDecoration(
                               color: AppColors.panelBackground,
                               borderRadius: BorderRadius.only(topLeft: Radius.circular(AppUIConfig.windowBorderRadius), bottomLeft: Radius.circular(AppUIConfig.windowBorderRadius)),
                               border: Border.all(color: AppColors.controlBorder)
                           ),
                           child: Icon(actualIcon, color: actualColor, size: 20),
                        )
                     )
                   ),
                   Tooltip(
                     message: 'Change Color',
                     child: InkWell(
                        onTap: () {
                          GlobalPickerState.instance.requestColor(
  initialColor: actualColor,
  onColorSelected: (cc) {
                                onColorChanged(cc);
                              },
);
showColorPickerWindow(context);
                        },
                        child: Container(
                           width: 40, height: 40,
                           decoration: BoxDecoration(
                               color: AppColors.panelBackground,
                               borderRadius: BorderRadius.only(topRight: Radius.circular(AppUIConfig.windowBorderRadius), bottomRight: Radius.circular(AppUIConfig.windowBorderRadius)),
                               border: Border(top: BorderSide(color: AppColors.controlBorder), right: BorderSide(color: AppColors.controlBorder), bottom: BorderSide(color: AppColors.controlBorder))
                           ),
                           child: Center(
                               child: Container(
                                  width: 20, height: 20,
                                  decoration: BoxDecoration(color: actualColor, shape: BoxShape.circle)
                               )
                           )
                        )
                     )
                   ),
                 ]
              )
          ]
      );
  }

  Future<void> _saveGlobalConfig(String prefKey, int? val) async {
      final prefs = await SharedPreferences.getInstance();
      if (val != null) await prefs.setInt(prefKey, val); else await prefs.remove(prefKey);
      VisualEditorScreen.configRefreshNotifier.value++;
  }

  Widget _buildGlobalActionIconsConfig() {
        return Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.background,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GLOBAL ACTION ICONS & TOOLS', style: TextStyle(color: Colors.white, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 24, runSpacing: 16,
                    alignment: WrapAlignment.start,
                    children: [
                      _buildGlobalActionConfig('Config', Icons.settings, AppUIConfig.configIconCodePoint != null ? IconData(AppUIConfig.configIconCodePoint!, fontFamily: 'MaterialIcons') : null, AppColors.accent, AppUIConfig.configIconColor, 
                        (ic) { setState(() => AppUIConfig.configIconCodePoint = ic?.codePoint); _saveGlobalConfig('ve_configIconCodePoint', ic?.codePoint); },
                        (c) { setState(() => AppUIConfig.configIconColor = c); _saveGlobalConfig('ve_configIconColor', c?.value); }),
                      _buildGlobalActionConfig('Bridge', Icons.rocket_launch, AppUIConfig.bridgeIconCodePoint != null ? IconData(AppUIConfig.bridgeIconCodePoint!, fontFamily: 'MaterialIcons') : null, Colors.redAccent, AppUIConfig.bridgeIconColor, 
                        (ic) { setState(() => AppUIConfig.bridgeIconCodePoint = ic?.codePoint); _saveGlobalConfig('ve_bridgeIconCodePoint', ic?.codePoint); },
                        (c) { setState(() => AppUIConfig.bridgeIconColor = c); _saveGlobalConfig('ve_bridgeIconColor', c?.value); }),
                      _buildGlobalActionConfig('Exit', Icons.exit_to_app, AppUIConfig.exitIconCodePoint != null ? IconData(AppUIConfig.exitIconCodePoint!, fontFamily: 'MaterialIcons') : null, AppColors.accent, AppUIConfig.exitIconColor, 
                        (ic) { setState(() => AppUIConfig.exitIconCodePoint = ic?.codePoint); _saveGlobalConfig('ve_exitIconCodePoint', ic?.codePoint); },
                        (c) { setState(() => AppUIConfig.exitIconColor = c); _saveGlobalConfig('ve_exitIconColor', c?.value); }),
                      _buildGlobalActionConfig('Zoom In', Icons.zoom_in, AppUIConfig.zoomInIconCodePoint != null ? IconData(AppUIConfig.zoomInIconCodePoint!, fontFamily: 'MaterialIcons') : null, AppColors.toolbarTextSecondary, AppUIConfig.zoomInIconColor, 
                        (ic) { setState(() => AppUIConfig.zoomInIconCodePoint = ic?.codePoint); _saveGlobalConfig('ve_zoomInIconCodePoint', ic?.codePoint); },
                        (c) { setState(() => AppUIConfig.zoomInIconColor = c); _saveGlobalConfig('ve_zoomInIconColor', c?.value); }),
                      _buildGlobalActionConfig('Zoom Out', Icons.zoom_out, AppUIConfig.zoomOutIconCodePoint != null ? IconData(AppUIConfig.zoomOutIconCodePoint!, fontFamily: 'MaterialIcons') : null, AppColors.toolbarTextSecondary, AppUIConfig.zoomOutIconColor, 
                        (ic) { setState(() => AppUIConfig.zoomOutIconCodePoint = ic?.codePoint); _saveGlobalConfig('ve_zoomOutIconCodePoint', ic?.codePoint); },
                        (c) { setState(() => AppUIConfig.zoomOutIconColor = c); _saveGlobalConfig('ve_zoomOutIconColor', c?.value); }),
                      _buildGlobalActionConfig('Reload', Icons.refresh, AppUIConfig.reloadIconCodePoint != null ? IconData(AppUIConfig.reloadIconCodePoint!, fontFamily: 'MaterialIcons') : null, AppColors.getAdaptiveGreen(AppColors.toolbarBackground), AppUIConfig.reloadIconColor, 
                        (ic) { setState(() => AppUIConfig.reloadIconCodePoint = ic?.codePoint); _saveGlobalConfig('ve_reloadIconCodePoint', ic?.codePoint); },
                        (c) { setState(() => AppUIConfig.reloadIconColor = c); _saveGlobalConfig('ve_reloadIconColor', c?.value); }),
                      _buildGlobalActionConfig('Restart', Icons.restart_alt, AppUIConfig.restartIconCodePoint != null ? IconData(AppUIConfig.restartIconCodePoint!, fontFamily: 'MaterialIcons') : null, AppColors.getAdaptiveAmber(AppColors.toolbarBackground), AppUIConfig.restartIconColor, 
                        (ic) { setState(() => AppUIConfig.restartIconCodePoint = ic?.codePoint); _saveGlobalConfig('ve_restartIconCodePoint', ic?.codePoint); },
                        (c) { setState(() => AppUIConfig.restartIconColor = c); _saveGlobalConfig('ve_restartIconColor', c?.value); }),
                      _buildGlobalActionConfig('Tools', Icons.build, AppUIConfig.toolsIconCodePoint != null ? IconData(AppUIConfig.toolsIconCodePoint!, fontFamily: 'MaterialIcons') : null, AppColors.toolbarTextSecondary, AppUIConfig.toolsIconColor, 
                        (ic) { setState(() => AppUIConfig.toolsIconCodePoint = ic?.codePoint); _saveGlobalConfig('ve_toolsIconCodePoint', ic?.codePoint); },
                        (c) { setState(() => AppUIConfig.toolsIconColor = c); _saveGlobalConfig('ve_toolsIconColor', c?.value); }),
                    ],
                  ),
                ],
              ),
            );
    }

}








