import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/profiler_service.dart';
import '../visual_editor_screen.dart';
import '../../../constants.dart';

final ValueNotifier<bool> showProfilerNotifier = ValueNotifier(false);

void showProfilerWindow(BuildContext context) {
  if (showProfilerNotifier.value) return;

  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showProfiler'), true));

  showProfilerNotifier.value = true;
}

void hideProfilerWindow() {
  showProfilerNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showProfiler'), false));
}

class ProfilerWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  const ProfilerWindow({super.key, required this.onClose, this.onFocus, this.isDocked = false});
  @override
  State<ProfilerWindow> createState() => _ProfilerWindowState();
}
class _ProfilerWindowState extends State<ProfilerWindow> {
  bool _isLoaded = false;

  double _width = 600;
  double _height = 500;
  bool _isCollapsed = false;
  double _bgOpacity = 0.4;
  Offset _offset = const Offset(150, 150);

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

        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('profiler_width')) ?? 600;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('profiler_height')) ?? 500;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.4;
        _isCollapsed = prefs.getBool(VisualEditorScreen.getPrefKey('profiler_isCollapsed')) ?? false;
        double dx = prefs.getDouble(VisualEditorScreen.getPrefKey('profiler_dx')) ?? 150;
        double dy = prefs.getDouble(VisualEditorScreen.getPrefKey('profiler_dy')) ?? 150;
        _offset = Offset(dx, dy);
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('profiler_width'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('profiler_height'), _height);
    await prefs.setBool(VisualEditorScreen.getPrefKey('profiler_isCollapsed'), _isCollapsed);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('profiler_dx'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('profiler_dy'), _offset.dy);
  }
  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    if (widget.isDocked) return Material(color: Colors.transparent, child: _buildProfilerContent());
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
                    height: _isCollapsed ? null : _height,
                    clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'profiler' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) : null,
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
                              Icon(AppToolWindows.getDef('profiler').icon,
                                  size: 16, color: AppToolWindows.getDef('profiler').color),
                              const SizedBox(width: 8),
                              Text(AppUIConfig.formatWindowTitle(AppToolWindows.getDef('profiler').name), style: TextStyle(
                                      color: AppColors.titleBarTextPrimary,
                                      fontSize: AppUIConfig.windowTitleFontSize,
                                      fontWeight: AppUIConfig.windowTitleFontWeight)),
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
                        if (!_isCollapsed)
                          Expanded(child: _buildProfilerContent()),
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

  Widget _buildProfilerContent() {
    return ListenableBuilder(
        listenable: AppProfilerService.instance,
        builder: (context, _) {
          final profiler = AppProfilerService.instance;
          return Column(children: [
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Live Telemetry', style: TextStyle(
                              color: AppColors.panelTextPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: AppUIConfig.rootFontSize)),
                      Row(
                        children: [
                          Text('Scale', style: TextStyle(
                                  color: AppColors.panelTextSecondary, fontSize: AppUIConfig.smallFontSize)),
                          SizedBox(
                              width: 50,
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 2.0,
                                  thumbShape: RoundSliderThumbShape(
                                      enabledThumbRadius: 6.0),
                                  overlayShape: RoundSliderOverlayShape(
                                      overlayRadius: 12.0),
                                  activeTrackColor: AppColors.accent,
                                  inactiveTrackColor: AppColors.borderSubtle,
                                  thumbColor: AppColors.accent,
                                ),
                                child: Slider(
                                  value: profiler.maxHistory.toDouble(),
                                  min: 50,
                                  max: 1000,
                                  divisions: 19,
                                  onChanged: (val) =>
                                      profiler.updateTimescale(val.toInt()),
                                ),
                              )),
                          const SizedBox(width: 8),
                          Switch(
                            value: profiler.isEnabled,
                            onChanged: (val) => profiler.toggleProfiler(),
                            activeThumbColor: AppColors.accent,
                          )
                        ],
                      )
                    ])),
            if (!profiler.isEnabled)
              Expanded(
                  child: Center(
                      child: Text('Profiler Disabled',
                          style:
                              TextStyle(color: AppColors.textMuted, fontSize: AppUIConfig.rootFontSize))))
            else
              Expanded(
                  child: Container(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(children: [
                        Expanded(
                            child: _buildMetricRow(
                                'Render FPS',
                                profiler.currentFps,
                                profiler.fpsHistory,
                                Colors.greenAccent,
                                'fps',
                                120.0)),
                        Expanded(
                            child: _buildMetricRow(
                                'Render Avg',
                                profiler.averageRender,
                                profiler.renderTimeHistory,
                                AppColors.accent,
                                'ms',
                                30.0)),
                        Expanded(
                            child: _buildMetricRow(
                                'DB Latency',
                                profiler.averageDb,
                                profiler.dbLatencyHistory,
                                Colors.amberAccent,
                                'ms',
                                50.0)),
                        Expanded(
                            child: _buildMetricRow(
                                'Sync Latency',
                                profiler.averageSync,
                                profiler.syncLatencyHistory,
                                Colors.purpleAccent,
                                'ms',
                                2000.0)),
                        Expanded(
                            child: _buildMetricRow(
                                'Audio Decode',
                                profiler.averageAudio,
                                profiler.audioDecodingHistory,
                                Colors.redAccent,
                                'ms',
                                50.0)),
                      ])))
          ]);
        });
  }

  Widget _buildMetricRow(String label, double value, Iterable<double> history,
      Color color, String unit, double maxScale) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              width: 90,
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(label,
                      style: TextStyle(
                          color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)))),
          Expanded(
              child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2.0),
                  decoration: BoxDecoration(
                      color: AppColors.overlaySubtle,
                      borderRadius: BorderRadius.circular(4)),
                  clipBehavior: Clip.hardEdge,
                  child: CustomPaint(
                      painter: SparklinePainter(
                          history: history.toList(),
                          color: color,
                          maxScale: maxScale)))),
          const SizedBox(width: 12),
          SizedBox(
              width: 50,
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${value.toStringAsFixed(1)}$unit',
                      style: TextStyle(
                          color: color,
                          fontSize: AppUIConfig.rootFontSize,
                          fontWeight: FontWeight.bold)))),
          const SizedBox(width: 16),
        ]));
  }
}

class SparklinePainter extends CustomPainter {
  final List<double> history;
  final Color color;
  final double maxScale;

  SparklinePainter(
      {required this.history, required this.color, required this.maxScale});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final maxPts = AppProfilerService.instance.maxHistory;
    final double stepX = size.width / (maxPts - 1).clamp(1, maxPts);
    final double startX = size.width - (history.length - 1) * stepX;

    double currentX = startX;

    for (int i = 0; i < history.length; i++) {
      final double val = history[i].clamp(0.0, maxScale);
      final double h = val / maxScale * size.height;
      final double y = size.height - h;

      if (i == 0) {
        path.moveTo(currentX, y);
        fillPath.moveTo(currentX, size.height);
        fillPath.lineTo(currentX, y);
      } else {
        path.lineTo(currentX, y);
        fillPath.lineTo(currentX, y);
      }
      currentX += stepX;
    }

    if (history.isNotEmpty) {
      fillPath.lineTo(currentX - stepX, size.height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) => true;
}


