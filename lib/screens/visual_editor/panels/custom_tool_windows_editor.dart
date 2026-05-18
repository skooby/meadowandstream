import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import '../../../constants.dart';
import '../visual_editor_screen.dart';
import '../../../services/ai_bridge_service.dart';
import '../../../state/global_picker_state.dart';
import 'global_color_picker_window.dart';
import 'global_icon_picker_window.dart';
class CustomToolWindowsEditor extends StatefulWidget {
  final Map<String, List<String>> windowAvailability;
  final Future<void> Function(String windowId, dynamic workspaceId) onAvailabilityChanged;
  final VoidCallback onToolWindowsChanged;

  const CustomToolWindowsEditor({
    super.key,
    required this.windowAvailability,
    required this.onAvailabilityChanged,
    required this.onToolWindowsChanged,
  });

  @override
  State<CustomToolWindowsEditor> createState() => _CustomToolWindowsEditorState();
}
class _CustomToolWindowsEditorState extends State<CustomToolWindowsEditor> {

  bool _showToolWindowEditor = false;
  ToolWindowDefinition? _editingWindowTarget;
  final _formKey = GlobalKey<FormBuilderState>();
  Color? _selectedColor;
  IconData? _selectedIcon;
  List<String> _currentAvail = [];

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.accent),
      labelStyle: TextStyle(color: AppColors.panelTextSecondary),
      filled: true,
      fillColor: AppColors.panelBackground,
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

  void _showEditWindow(ToolWindowDefinition? existing) {
    setState(() {
      _editingWindowTarget = existing;
      _selectedColor = existing?.color ?? AppColors.accent;
      _selectedIcon = existing?.icon ?? Icons.build;
      
      _currentAvail = [];
      if (existing != null) {
         final list = widget.windowAvailability[existing.id];
         if (list != null) {
             _currentAvail = list.where((id) => AppWorkspaces.available.any((w) => w.id == id) || id == 'all' || id == 'none').toList();
         }
      }
      if (_currentAvail.isEmpty) {
          _currentAvail = ['all'];
      }
      
      _showToolWindowEditor = true;
    });
  }

  Widget _buildToolWindowEditor() {
    final existing = _editingWindowTarget;
    final allWorkspaces = AppWorkspaces.available;
    final availItems = [
      FormBuilderChipOption<String>(value: 'none', child: Text('Hide', style: TextStyle(color: AppColors.panelTextPrimary))),
      FormBuilderChipOption<String>(value: 'all', child: Text('All', style: TextStyle(color: AppColors.panelTextPrimary))),
      ...allWorkspaces.map((ws) => FormBuilderChipOption<String>(value: ws.id, child: Text(ws.name, style: TextStyle(color: AppColors.panelTextPrimary)))),
    ];

    return Positioned.fill(
      child: Container(
        color: AppColors.background.withValues(alpha: 0.8),
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.windowBackground,
              borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
              border: Border.all(color: AppColors.controlBorder),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))]
            ),
            child: SingleChildScrollView(
              child: FormBuilder(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(existing == null ? 'Add Tool Window' : 'Edit Tool Window', style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.headerFontSize, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    FormBuilderTextField(
                      name: 'name',
                      initialValue: existing?.name,
                      decoration: _inputDecoration('Window Name', Icons.title),
                      style: TextStyle(color: AppColors.panelTextPrimary),
                    ),
                    const SizedBox(height: 16),
                    FormBuilderTextField(
                      name: 'shortLabel',
                      initialValue: existing?.shortLabel,
                      decoration: _inputDecoration('Short Label', Icons.label),
                      style: TextStyle(color: AppColors.panelTextPrimary),
                    ),
                    const SizedBox(height: 16),
                    FormBuilderTextField(
                      name: 'id',
                      initialValue: existing?.id,
                      decoration: _inputDecoration('Internal ID (Must be unique)', Icons.key),
                      style: TextStyle(color: AppColors.panelTextPrimary),
                      enabled: existing == null,
                    ),
                    const SizedBox(height: 16),
                    FormBuilderTextField(
                      name: 'description',
                      initialValue: existing?.description,
                      decoration: _inputDecoration('Description', Icons.description),
                      style: TextStyle(color: AppColors.panelTextPrimary),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    FormBuilderFilterChips<String>(
                        name: 'availability',
                        initialValue: _currentAvail,
                        decoration: _inputDecoration('Workspace Binding', Icons.visibility),
                        options: availItems,
                        backgroundColor: AppColors.panelBackground,
                        selectedColor: AppColors.accent,
                        checkmarkColor: AppColors.panelTextPrimary,
                        showCheckmark: false,
                        spacing: 8,
                        runSpacing: 8,
                        onChanged: (val) {
                          if (val == null) return;
                          if (val.contains('none') && !_currentAvail.contains('none')) {
                             _formKey.currentState?.fields['availability']?.didChange(['none']);
                          } else if (val.contains('all') && !_currentAvail.contains('all')) {
                             _formKey.currentState?.fields['availability']?.didChange(['all']);
                          } else if (val.length > 1 && (val.contains('all') || val.contains('none'))) {
                             final newVal = val.where((v) => v != 'all' && v != 'none').toList();
                             _formKey.currentState?.fields['availability']?.didChange(newVal);
                          }
                          _currentAvail = List<String>.from(_formKey.currentState?.fields['availability']?.value ?? []);
                        },
                    ),
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
                                    color: AppColors.panelBackground,
                                    borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                                    border: Border.all(color: AppColors.borderSubtle)
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
                                    color: AppColors.panelBackground,
                                    borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                                    border: Border.all(color: AppColors.borderSubtle)
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
                      children: [
                        if (existing != null)
                          ElevatedButton.icon(
                            icon: Icon(Icons.auto_awesome, color: AppColors.panelTextPrimary, size: 16),
                            label: Text('Request AI Change', style: TextStyle(color: AppColors.panelTextPrimary)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                            onPressed: () {
                              setState(() => _showToolWindowEditor = false);
                              _showRequestChangePrompt(existing);
                            },
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() => _showToolWindowEditor = false),
                          child: Text('Cancel', style: TextStyle(color: AppColors.panelTextSecondary)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState?.saveAndValidate() ?? false) {
                              final vals = _formKey.currentState!.value;
                              final newDef = ToolWindowDefinition(
                                id: existing?.id ?? vals['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                                name: vals['name'] ?? 'Untitled',
                                shortLabel: vals['shortLabel'] ?? 'N/A',
                                icon: _selectedIcon ?? Icons.build,
                                color: _selectedColor ?? AppColors.accent,
                                description: vals['description'] ?? '',
                              );
                              
                              setState(() {
                                if (existing != null) {
                                  final idx = AppToolWindows.available.indexWhere((e) => e.id == existing.id);
                                  if (idx >= 0) AppToolWindows.available[idx] = newDef;
                                } else {
                                  AppToolWindows.available.add(newDef);
                                }
                                _showToolWindowEditor = false;
                              });
                              
                              await widget.onAvailabilityChanged(newDef.id, vals['availability'] ?? ['all']);
                              
                              AppToolWindows.saveCustom().then((_) => VisualEditorScreen.configRefreshNotifier.value++);
                              widget.onToolWindowsChanged();
                            }
                          }, 
                          child: Text('Save')
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddWindowPrompt() {
    final TextEditingController promptCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.windowBackground,
          title: Text('Request New Tool Window', style: TextStyle(color: AppColors.panelTextPrimary)),
          content: SizedBox(
            width: 400,
            child: TextField(
              controller: promptCtrl,
              maxLines: 4,
              style: TextStyle(color: AppColors.panelTextPrimary),
              decoration: InputDecoration(
                hintText: 'Describe the functionality and layout of the new tool window...',
                hintStyle: TextStyle(color: AppColors.panelTextSecondary),
                filled: true,
                fillColor: AppColors.panelBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: AppColors.panelTextSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final prompt = promptCtrl.text.trim();
                if (prompt.isNotEmpty) {
                  await AiBridgeService.instance.addTask(
                    'Create New Tool Window',
                    'Create a new dynamic tool window according to the following requirements: $prompt\n\nMake sure to add it to the AppToolWindows.available registry defaults in constants.dart, create the relevant component inside lib/screens/visual_editor/panels/, and register the visibility ValueNotifier in visual_editor_screen.dart.',
                    status: AiTaskStatus.open,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Task added to AI Bridge Queue!'), backgroundColor: Colors.green),
                    );
                  }
                }
                Navigator.pop(ctx);
              },
              child: Text('Submit Request'),
            ),
          ],
        );
      }
    );
  }

  void _showRequestChangePrompt(ToolWindowDefinition existing) {
    final TextEditingController promptCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.windowBackground,
          title: Text('Request Change: ${existing.name}', style: TextStyle(color: AppColors.panelTextPrimary)),
          content: SizedBox(
            width: 400,
            child: TextField(
              controller: promptCtrl,
              maxLines: 4,
              style: TextStyle(color: AppColors.panelTextPrimary),
              decoration: InputDecoration(
                hintText: 'Describe the features or changes you want to add to this tool window...',
                hintStyle: TextStyle(color: AppColors.panelTextSecondary),
                filled: true,
                fillColor: AppColors.panelBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: AppColors.panelTextSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final prompt = promptCtrl.text.trim();
                if (prompt.isNotEmpty) {
                  await AiBridgeService.instance.addTask(
                    'Modify Tool Window: ${existing.name}',
                    'Modify the existing tool window "${existing.name}" (ID: ${existing.id}) according to the following requirements: $prompt\n\nThe relevant widget is likely located in lib/screens/visual_editor/panels/.',
                    status: AiTaskStatus.open,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Task added to AI Bridge Queue!'), backgroundColor: Colors.green),
                    );
                  }
                }
                Navigator.pop(ctx);
              },
              child: Text('Submit Request'),
            ),
          ],
        );
      }
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
              Text('CUSTOM TOOL WINDOWS', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ElevatedButton.icon(
                icon: Icon(Icons.add, color: AppColors.panelTextPrimary),
                label: Text('Request Window', style: TextStyle(color: AppColors.panelTextPrimary)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: _showAddWindowPrompt,
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView(
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
                final item = AppToolWindows.available.removeAt(oldIndex);
                AppToolWindows.available.insert(newIndex, item);
              });
              AppToolWindows.saveCustom().then((_) => VisualEditorScreen.configRefreshNotifier.value++);
              widget.onToolWindowsChanged();
            },
            children: AppToolWindows.available.asMap().entries.map((entry) {
              final idx = entry.key;
              final w = entry.value;
              
              // Get current availability display text and color
              String availText = 'Available on All Workspaces';
              Color? wsColor;
              final list = widget.windowAvailability[w.id];
              if (list != null && list.contains('none')) {
                  availText = 'Hidden';
                  wsColor = Colors.grey;
              } else if (list == null || list.isEmpty || list.contains('all')) {
                  availText = 'Available on All Workspaces';
              } else if (list.length == 1) {
                  final ws = AppWorkspaces.available.firstWhere((ws) => ws.id == list.first, orElse: () => WorkspaceDefinition(id: list.first, name: list.first, shortLabel: list.first, icon: Icons.error, description: ''));
                  availText = 'Restricted to: ${ws.name}';
                  wsColor = ws.color;
              } else {
                  availText = 'Restricted to ${list.length} Workspaces';
              }

              return Material(
                key: ValueKey(w.id),
                color: (wsColor ?? Colors.white).withOpacity(idx % 2 == 0 ? 0.12 : 0.04),
                child: Tooltip(
                  message: w.description,
                  waitDuration: const Duration(milliseconds: 500),
                  child: ListTile(
                    dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(w.icon, color: w.color, size: 20),
                  title: Text(w.name, style: TextStyle(color: AppColors.panelTextPrimary, fontWeight: FontWeight.w500)),
                  subtitle: Text(availText, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: AppUIConfig.smallFontSize)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () {
                        setState(() {
                          AppToolWindows.available.removeWhere((e) => e.id == w.id);
                        });
                        AppToolWindows.saveCustom().then((_) => VisualEditorScreen.configRefreshNotifier.value++);
                        widget.onToolWindowsChanged();
                      },
                    ),
                    ReorderableDragStartListener(
                      index: idx,
                      child: Icon(Icons.drag_handle, color: AppColors.panelTextSecondary),
                    )
                  ],
                ),
                onTap: () => _showEditWindow(w),
              )));
            }).toList(),
          ),
        ),
      ],
    );

    return Stack(
      children: [
        mainContent,
        if (_showToolWindowEditor)
          _buildToolWindowEditor(),
      ],
    );
  }
}



