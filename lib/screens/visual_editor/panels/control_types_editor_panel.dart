import 'package:flutter/material.dart';
import '../../../constants.dart';
import '../../../services/control_type_registry.dart';
import '../../../models/control_type_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../state/global_picker_state.dart';
import 'global_color_picker_window.dart';
import 'global_icon_picker_window.dart';

final ValueNotifier<bool> showControlTypesEditorNotifier = ValueNotifier(false);

class ControlTypesEditorWindow extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  final bool isDocked;

  const ControlTypesEditorWindow({
    super.key, 
    required this.onClose,
    this.onFocus,
    this.isDocked = false,
  });

  @override
  State<ControlTypesEditorWindow> createState() => _ControlTypesEditorWindowState();
}

class _ControlTypesEditorWindowState extends State<ControlTypesEditorWindow> {
  bool _showTypeEditor = false;
  CustomControlType? _editingTypeTarget;
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _labelCtrl = TextEditingController();
  final TextEditingController _constraintsCtrl = TextEditingController();
  String? _selectedParentType;
  IconData? _selectedIcon;
  String _errorText = '';
  double _width = 400;
  double _height = 500;
  Offset _offset = const Offset(150, 150);
  final Set<String> _expandedFolders = {};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    ControlTypeRegistry.instance.addListener(_onRegistryChanged);
  }

  @override
  void dispose() {
    ControlTypeRegistry.instance.removeListener(_onRegistryChanged);
    super.dispose();
  }

  void _onRegistryChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _offset = Offset(prefs.getDouble('cte_dx') ?? 150, prefs.getDouble('cte_dy') ?? 150);
        _width = prefs.getDouble('cte_w') ?? 400;
        _height = prefs.getDouble('cte_h') ?? 500;
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('cte_dx', _offset.dx);
    await prefs.setDouble('cte_dy', _offset.dy);
    await prefs.setDouble('cte_w', _width);
    await prefs.setDouble('cte_h', _height);
  }

  void _showAddEditType([CustomControlType? existingType]) {
    setState(() {
      _editingTypeTarget = existingType;
      _idCtrl.text = existingType?.id ?? '';
      _labelCtrl.text = existingType?.label ?? '';
      _constraintsCtrl.text = existingType?.constraintKeys.join(', ') ?? '';
      _selectedParentType = existingType?.parentType;
      _selectedIcon = existingType?.icon ?? Icons.extension;
      _errorText = '';
      _showTypeEditor = true;
    });
  }

  Widget _buildTypeEditor() {
    final existingType = _editingTypeTarget;
    return Positioned.fill(
      child: Container(
        color: AppColors.background.withValues(alpha: 0.8),
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 400,
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
                children: [
                  Text(existingType == null ? 'Add Control Type' : 'Edit Control Type', style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.headerFontSize, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _idCtrl,
                    style: TextStyle(color: AppColors.panelTextPrimary),
                    decoration: InputDecoration(labelText: 'ID (no spaces)', labelStyle: TextStyle(color: AppColors.panelTextSecondary), filled: true, fillColor: AppColors.windowBackground, border: OutlineInputBorder(borderSide: BorderSide.none)),
                    enabled: existingType == null,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _labelCtrl,
                    style: TextStyle(color: AppColors.panelTextPrimary),
                    decoration: InputDecoration(labelText: 'Label', labelStyle: TextStyle(color: AppColors.panelTextSecondary), filled: true, fillColor: AppColors.windowBackground, border: OutlineInputBorder(borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _constraintsCtrl,
                    style: TextStyle(color: AppColors.panelTextPrimary),
                    decoration: InputDecoration(labelText: 'Constraint Keys (comma separated)', labelStyle: TextStyle(color: AppColors.panelTextSecondary), filled: true, fillColor: AppColors.windowBackground, border: OutlineInputBorder(borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedParentType,
                    dropdownColor: AppColors.panelBackground,
                    style: TextStyle(color: AppColors.panelTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'Parent Type (Optional)', 
                      labelStyle: TextStyle(color: AppColors.panelTextSecondary),
                      filled: true,
                      fillColor: AppColors.windowBackground,
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...ControlTypeRegistry.instance.types
                          .where((t) => existingType == null || t.id != existingType.id)
                          .map((t) => DropdownMenuItem<String>(
                        value: t.id,
                        child: Text(t.label),
                      )).toList(),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedParentType = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
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
                  if (_errorText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_errorText, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _showTypeEditor = false),
                        child: Text('Cancel', style: TextStyle(color: AppColors.panelTextSecondary)),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                        onPressed: () {
                          final id = _idCtrl.text.trim();
                          final label = _labelCtrl.text.trim();
                          final constraints = _constraintsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                          
                          if (id.isEmpty) {
                            setState(() => _errorText = 'ID cannot be empty');
                            return;
                          }
                          if (id.contains(' ')) {
                            setState(() => _errorText = 'ID cannot contain spaces');
                            return;
                          }
                          if (label.isEmpty) {
                            setState(() => _errorText = 'Label cannot be empty');
                            return;
                          }
                          if (existingType == null && ControlTypeRegistry.instance.getType(id) != null) {
                            setState(() => _errorText = 'Control Type ID already exists');
                            return;
                          }

                          final newType = CustomControlType(
                            id: id,
                            label: label,
                            icon: _selectedIcon ?? Icons.extension,
                            constraintKeys: constraints,
                            parentType: _selectedParentType,
                          );

                          if (existingType == null) {
                            ControlTypeRegistry.instance.addType(newType);
                          } else {
                            ControlTypeRegistry.instance.updateType(newType);
                          }

                          setState(() => _showTypeEditor = false);
                        },
                        child: Text('Save', style: TextStyle(color: AppColors.panelTextPrimary)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInnerContent() {
    return Stack(
      children: [
        Column(
          children: [
            if (!widget.isDocked)
              GestureDetector(
                onPanUpdate: (details) {
                  setState(() => _offset += details.delta);
                },
                onPanEnd: (_) => _savePreferences(),
                child: Container(
                  height: 32.0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.panelBackground,
                    border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.settings_input_component, size: 16, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Text(AppUIConfig.formatWindowTitle(AppToolWindows.getDef('control_types_editor').name), style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize, fontWeight: AppUIConfig.windowTitleFontWeight, letterSpacing: 1.2)),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.add, size: 16, color: AppColors.panelTextSecondary),
                        onPressed: () => _showAddEditType(),
                        tooltip: 'Add Control Type',
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 16, color: AppColors.panelTextSecondary),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: ControlTypeRegistry.instance.types.where((t) => t.parentType == null).map((root) {
                  final children = ControlTypeRegistry.instance.types.where((t) => t.parentType == root.id).toList();
                  final isExpanded = _expandedFolders.contains(root.id);
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropZoneWidget(
                        key: ValueKey(root.id),
                        type: root,
                        isRoot: true,
                        onReorderAbove: (s, t) => ControlTypeRegistry.instance.reorderType(s, t, true),
                        onReorderBelow: (s, t) => ControlTypeRegistry.instance.reorderType(s, t, false),
                        onReparentInto: (s, t) => ControlTypeRegistry.instance.reparentType(s, t),
                        child: ListTile(
                          onTap: () {
                            if (children.isNotEmpty) {
                              setState(() {
                                if (isExpanded) {
                                  _expandedFolders.remove(root.id);
                                } else {
                                  _expandedFolders.clear();
                                  _expandedFolders.add(root.id);
                                }
                              });
                            }
                          },
                          leading: Icon(root.icon, color: AppColors.accent),
                          title: Text(root.label, style: TextStyle(color: AppColors.panelTextPrimary)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, size: 16, color: AppColors.panelTextSecondary),
                                onPressed: () => _showAddEditType(root),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                                onPressed: () => ControlTypeRegistry.instance.deleteType(root.id),
                              ),
                              if (children.isNotEmpty)
                                IconButton(
                                  icon: Icon(isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, size: 20, color: AppColors.panelTextSecondary),
                                  onPressed: () {
                                      setState(() {
                                        if (isExpanded) {
                                          _expandedFolders.remove(root.id);
                                        } else {
                                          _expandedFolders.clear();
                                          _expandedFolders.add(root.id);
                                        }
                                      });
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (isExpanded && children.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 32.0),
                          child: Column(
                            children: children.map((child) => DropZoneWidget(
                                key: ValueKey(child.id),
                                type: child,
                                isRoot: false,
                                onReorderAbove: (s, t) => ControlTypeRegistry.instance.reorderType(s, t, true),
                                onReorderBelow: (s, t) => ControlTypeRegistry.instance.reorderType(s, t, false),
                                child: ListTile(
                                  leading: Icon(child.icon, color: AppColors.accent, size: 18),
                                  title: Text(child.label, style: TextStyle(color: AppColors.panelTextPrimary)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit, size: 16, color: AppColors.panelTextSecondary),
                                        onPressed: () => _showAddEditType(child),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                                        onPressed: () => ControlTypeRegistry.instance.deleteType(child.id),
                                      ),
                                    ],
                                  ),
                                ),
                              )).toList(),
                          ),
                        ),
                    ],
                  ) as Widget;
                }).toList()..add(
                  DragTarget<String>(
                    onAcceptWithDetails: (details) => ControlTypeRegistry.instance.reparentType(details.data, null),
                    builder: (context, candidateData, rejectedData) => Container(
                      height: 60,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: candidateData.isNotEmpty ? AppColors.accent.withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: candidateData.isNotEmpty ? AppColors.accent.withValues(alpha: 0.5) : Colors.transparent,
                          style: BorderStyle.solid,
                          width: 2,
                        ),
                      ),
                      child: candidateData.isNotEmpty 
                        ? Center(child: Text('Move to Root', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)))
                        : const SizedBox(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
        if (!widget.isDocked)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _width = (_width + details.delta.dx).clamp(300.0, 1200.0);
                  _height = (_height + details.delta.dy).clamp(300.0, 1000.0);
                });
              },
              onPanEnd: (_) => _savePreferences(),
              child: const MouseRegion(
                cursor: SystemMouseCursors.resizeDownRight,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: Icon(Icons.drag_indicator, size: 12, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
        if (_showTypeEditor) _buildTypeEditor(),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    if (widget.isDocked) {
      return Material(
        color: Colors.transparent,
        child: _buildInnerContent(),
      );
    }

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      width: _width,
      height: _height,
      child: Listener(
        onPointerDown: (_) => widget.onFocus?.call(),
        behavior: HitTestBehavior.deferToChild,
        child: Material(
          color: Colors.transparent,
          elevation: 8,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.windowBackground.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
              border: Border.all(color: AppColors.borderSubtle),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 2),
              ]
            ),
            child: _buildInnerContent(),
          ),
        ),
      ),
    );
  }
}

class DropZoneWidget extends StatefulWidget {
  final Widget child;
  final CustomControlType type;
  final bool isRoot;
  final Function(String sourceId, String targetId) onReorderAbove;
  final Function(String sourceId, String targetId) onReorderBelow;
  final Function(String sourceId, String targetId)? onReparentInto;

  const DropZoneWidget({
    super.key,
    required this.child,
    required this.type,
    required this.isRoot,
    required this.onReorderAbove,
    required this.onReorderBelow,
    this.onReparentInto,
  });

  @override
  State<DropZoneWidget> createState() => _DropZoneWidgetState();
}

class _DropZoneWidgetState extends State<DropZoneWidget> {
  int _hoverZone = 0; // 0 = none, 1 = top, 2 = middle, 3 = bottom

  @override
  Widget build(BuildContext context) {
    return Draggable<String>(
      data: widget.type.id,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.panelBackground,
            border: Border.all(color: AppColors.accent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.type.icon, color: AppColors.accent, size: 16),
              const SizedBox(width: 8),
              Text(widget.type.label, style: TextStyle(color: AppColors.panelTextPrimary)),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: widget.child,
      ),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) => details.data != widget.type.id,
        onAcceptWithDetails: (details) {
          if (_hoverZone == 1) {
            widget.onReorderAbove(details.data, widget.type.id);
          } else if (_hoverZone == 2 && widget.onReparentInto != null) {
            widget.onReparentInto!(details.data, widget.type.id);
          } else if (_hoverZone == 3) {
            widget.onReorderBelow(details.data, widget.type.id);
          }
          setState(() => _hoverZone = 0);
        },
        onLeave: (_) => setState(() => _hoverZone = 0),
        onMove: (details) {
          final RenderBox box = context.findRenderObject() as RenderBox;
          final Offset localOffset = box.globalToLocal(details.offset);
          final double y = localOffset.dy;
          final double h = box.size.height;
          
          int newZone = 0;
          if (y < h * 0.25) {
            newZone = 1;
          } else if (y > h * 0.75) {
            newZone = 3;
          } else if (widget.onReparentInto != null) {
            final draggedId = details.data;
            final hasChildren = ControlTypeRegistry.instance.types.any((t) => t.parentType == draggedId);
            if (!hasChildren) {
              newZone = 2;
            } else {
              newZone = y < h * 0.5 ? 1 : 3;
            }
          } else {
            newZone = y < h * 0.5 ? 1 : 3;
          }

          if (_hoverZone != newZone) {
            setState(() => _hoverZone = newZone);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty || rejectedData.isNotEmpty;
          return Stack(
            children: [
              if (isHovering && _hoverZone == 2)
                Positioned.fill(
                  child: Container(color: AppColors.accent.withValues(alpha: 0.2)),
                ),
              widget.child,
              if (isHovering && _hoverZone == 1)
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(height: 2, color: AppColors.accent),
                ),
              if (isHovering && _hoverZone == 3)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(height: 2, color: AppColors.accent),
                ),
            ],
          );
        },
      ),
    );
  }
}

void hideControlTypesEditorWindow() {
  showControlTypesEditorNotifier.value = false;
}

void showControlTypesEditorWindow(BuildContext context) {
  showControlTypesEditorNotifier.value = true;
}
