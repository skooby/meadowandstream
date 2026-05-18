import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/backup_service.dart';
import '../visual_editor_screen.dart';
import 'package:path/path.dart' as p;
import '../../../constants.dart';

final ValueNotifier<bool> showBackupNotifier = ValueNotifier(false);

void showBackupWindow(BuildContext context) {
  if (showBackupNotifier.value) return;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showBackup'), true));
  showBackupNotifier.value = true;
}

void hideBackupWindow() {
  showBackupNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showBackup'), false));
}

class BackupManagerPanel extends StatefulWidget {
  final bool isDocked;
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  const BackupManagerPanel({super.key, required this.onClose, this.onFocus, this.isDocked = false});

  @override
  State<BackupManagerPanel> createState() => _BackupManagerPanelState();
}
class _BackupManagerPanelState extends State<BackupManagerPanel> {
  bool _isLoaded = false;

  double _width = 600;
  double _height = 500;
  double _bgOpacity = 0.4;
  Offset _offset = const Offset(200, 200);

  List<File> _backups = [];
  bool _isLoading = false;
  Set<String> _collapsedFolders = {};

  final TextEditingController _minorCtrl = TextEditingController();
  final TextEditingController _majorCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _refreshBackups();
    VisualEditorScreen.currentWorkspace.addListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.addListener(_loadPreferences);
  }

  @override
  void dispose() {
    VisualEditorScreen.currentWorkspace.removeListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.removeListener(_loadPreferences);
    _minorCtrl.dispose();
    _majorCtrl.dispose();
    super.dispose();
  }
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isLoaded = true;

        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('backup_width')) ?? 600;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('backup_height')) ?? 500;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.4;
        double dx = prefs.getDouble(VisualEditorScreen.getPrefKey('backup_dx')) ?? 200;
        double dy = prefs.getDouble(VisualEditorScreen.getPrefKey('backup_dy')) ?? 200;
        _offset = Offset(dx, dy);

        final List<String> collapsed = prefs.getStringList(VisualEditorScreen.getPrefKey('backup_collapsed')) ?? [];
        _collapsedFolders = collapsed.toSet();
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('backup_width'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('backup_height'), _height);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('backup_dx'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('backup_dy'), _offset.dy);
    await prefs.setStringList(VisualEditorScreen.getPrefKey('backup_collapsed'), _collapsedFolders.toList());
  }

  Future<void> _refreshBackups() async {
    setState(() => _isLoading = true);
    try {
      final list = await BackupService.instance.listBackups();
      final vs = await BackupService.instance.getNextVersions();
      _minorCtrl.text = vs.$1;
      _majorCtrl.text = vs.$2;
      setState(() {
        _backups = list;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load archives: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _createBackup(String exactVersion, bool isMajor) {
    if (exactVersion.trim().isEmpty) exactVersion = '1.0';
    final tCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) {
       return AlertDialog(
         backgroundColor: AppColors.windowBackground,
         title: Text('Create $exactVersion Backup', style: TextStyle(color: AppColors.panelTextPrimary)),
         content: TextField(
           controller: tCtrl,
           style: TextStyle(color: AppColors.panelTextPrimary),
           decoration: InputDecoration(
             labelText: 'Optional Backup Label',
             labelStyle: TextStyle(color: AppColors.panelTextSecondary)
           ),
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
           ElevatedButton(
             onPressed: () async {
               Navigator.pop(ctx);
               setState(() => _isLoading = true);
               try {
                 await BackupService.instance.createBackup(tCtrl.text.trim(), exactVersion: exactVersion.trim());
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Version $exactVersion backup safely compressed natively.')));
                 _refreshBackups();
               } catch(e) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to zip project: $e'), backgroundColor: Colors.red));
                 setState(() => _isLoading = false);
               }
             },
             style: ElevatedButton.styleFrom(backgroundColor: isMajor ? AppColors.accent : Color(0xFF2C2C2C), foregroundColor: isMajor ? AppColors.panelTextPrimary : AppColors.accent),
             child: Text('Confirm v$exactVersion Backup')
           )
         ]
       );
    });
  }

  @override
  Widget _buildBackupContent() { return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
Container(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _createBackup(_minorCtrl.text, false),
                              icon: const Icon(Icons.exposure_plus_1, size: 16),
                              label: Text('Backup Minor'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C2C2C),
                                foregroundColor: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(width: 50, height: 32, child: TextField(
                              controller: _minorCtrl,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(filled: true, fillColor: AppColors.windowBackground, contentPadding: EdgeInsets.zero, border: OutlineInputBorder(borderSide: BorderSide.none))
                            )),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () => _createBackup(_majorCtrl.text, true),
                              icon: const Icon(Icons.upgrade, size: 16),
                              label: Text('Backup Major'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: AppColors.panelTextPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(width: 50, height: 32, child: TextField(
                              controller: _majorCtrl,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(filled: true, fillColor: AppColors.windowBackground, contentPadding: EdgeInsets.zero, border: OutlineInputBorder(borderSide: BorderSide.none))
                            )),
                             const Spacer(),
                             IconButton(
                               icon: Icon(Icons.refresh, color: AppColors.panelTextSecondary),
                               onPressed: _refreshBackups,
                             )
                          ]
                        )
                      ),
                      Expanded(
                        child: _isLoading 
                         ? Center(child: CircularProgressIndicator()) 
                         : _backups.isEmpty 
                           ? Center(child: Text('No active local project archives found natively.', style: TextStyle(color: AppColors.panelTextSecondary)))
                           : Builder(
                               builder: (context) {
                                  final grouped = <String, List<File>>{};
                                  for (var f in _backups) {
                                     final pName = p.basename(p.dirname(f.path));
                                     grouped.putIfAbsent(pName, () => []).add(f);
                                  }
                                  final sortedKeys = grouped.keys.toList()..sort((a,b) => b.compareTo(a));
                                  
                                  return ListView(
                                     children: sortedKeys.map((versionFolder) {
                                        return ExpansionTile(
                                           dense: true,
                                           visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                                           tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                                           initiallyExpanded: !_collapsedFolders.contains(versionFolder),
                                           onExpansionChanged: (expanded) {
                                              setState(() {
                                                if (expanded) {
                                                   _collapsedFolders.remove(versionFolder);
                                                } else {
                                                   _collapsedFolders.add(versionFolder);
                                                }
                                              });
                                              _savePreferences();
                                           },
                                           collapsedIconColor: AppColors.panelTextSecondary,
                                           iconColor: Colors.amberAccent,
                                           title: Text(versionFolder.toUpperCase(), style: TextStyle(color: AppColors.panelTextPrimary, fontWeight: FontWeight.bold, fontSize: AppUIConfig.rootFontSize, letterSpacing: 1)),
                                           children: grouped[versionFolder]!.where((file) => file.existsSync()).map((file) {
                                              final m = file.lastModifiedSync();
                                              return ListTile(
                                                 dense: true,
                                                 visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                                                 minVerticalPadding: 0,
                                                 contentPadding: const EdgeInsets.only(left: 32, right: 16),
                                                 title: Text(p.basename(file.path), style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold)),
                                                 subtitle: Text('${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB - ${m.year}-${m.month}-${m.day} ${m.hour}:${m.minute}', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
                                                 trailing: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                       IconButton(
                                                          icon: Icon(AppToolWindows.getDef('backup').icon, size: 16, color: AppToolWindows.getDef('backup').color),
                                                          tooltip: 'Restore Source Code',
                                                          onPressed: () {
                                                             showDialog(context: context, builder: (ctx) => AlertDialog(
                                                                backgroundColor: AppColors.windowBackground,
                                                                title: Text('Confirm Data Purge', style: TextStyle(color: AppColors.panelTextPrimary)),
                                                                content: Text('Are you sure you want to completely overwrite current app workspace with this archive snapshot state?', style: TextStyle(color: AppColors.panelTextSecondary)),
                                                                actions: [
                                                                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
                                                                  ElevatedButton(
                                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                                    onPressed: () async {
                                                                       Navigator.pop(ctx);
                                                                       setState(() => _isLoading = true);
                                                                       try {
                                                                          await BackupService.instance.restoreBackup(file);
                                                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project gracefully restored from local zip native archive.')));
                                                                       } catch(e) {
                                                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to restore from archive: $e'), backgroundColor: Colors.red));
                                                                       } finally {
                                                                          setState(() => _isLoading = false);
                                                                       }
                                                                    }, 
                                                                    child: Text('Overwrite Workspace', style: TextStyle(color: AppColors.panelTextPrimary))
                                                                  )
                                                                ]
                                                             ));
                                                          }
                                                       ),
                                                       IconButton(
                                                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                                          tooltip: 'Deallocate Zip File',
                                                          onPressed: () async {
                                                             await BackupService.instance.deleteBackup(file);
                                                             _refreshBackups();
                                                          }
                                                       )
                                                    ]
                                                 )
                                              );
                                           }).toList()
                                        );
                                     }).toList()
                                  );
                               }
                           )
                      ),
                    
]); }
  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    if (widget.isDocked) return Material(color: Colors.transparent, child: _buildBackupContent());
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
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(AppUIConfig.windowBorderRadius))),
                          child: Row(
                            children: [
                              Icon(Icons.backup,
                                  size: 16, color: AppColors.accent),
                              const SizedBox(width: 8),
                              Text(AppUIConfig.formatWindowTitle(AppToolWindows.getDef('backup').name), style: TextStyle(
                                      color: AppColors.titleBarTextPrimary,
                                      fontSize: AppUIConfig.windowTitleFontSize,
                                      fontWeight: AppUIConfig.windowTitleFontWeight)),
                              const SizedBox(width: 12),
                              FutureBuilder<String>(
                                future: BackupService.instance.getBackupDirectory(),
                                builder: (ctx, snap) {
                                   if (!snap.hasData) return const SizedBox.shrink();
                                   return Expanded(
                                      child: Text(
                                         snap.data!,
                                         style: TextStyle(color: AppColors.textMuted, fontSize: AppUIConfig.smallFontSize, fontStyle: FontStyle.italic),
                                         maxLines: 1,
                                         overflow: TextOverflow.ellipsis,
                                      )
                                   );
                                }
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
                      Expanded(child: _buildBackupContent())])
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


