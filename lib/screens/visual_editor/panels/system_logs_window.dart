import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/system_logs_service.dart';
import '../../../services/ai_bridge_service.dart';
import '../visual_editor_screen.dart';
import '../../../constants.dart';

final ValueNotifier<bool> showSystemLogsNotifier = ValueNotifier(false);

void showSystemLogsWindow(BuildContext context) {
  if (showSystemLogsNotifier.value) return;

  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showSystemLogs'), true));

  showSystemLogsNotifier.value = true;
}

void hideSystemLogsWindow() {
  showSystemLogsNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showSystemLogs'), false));
}

class SystemLogsWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  const SystemLogsWindow({super.key, required this.onClose, this.onFocus, this.isDocked = false});

  static final ValueNotifier<bool> isPinnedOnTopNotifier = ValueNotifier<bool>(false);

  @override
  State<SystemLogsWindow> createState() => _SystemLogsWindowState();
}
class _SystemLogsWindowState extends State<SystemLogsWindow> {
  bool _isLoaded = false;

  LogCategory? _selectedLogCategory;
  double _width = 800;
  double _height = 600;
  double _bgOpacity = 0.4;
  Offset _offset = const Offset(100, 100);

  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    SystemLogsService.instance.addListener(_scrollToBottomIfNeeded);
    _loadPreferences();
    VisualEditorScreen.currentWorkspace.addListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.addListener(_loadPreferences);
    VisualEditorScreen.activeWindowNotifier.addListener(_onActiveWindowChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    SystemLogsService.instance.removeListener(_scrollToBottomIfNeeded);
    _scrollController.dispose();
    VisualEditorScreen.currentWorkspace.removeListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.removeListener(_loadPreferences);
    VisualEditorScreen.activeWindowNotifier.removeListener(_onActiveWindowChanged);
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      
      // If the user scrolls up by more than 10 pixels, disable autoScroll.
      // If they scroll back down to the bottom (within 10 pixels), re-enable autoScroll.
      if (maxScroll - currentScroll > 10) {
        if (_autoScroll) {
          setState(() {
            _autoScroll = false;
          });
        }
      } else {
        if (!_autoScroll) {
          setState(() {
            _autoScroll = true;
          });
        }
      }
    }
  }

  void _scrollToBottomIfNeeded() {
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _onActiveWindowChanged() {
    if (mounted) setState(() {});
  }
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isLoaded = true;

        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('sys_logs_width')) ?? 800;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('sys_logs_height')) ?? 600;
        _bgOpacity = prefs.getDouble('sys_logs_opacity') ?? prefs.getDouble('ve_toolWindowOpacity') ?? 0.4;
        double dx = prefs.getDouble(VisualEditorScreen.getPrefKey('sys_logs_dx')) ?? 100;
        double dy = prefs.getDouble(VisualEditorScreen.getPrefKey('sys_logs_dy')) ?? 100;
        _offset = Offset(dx, dy);
        
        SystemLogsWindow.isPinnedOnTopNotifier.value = prefs.getBool('sys_logs_pinned') ?? false;
      });
      _scrollToBottomIfNeeded();
    }
  }

  void _cycleOpacity() async {
     double nextOpacity;
     if (_bgOpacity > 0.6) {
        nextOpacity = 0.50; // 50% transparent
     } else if (_bgOpacity > 0.35) {
        nextOpacity = 0.25; // 75% transparent
     } else {
        nextOpacity = 0.75; // 25% transparent
     }
     setState(() {
        _bgOpacity = nextOpacity;
     });
     final prefs = await SharedPreferences.getInstance();
     await prefs.setDouble('sys_logs_opacity', nextOpacity);
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('sys_logs_width'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('sys_logs_height'), _height);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('sys_logs_dx'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('sys_logs_dy'), _offset.dy);
  }
  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    if (widget.isDocked) return Material(color: Colors.transparent, child: _buildLogsContent());
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
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'logs' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) : null,
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
                              Icon(Icons.receipt_long,
                                  size: 16, color: AppColors.accent),
                              const SizedBox(width: 8),
                              Text(AppUIConfig.formatWindowTitle('System Logs'), style: TextStyle(
                                      color: AppColors.titleBarTextPrimary,
                                      fontSize: AppUIConfig.windowTitleFontSize,
                                      fontWeight: AppUIConfig.windowTitleFontWeight)),
                              const Spacer(),
                              ValueListenableBuilder<bool>(
                                valueListenable: SystemLogsWindow.isPinnedOnTopNotifier,
                                builder: (context, isPinned, _) {
                                  return IconButton(
                                    icon: Icon(
                                      isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                      size: 16,
                                      color: isPinned ? AppColors.accent : AppColors.titleBarTextSecondary,
                                    ),
                                    tooltip: isPinned ? 'Always on Top (Pinned)' : 'Pin on Top',
                                    onPressed: () async {
                                      final newValue = !isPinned;
                                      SystemLogsWindow.isPinnedOnTopNotifier.value = newValue;
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.setBool('sys_logs_pinned', newValue);
                                      if (mounted) setState(() {});
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: Icon(
                                  Icons.opacity,
                                  size: 16,
                                  color: AppColors.titleBarTextSecondary,
                                ),
                                tooltip: 'Toggle Transparency (${(100 - (_bgOpacity * 100)).round()}% transparent)',
                                onPressed: _cycleOpacity,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 12),
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
                      Expanded(child: _buildLogsContent()),
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

  Widget _buildLogsContent() {
    return ListenableBuilder(
      listenable: SystemLogsService.instance,
      builder: (context, _) {
        final logs = _selectedLogCategory == null
            ? SystemLogsService.instance.logs
            : SystemLogsService.instance.logs
                .where((l) => l.category == _selectedLogCategory)
                .toList();

        return Column(
          children: [
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.overlaySubtle)),
                ),
                child: Wrap(spacing: 4.0, runSpacing: 4.0, children: [
                  _buildCategoryChip(null, 'ALL'),
                  ...SystemLogsService.instance.categoryConfigs
                      .where((cfg) => cfg.system)
                      .map((cfg) => _buildCategoryChip(cfg.category, cfg.category.name))
                      .toList(),
                ])),
            Expanded(
              child: logs.isEmpty
                  ? Center(
                      child: Text(
                        'No system logs available yet.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: AppUIConfig.rootFontSize),
                      ),
                    )
                  : Scrollbar(
                      controller: _scrollController,
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          Color tagColor = Colors.greenAccent;
                          if (log.category == LogCategory.ERROR) {
                            tagColor = Colors.redAccent;
                          } else if (log.category == LogCategory.NETWORK)
                            tagColor = AppColors.accent;
                          else if (log.category == LogCategory.DB)
                            tagColor = Colors.amberAccent;
                          else if (log.category == LogCategory.AI)
                            tagColor = Colors.purpleAccent;
                          else if (log.category == LogCategory.MACRO)
                            tagColor = Colors.tealAccent;
                          else if (log.category == LogCategory.VC)
                            tagColor = Colors.blueAccent;
                          else if (log.category == LogCategory.CLI)
                            tagColor = Colors.cyanAccent;
                          else if (log.category == LogCategory.SYNC)
                            tagColor = Colors.orangeAccent;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 2.0),
                            child: SelectableText(
                              '[${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}] [${log.category.name}] ${log.message}',
                              style: TextStyle(
                                  color: tagColor,
                                  fontSize: AppUIConfig.rootFontSize,
                                  fontFamily: 'monospace'),
                            ),
                          );
                        },
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.overlaySubtle)),
              ),
              child: Row(children: [
                Tooltip(
                  message: 'Clear',
                  child: IconButton(
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.panelBackground,
                        shape: RoundedRectangleBorder(
                            side: BorderSide(color: AppColors.overlaySubtle),
                            borderRadius: BorderRadius.circular(4))),
                    onPressed: () => SystemLogsService.instance.clearLogs(),
                    icon: Icon(Icons.clear_all,
                        size: 16, color: AppColors.panelTextSecondary),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: 'Copy All',
                  child: IconButton(
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.panelBackground,
                        shape: RoundedRectangleBorder(
                            side: BorderSide(color: AppColors.overlaySubtle),
                            borderRadius: BorderRadius.circular(4))),
                    onPressed: () {
                      final allLogsStr = logs
                          .map((l) =>
                              '[${l.timestamp.hour.toString().padLeft(2, '0')}:${l.timestamp.minute.toString().padLeft(2, '0')}:${l.timestamp.second.toString().padLeft(2, '0')}] [${l.category.name}] ${l.message}')
                          .join('\n');
                      Clipboard.setData(ClipboardData(text: allLogsStr));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Logs copied to clipboard'),
                          duration: Duration(seconds: 2)));
                    },
                    icon: const Icon(Icons.copy,
                        size: 16, color: Colors.greenAccent),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Send to Task Manager',
                  child: IconButton(
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.panelBackground,
                        shape: RoundedRectangleBorder(
                            side: BorderSide(color: AppColors.overlaySubtle),
                            borderRadius: BorderRadius.circular(4))),
                    onPressed: () {
                      final recentLogsData = logs.length > 20
                          ? logs.sublist(logs.length - 20)
                          : logs;
                      final latestFormatContext = recentLogsData.isEmpty
                          ? 'No logs'
                          : recentLogsData
                              .map((l) =>
                                  '[${l.timestamp.hour.toString().padLeft(2, '0')}:${l.timestamp.minute.toString().padLeft(2, '0')}:${l.timestamp.second.toString().padLeft(2, '0')}] [${l.category.name}] ${l.message}')
                              .join('\n\n');
                      AiBridgeService.instance.addTask(
                          'Investigate Latest Log Exception', '',
                          notes: 'Recent Logs Context:\n$latestFormatContext');
                    },
                    icon: Icon(Icons.add_task,
                        size: 16, color: AppColors.accent),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                )
              ]),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryChip(LogCategory? category, String label) {
    final isSelected = _selectedLogCategory == category;
    return Padding(
        padding: const EdgeInsets.only(right: 6.0),
        child: InkWell(
            onTap: () {
              setState(() => _selectedLogCategory = category);
              _scrollToBottomIfNeeded();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accent.withOpacity(0.2)
                    : Colors.transparent,
                border: Border.all(
                    color: isSelected ? AppColors.accent : AppColors.borderSubtle),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(label,
                  style: TextStyle(
                      color: isSelected ? AppColors.accent : AppColors.panelTextSecondary,
                      fontSize: AppUIConfig.smallFontSize,
                      fontWeight: FontWeight.bold)),
            )));
  }
}


