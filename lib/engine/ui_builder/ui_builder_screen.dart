import 'dart:convert';
import 'package:flutter/material.dart';
import 'layout_serializer.dart';

class UiBuilderScreen extends StatefulWidget {
  const UiBuilderScreen({Key? key}) : super(key: key);

  @override
  State<UiBuilderScreen> createState() => _UiBuilderScreenState();
}

class _UiBuilderScreenState extends State<UiBuilderScreen> {
  Map<String, dynamic> _layoutTree = {
    "type": "Stack",
    "id": "root_stack",
    "children": []
  };
  
  String? _selectedNodeId;

  void _importJson() {
    // In a real app we'd open a File Picker here.
    // Stub implementation to load a basic layout:
    setState(() {
      _layoutTree = {
        "type": "Stack",
        "id": "root_stack",
        "children": [
           {
             "type": "Positioned",
             "id": "test_node_1",
             "properties": {"left": 50, "top": 50},
             "child": {
                "type": "Container",
                "id": "test_container_1",
                "properties": {"width": 200, "height": 100, "color": "#2196F3"},
                "child": {
                  "type": "Text",
                  "id": "test_text_1",
                  "properties": {"text": "Imported Node", "color": "#FFFFFF", "fontSize": 18}
                }
             }
           }
        ]
      };
      _selectedNodeId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON layout imported.')));
  }

  void _exportJson() {
    // Stringify and mock export.
    final jsonString = const JsonEncoder.withIndent('  ').convert(_layoutTree);
    debugPrint(jsonString);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON exported to console!')));
  }

  void _addComponent(String type, Offset position) {
    setState(() {
      final children = _layoutTree['children'] as List<dynamic>;
      final newNodeId = 'node_${DateTime.now().millisecondsSinceEpoch}';
      
      Map<String, dynamic> newComponent = {
        "type": type,
        "id": "${newNodeId}_content",
        "properties": {}
      };

      if (type == 'Container') {
        newComponent['properties'] = {"width": 100, "height": 100, "color": "#4CAF50"};
      } else if (type == 'Text') {
        newComponent['properties'] = {"text": "New Text", "color": "#FFFFFF", "fontSize": 16};
      } else if (type == 'Column' || type == 'Row') {
        newComponent['children'] = [];
      }

      // Wrap in Positioned since root is a Stack.
      children.add({
        "type": "Positioned",
        "id": newNodeId,
        "properties": {
          "left": position.dx,
          "top": position.dy,
        },
        "child": newComponent
      });
    });
  }

  Map<String, dynamic>? _findNodeSync(Map<String, dynamic> tree, String targetId) {
    if (tree['id'] == targetId) return tree;
    if (tree['child'] != null) {
      final res = _findNodeSync(tree['child'], targetId);
      if (res != null) return res;
    }
    if (tree['children'] != null) {
      for (var child in tree['children']) {
        final res = _findNodeSync(child, targetId);
        if (res != null) return res;
      }
    }
    return null;
  }

  void _updateNodeProperty(String nodeId, String key, dynamic value) {
    setState(() {
       final node = _findNodeSync(_layoutTree, nodeId);
       if (node != null) {
          node['properties'] ??= {};
          node['properties'][key] = value;
       }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UI Builder Engine'),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(icon: const Icon(Icons.download), onPressed: _importJson, tooltip: "Import JSON"),
          IconButton(icon: const Icon(Icons.save), onPressed: _exportJson, tooltip: "Export JSON"),
        ],
      ),
      backgroundColor: const Color(0xFF121212),
      body: Row(
        children: [
          _buildComponentLibrary(),
          const VerticalDivider(width: 1, color: Colors.white24),
          _buildWorkspace(),
          const VerticalDivider(width: 1, color: Colors.white24),
          _buildPropertiesInspector(),
        ],
      ),
    );
  }

  Widget _buildComponentLibrary() {
    return Container(
      width: 250,
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("COMPONENTS", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          ),
          _buildLibraryItem('Container', Icons.crop_square_outlined),
          _buildLibraryItem('Text', Icons.text_fields),
          _buildLibraryItem('Row', Icons.view_column_outlined),
          _buildLibraryItem('Column', Icons.view_headline_outlined),
        ],
      ),
    );
  }

  Widget _buildLibraryItem(String type, IconData icon) {
    return Draggable<String>(
      data: type,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blueAccent.withOpacity(0.5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white), const SizedBox(width: 8), Text(type, style: const TextStyle(color: Colors.white))]),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(type, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildWorkspace() {
    return Expanded(
      child: DragTarget<String>(
        onAcceptWithDetails: (details) {
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final localOffset = renderBox.globalToLocal(details.offset);
          // Adjust offset to account for the left sidebar width.
          _addComponent(details.data, Offset(localOffset.dx - 250, localOffset.dy));
        },
        builder: (context, candidateData, rejectedData) {
          return Stack(
            children: [
               LayoutSerializer.buildFromJson(
                 _layoutTree,
                 editMode: true,
                 onSelectNode: (id) {
                   setState(() {
                     _selectedNodeId = id;
                   });
                 }
               ),
               if (candidateData.isNotEmpty)
                  Positioned.fill(
                    child: Container(color: Colors.blueAccent.withOpacity(0.1)),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPropertiesInspector() {
    return Container(
      width: 300,
      color: const Color(0xFF1E1E1E),
      child: _selectedNodeId == null
          ? const Center(child: Text("No node selected", style: TextStyle(color: Colors.white54)))
          : _buildActiveNodeEditor(),
    );
  }

  Widget _buildActiveNodeEditor() {
    final activeNode = _findNodeSync(_layoutTree, _selectedNodeId!);
    if (activeNode == null) return const Center(child: Text("Node lost"));

    final String type = activeNode['type'];
    final Map<String, dynamic> props = activeNode['properties'] ?? {};

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Type: $type", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text("Properties", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          if (type == 'Container' || type == 'SizedBox') ...[
            _propField('Width', 'width', props),
            _propField('Height', 'height', props),
          ],
          if (type == 'Container' || type == 'Text') ...[
             _propField('Color (Hex)', 'color', props),
          ],
          if (type == 'Text') ...[
             _propField('Text', 'text', props),
             _propField('FontSize', 'fontSize', props),
          ],
          if (type == 'Positioned') ...[
             _propField('Left', 'left', props),
             _propField('Top', 'top', props),
          ]
        ],
      ),
    );
  }

  Widget _propField(String label, String key, Map<String, dynamic> props) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: TextEditingController(text: props[key]?.toString()),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.black26,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (val) {
          _updateNodeProperty(_selectedNodeId!, key, val);
        },
      ),
    );
  }
}
