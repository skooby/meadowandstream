import 'package:music_app/constants.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ElementRegistry extends ChangeNotifier {
  static final ElementRegistry instance = ElementRegistry._();
  ElementRegistry._();

  final Map<String, dynamic> activeElements = {};
  final Map<String, GlobalKey> activeKeys = {};
  
  bool isInspecting = false;
  String? hoveredId;
  String? selectedId;
  
  final Map<String, Map<String, dynamic>> elementNotes = {};
  bool annotationsVisible = true;

  Future<void> loadNotes() async {
     try {
       final prefs = await SharedPreferences.getInstance();
       annotationsVisible = prefs.getBool('elementNotes_visible') ?? true;

       final str = prefs.getString('elementNotes_v2');
       if (str != null) {
          final map = jsonDecode(str) as Map<String, dynamic>;
          elementNotes.clear();
          for (final kv in map.entries) {
             elementNotes[kv.key] = Map<String, dynamic>.from(kv.value);
          }
       }
       // Call notify at the end of load
       _safeNotify();
     } catch(_) {}
  }

  void toggleAnnotations() async {
      annotationsVisible = !annotationsVisible;
      _safeNotify();
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('elementNotes_visible', annotationsVisible);
  }

  void setNote(String id, String note, {String? colorHex}) async {
    if (note.trim().isEmpty) {
       elementNotes.remove(id);
    } else {
       elementNotes[id] = {
           'note': note,
           'color': colorHex ?? elementNotes[id]?['color'] ?? 'FFFFAB40', // Amber default
       };
    }
    _safeNotify();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('elementNotes_v2', jsonEncode(elementNotes));
  }
  
  Map<String, dynamic>? getNoteData(String id) => elementNotes[id];

  void toggleInspectMode() {
    isInspecting = !isInspecting;
    if (!isInspecting) {
       hoveredId = null;
    }
    notifyListeners();
  }

  void setHover(String? id) {
    if (hoveredId != id) {
       hoveredId = id;
       notifyListeners();
    }
  }

  void selectElement(String id) {
    selectedId = id;
    isInspecting = false; // Turn off immediately after picking!
    hoveredId = null;
    print("Clicked Object ID: $id");
    notifyListeners();
  }

  void _safeNotify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  final Map<String, LayerLink> activeLayerLinks = {};

  void register(String id, {dynamic meta, GlobalKey? key, LayerLink? link}) {
    activeElements[id] = meta ?? {};
    if (key != null) activeKeys[id] = key;
    if (link != null) activeLayerLinks[id] = link;
    _safeNotify();
  }

  void unregister(String id) {
    activeElements.remove(id);
    activeKeys.remove(id);
    activeLayerLinks.remove(id);
    if (hoveredId == id) hoveredId = null;
    if (selectedId == id) selectedId = null;
    _safeNotify();
  }
}

class ActiveScreenScope extends InheritedWidget {
  final String screenName;

  const ActiveScreenScope({
    super.key,
    required this.screenName,
    required super.child,
  });

  static String? of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ActiveScreenScope>();
    return scope?.screenName;
  }

  @override
  bool updateShouldNotify(ActiveScreenScope old) => screenName != old.screenName;
}

class RegisteredElement extends StatefulWidget {
  final String id;
  final Widget child;
  final dynamic meta;

  const RegisteredElement({
    super.key, 
    required this.id, 
    required this.child, 
    this.meta
  });

  @override
  State<RegisteredElement> createState() => _RegisteredElementState();
}

class _RegisteredElementState extends State<RegisteredElement> {
  final GlobalKey _key = GlobalKey();
  final LayerLink _layerLink = LayerLink();

  @override
  void didUpdateWidget(RegisteredElement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!kReleaseMode && (oldWidget.id != widget.id || oldWidget.meta != widget.meta)) {
      ElementRegistry.instance.unregister(oldWidget.id);
      _register();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  void _register() {
      if (kReleaseMode) return;
      dynamic finalMeta = widget.meta ?? <String, dynamic>{};
      
      // Attempt to find the nearest screen scope
      if (mounted) {
         final screenName = ActiveScreenScope.of(context);
         if (screenName != null) {
            if (finalMeta is Map) {
               finalMeta = Map<String, dynamic>.from(finalMeta);
               finalMeta['screen'] = screenName;
            }
         }
      }
      
      ElementRegistry.instance.register(widget.id, meta: finalMeta, key: _key, link: _layerLink);
  }

  @override
  void dispose() {
    if (!kReleaseMode) ElementRegistry.instance.unregister(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
     if (kReleaseMode) return widget.child;
    
    return KeyedSubtree(
       key: _key,
       child: ListenableBuilder(
         listenable: ElementRegistry.instance,
         builder: (context, _) {
             final isInspecting = ElementRegistry.instance.isInspecting;
             final isHovered = ElementRegistry.instance.hoveredId == widget.id;
             final isSelected = ElementRegistry.instance.selectedId == widget.id;
             final noteInfo = ElementRegistry.instance.getNoteData(widget.id);

             if (!isInspecting && !isSelected && !isHovered && noteInfo == null) {
                return widget.child;
             }

          return MouseRegion(
             onEnter: (_) {
                 ElementRegistry.instance.setHover(widget.id);
             },
             onExit: (_) {
                 if (ElementRegistry.instance.hoveredId == widget.id) {
                    ElementRegistry.instance.setHover(null);
                 }
             },
             child: GestureDetector(
                onTap: isInspecting ? () {
                   ElementRegistry.instance.selectElement(widget.id);
                } : null,
                behavior: isInspecting ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
                child: CompositedTransformTarget(
                 link: _layerLink,
                 child: DecoratedBox(
                   position: DecorationPosition.foreground,
                   decoration: BoxDecoration(
                      border: (isHovered && isInspecting)
                         ? Border.all(color: Colors.amberAccent, width: 2) 
                         : (isSelected ? Border.all(color: AppColors.accent, width: 2) : null),
                      color: (isHovered && isInspecting) ? Colors.amberAccent.withValues(alpha: 0.2) : Colors.transparent,
                   ),
                   child: widget.child,
                 )
                )
               )
            );
         }
       )
    );
  }
}
