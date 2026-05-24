import 'package:flutter/material.dart';

class SceneNode {
  final String name;
  final String id;
  final Rect? bounds;
  final List<SceneNode> children;

  // Natively capture some important properties
  final Map<String, dynamic> properties;

  SceneNode({
    required this.name,
    required this.id,
    this.bounds,
    required this.children,
    this.properties = const {},
  });
}

class SceneGraphWalker {
  /// Recursively walks down the active `Element` tree starting from `rootContext`
  /// and builds a localized diagnostic Scene Graph mapped to geometric screen coordinates.
  static SceneNode buildGraph(BuildContext rootContext) {
    final root = SceneNode(name: "Root", id: "root", children: []);

    void walk(Element element, SceneNode? parentNode,
        String nearestCustomComponent, String domPath) {
      final widget = element.widget;
      final typeName = widget.runtimeType.toString();

      // Filter out overly noisy framework internals to make the tree readable.
      bool isMeaningful = true;
      const noiseList = {
        'RepaintBoundary', 'Semantics', 'Builder', 'StatefulBuilder',
        'LayoutBuilder',
        'KeyedSubtree', 'DefaultTextStyle', 'MediaQuery', 'Directionality',
        'ScrollConfiguration', 'PrimaryScrollController',
        'NotificationListener',
        'ExcludeSemantics', 'AnimatedBuilder', 'ValueListenableBuilder',
        'FractionallySizedBox',
        'ListenableBuilder', 'FocusScope', 'Focus', 'UnmanagedRestorationScope',
        'FittedBox',
        'RestorationScope', 'IntrinsicWidth', 'IntrinsicHeight',
        'EnsureVisible',
        'Scrollable', 'Viewport', 'View', 'HeroControllerScope',
        'CupertinoTheme',
        'AnimatedTheme', 'Theme', 'AnimatedDefaultTextStyle',
        'DefaultSelectionStyle',
        'MaterialApp', 'Router', 'Navigator', 'Overlay', 'SafeArea',
        'IgnorePointer',
        'AbsorbPointer', 'Listener', 'AnnotatedRegion', 'IconTheme',
        'ThemeData',
        'Material', 'InkResponse', 'TouchRipple', 'InkWell', 'GestureDetector',
        'Padding',
        'Center', 'Align', 'SizedBox', 'Expanded', 'Flexible', 'Flex',
        'Positioned', 'RichText',
        'ConstrainedBox', 'DecoratedBox', 'LimitedBox', 'Offstage',
        'OverflowBox', 'Transform',
        'RawGestureDetector', 'MouseRegion', 'Tooltip', 'Ink', 'Actions',
        'IconButtonTheme',
        'ElevatedButtonTheme', 'TextButtonTheme', 'ButtonStyleButton',
        '_', // We dynamically handle '_' prefix below
      };

      const layerClasses = {
        'Text',
        'Icon',
        'Image',
        'IconButton',
        'ListTile',
        'ElevatedButton',
        'TextButton',
        'FloatingActionButton',
        'Checkbox',
        'Switch',
        'Slider',
        'Radio'
      };

      const primitives = {
        'Container',
        'Row',
        'Column',
        'Stack',
        'SizedBox',
        'Expanded',
        'Flexible',
        'Center',
        'Padding',
        'ListView',
        'ReorderableListView',
        'SingleChildScrollView',
        'Scaffold',
        'AbsorbPointer',
        'IgnorePointer',
        'Card',
        'Align',
        'ClipRRect',
        'ClipRect',
        'SafeArea',
        'DecoratedBox',
        'ConstrainedBox',
        'FittedBox',
        'Scrollbar',
        'CustomPaint',
        'Material',
        'InkResponse',
        'InkWell',
        'Semantics',
        'Tooltip',
        'SnapshotWidget',
        'ReorderableItem',
        'Draggable',
        'DragTarget',
        'LongPressDraggable'
      };

      String currentComponentOwner = nearestCustomComponent;
      String nextDomPath = domPath;
      final isFrameworkSuffix = typeName.endsWith('Listener') ||
          typeName.endsWith('Builder') ||
          typeName.endsWith('Inherited') ||
          typeName.endsWith('Theme') ||
          typeName.endsWith('Provider') ||
          typeName.endsWith('Scope') ||
          typeName.endsWith('Controller') ||
          typeName.endsWith('Transition');

      bool isCustomUserWidget = false;
      if (!typeName.startsWith('_') && !noiseList.contains(typeName)) {
        if (!primitives.contains(typeName) &&
            !layerClasses.contains(typeName) &&
            !isFrameworkSuffix &&
            !typeName.contains('Layout')) {
          isCustomUserWidget = true;
          currentComponentOwner = typeName;
          // STRICTLY reset path so it never bubbles into WidgetsApp or Root wrappers!
          nextDomPath = typeName;
        } else {
          final cleanType = typeName.split('<').first; // Strip Generics spam
          nextDomPath += nextDomPath.isEmpty ? cleanType : " > $cleanType";
        }
      }

      if (typeName.startsWith('_') ||
          noiseList.contains(typeName) ||
          (primitives.contains(typeName)) ||
          isFrameworkSuffix) {
        isMeaningful = false;
      }

      // Explicitly show base visual layers AND custom user widgets
      if (layerClasses.contains(typeName) || isCustomUserWidget) {
        isMeaningful = true;
      }

      final typeStr = widget.key.runtimeType.toString();
      bool hasActionableKey = widget.key != null &&
          (typeStr == "ValueKey<String>" || typeStr == "ValueKey<int>");

      String nameLabel = typeName;
      if (hasActionableKey) {
        // Clean ValueKey string extraction safely
        String keyStr =
            widget.key.toString().replaceAll(RegExp(r"[<>'\[\]]"), "");
        if (keyStr.startsWith("ValueKey("))
          keyStr = keyStr
              .replaceAll("ValueKey(", "")
              .replaceAll(")", "")
              .replaceAll("'", "");
        nameLabel += " [#$keyStr]";
      }

      // EXPOSE INTERNAL ROOT SYSTEM MEMORY ADDRESS EXPLICITLY NATIVELY
      nameLabel += " [Mem:${element.hashCode}]";

      Rect? bounds;
      final ro = element.renderObject;
      if (ro is RenderBox && ro.hasSize) {
        try {
          final pos = ro.localToGlobal(Offset.zero);
          bounds = pos & ro.size;
        } catch (_) {}
      }

      // Dynamically reflect properties natively from the widget instance via Flutter's internal Diagnostics!
      Map<String, dynamic> props = {};

      if (hasActionableKey) {
        String keyStr =
            widget.key.toString().replaceAll(RegExp(r"[<>'\[\]]"), "");
        if (keyStr.startsWith("ValueKey("))
          keyStr = keyStr
              .replaceAll("ValueKey(", "")
              .replaceAll(")", "")
              .replaceAll("'", "");
        props['Codebase ID'] = keyStr;
      }

      try {
        final diagNode = widget.toDiagnosticsNode();
        final properties = diagNode.getProperties();
        for (var prop in properties) {
          if (prop.name != null && prop.value != null) {
            final String valStr = prop.value.toString();
            if (valStr == 'null' ||
                valStr.isEmpty ||
                prop.name == 'dependencies' ||
                prop.name == 'child') continue;
            props[prop.name!] = valStr;
          }
        }
      } catch (_) {
        // Silently fail if generic reflective diagnostics crash on a custom class
      }

      // Contextualize generic components dynamically linking back to their parent builder class!
      if (currentComponentOwner.isNotEmpty &&
          currentComponentOwner != typeName) {
        props['ownerClass'] = currentComponentOwner;
      }

      // Aggressive child scraper attached natively to the walk operation
      final List<String> internalChildrenCtx = [];
      String extractedSurfaceText = "";

      void nestedScrape(Element e) {
        if (e.widget is Text) {
          final pureText = (e.widget as Text).data ?? '';
          internalChildrenCtx.add("Text: '$pureText'");
          if (extractedSurfaceText.isEmpty && pureText.trim().isNotEmpty) {
            extractedSurfaceText = pureText;
          }
        } else if (e.widget is Icon)
          internalChildrenCtx
              .add("Icon: ${(e.widget as Icon).icon?.codePoint}");
        else if (e.widget is Tooltip)
          internalChildrenCtx
              .add("Tooltip: '${(e.widget as Tooltip).message}'");
        e.visitChildren(nestedScrape);
      }

      element.visitChildren(nestedScrape);
      if (internalChildrenCtx.isNotEmpty) {
        props['childContexts'] = internalChildrenCtx;
        // natively bind inner label directly to the wrapper node!
        if (extractedSurfaceText.isNotEmpty && widget is! Text) {
          String s = extractedSurfaceText;
          if (s.length > 20) s = "${s.substring(0, 20)}...";
          nameLabel += ' ("$s")';
        }
      }

      // Explicitly append naming label descriptors for the tree viewer
      if (widget is Text) {
        final txt = widget.data ?? widget.textSpan?.toPlainText() ?? '';
        nameLabel +=
            ' ("${txt.length > 20 ? '${txt.substring(0, 20)}...' : txt}")';
        isMeaningful = true; // Text is inherently semantic
      } else if (widget is Container) {
        props['color'] = widget.color?.toString();
      } else if (widget is SizedBox) {
        props['width'] = widget.width;
        props['height'] = widget.height;
      } else if (widget is Icon) {
        final iconData = widget.icon;
        if (iconData != null) {
          final family = iconData.fontFamily ?? "MaterialIcons";
          // Map the literal font namespace along with the hex codePoint mapped to it!
          nameLabel += ' [$family: ${iconData.codePoint}]';
          props['fontFamily'] = family;
          props['codePoint'] = iconData.codePoint.toString();
        } else {
          nameLabel += ' (Graphic)';
        }
        isMeaningful = true;
      } else if (widget is Image) {
        props['image'] = widget.image.toString();
        // Condense verbose FileImage or NetworkImage strings into a clean UI label bracket
        String shortImg = props['image'];
        if (shortImg.length > 25) shortImg = "${shortImg.substring(0, 25)}...";
        nameLabel += ' [$shortImg]';
        isMeaningful = true; // Image bounds are always semantic
      }

      SceneNode? currentNode;

      if (isMeaningful) {
        currentNode = SceneNode(
          name: nameLabel,
          id: element.hashCode.toString(),
          bounds: bounds,
          children: [],
          properties: props,
        );
        // Expose locator CSS-style pathing
        if (nextDomPath.isNotEmpty)
          currentNode.properties['structuralLocator'] = nextDomPath;

        if (parentNode != null) {
          parentNode.children.add(currentNode);
        }
      }

      final passNode = isMeaningful ? currentNode : parentNode;
      element.visitChildren(
          (e) => walk(e, passNode, currentComponentOwner, nextDomPath));
    }

    if (rootContext is Element) {
      rootContext.visitChildren((e) => walk(e, root, "Root", ""));
    }

    return root;
  }
}
