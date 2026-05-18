import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../../services/ai_bridge_service.dart';
import 'element_registry.dart';
import '../../screens/visual_editor/visual_editor_screen.dart';
import '../../constants.dart';

final ValueNotifier<bool> showUiHelperNotifier = ValueNotifier(false);

void showUiHelperWindow(BuildContext context) {
  if (showUiHelperNotifier.value) return;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showUiHelper'), true));
  showUiHelperNotifier.value = true;
}

void hideUiHelperWindow() {
  showUiHelperNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showUiHelper'), false));
}

class UiInspectorWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  const UiInspectorWindow({super.key, required this.onClose, this.onFocus, this.isDocked = false});

  @override
  State<UiInspectorWindow> createState() => _UiInspectorWindowState();
}

class _UiInspectorWindowState extends State<UiInspectorWindow> {
  double _width = 400;
  double _height = 550;
  bool _isCollapsed = false;
  double _bgOpacity = 0.8;
  Offset _offset = const Offset(250, 250);

  bool _isExpanded = true;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    ElementRegistry.instance.loadNotes();
    VisualEditorScreen.currentWorkspace.addListener(_loadPreferences);
  }

  @override
  void dispose() {
    VisualEditorScreen.currentWorkspace.removeListener(_loadPreferences);
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isExpanded = prefs.getBool(VisualEditorScreen.getPrefKey('ui_helper_expanded')) ?? true;
        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('ui_helper_width')) ?? 400;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('ui_helper_height')) ?? 550;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.8;
        _isCollapsed = prefs.getBool(VisualEditorScreen.getPrefKey('ui_helper_isCollapsed')) ?? false;
        double dx = prefs.getDouble(VisualEditorScreen.getPrefKey('ui_helper_dx')) ?? 250;
        double dy = prefs.getDouble(VisualEditorScreen.getPrefKey('ui_helper_dy')) ?? 250;
        _offset = Offset(dx, dy);
        _prefsLoaded = true;
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(VisualEditorScreen.getPrefKey('ui_helper_expanded'), _isExpanded);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('ui_helper_width'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('ui_helper_height'), _height);
    await prefs.setBool(VisualEditorScreen.getPrefKey('ui_helper_isCollapsed'), _isCollapsed);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('ui_helper_dx'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('ui_helper_dy'), _offset.dy);
  }

  void _activateColorPicker(BuildContext context) async {
     final boundary = VisualEditorScreen.editorScreenKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
     if (boundary == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot capture screen pixels.')));
        return;
     }
     
     // Delay slightly to let the IconButton ripple effect flush to the frame buffer naturally
     await Future.delayed(const Duration(milliseconds: 50));
     
     // Must be wrapped in try/catch or await loop since dirty frames block toImage
     ui.Image? image;
     try {
         image = await boundary.toImage(pixelRatio: 1.0);
     } catch(e) {
         if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Screen buffer dirty. Please try again!')));
         return;
     }

     final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
     if (bytes == null) return;
     if (!context.mounted) return;
     final nonNullImage = image;
     showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        useSafeArea: false,
        builder: (ctx) => _ScreenColorPickerOverlay(image: nonNullImage, bytes: bytes)
     );
  }

    void _showHelperPrompt(String title, String label) {
       final ctrl = TextEditingController();
       showDialog(
           context: context,
           builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.panelBackground,
              title: Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
              content: TextField(
                 controller: ctrl,
                 style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                 autofocus: true,
                 decoration: InputDecoration(
                    hintText: 'Describe what to do...',
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderSubtle)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amberAccent)),
                 )
              ),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text('CANCEL', style: TextStyle(color: AppColors.textSecondary, fontSize: 11))),
                  TextButton(onPressed: () {
                      if (ctrl.text.trim().isNotEmpty) {
                          AiBridgeService.instance.addTask(
                             '$label: ${ctrl.text.trim()}',
                             'Execute: ${ctrl.text.trim()}',
                             notes: 'Initiated from Global UI Helper\nCRITICAL: Once this task is complete, ensure you trigger the global Red Screen Blocker overlay to indicate task completion visually.',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generated Task: $label')));
                          Navigator.pop(ctx);
                      }
                  }, child: const Text('SUBMIT', style: TextStyle(color: Colors.amberAccent, fontSize: 11))),
              ]
           )
       );
    }

  @override
  Widget build(BuildContext context) {
    if (widget.isDocked) return _buildInspectorContent();
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
            child: Transform.scale(
            scale: 1.0,
            alignment: Alignment.topLeft,
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                              color: AppColors.titleBarBackground
                                  .withValues(alpha: _bgOpacity),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(AppUIConfig.windowBorderRadius))),
                          child: Row(
                            children: [
                              Icon(AppToolWindows.getDef('ui_helper').icon,
                                  size: 16, color: AppToolWindows.getDef('ui_helper').color),
                              const SizedBox(width: 8),
                              Text(AppToolWindows.getDef('ui_helper').name.toUpperCase(),
                                  style: TextStyle(
                                      color: AppColors.titleBarTextPrimary,
                                      fontSize: AppUIConfig.windowTitleFontSize,
                                      fontWeight: FontWeight.bold)),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(Icons.close,
                                      size: 18, color: AppColors.textSecondary),
                                  onPressed: widget.onClose,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              ],
                            ),
                          ),
                        ),
                        if (!_isCollapsed)
                          Expanded(child: _buildInspectorContent()),
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

  Widget _buildInspectorContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Tooltip(message: 'Add UI Element', child: IconButton(icon: Icon(Icons.add_box, size: 18, color: AppColors.textSecondary), onPressed: () => _showHelperPrompt('Add UI Element', 'Add Element'), padding: EdgeInsets.zero, constraints: BoxConstraints(), splashRadius: 16)),
              Tooltip(message: 'Connect UI Element ID', child: IconButton(icon: Icon(Icons.link, size: 18, color: AppColors.textSecondary), onPressed: () => _showHelperPrompt('Connect Logic', 'Wire Component'), padding: EdgeInsets.zero, constraints: BoxConstraints(), splashRadius: 16)),
              Tooltip(message: 'Scene Directive', child: IconButton(icon: Icon(Icons.smart_display, size: 18, color: AppColors.textSecondary), onPressed: () => _showHelperPrompt('Modify Active Scene', 'Scene Directive'), padding: EdgeInsets.zero, constraints: BoxConstraints(), splashRadius: 16)),

              ListenableBuilder(
                 listenable: ElementRegistry.instance,
                 builder: (context, _) {
                    final isInspecting = ElementRegistry.instance.isInspecting;
                    return Tooltip(
                       message: isInspecting ? 'Select Component (Active)' : 'Select Component',
                       child: IconButton(
                          icon: Icon(isInspecting ? Icons.gps_fixed : Icons.mouse, size: 18, color: isInspecting ? Colors.amberAccent : AppColors.textSecondary),
                          onPressed: () => ElementRegistry.instance.toggleInspectMode(),
                          padding: EdgeInsets.zero, constraints: const BoxConstraints(), splashRadius: 16
                       )
                    );
                 }
              ),
              ListenableBuilder(
                 listenable: ElementRegistry.instance,
                 builder: (context, _) {
                    final isVisible = ElementRegistry.instance.annotationsVisible;
                    return Tooltip(
                       message: 'Toggle Annotations',
                       child: IconButton(
                          icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off, size: 18, color: isVisible ? Colors.amberAccent : AppColors.textSecondary),
                          onPressed: () => ElementRegistry.instance.toggleAnnotations(),
                          padding: EdgeInsets.zero, constraints: const BoxConstraints(), splashRadius: 16
                       )
                    );
                 }
              ),
              Tooltip(message: 'Color Picker', child: IconButton(icon: const Icon(Icons.colorize, size: 18, color: Colors.amberAccent), onPressed: () => _activateColorPicker(context), padding: EdgeInsets.zero, constraints: const BoxConstraints(), splashRadius: 16)),
              Tooltip(message: 'Config', child: IconButton(icon: Icon(Icons.settings, size: 18, color: AppColors.textSecondary), onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UI Helper Config is fully active.')));
              }, padding: EdgeInsets.zero, constraints: const BoxConstraints(), splashRadius: 16)),
            ]
          )
        ),
        Divider(height: 1, color: AppColors.overlaySubtle),
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: 1, // Wraps listenable properly
            itemBuilder: (context, _) => ListenableBuilder(
              listenable: ElementRegistry.instance,
              builder: (context, _) {
                 List<MapEntry<String, dynamic>> rawElements = ElementRegistry.instance.activeElements.entries.where((e) {
                     final key = ElementRegistry.instance.activeKeys[e.key];
                     if (key?.currentContext == null) return false;
                     final route = ModalRoute.of(key!.currentContext!);
                     return route == null || route.isCurrent;
                 }).toList();
                 
                 if (rawElements.isEmpty) {
                   return Center(
                     child: Padding(
                       padding: EdgeInsets.all(24.0),
                       child: Text(
                         'No Elements Registered.\n\nWrap widgets with RegisteredElement(id: "...") to expose them here deterministically.',
                         textAlign: TextAlign.center,
                         style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
                       ),
                     ),
                   );
                 }
                 
                 final Map<String, Map<String, List<MapEntry<String, dynamic>>>> screenGroups = {};
                 
                 for (final e in rawElements) {
                     final screenStr = (e.value is Map && e.value['screen'] != null) ? e.value['screen'].toString() : 'Global';
                     final typeStr = (e.value is Map && e.value['type'] != null) ? e.value['type'].toString().toLowerCase() : '';
                     final idStr = e.key.toLowerCase();
                     
                     String typeBucket = 'Uncategorized';
                     if (typeStr.contains('btn') || typeStr.contains('button') || idStr.contains('btn') || idStr.contains('button')) {
                       typeBucket = 'Buttons';
                     } else if (typeStr.contains('card') || idStr.contains('card')) typeBucket = 'Cards';
                     else if (typeStr.contains('img') || typeStr.contains('image') || idStr.contains('img') || idStr.contains('image') || typeStr.contains('cover')) typeBucket = 'Images';
                     else if (typeStr.contains('bar') || idStr.contains('bar')) typeBucket = 'Toolbars';
                     else if (typeStr.contains('text') || idStr.contains('text')) typeBucket = 'Text';
                     else if (typeStr.contains('scroll') || typeStr.contains('list') || idStr.contains('list') || idStr.contains('scroll')) typeBucket = 'Scroll Areas';
                     else if (typeStr.contains('icon') || idStr.contains('icon')) typeBucket = 'Icons';
                     
                     if (!screenGroups.containsKey(screenStr)) {
                         screenGroups[screenStr] = {
                             for (final t in ['Buttons', 'Toolbars', 'Cards', 'Images', 'Text', 'Scroll Areas', 'Icons', 'Uncategorized']) t: []
                         };
                     }
                     screenGroups[screenStr]![typeBucket]!.add(e);
                 }
                 
                 final activeScreens = screenGroups.entries.where((s) => s.value.values.any((list) => list.isNotEmpty)).toList();

                 return ListView.builder(
                   shrinkWrap: true,
                   physics: const NeverScrollableScrollPhysics(),
                   itemCount: activeScreens.length,
                   itemBuilder: (context, index) {
                      final screenGroup = activeScreens[index];
                      final activeTypes = screenGroup.value.entries.where((t) => t.value.isNotEmpty).toList();
                      
                      return Theme(
                         data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                         child: ExpansionTile(
                            initiallyExpanded: true,
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -2),
                            iconColor: Colors.purpleAccent,
                            collapsedIconColor: Colors.purpleAccent.withValues(alpha: 0.5),
                            title: Text('SCREEN: ${screenGroup.key.toUpperCase()}', style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0)),
                            children: activeTypes.map((group) {
                               return ExpansionTile(
                                  initiallyExpanded: true,
                                  dense: true,
                                  visualDensity: const VisualDensity(vertical: -2),
                                  iconColor: Colors.amberAccent,
                                  collapsedIconColor: AppColors.textSecondary,
                                  title: Text('${group.key.toUpperCase()} (${group.value.length})', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0)),
                                  children: group.value.map((item) => _buildElementTile(context, item)).toList()
                               );
                            }).toList()
                          )
                       );
                   },
                 );
               },
             )
          )
        )
      ]
    );
  }

  Widget _buildElementTile(BuildContext context, MapEntry<String, dynamic> item) {
      final isHovered = ElementRegistry.instance.hoveredId == item.key;
      final isSelected = ElementRegistry.instance.selectedId == item.key;

      return Container(
         decoration: BoxDecoration(
            color: isSelected ? AppColors.accent.withOpacity(0.2) : (isHovered ? Colors.amberAccent.withOpacity(0.2) : null),
            border: Border(bottom: BorderSide(color: AppColors.overlaySubtle))
         ),
       child: MouseRegion(
         onEnter: (_) {
            ElementRegistry.instance.setHover(item.key);
         },
         onExit: (_) {
            if (ElementRegistry.instance.hoveredId == item.key) {
               ElementRegistry.instance.setHover(null);
            }
         },
         child: ExpansionTile(
            dense: true,
            visualDensity: const VisualDensity(vertical: -4),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            iconColor: AppColors.textSecondary,
            collapsedIconColor: AppColors.borderSubtle,
            title: Row(
               children: [
                  Icon(Icons.tag, size: 14, color: isHovered ? Colors.amberAccent : AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item.key, style: TextStyle(color: isHovered || isSelected ? AppColors.textPrimary : AppColors.textSecondary, fontSize: 13, fontWeight: isHovered || isSelected ? FontWeight.bold : FontWeight.normal))),
               ]
            ),
            children: [
                Container(
                   width: double.infinity,
                   color: const Color(0xFF2D2D30),
                   padding: const EdgeInsets.all(12),
                   child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         _LiveElementDetails(itemKey: item.key, initialMeta: item.value),
                         Text('AI Directives:', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                         const SizedBox(height: 8),
                         Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                               _buildDirectiveBtn(context, item.key, item.value, 'Not working right', 'Fix logic/interaction for ${item.key}.'),
                               _buildDirectiveBtn(context, item.key, item.value, 'Delete element', 'Remove element ${item.key}.'),
                               _buildDirectiveBtn(context, item.key, item.value, 'Connect UI Element ID', 'Connect or map ${item.key} to another functional component.'),
                               _buildDirectiveBtn(context, item.key, item.value, 'Change how it looks', 'Edit styling/layout for ${item.key}.'),
                               _buildDirectiveBtn(context, item.key, item.value, 'Change how it works', 'Refactor behavior for ${item.key}.'),
                               _buildDirectiveBtn(context, item.key, item.value, 'Animate element', 'Add animation or transition effects to ${item.key}.'),
                               _buildDirectiveBtn(context, item.key, item.value, 'Localize text', 'Extract and localize hardcoded text in ${item.key}.'),
                               _buildDirectiveBtn(context, item.key, item.value, 'Connect to backend data', 'Bind ${item.key} to real backend data source.'),
                            ]
                         )
                      ]
                   )
                )
            ]
         )
      ));
  }

  Widget _buildDirectiveBtn(BuildContext context, String key, dynamic meta, String label, String taskDescription) {
     return InkWell(
        onTap: () {
            AiBridgeService.instance.addTask(
               '$label: $key',
               taskDescription,
               notes: 'Meta attributes: ${meta.toString()}\nCRITICAL: Once this task is complete, ensure you trigger the global Red Screen Blocker overlay to indicate task completion visually.',
            );
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generated Task: $label')));
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
           decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.accent.withOpacity(0.3))
           ),
           child: Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w500)),
        )
     );
  }
}

class _LiveElementDetails extends StatefulWidget {
   final String itemKey;
   final dynamic initialMeta;
   
   const _LiveElementDetails({required this.itemKey, required this.initialMeta});
   
   @override
   _LiveElementDetailsState createState() => _LiveElementDetailsState();
}

class _LiveElementDetailsState extends State<_LiveElementDetails> {
   Map<String, dynamic> activeMeta = {};
   String? text;
   String? font;
   double? fontSize;
   Color? color;
   IconData? icon;
   late TextEditingController _noteCtrl;

   @override
   void initState() {
      super.initState();
      _noteCtrl = TextEditingController(text: ElementRegistry.instance.getNoteData(widget.itemKey)?['note'] ?? '');
      _fetchData();
   }

   @override
   void didUpdateWidget(_LiveElementDetails oldWidget) {
      super.didUpdateWidget(oldWidget);
      if (oldWidget.itemKey != widget.itemKey) {
         _noteCtrl.text = ElementRegistry.instance.getNoteData(widget.itemKey)?['note'] ?? '';
         _fetchData();
      }
   }

   void _fetchData() {
      activeMeta = Map.from(widget.initialMeta is Map ? widget.initialMeta : {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (!mounted) return;
         final key = ElementRegistry.instance.activeKeys[widget.itemKey];
         if (key != null && key.currentContext != null) {
            final ro = key.currentContext!.findRenderObject();
            if (ro is RenderBox && ro.hasSize) {
               final pos = ro.localToGlobal(Offset.zero);
               activeMeta['x'] = pos.dx.toStringAsFixed(1);
               activeMeta['y'] = pos.dy.toStringAsFixed(1);
               activeMeta['width'] = ro.size.width.toStringAsFixed(1);
               activeMeta['height'] = ro.size.height.toStringAsFixed(1);
            }
            
            void walk(Element element) {
               final w = element.widget;
               if (w is Text) {
                  text ??= w.data;
                  font ??= w.style?.fontFamily;
                  fontSize ??= w.style?.fontSize;
                  color ??= w.style?.color;
               } else if (w is Icon) {
                  icon ??= w.icon;
                  color ??= w.color;
                  fontSize ??= w.size;
               }
               element.visitChildElements(walk);
            }
            key.currentContext!.visitChildElements(walk);
            
            if (text != null) activeMeta['Text'] = text;
            if (font != null) activeMeta['Font'] = font;
            if (fontSize != null) activeMeta['FontSize'] = fontSize;
            if (mounted) setState(() {});
         }
      });
   }
   
   Widget _labeledRow(String label, Widget content) {
       return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                SizedBox(width: 110, child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                Expanded(child: content),
             ]
          )
       );
   }

   @override
   Widget build(BuildContext context) {
       if (activeMeta.isNotEmpty) {
          final String? hexColor = color != null ? '#${color!.value.toRadixString(16).padLeft(8, '0').toUpperCase()}' : null;
          
          return Stack(
             children: [
              Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    _labeledRow('ID:', Text(widget.itemKey, style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold))),
                    if (activeMeta['type'] != null) _labeledRow('Type of control:', Text('${activeMeta['type']}', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold))),
                    if (activeMeta['x'] != null) _labeledRow('Geometry:', Text('x: ${activeMeta['x']}, y: ${activeMeta['y']}, w: ${activeMeta['width']}, h: ${activeMeta['height']}', style: TextStyle(color: AppColors.textPrimary, fontSize: 12))),
                    if (activeMeta['Font'] != null || activeMeta['FontSize'] != null || color != null || activeMeta['Text'] != null || icon != null) ...[
                       const SizedBox(height: 8),
                       const Text('Control Specific Information:', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 6),
                    ],
                    if (activeMeta['Font'] != null) _labeledRow('Font:', Text('${activeMeta['Font']}', style: TextStyle(color: AppColors.textPrimary, fontSize: 12))),
                    if (activeMeta['FontSize'] != null) _labeledRow('Font Size:', Text('${activeMeta['FontSize']}', style: TextStyle(color: AppColors.textPrimary, fontSize: 12))),
                    if (activeMeta['Text'] != null) _labeledRow('Text:', Text('${activeMeta['Text']}', style: TextStyle(color: AppColors.textPrimary, fontSize: 12))),
                    const SizedBox(height: 12),
                    Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                          const Text('Annotation Notes:', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          Row(
                             children: [...['FFFFAB40', 'FFFF5252', 'FF69F0AE', 'FF448AFF'].map((h) {
                                final c = Color(int.parse(h, radix: 16));
                                final isActive = (ElementRegistry.instance.getNoteData(widget.itemKey)?['color'] ?? 'FFFFAB40') == h;
                                return InkWell(
                                   onTap: () {
                                      if (_noteCtrl.text.isNotEmpty) ElementRegistry.instance.setNote(widget.itemKey, _noteCtrl.text, colorHex: h);
                                      setState(() {});
                                   },
                                   child: Container(
                                      width: 14, height: 14, margin: const EdgeInsets.only(left: 6),
                                      decoration: BoxDecoration(color: c, border: isActive ? Border.all(color: AppColors.textPrimary, width: 2) : null, shape: BoxShape.circle)
                                   )
                                );
                             })]
                          )
                       ]
                    ),
                    const SizedBox(height: 6),
                    TextField(
                       controller: _noteCtrl,
                       style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                       maxLines: null,
                       decoration: InputDecoration(
                          hintText: 'Add an editable note here to annotate this element...',
                          hintStyle: TextStyle(color: AppColors.textSecondary),
                          isDense: true,
                          contentPadding: EdgeInsets.all(8),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.borderSubtle)),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amberAccent)),
                       ),
                       onChanged: (val) {
                          ElementRegistry.instance.setNote(widget.itemKey, val);
                       },
                    ),
                    const SizedBox(height: 12),
                 ]
              ),
              if (icon != null || color != null)
                 Positioned(
                    top: 0,
                    right: 0,
                    child: Row(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          if (color != null)
                             Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: InkWell(
                                   onTap: () {
                                      if (hexColor != null) {
                                         Clipboard.setData(ClipboardData(text: hexColor));
                                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied color $hexColor to clipboard'), duration: const Duration(seconds: 1)));
                                      }
                                   },
                                   child: Column(
                                      children: [
                                         Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                               color: color,
                                               border: Border.all(color: AppColors.textSecondary, width: 2),
                                               borderRadius: BorderRadius.circular(6)
                                            )
                                         ),
                                         const SizedBox(height: 4),
                                         Text(hexColor ?? '', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 0.5))
                                      ]
                                   )
                                )
                             ),
                          if (icon != null)
                             Column(
                                children: [
                                   Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                         color: Colors.black26,
                                         border: Border.all(color: AppColors.textSecondary, width: 2),
                                         borderRadius: BorderRadius.circular(6)
                                      ),
                                      child: Center(child: Icon(icon, size: 28, color: color ?? AppColors.textPrimary)),
                                   ),
                                   const SizedBox(height: 4),
                                   SizedBox(
                                      width: 60, 
                                      child: Text(icon.toString(), style: TextStyle(color: AppColors.textSecondary, fontSize: 9), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)
                                   )
                                ]
                             )
                       ]
                    )
                 )
             ]
          );
       } else {
          return Text('Meta: ${widget.initialMeta.toString()}', style: TextStyle(color: AppColors.textSecondary, fontSize: 12));
       }
   }
}

class _ScreenColorPickerOverlay extends StatefulWidget {
  final ui.Image image;
  final ByteData bytes;
  const _ScreenColorPickerOverlay({required this.image, required this.bytes});
  
  @override
  _ScreenColorPickerOverlayState createState() => _ScreenColorPickerOverlayState();
}

class _ScreenColorPickerOverlayState extends State<_ScreenColorPickerOverlay> {
  Offset? _pointerPos;
  Color? _hoveredColor;
  
  void _updateColor(Offset local) {
      int w = widget.image.width;
      int h = widget.image.height;
      if (local.dx < 0 || local.dy < 0 || local.dx >= w || local.dy >= h) return;
      int x = local.dx.toInt();
      int y = local.dy.toInt();
      int byteOffset = (y * w + x) * 4;
      if (byteOffset + 3 < widget.bytes.lengthInBytes) {
          int r = widget.bytes.getUint8(byteOffset);
          int g = widget.bytes.getUint8(byteOffset + 1);
          int b = widget.bytes.getUint8(byteOffset + 2);
          int a = widget.bytes.getUint8(byteOffset + 3);
          
          setState(() {
             _hoveredColor = Color.fromARGB(a, r, g, b);
          });
      }
  }

  @override
  Widget build(BuildContext context) {
      return Scaffold(
         backgroundColor: Colors.transparent,
         body: Stack(
            children: [
               Positioned.fill(
                  child: MouseRegion(
                     cursor: SystemMouseCursors.precise,
                     onHover: (e) {
                         setState(() => _pointerPos = e.localPosition);
                         _updateColor(e.localPosition);
                     },
                     child: GestureDetector(
                        onTap: () {
                           if (_hoveredColor != null) {
                               final hex = '#${_hoveredColor!.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
                               Clipboard.setData(ClipboardData(text: hex));
                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied crosshair color $hex to clipboard')));
                           }
                           Navigator.pop(context);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(color: Colors.transparent)
                     )
                  )
               ),
               if (_pointerPos != null && _hoveredColor != null)
                 Positioned(
                    left: _pointerPos!.dx - 50,
                    top: _pointerPos!.dy - 50,
                    child: IgnorePointer(
                       child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                             shape: BoxShape.circle,
                             border: Border.all(color: AppColors.textPrimary, width: 2),
                             boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]
                          ),
                          child: ClipOval(
                             child: Stack(
                                children: [
                                   Positioned.fill(
                                      child: CustomPaint(
                                         painter: _ZoomMagnifierPainter(
                                            image: widget.image,
                                            pointerPos: _pointerPos!
                                         )
                                      )
                                   ),
                                   Center(
                                      child: Icon(Icons.add, size: 24, color: (_hoveredColor!.computeLuminance() > 0.5) ? Colors.black87 : AppColors.textPrimary)
                                   )
                                ]
                             )
                          )
                       )
                    )
                 )
            ]
         )
      );
  }
}

class _ZoomMagnifierPainter extends CustomPainter {
   final ui.Image image;
   final Offset pointerPos;

   _ZoomMagnifierPainter({required this.image, required this.pointerPos});

   @override
   void paint(Canvas canvas, Size size) {
      final double outRadius = size.width / 2;
      final Offset center = Offset(outRadius, outRadius);
      const double zoomSpeed = 4.0;
      
      double srcSide = (outRadius * 2) / zoomSpeed;
      Rect srcRect = Rect.fromCenter(center: pointerPos, width: srcSide, height: srcSide);
      Rect dstRect = Rect.fromCenter(center: center, width: outRadius * 2, height: outRadius * 2);
      
      canvas.drawRect(dstRect, Paint()..color = Colors.black);
      canvas.drawImageRect(image, srcRect, dstRect, Paint()..isAntiAlias = false..filterQuality = FilterQuality.none);
   }

   @override
   bool shouldRepaint(covariant _ZoomMagnifierPainter oldDelegate) {
      return oldDelegate.pointerPos != pointerPos;
   }
}
