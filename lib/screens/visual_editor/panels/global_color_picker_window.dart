import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:cyclop/cyclop.dart' hide ColorPicker;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../constants.dart';
import '../visual_editor_screen.dart';
import '../../../state/global_picker_state.dart';

enum SwatchSortMethod { curated, hsv, lightness }

final ValueNotifier<bool> showColorPickerNotifier = ValueNotifier(false);

void showColorPickerWindow(BuildContext context) {
  if (showColorPickerNotifier.value) return;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showColorPicker'), true));
  showColorPickerNotifier.value = true;
}

void hideColorPickerWindow() {
  showColorPickerNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showColorPicker'), false));
}

class GlobalColorPickerWindow extends StatefulWidget {
  final VoidCallback onClose;
  final bool isDocked;
  final VoidCallback? onFocus;
  
  const GlobalColorPickerWindow({
    super.key, 
    required this.onClose, 
    this.onFocus, 
    this.isDocked = false
  });

  @override
  State<GlobalColorPickerWindow> createState() => _GlobalColorPickerWindowState();
}

class _GlobalColorPickerWindowState extends State<GlobalColorPickerWindow> {
  bool _isLoaded = false;
  bool _showingCustomColor = false;
  SwatchSortMethod _sortMethod = SwatchSortMethod.curated;
  double _width = 350;
  double _height = 450;
  double _bgOpacity = 0.4;
  Offset _offset = const Offset(300, 300);

  Color? _currentColor;
  ColorSwatch? _currentSwatch;
  late final TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController();
    _loadPreferences();
    VisualEditorScreen.currentWorkspace.addListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.addListener(_loadPreferences);
    VisualEditorScreen.activeWindowNotifier.addListener(_onActiveWindowChanged);
    GlobalPickerState.instance.activeColorRequest.addListener(_onRequestChanged);
    if (GlobalPickerState.instance.activeColorRequest.value != null) {
      _currentColor = GlobalPickerState.instance.activeColorRequest.value!.initialColor;
      _updateHexController();
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    VisualEditorScreen.currentWorkspace.removeListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.removeListener(_loadPreferences);
    GlobalPickerState.instance.activeColorRequest.removeListener(_onRequestChanged);
    VisualEditorScreen.activeWindowNotifier.removeListener(_onActiveWindowChanged);
    super.dispose();
  }

  void _onActiveWindowChanged() {
    if (mounted) setState(() {});
  }

  void _updateHexController() {
    if (_currentColor != null) {
      String newText = _currentColor!.value.toRadixString(16).padLeft(8, '0').toUpperCase();
      if (newText.startsWith('FF')) {
        newText = newText.substring(2);
      }
      if (_hexController.text != newText) {
        _hexController.text = newText;
      }
    } else {
      if (_hexController.text != '') {
        _hexController.text = '';
      }
    }
  }

  void _onHexChanged(String value) {
    String cleanValue = value.trim().replaceAll('#', '');
    if (cleanValue.length == 6) {
      cleanValue = 'FF$cleanValue';
    }
    if (cleanValue.length == 8) {
      final int? val = int.tryParse(cleanValue, radix: 16);
      if (val != null) {
        setState(() {
          _currentColor = Color(val);
        });
        final req = GlobalPickerState.instance.activeColorRequest.value;
        if (req != null) req.onColorSelected(_currentColor);
      }
    }
  }

  // (dispose has been moved above)

  void _onRequestChanged() {
    final req = GlobalPickerState.instance.activeColorRequest.value;
    if (req != null) {
      setState(() {
        _currentColor = req.initialColor;
        _updateHexController();
      });
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isLoaded = true;
        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('col_picker_width')) ?? 350;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('col_picker_height')) ?? 450;
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.4;
        double dx = prefs.getDouble(VisualEditorScreen.getPrefKey('col_picker_dx')) ?? 300;
        double dy = prefs.getDouble(VisualEditorScreen.getPrefKey('col_picker_dy')) ?? 300;
        _offset = Offset(dx, dy);
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('col_picker_width'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('col_picker_height'), _height);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('col_picker_dx'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('col_picker_dy'), _offset.dy);
  }

  static const MaterialColor _customBW = MaterialColor(
    0xFFFFFFFF,
    <int, Color>{
      50: Color(0xFFFFFFFF),
      100: Color(0xFFE0E0E0),
      200: Color(0xFFC0C0C0),
      300: Color(0xFFA0A0A0),
      400: Color(0xFF808080),
      500: Color(0xFF606060),
      600: Color(0xFF404040),
      700: Color(0xFF202020),
      800: Color(0xFF101010),
      900: Color(0xFF000000),
    },
  );
  
  static const MaterialColor _customNavy = MaterialColor(0xFF0D47A1, <int, Color>{50: Color(0xFFE3F2FD), 100: Color(0xFFBBDEFB), 200: Color(0xFF90CAF9), 300: Color(0xFF64B5F6), 400: Color(0xFF42A5F5), 500: Color(0xFF2196F3), 600: Color(0xFF1E88E5), 700: Color(0xFF1976D2), 800: Color(0xFF1565C0), 900: Color(0xFF0D47A1)});
  static const MaterialColor _customForest = MaterialColor(0xFF1B5E20, <int, Color>{50: Color(0xFFE8F5E9), 100: Color(0xFFC8E6C9), 200: Color(0xFFA5D6A7), 300: Color(0xFF81C784), 400: Color(0xFF66BB6A), 500: Color(0xFF4CAF50), 600: Color(0xFF43A047), 700: Color(0xFF388E3C), 800: Color(0xFF2E7D32), 900: Color(0xFF1B5E20)});
  static const MaterialColor _customCrimson = MaterialColor(0xFFB71C1C, <int, Color>{50: Color(0xFFFFEBEE), 100: Color(0xFFFFCDD2), 200: Color(0xFFEF9A9A), 300: Color(0xFFE57373), 400: Color(0xFFEF5350), 500: Color(0xFFF44336), 600: Color(0xFFE53935), 700: Color(0xFFD32F2F), 800: Color(0xFFC62828), 900: Color(0xFFB71C1C)});
  static const MaterialColor _customOrange = MaterialColor(0xFFE65100, <int, Color>{50: Color(0xFFFFF3E0), 100: Color(0xFFFFE0B2), 200: Color(0xFFFFCC80), 300: Color(0xFFFFB74D), 400: Color(0xFFFFA726), 500: Color(0xFFFF9800), 600: Color(0xFFFB8C00), 700: Color(0xFFF57C00), 800: Color(0xFFEF6C00), 900: Color(0xFFE65100)});
  static const MaterialColor _customViolet = MaterialColor(0xFF4A148C, <int, Color>{50: Color(0xFFF3E5F5), 100: Color(0xFFE1BEE7), 200: Color(0xFFCE93D8), 300: Color(0xFFBA68C8), 400: Color(0xFFAB47BC), 500: Color(0xFF9C27B0), 600: Color(0xFF8E24AA), 700: Color(0xFF7B1FA2), 800: Color(0xFF6A1B9A), 900: Color(0xFF4A148C)});
  static const MaterialColor _customMint = MaterialColor(0xFF00BFA5, <int, Color>{50: Color(0xFFE0F2F1), 100: Color(0xFFB2DFDB), 200: Color(0xFF80CBC4), 300: Color(0xFF4DB6AC), 400: Color(0xFF26A69A), 500: Color(0xFF009688), 600: Color(0xFF00897B), 700: Color(0xFF00796B), 800: Color(0xFF00695C), 900: Color(0xFF004D40)});
  static const MaterialColor _customGold = MaterialColor(0xFFFFD54F, <int, Color>{50: Color(0xFFFFF8E1), 100: Color(0xFFFFECB3), 200: Color(0xFFFFE082), 300: Color(0xFFFFD54F), 400: Color(0xFFFFCA28), 500: Color(0xFFFFC107), 600: Color(0xFFFFB300), 700: Color(0xFFFFA000), 800: Color(0xFFFF8F00), 900: Color(0xFFFF6F00)});
  static const MaterialColor _customRose = MaterialColor(0xFFC2185B, <int, Color>{50: Color(0xFFFCE4EC), 100: Color(0xFFF8BBD0), 200: Color(0xFFF48FB1), 300: Color(0xFFF06292), 400: Color(0xFFEC407A), 500: Color(0xFFE91E63), 600: Color(0xFFD81B60), 700: Color(0xFFC2185B), 800: Color(0xFFAD1457), 900: Color(0xFF880E4F)});

  List<ColorSwatch?> get _allSwatches {
    final baseList = <ColorSwatch?>[
      null,
      _customBW,
      Colors.redAccent,
      Colors.red,
      _customCrimson,
      Colors.pinkAccent,
      Colors.pink,
      Colors.purpleAccent,
      Colors.purple,
      _customViolet,
      _customRose,
      Colors.deepPurpleAccent,
      Colors.deepPurple,
      Colors.indigoAccent,
      Colors.indigo,
      _customNavy,
      Colors.blueAccent,
      Colors.blue,
      Colors.lightBlueAccent,
      Colors.lightBlue,
      Colors.cyanAccent,
      Colors.cyan,
      Colors.tealAccent,
      Colors.teal,
      _customMint,
      _customForest,
      Colors.greenAccent,
      Colors.green,
      Colors.lightGreenAccent,
      Colors.lightGreen,
      Colors.limeAccent,
      Colors.lime,
      Colors.yellowAccent,
      Colors.yellow,
      Colors.amberAccent,
      Colors.amber,
      _customGold,
      Colors.orangeAccent,
      Colors.orange,
      _customOrange,
      Colors.deepOrangeAccent,
      Colors.deepOrange,
      Colors.brown,
      Colors.blueGrey,
    ];

    if (_sortMethod == SwatchSortMethod.curated) {
      return baseList;
    }

    final validSwatches = baseList.whereType<ColorSwatch>().toList();

    if (_sortMethod == SwatchSortMethod.hsv) {
      validSwatches.sort((a, b) {
        final hsvA = HSVColor.fromColor(a);
        final hsvB = HSVColor.fromColor(b);
        int cmp = hsvA.hue.compareTo(hsvB.hue);
        if (cmp == 0) cmp = hsvA.saturation.compareTo(hsvB.saturation);
        if (cmp == 0) cmp = hsvA.value.compareTo(hsvB.value);
        return cmp;
      });
    } else if (_sortMethod == SwatchSortMethod.lightness) {
      validSwatches.sort((a, b) {
        final hsvA = HSVColor.fromColor(a);
        final hsvB = HSVColor.fromColor(b);
        int cmp = hsvA.value.compareTo(hsvB.value);
        if (cmp == 0) cmp = hsvA.saturation.compareTo(hsvB.saturation);
        if (cmp == 0) cmp = hsvA.hue.compareTo(hsvB.hue);
        return -cmp; // sort from lightest to darkest
      });
    }

    return [null, ...validSwatches];
  }

  ColorSwatch? _getSwatchForColor(Color? color) {
    if (color == null) return null;
    final int rgb = color.value & 0x00FFFFFF;
    
    // Pass 1: Exact Primary Matches (prioritize selecting the swatch circle the user actually clicked)
    for (var swatch in _allSwatches) {
      if (swatch == null) continue;
      if ((swatch.value & 0x00FFFFFF) == rgb) return swatch;
    }
    
    // Pass 2: Fallback to matching shades
    for (var swatch in _allSwatches) {
      if (swatch == null) continue;
      final keys = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900];
      for (int i = 0; i < keys.length; i++) {
        final c1 = swatch[keys[i]];
        if (c1 != null && (c1.value & 0x00FFFFFF) == rgb) return swatch;
        if (i < keys.length - 1) {
          final c2 = swatch[keys[i + 1]];
          if (c1 != null && c2 != null) {
            final mid = Color.lerp(c1, c2, 0.5)!;
            if ((mid.value & 0x00FFFFFF) == rgb) return swatch;
          }
        }
      }
    }
    return null;
  }

  Widget _buildShades() {
    if (_currentColor == null) return const SizedBox.shrink();
    final swatch = _getSwatchForColor(_currentColor);
    final int alpha = _currentColor!.alpha;
    List<Color> shades = [];

    if (swatch != null) {
      final keys = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900];
      final availableKeys = keys.where((k) => swatch[k] != null).toList();
      
      if (availableKeys.isNotEmpty) {
        final lightest = swatch[availableKeys.first]!;
        shades.add(Color.lerp(Colors.white, lightest, 0.3)!.withAlpha(alpha));
        shades.add(Color.lerp(Colors.white, lightest, 0.6)!.withAlpha(alpha));
        
        for (int i = 0; i < keys.length; i++) {
          final c1 = swatch[keys[i]];
          if (c1 != null) {
            shades.add(c1.withAlpha(alpha));
            if (i < keys.length - 1) {
              final c2 = swatch[keys[i + 1]];
              if (c2 != null) {
                shades.add(Color.lerp(c1, c2, 0.5)!.withAlpha(alpha));
              }
            }
          }
        }
        
        final darkest = swatch[availableKeys.last]!;
        shades.add(Color.lerp(darkest, Colors.black, 0.3)!.withAlpha(alpha));
        shades.add(Color.lerp(darkest, Colors.black, 0.6)!.withAlpha(alpha));
        shades.add(Color.lerp(darkest, Colors.black, 0.8)!.withAlpha(alpha));
      } else {
        shades.add(swatch.withAlpha(alpha));
      }
    } else {
      final baseColor = _currentColor!.withAlpha(255);
      final hsl = HSLColor.fromColor(baseColor);
      for (int i = 0; i <= 24; i++) {
          final double lightness = 0.96 - (i * 0.038);
          shades.add(hsl.withLightness(lightness.clamp(0.0, 1.0)).toColor().withAlpha(alpha));
      }
    }
    
    // Remove duplicate color entries from shades
    shades = shades.toSet().toList();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select color shade', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: shades.map((c) => GestureDetector(
              onTap: () {
                setState(() => _currentColor = c);
                _updateHexController();
                final req = GlobalPickerState.instance.activeColorRequest.value;
                if (req != null) req.onColorSelected(c);
              },
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: _currentColor?.value == c.value ? Colors.white : Colors.white24, width: _currentColor?.value == c.value ? 2 : 1),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))
                  ]
                ),
                child: _currentColor?.value == c.value ? Icon(Icons.check, size: 10, color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white) : null,
              ),
            )).toList(),
          )
        ]
      )
    );
  }



  Widget _buildContent() {
    return Container(
      color: AppColors.panelBackground,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
               padding: const EdgeInsets.all(16),
               child: Row(
                  children: [
                     Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                           color: _currentColor ?? Colors.transparent,
                           borderRadius: BorderRadius.zero,
                           border: Border.all(color: Colors.white24)
                        ),
                        child: _currentColor == null ? const Icon(Icons.format_color_reset, color: Colors.white24) : null,
                     ),
                     const SizedBox(width: 16),
                     Expanded(
                       child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             if (_currentColor == null)
                                Text('None', style: TextStyle(color: AppColors.panelTextSecondary))
                             else
                                Row(
                                   children: [
                                      SizedBox(
                                         height: 20,
                                         width: 100,
                                         child: TextField(
                                            controller: _hexController,
                                            style: TextStyle(color: AppColors.panelTextSecondary, fontSize: 13),
                                            decoration: InputDecoration(
                                               prefixText: '#',
                                               prefixStyle: TextStyle(color: AppColors.panelTextSecondary, fontSize: 13),
                                               isDense: true,
                                               contentPadding: EdgeInsets.zero,
                                               border: InputBorder.none,
                                            ),
                                            onChanged: _onHexChanged,
                                         ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                         icon: Icon(Icons.copy, size: 14, color: AppColors.panelTextSecondary),
                                         padding: EdgeInsets.zero,
                                         constraints: const BoxConstraints(),
                                         onPressed: () {
                                            Clipboard.setData(ClipboardData(text: '#${_hexController.text}'));
                                         },
                                      )
                                   ]
                                )
                          ]
                       ),
                     ),
                     Row(
                        children: [
                           Container(
                             decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               border: Border.all(color: Colors.white24, width: 1.0),
                             ),
                             child: IconButton(
                               icon: const Icon(Icons.colorize, size: 16),
                               color: Colors.white,
                               padding: const EdgeInsets.all(8),
                               constraints: const BoxConstraints(),
                               onPressed: () {
                                 Future.delayed(const Duration(milliseconds: 50), () {
                                   EyeDrop.of(context).capture(context, (Color c) {
                                     setState(() => _currentColor = c);
                                     _updateHexController();
                                     final req = GlobalPickerState.instance.activeColorRequest.value;
                                     if (req != null) req.onColorSelected(c);
                                   }, null);
                                 });
                               },
                             ),
                           ),
                           const SizedBox(width: 8),
                           Tooltip(
                             message: 'Custom',
                             child: Container(
                               decoration: BoxDecoration(
                                 shape: BoxShape.circle,
                                 border: Border.all(color: Colors.white24, width: 1.0),
                               ),
                               child: IconButton(
                                 icon: const Icon(Icons.palette, size: 16),
                                 color: Colors.white,
                                 padding: const EdgeInsets.all(8),
                                 constraints: const BoxConstraints(),
                                 onPressed: () {
                                   setState(() => _showingCustomColor = !_showingCustomColor);
                                 },
                               ),
                             ),
                           )
                        ]
                     )
                  ]
               )
            ),
            
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 16),
            
            if (_showingCustomColor) ...[
               ColorPicker(
                  color: _currentColor ?? Colors.white,
                  onColorChanged: (c) {
                     setState(() => _currentColor = c);
                     _updateHexController();
                     final req = GlobalPickerState.instance.activeColorRequest.value;
                     if (req != null) req.onColorSelected(c);
                  },
                  pickersEnabled: const {
                     ColorPickerType.both: false,
                     ColorPickerType.primary: false,
                     ColorPickerType.accent: false,
                     ColorPickerType.bw: false,
                     ColorPickerType.custom: false,
                     ColorPickerType.customSecondary: false,
                     ColorPickerType.wheel: true,
                  },
                  enableShadesSelection: false,
                  enableOpacity: true,
               )
            ] else ...[
              Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 16),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text('Swatches', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
                     Row(
                       children: SwatchSortMethod.values.map((method) {
                         final isSelected = _sortMethod == method;
                         return Padding(
                           padding: const EdgeInsets.only(left: 4),
                           child: InkWell(
                             onTap: () {
                               setState(() {
                                 _sortMethod = method;
                               });
                             },
                             child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                               decoration: BoxDecoration(
                                 color: isSelected ? AppColors.accent.withOpacity(0.2) : Colors.transparent,
                                 borderRadius: BorderRadius.circular(4),
                                 border: Border.all(color: isSelected ? AppColors.accent : Colors.white12),
                               ),
                               child: Text(
                                 method.name.toUpperCase(),
                                 style: TextStyle(
                                   fontSize: 9,
                                   color: isSelected ? Colors.white : Colors.white54,
                                   fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                 ),
                               ),
                             ),
                           ),
                         );
                       }).toList(),
                     )
                   ]
                 ),
              ),
              const SizedBox(height: 12),
              Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 16),
                 child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _allSwatches.map((swatch) {
                       bool isSelected = false;
                       if (_currentColor == null) {
                           isSelected = swatch == null;
                       } else {
                           isSelected = _getSwatchForColor(_currentColor) == swatch && swatch != null;
                       }
                       return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                             setState(() => _currentColor = swatch);
                             _updateHexController();
                             final req = GlobalPickerState.instance.activeColorRequest.value;
                             if (req != null) req.onColorSelected(swatch);
                          },
                          child: Container(
                             width: 16, height: 16,
                             decoration: BoxDecoration(
                                color: swatch ?? Colors.transparent,
                                borderRadius: BorderRadius.zero,
                                border: Border.all(color: isSelected ? Colors.white : Colors.white24, width: isSelected ? 2 : 1)
                             ),
                             child: swatch == null
                                 ? const Icon(Icons.format_color_reset, size: 14, color: Colors.white24)
                                 : (isSelected ? Icon(Icons.check, size: 14, color: swatch.computeLuminance() > 0.5 ? Colors.black : Colors.white) : null),
                          )
                       );
                    }).toList()
                 )
              ),
              const SizedBox(height: 8),
              _buildShades(),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
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
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'color_picker' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) : null,
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
                              Icon(Icons.color_lens,
                                  size: 16 / scale, color: AppToolWindows.getDef('color_picker').color),
                              const SizedBox(width: 8),
                              Text(AppUIConfig.formatWindowTitle('Color Picker'), style: TextStyle(
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
