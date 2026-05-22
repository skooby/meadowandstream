import 'package:music_app/constants.dart';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'visual_editor_screen.dart';
import 'panels/ai_bridge_window.dart';

enum DockPosition { floating, left, right, top, bottom }

class DockablePanel {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  final Widget Function() floatingBuilder;
  final VoidCallback? onFocus;

  ValueNotifier<DockPosition> dockPosition = ValueNotifier(DockPosition.floating);
  ValueNotifier<bool> isVisible = ValueNotifier(false);

  DockablePanel({
    required this.id,
    required this.title,
    required this.icon,
    Color? color,
    required this.child,
    required this.floatingBuilder,
    this.onFocus,
  }) : color = color ?? AppColors.accent;

  void show() => isVisible.value = true;
  void hide() => isVisible.value = false;
  void dock(DockPosition position) => dockPosition.value = position;
  void undock() => dockPosition.value = DockPosition.floating;
}

class WindowDockManager {
  static final WindowDockManager instance = WindowDockManager._internal();
  WindowDockManager._internal() {
    VisualEditorScreen.configRefreshNotifier.addListener(() {
      _notify();
    });
  }

  final List<DockablePanel> panels = [];
  final ValueNotifier<int> stateToken = ValueNotifier(0);

  /// Per-side layout mode: true = tabbed, false = stacked (default)
  final Map<DockPosition, bool> _tabbedMode = {};

  /// Persistent controllers keyed by a composition string
  final Map<String, MultiSplitViewController> _controllers = {};

  /// Saved area sizes keyed by controller id + area index
  final Map<String, double> _savedSizes = {};

  bool _prefsLoaded = false;

  bool isTabbedMode(DockPosition position) => _tabbedMode[position] ?? false;

  void toggleTabbedMode(DockPosition position) {
    _tabbedMode[position] = !isTabbedMode(position);
    SharedPreferences.getInstance().then((prefs) => 
        prefs.setBool('dock_tabbed_${position.name}', _tabbedMode[position]!));
    _notify();
  }

  void registerPanel(DockablePanel panel) {
    if (!panels.any((p) => p.id == panel.id)) {
      panels.add(panel);
      
      SharedPreferences.getInstance().then((prefs) {
        final savedPosName = prefs.getString('dock_pos_${panel.id}');
        if (savedPosName != null) {
          for (final pos in DockPosition.values) {
            if (pos.name == savedPosName) {
              panel.dockPosition.value = pos;
              break;
            }
          }
        } else {
          // Default initial fallback if never saved
          if (panel.id == 'layer_tree') panel.dockPosition.value = DockPosition.left;
          if (panel.id == 'timeline') panel.dockPosition.value = DockPosition.bottom;
        }

        panel.dockPosition.addListener(() {
          prefs.setString('dock_pos_${panel.id}', panel.dockPosition.value.name);
          _notify();
        });
      });
      
      panel.isVisible.addListener(_notify);
    }
  }

  void _notify() {
    stateToken.value++;
  }

  List<DockablePanel> getPanelsFor(DockPosition position) {
    return panels.where((p) => p.isVisible.value && p.dockPosition.value == position).toList();
  }

  /// Load saved dock configurations from SharedPreferences
  Future<void> loadSavedSizes() async {
    if (_prefsLoaded) return;
    _prefsLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    for (final pos in DockPosition.values) {
      _tabbedMode[pos] = prefs.getBool('dock_tabbed_${pos.name}') ?? false;
    }
    for (final key in prefs.getKeys()) {
      if (key.startsWith('dock_size_')) {
        _savedSizes[key] = prefs.getDouble(key) ?? 0;
      }
    }
  }

  /// Save a specific area size to SharedPreferences
  void _saveSize(String key, double size) {
    _savedSizes[key] = size;
    SharedPreferences.getInstance().then((prefs) => prefs.setDouble(key, size));
  }

  /// Get or create a controller. Reuses existing if composition matches.
  MultiSplitViewController _getController(String id, List<Area> areas) {
    final existing = _controllers[id];
    if (existing != null && existing.areas.length == areas.length) {
      return existing;
    }
    // Restore saved sizes into areas
    for (int i = 0; i < areas.length; i++) {
      final sizeKey = 'dock_size_${id}_$i';
      final savedSize = _savedSizes[sizeKey];
      if (savedSize != null && savedSize > 0) {
        areas[i] = Area(
          size: areas[i].flex != null ? null : savedSize,
          flex: areas[i].flex,
          min: areas[i].min,
          max: areas[i].max,
          builder: areas[i].builder,
        );
      }
    }
    final controller = MultiSplitViewController(areas: areas);
    _controllers[id] = controller;
    return controller;
  }

  /// Called when a divider drag ends — saves all area sizes for that controller
  void _onDividerDragEnd(String controllerId, MultiSplitViewController controller) {
    for (int i = 0; i < controller.areas.length; i++) {
      final area = controller.areas[i];
      if (area.size != null) {
        _saveSize('dock_size_${controllerId}_$i', area.size!);
      }
    }
  }

  /// Builds a single panel's header + content
  Widget _buildDockedWindowContainer(DockablePanel panel, {bool showLayoutToggle = false}) {
    final position = panel.dockPosition.value;
    final siblingCount = getPanelsFor(position).length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
      ),
      child: Column(
        children: [
          ValueListenableBuilder<String>(
            valueListenable: VisualEditorScreen.activeWindowNotifier,
            builder: (context, activeId, child) {
              final isActive = activeId == panel.id;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: isActive ? AppColors.activeWindowBorder : AppColors.controlBorder),
                child: child,
              );
            },
            child: Row(
              children: [
                panel.id == 'ai_bridge'
                    ? AiBridgeActivityIcon(size: 16, color: panel.color, defaultIcon: panel.icon)
                    : Icon(panel.icon, size: 16, color: panel.color),
                const SizedBox(width: 8),
                Expanded(
                  child: panel.id == 'ai_bridge'
                      ? ValueListenableBuilder<bool>(
                          valueListenable: AiBridgeWindow.showBridgeMonitorNotifier,
                          builder: (context, showBridgeMonitor, _) {
                            return Text(
                              showBridgeMonitor ? 'Bridge Monitor' : 'Task Manager',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: AppUIConfig.windowTitleFontSize,
                                fontWeight: AppUIConfig.windowTitleFontWeight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        )
                      : Text(
                          AppUIConfig.formatWindowTitle(panel.title),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: AppUIConfig.windowTitleFontSize,
                            fontWeight: AppUIConfig.windowTitleFontWeight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                const SizedBox(width: 8),
                if (panel.id == 'ai_bridge') ...[
                  ValueListenableBuilder<bool>(
                    valueListenable: AiBridgeWindow.showBridgeMonitorNotifier,
                    builder: (context, showBridgeMonitor, _) {
                      return Tooltip(
                        message: showBridgeMonitor ? 'Switch to Task Manager' : 'Switch to Bridge Monitor',
                        child: InkWell(
                          onTap: AiBridgeWindow.toggleMode,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              showBridgeMonitor ? Icons.assignment : Icons.analytics,
                              color: AppColors.textSecondary,
                              size: 16,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                ],
                // Show layout toggle when multiple panels share this side
                if (showLayoutToggle && siblingCount > 1)
                  Tooltip(
                    message: isTabbedMode(position) ? 'Switch to Stacked' : 'Switch to Tabbed',
                    child: InkWell(
                      onTap: () => toggleTabbedMode(position),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isTabbedMode(position) ? Icons.view_agenda : Icons.tab,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                if (showLayoutToggle && siblingCount > 1)
                  const SizedBox(width: 4),
                Tooltip(
                  message: 'Undock Window',
                  child: InkWell(
                    onTap: () => panel.undock(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.open_in_new, size: 16, color: Colors.orangeAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Close Panel',
                  child: InkWell(
                    onTap: () => panel.hide(),
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16, color: AppColors.accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: panel.child),
        ],
      ),
    );
  }

  /// Builds the dock region for a side — chooses stacked or tabbed based on mode
  Widget _buildSideDockContainer(List<DockablePanel> panels, DockPosition position) {
    if (panels.length == 1) return _buildDockedWindowContainer(panels.first, showLayoutToggle: true);

    if (isTabbedMode(position)) {
      return _TabbedDockWidget(panels: panels, position: position);
    }

    // Stacked mode: Left/Right → stack vertically; Top/Bottom → stack horizontally
    final axis = (position == DockPosition.left || position == DockPosition.right)
        ? Axis.vertical
        : Axis.horizontal;

    final stackId = 'stack_${position.name}';
    final areas = panels.map((p) =>
      Area(flex: 1.0, builder: (context, area) => _buildDockedWindowContainer(p, showLayoutToggle: true))
    ).toList();

    final controller = _getController(stackId, areas);

    return MultiSplitView(
      axis: axis,
      controller: controller,
      onDividerDragUpdate: (index) {},
      onDividerDragEnd: (index) => _onDividerDragEnd(stackId, controller),
    );
  }

  Widget buildWorkspaceLayout(BuildContext context, Widget centralCanvas, double uiScale) {
    return ValueListenableBuilder<int>(
      valueListenable: stateToken,
      builder: (context, _, __) {
        final leftPanels = getPanelsFor(DockPosition.left);
        final rightPanels = getPanelsFor(DockPosition.right);
        final bottomPanels = getPanelsFor(DockPosition.bottom);
        final topPanels = getPanelsFor(DockPosition.top);

        // Core Horizontal Layout (Left + Center + Right)
        const hId = 'h_main';
        List<Area> horizontalAreas = [];

        if (leftPanels.isNotEmpty) {
           horizontalAreas.add(Area(size: 250, min: 150, builder: (context, area) => _buildSideDockContainer(leftPanels, DockPosition.left)));
        }

        horizontalAreas.add(Area(flex: 1.0, builder: (context, area) => centralCanvas));

        if (rightPanels.isNotEmpty) {
           horizontalAreas.add(Area(size: 250, min: 150, builder: (context, area) => _buildSideDockContainer(rightPanels, DockPosition.right)));
        }

        // Compute composition key to detect panel changes
        final hKey = '${leftPanels.map((p) => p.id).join(",")}_${rightPanels.map((p) => p.id).join(",")}';
        
        Widget horizontalSplit;
        if (horizontalAreas.length == 1) {
           horizontalSplit = centralCanvas;
        } else {
           final hController = _getController('$hId:$hKey', horizontalAreas);
           horizontalSplit = MultiSplitViewTheme(
             data: MultiSplitViewThemeData(
               dividerThickness: 8,
               dividerPainter: DividerPainters.grooved1(
                 color: AppColors.borderSubtle,
                 highlightedColor: AppColors.accent,
               ),
             ),
             child: MultiSplitView(
               axis: Axis.horizontal,
               controller: hController,
               onDividerDragUpdate: (index) {},
               onDividerDragEnd: (index) => _onDividerDragEnd('$hId:$hKey', hController),
             ),
           );
        }

        // Core Vertical Layout (Top + Horizontal Split + Bottom)
        const vId = 'v_main';
        final List<Area> verticalAreas = [];

        if (topPanels.isNotEmpty) {
           verticalAreas.add(Area(size: 200, min: 100, builder: (context, area) => _buildSideDockContainer(topPanels, DockPosition.top)));
        }

        verticalAreas.add(Area(flex: 1.0, builder: (context, area) => horizontalSplit));

        if (bottomPanels.isNotEmpty) {
           verticalAreas.add(Area(size: 200, min: 100, builder: (context, area) => _buildSideDockContainer(bottomPanels, DockPosition.bottom)));
        }

        final vKey = '${topPanels.map((p) => p.id).join(",")}_${bottomPanels.map((p) => p.id).join(",")}';

        Widget finalLayout;
        if (verticalAreas.length == 1) {
           finalLayout = horizontalSplit;
        } else {
           final vController = _getController('$vId:$vKey', verticalAreas);
           finalLayout = MultiSplitViewTheme(
             data: MultiSplitViewThemeData(
               dividerThickness: 8,
               dividerPainter: DividerPainters.grooved1(
                 color: AppColors.borderSubtle,
                 highlightedColor: AppColors.accent,
               ),
             ),
             child: MultiSplitView(
               axis: Axis.vertical,
               controller: vController,
               onDividerDragUpdate: (index) {},
               onDividerDragEnd: (index) => _onDividerDragEnd('$vId:$vKey', vController),
             ),
           );
        }

        return finalLayout;
      }
    );
  }

  List<Widget> buildFloatingWindows() {
    return getPanelsFor(DockPosition.floating).map((p) => p.floatingBuilder()).toList();
  }
}

/// Tabbed dock widget — shows panels as switchable tabs within a shared dock region
class _TabbedDockWidget extends StatefulWidget {
  final List<DockablePanel> panels;
  final DockPosition position;
  const _TabbedDockWidget({required this.panels, required this.position});

  @override
  State<_TabbedDockWidget> createState() => _TabbedDockWidgetState();
}

class _TabbedDockWidgetState extends State<_TabbedDockWidget> {
  int _activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (_activeIndex >= widget.panels.length) {
      _activeIndex = widget.panels.length - 1;
    }

    final activePanel = widget.panels[_activeIndex];
    final mgr = WindowDockManager.instance;

    return Container(
      decoration: BoxDecoration(color: AppColors.panelBackground),
      child: Column(
        children: [
          // Tab bar
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => activePanel.onFocus?.call(),
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFF2D2D2D),
                border: Border(bottom: BorderSide(color: AppColors.overlaySubtle)),
              ),
              child: Row(
                children: [
                  // Tab buttons
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                      children: List.generate(widget.panels.length, (i) {
                        final panel = widget.panels[i];
                        final isActive = i == _activeIndex;
                        return InkWell(
                          onTap: () {
                             setState(() => _activeIndex = i);
                             panel.onFocus?.call();
                          },
                          child: ValueListenableBuilder<String>(
                            valueListenable: VisualEditorScreen.activeWindowNotifier,
                            builder: (context, activeId, _) {
                              final isWindowActive = activeId == panel.id;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isActive ? (isWindowActive ? AppColors.activeWindowBorder : AppColors.controlBorder) : Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isActive ? AppColors.accent : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    panel.id == 'ai_bridge'
                                        ? AiBridgeActivityIcon(size: 14, color: isActive ? panel.color : panel.color.withOpacity(0.5), defaultIcon: panel.icon)
                                        : Icon(panel.icon, size: 14, color: isActive ? panel.color : panel.color.withOpacity(0.5)),
                                    const SizedBox(width: 6),
                                    panel.id == 'ai_bridge'
                                        ? ValueListenableBuilder<bool>(
                                            valueListenable: AiBridgeWindow.showBridgeMonitorNotifier,
                                            builder: (context, showBridgeMonitor, _) {
                                              return Text(
                                                showBridgeMonitor ? 'Bridge Monitor' : 'Task Manager',
                                                style: TextStyle(
                                                  color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                                                  fontSize: 11,
                                                  fontWeight: isActive ? AppUIConfig.windowTitleFontWeight : FontWeight.normal,
                                                ),
                                              );
                                            },
                                          )
                                        : Text(
                                            AppUIConfig.formatWindowTitle(panel.title),
                                            style: TextStyle(
                                              color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                                              fontSize: 11,
                                              fontWeight: isActive ? AppUIConfig.windowTitleFontWeight : FontWeight.normal,
                                            ),
                                          ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                // Action buttons
                const SizedBox(width: 4),
                if (activePanel.id == 'ai_bridge') ...[
                  ValueListenableBuilder<bool>(
                    valueListenable: AiBridgeWindow.showBridgeMonitorNotifier,
                    builder: (context, showBridgeMonitor, _) {
                      return Tooltip(
                        message: showBridgeMonitor ? 'Switch to Task Manager' : 'Switch to Bridge Monitor',
                        child: InkWell(
                          onTap: AiBridgeWindow.toggleMode,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              showBridgeMonitor ? Icons.assignment : Icons.analytics,
                              color: AppColors.textSecondary,
                              size: 14,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                ],
                Tooltip(
                  message: 'Switch to Stacked',
                  child: InkWell(
                    onTap: () => mgr.toggleTabbedMode(widget.position),
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.view_agenda, size: 14, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Undock Window',
                  child: InkWell(
                    onTap: () => activePanel.undock(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.open_in_new, size: 14, color: Colors.orangeAccent),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Close Panel',
                  child: InkWell(
                    onTap: () => activePanel.hide(),
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 14, color: AppColors.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          ),
          // Active panel content
          Expanded(
            child: IndexedStack(
              index: _activeIndex,
              children: widget.panels.map((p) => p.child).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
