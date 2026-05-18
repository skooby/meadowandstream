import 'package:flutter/material.dart';
import 'package:music_app/constants.dart';
import 'package:flutter/foundation.dart';
import 'element_registry.dart';

class AnnotationCanvasLayer extends StatelessWidget {
   const AnnotationCanvasLayer({super.key});

   @override
   Widget build(BuildContext context) {
      if (kReleaseMode) return const SizedBox();

      return ListenableBuilder(
         listenable: ElementRegistry.instance,
         builder: (context, _) {
            final activeLinks = ElementRegistry.instance.activeLayerLinks.entries.toList();
            if (activeLinks.isEmpty || (!ElementRegistry.instance.annotationsVisible && ElementRegistry.instance.hoveredId == null && ElementRegistry.instance.selectedId == null)) return const SizedBox();

            return Stack(
               clipBehavior: Clip.none,
               children: activeLinks.map((e) {
                  final k = ElementRegistry.instance.activeKeys[e.key];
                  bool isTopHalf = false;
                  if (k?.currentContext != null && k!.currentContext!.mounted) {
                     try {
                        final ro = k.currentContext!.findRenderObject();
                        if (ro is RenderBox && ro.hasSize) {
                           final pos = ro.localToGlobal(Offset.zero);
                           if (pos.dy < 300) isTopHalf = true;
                        }
                     } catch (_) {}
                  }

                  final noteInfo = ElementRegistry.instance.getNoteData(e.key);
                  final isHovered = ElementRegistry.instance.hoveredId == e.key;
                  final isSelected = ElementRegistry.instance.selectedId == e.key;
                  
                  bool shouldShowGlobally = ElementRegistry.instance.annotationsVisible;
                  if (!shouldShowGlobally && !isHovered && !isSelected) return const SizedBox();
                  if (noteInfo == null && !isHovered && !isSelected) return const SizedBox();
                  
                  final noteText = noteInfo?['note'] ?? '';
                  final color = Color(int.tryParse(noteInfo?['color'] ?? 'FFFFAB40', radix: 16) ?? 0xFFFFAB40);

                  return Positioned(
                     top: 0, left: 0,
                     child: CompositedTransformFollower(
                        link: e.value,
                        showWhenUnlinked: false,
                        targetAnchor: isTopHalf ? Alignment.bottomCenter : Alignment.topCenter,
                        followerAnchor: isTopHalf ? Alignment.topCenter : Alignment.bottomCenter,
                        offset: Offset(0, isTopHalf ? 8 : -8),
                        child: Material(
                           color: Colors.transparent,
                           elevation: 28, // Simulator is 24. This floats it strictly above securely but below floating top-level toolbars natively.
                           shadowColor: Colors.transparent,
                           child: IgnorePointer(
                              child: Container(
                                 padding: EdgeInsets.symmetric(horizontal: noteText.isEmpty ? 4 : 8, vertical: noteText.isEmpty ? 4 : 6),
                                 constraints: const BoxConstraints(minWidth: 10, maxWidth: 180),
                                 decoration: BoxDecoration(
                                    color: color.withOpacity(0.9), 
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.borderSubtle),
                                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
                                 ),
                                 child: noteText.isEmpty ? const SizedBox(width: 8, height: 8) : Text(noteText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold, height: 1.3)),
                              )
                           )
                        )
                     )
                  );
               }).toList()
            );
         }
      );
   }
}
