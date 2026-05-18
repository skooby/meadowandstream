import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../constants.dart';
import '../../../utils/icon_library.dart';
import '../visual_editor_screen.dart';
import '../../../state/global_picker_state.dart';

final ValueNotifier<bool> showIconPickerNotifier = ValueNotifier(false);

void showIconPickerWindow(BuildContext context) {
  if (showIconPickerNotifier.value) return;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showIconPicker'), true));
  showIconPickerNotifier.value = true;
}

void hideIconPickerWindow() {
  showIconPickerNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showIconPicker'), false));
}

class GlobalIconPickerWindow extends StatefulWidget {
  final VoidCallback onClose;
  final bool isDocked;
  final VoidCallback? onFocus;

  const GlobalIconPickerWindow({
    super.key,
    required this.onClose,
    this.isDocked = false,
    this.onFocus,
  });

  @override
  State<GlobalIconPickerWindow> createState() => _GlobalIconPickerWindowState();
}

class _GlobalIconPickerWindowState extends State<GlobalIconPickerWindow> {
  bool _isLoaded = false;
  double _width = 350;
  double _height = 450;
  double _bgOpacity = 0.4;
  Offset _offset = const Offset(350, 300);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  IconData? _currentIcon;

  static const Map<String, List<String>> _iconTags = {
    'rocket_launch': ['task manager', 'space', 'ship', 'fast'],
    'rocket': ['task manager', 'space', 'ship', 'fast'],
    'emoji_emotions': ['smile', 'face', 'happy'],
    'folder': ['directory', 'files', 'group'],
    'folder_open': ['directory', 'files', 'group'],
    'settings': ['config', 'options', 'preferences'],
    'check_circle': ['done', 'success', 'complete'],
    'cancel': ['close', 'error', 'stop', 'remove'],
  };

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _loadPreferences();
    VisualEditorScreen.currentWorkspace.addListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.addListener(_loadPreferences);
    VisualEditorScreen.activeWindowNotifier.addListener(_onActiveWindowChanged);
    GlobalPickerState.instance.activeIconRequest.addListener(_onRequestChanged);
    if (GlobalPickerState.instance.activeIconRequest.value != null) {
      _currentIcon = GlobalPickerState.instance.activeIconRequest.value!.initialIcon;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    VisualEditorScreen.currentWorkspace.removeListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.removeListener(_loadPreferences);
    GlobalPickerState.instance.activeIconRequest.removeListener(_onRequestChanged);
    VisualEditorScreen.activeWindowNotifier.removeListener(_onActiveWindowChanged);
    super.dispose();
  }

  void _onActiveWindowChanged() {
    if (mounted) setState(() {});
  }

  void _onRequestChanged() {
    final req = GlobalPickerState.instance.activeIconRequest.value;
    if (req != null) {
      setState(() {
        _currentIcon = req.initialIcon;
      });
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isLoaded = true;
        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('icon_picker_width')) ?? 350;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('icon_picker_height')) ?? 450;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.4;
        double dx = prefs.getDouble(VisualEditorScreen.getPrefKey('icon_picker_dx')) ?? 350;
        double dy = prefs.getDouble(VisualEditorScreen.getPrefKey('icon_picker_dy')) ?? 300;
        _offset = Offset(dx, dy);
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('icon_picker_width'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('icon_picker_height'), _height);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('icon_picker_dx'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('icon_picker_dy'), _offset.dy);
  }

  Widget _buildContent() {
    String? currentIconName;
    if (_currentIcon != null) {
      currentIconName = IconLibrary.allIcons.entries.where((e) => e.value == _currentIcon).map((e) => e.key).firstOrNull;
      if (currentIconName == null) currentIconName = 'Custom Icon';
    }

    return Container(
      color: AppColors.panelBackground,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize),
              decoration: InputDecoration(
                hintText: 'Search icons...',
                hintStyle: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
                prefixIcon: Icon(Icons.search, color: AppColors.panelTextSecondary, size: 16),
                filled: true,
                fillColor: AppColors.windowBackground,
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(4),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          if (_currentIcon != null)
            Padding(
              padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 8.0),
              child: Row(
                children: [
                  Text('Current:', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.smallFontSize)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.accent),
                    ),
                    child: Icon(_currentIcon, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentIconName ?? '',
                      style: TextStyle(color: AppColors.accent, fontSize: AppUIConfig.smallFontSize, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _searchQuery.isEmpty ? _buildCategorizedList() : _buildSearchResults(),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              final req = GlobalPickerState.instance.activeIconRequest.value;
              if (req != null) {
                req.onIconSelected(null);
              }
            },
            icon: Icon(Icons.block, size: 16, color: AppColors.titleBarTextSecondary),
            label: Text('Clear Icon', style: TextStyle(color: AppColors.titleBarTextSecondary)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String name, Map<String, IconData> icons) {
     switch(name) {
      case 'Action': return Icons.touch_app;
      case 'Alert': return Icons.warning;
      case 'AV': return Icons.audiotrack;
      case 'Communication': return Icons.chat;
      case 'Content': return Icons.article;
      case 'Device': return Icons.devices;
      case 'Editor': return Icons.edit;
      case 'File': return Icons.folder;
      case 'Hardware': return Icons.memory;
      case 'Image': return Icons.image;
      case 'Maps': return Icons.map;
      case 'Navigation': return Icons.navigation;
      case 'Notification': return Icons.notifications;
      case 'Places': return Icons.place;
      case 'Social': return Icons.people;
      case 'Toggle': return Icons.toggle_on;
      default: return icons.values.isNotEmpty ? icons.values.first : Icons.category;
    }
  }

  Widget _buildCategorizedList() {
    return DefaultTabController(
      length: IconLibrary.categories.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.panelTextSecondary,
            indicatorColor: AppColors.accent,
            tabs: IconLibrary.categories.map((c) => Tab(
               child: Tooltip(
                 message: c.name,
                 child: Icon(_getCategoryIcon(c.name, c.icons), size: 15),
               )
            )).toList(),
          ),
          Expanded(
            child: TabBarView(
              children: IconLibrary.categories.map((c) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: _buildIconGrid(c.icons),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final Map<String, IconData> filtered = {};
    IconLibrary.allIcons.forEach((key, value) {
      bool matches = key.replaceAll('_', ' ').toLowerCase().contains(_searchQuery);
      if (!matches) {
         final tags = _iconTags[key];
         if (tags != null && tags.any((t) => t.contains(_searchQuery))) {
            matches = true;
         }
      }
      if (matches) {
        filtered[key] = value;
      }
    });

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No icons found',
          style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: _buildIconGrid(filtered),
    );
  }

  Widget _buildIconGrid(Map<String, IconData> icons) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: icons.entries.map((e) {
        final isSelected = _currentIcon == e.value;
        return Tooltip(
          message: e.key,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _currentIcon = e.value;
              });
              final req = GlobalPickerState.instance.activeIconRequest.value;
              if (req != null) {
                req.onIconSelected(e.value);
              }
            },
            child: Container(
              width: 27 * (AppUIConfig.rootFontSize / 12),
              height: 27 * (AppUIConfig.rootFontSize / 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent.withOpacity(0.2) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.accent : AppColors.borderSubtle,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Icon(
                  e.value,
                  size: 15 * (AppUIConfig.rootFontSize / 12),
                  color: isSelected ? Colors.white : AppColors.panelTextPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
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
          return Transform.scale(scale: scale, alignment: Alignment.topLeft,
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
                    width: _width / scale,
                    height: _height / scale,
                    clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'icon_picker' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) : null,
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
                          height: AppUIConfig.titleBarHeight / scale,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                              color: AppColors.titleBarBackground.withValues(alpha: _bgOpacity),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(AppUIConfig.windowBorderRadius))),
                          child: Row(
                            children: [
                              Icon(Icons.emoji_emotions,
                                  size: 16 / scale, color: AppToolWindows.getDef('icon_picker')?.color ?? AppColors.accent),
                              const SizedBox(width: 8),
                              Text(AppUIConfig.formatWindowTitle('Icon Picker'), style: TextStyle(
                                      color: AppColors.titleBarTextPrimary,
                                      fontSize: AppUIConfig.windowTitleFontSize / scale,
                                      fontWeight: AppUIConfig.windowTitleFontWeight)),
                              const Spacer(),
                              IconButton(
                                icon: Icon(Icons.close,
                                    size: 18 / scale, color: AppColors.titleBarTextSecondary),
                                onPressed: widget.onClose,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              )
                            ],
                          ),
                        ),
                      ),
                      Expanded(child: _buildContent()),
                    ])
                  ),
                ),
              ),
                rz(t: 0, l: 12, r: 12, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){
                    double nH = _height - (d.delta.dy * scale);
                    if (nH >= 300 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy * scale); }
                })),
                rz(b: 0, l: 12, r: 12, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){
                    double nH = _height + (d.delta.dy * scale);
                    if (nH >= 300 && nH <= 1200) { _height = nH; }
                })),
                rz(l: 0, t: 12, b: 12, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){
                    double nW = _width - (d.delta.dx * scale);
                    if (nW >= 300 && nW <= 1600) { _width = nW; _offset += Offset(d.delta.dx * scale, 0); }
                })),
                rz(r: 0, t: 12, b: 12, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){
                    double nW = _width + (d.delta.dx * scale);
                    if (nW >= 300 && nW <= 1600) { _width = nW; }
                })),
                rz(t: 0, l: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){
                    double nW = _width - (d.delta.dx * scale); double nH = _height - (d.delta.dy * scale);
                    if (nW >= 300 && nW <= 1600) { _width = nW; _offset += Offset(d.delta.dx * scale, 0); }
                    if (nH >= 300 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy * scale); }
                })),
                rz(t: 0, r: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (d) => setState((){
                    double nW = _width + (d.delta.dx * scale); double nH = _height - (d.delta.dy * scale);
                    if (nW >= 300 && nW <= 1600) { _width = nW; }
                    if (nH >= 300 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy * scale); }
                })),
                rz(b: 0, l: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (d) => setState((){
                    double nW = _width - (d.delta.dx * scale); double nH = _height + (d.delta.dy * scale);
                    if (nW >= 300 && nW <= 1600) { _width = nW; _offset += Offset(d.delta.dx * scale, 0); }
                    if (nH >= 300 && nH <= 1200) { _height = nH; }
                })),
                rz(b: 0, r: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){
                    double nW = _width + (d.delta.dx * scale); double nH = _height + (d.delta.dy * scale);
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
