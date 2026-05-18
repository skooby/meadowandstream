import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'ai_copilot_theme.dart';
import '../../models/agent_models.dart';
import '../../services/ai_bridge_service.dart';
import '../../state/global_picker_state.dart';
import '../../screens/visual_editor/panels/global_color_picker_window.dart';
import '../../screens/visual_editor/panels/global_icon_picker_window.dart';

class AgentsPanel extends StatefulWidget {
  final AiCopilotTheme theme;
  final void Function(String moduleName, String payload) onDispatch;

  const AgentsPanel({
    super.key,
    this.theme = const AiCopilotTheme(),
    required this.onDispatch,
  });

  @override
  AgentsPanelState createState() => AgentsPanelState();
}

class AgentsPanelState extends State<AgentsPanel> {
  bool _isLoaded = false;
  List<AgentNode> _rootNodes = [];
  final TextEditingController _commonPromptCtrl = TextEditingController();
  final Set<String> _expandedNodes = {};

  bool _showNodeEditor = false;
  AgentNode? _editingNodeTarget;
  AgentNode? _editingNodeParent;
  
  // Node editor state
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _promptCtrl = TextEditingController();
  Color? _selectedColor;
  int? _selectedIcon;

  bool _parentLabelsUppercase = true;
  bool _parentLabelsBold = true;
  bool _childLabelsUppercase = false;
  bool _childLabelsBold = false;

  void _expandAll(List<AgentNode> nodes) {
    for (var node in nodes) {
      _expandedNodes.add(node.id);
      if (node.children.isNotEmpty) {
        _expandAll(node.children);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _commonPromptCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _commonPromptCtrl.text = prefs.getString('ve_agents_common_prompt') ??
            "You are a specialized AI Agent.\\n\\nReturn your output directly, acting precisely according to the prompt provided. No markdown chat introductions.";

        final str = prefs.getString('ve_agents_nodes');
        if (str != null) {
          try {
            final List<dynamic> decoded = jsonDecode(str);
            _rootNodes = decoded.map((e) => AgentNode.fromJson(e)).toList();
            _expandAll(_rootNodes);
          } catch (_) {
            _populateDefaultNodes();
          }
        } else {
          _populateDefaultNodes();
        }
        _isLoaded = true;
      });
    }
  }

  void _saveNodes() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('ve_agents_nodes',
          jsonEncode(_rootNodes.map((e) => e.toJson()).toList()));
    });
  }

  void _saveCommonPrompt() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('ve_agents_common_prompt', _commonPromptCtrl.text);
    });
  }

  void _populateDefaultNodes() {
    setState(() {
      _rootNodes = [
        AgentNode(
            id: "1",
            title: "Code Reviewers",
            description: "Group of agents for reviewing code",
            children: [
              AgentNode(
                  id: "2",
                  title: "Architecture Reviewer",
                  description: "Focuses on structural patterns",
                  prompt:
                      "Review the following code for architectural anti-patterns.",
                  children: []),
              AgentNode(
                  id: "3",
                  title: "Security Reviewer",
                  description: "Focuses on vulnerabilities",
                  prompt:
                      "Review the following code for potential security vulnerabilities.",
                  children: [])
            ])
      ];
      _expandAll(_rootNodes);
      _isLoaded = true;
    });
    _saveNodes();
  }

  bool _removeFromTree(List<AgentNode> list, String targetId) {
    for (int i = 0; i < list.length; i++) {
      if (list[i].id == targetId) {
        list.removeAt(i);
        return true;
      }
      if (_removeFromTree(list[i].children, targetId)) {
        return true;
      }
    }
    return false;
  }

  void showManageSystemPromptDialog() {
    final commonPromptCtrl =
        TextEditingController(text: _commonPromptCtrl.text);
    bool tempPU = _parentLabelsUppercase;
    bool tempPB = _parentLabelsBold;
    bool tempCU = _childLabelsUppercase;
    bool tempCB = _childLabelsBold;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
        return Dialog(
          backgroundColor: widget.theme.background,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.theme.cornerRadius)),
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Agent Configuration',
                    style: TextStyle(
                        color: widget.theme.textPrimary,
                        fontSize: widget.theme.headerFontSize,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: commonPromptCtrl,
                  maxLines: 5,
                  style: TextStyle(color: widget.theme.textPrimary),
                  decoration: InputDecoration(
                      labelText: 'Common System Instructions',
                      filled: true,
                      fillColor: widget.theme.panelBackground,
                      border: OutlineInputBorder(borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 24),
                Text('Visual Settings',
                    style: TextStyle(
                        color: widget.theme.textPrimary,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Parent Nodes',
                              style: TextStyle(
                                  color: widget.theme.textSecondary,
                                  fontSize: 12)),
                          CheckboxListTile(
                            title: Text('Uppercase',
                                style: TextStyle(
                                    color: widget.theme.textPrimary,
                                    fontSize: 13)),
                            value: tempPU,
                            dense: true,
                            activeColor: widget.theme.accent,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) =>
                                setStateBuilder(() => tempPU = v ?? true),
                          ),
                          CheckboxListTile(
                            title: Text('Bold',
                                style: TextStyle(
                                    color: widget.theme.textPrimary,
                                    fontSize: 13)),
                            value: tempPB,
                            dense: true,
                            activeColor: widget.theme.accent,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) =>
                                setStateBuilder(() => tempPB = v ?? true),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Child Nodes',
                              style: TextStyle(
                                  color: widget.theme.textSecondary,
                                  fontSize: 12)),
                          CheckboxListTile(
                            title: Text('Uppercase',
                                style: TextStyle(
                                    color: widget.theme.textPrimary,
                                    fontSize: 13)),
                            value: tempCU,
                            dense: true,
                            activeColor: widget.theme.accent,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) =>
                                setStateBuilder(() => tempCU = v ?? false),
                          ),
                          CheckboxListTile(
                            title: Text('Bold',
                                style: TextStyle(
                                    color: widget.theme.textPrimary,
                                    fontSize: 13)),
                            value: tempCB,
                            dense: true,
                            activeColor: widget.theme.accent,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) =>
                                setStateBuilder(() => tempCB = v ?? false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text('Cancel',
                            style: TextStyle(color: widget.theme.textMuted))),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: widget.theme.accent),
                      onPressed: () {
                        setState(() {
                          _commonPromptCtrl.text = commonPromptCtrl.text;
                          _parentLabelsUppercase = tempPU;
                          _parentLabelsBold = tempPB;
                          _childLabelsUppercase = tempCU;
                          _childLabelsBold = tempCB;
                        });
                        SharedPreferences.getInstance().then((prefs) {
                          prefs.setString('ve_agents_common_prompt',
                              _commonPromptCtrl.text);
                          prefs.setBool(
                              've_agents_parent_upper', _parentLabelsUppercase);
                          prefs.setBool(
                              've_agents_parent_bold', _parentLabelsBold);
                          prefs.setBool(
                              've_agents_child_upper', _childLabelsUppercase);
                          prefs.setBool(
                              've_agents_child_bold', _childLabelsBold);
                        });
                        Navigator.of(ctx).pop();
                      },
                      child: Text('Save',
                          style: TextStyle(color: widget.theme.textPrimary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void showEditNodeDialog(AgentNode? parentNode, AgentNode? node) {
    setState(() {
      _editingNodeParent = parentNode;
      _editingNodeTarget = node;
      
      _titleCtrl.text = node?.title ?? '';
      _descCtrl.text = node?.description ?? '';
      _promptCtrl.text = node?.prompt ?? '';
      _selectedColor = (node?.color != null) ? Color(node!.color!) : null;
      _selectedIcon = node?.iconCodePoint;
      
      _showNodeEditor = true;
    });
  }

  Widget _buildNodeEditor() {
    final isNew = _editingNodeTarget == null;
    
    return Positioned.fill(
      child: Container(
        color: widget.theme.background.withValues(alpha: 0.8),
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: widget.theme.background,
              borderRadius: BorderRadius.circular(widget.theme.cornerRadius),
              border: Border.all(color: widget.theme.borderSubtle),
              boxShadow: [
                BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))
              ]
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(isNew ? 'New Node' : 'Edit Node',
                      style: TextStyle(
                          color: widget.theme.textPrimary,
                          fontSize: widget.theme.headerFontSize,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                      'Leave "Prompt" blank to make this node act purely as a folder.',
                      style: TextStyle(
                          color: widget.theme.textMuted,
                          fontSize: widget.theme.smallFontSize)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleCtrl,
                    style: TextStyle(color: widget.theme.textPrimary),
                    decoration: InputDecoration(
                        labelText: 'Title / Folder Name',
                        filled: true,
                        fillColor: widget.theme.panelBackground,
                        border:
                            OutlineInputBorder(borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    style: TextStyle(color: widget.theme.textPrimary),
                    decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        filled: true,
                        fillColor: widget.theme.panelBackground,
                        border:
                            OutlineInputBorder(borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _promptCtrl,
                    maxLines: 4,
                    style: TextStyle(color: widget.theme.textPrimary),
                    decoration: InputDecoration(
                        labelText: 'Prompt (optional)',
                        filled: true,
                        fillColor: widget.theme.panelBackground,
                        border:
                            OutlineInputBorder(borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Color:', style: TextStyle(color: widget.theme.textMuted)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                GlobalPickerState.instance.requestColor(
                                  initialColor: _selectedColor ?? widget.theme.accent,
                                  onColorSelected: (c) => setState(() => _selectedColor = c)
                                );
                                showColorPickerWindow(context);
                              },
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: widget.theme.panelBackground,
                                  borderRadius: BorderRadius.circular(widget.theme.cornerRadius),
                                  border: Border.all(color: widget.theme.borderSubtle)
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 20, height: 20,
                                      decoration: BoxDecoration(
                                        color: _selectedColor ?? Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: widget.theme.textMuted)
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(_selectedColor == null ? 'None' : 'Selected', style: TextStyle(color: widget.theme.textPrimary)),
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
                            Text('Icon:', style: TextStyle(color: widget.theme.textMuted)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                GlobalPickerState.instance.requestIcon(
                                  initialIcon: _selectedIcon != null ? IconData(_selectedIcon!, fontFamily: 'MaterialIcons') : null,
                                  onIconSelected: (ic) => setState(() => _selectedIcon = ic?.codePoint)
                                );
                                showIconPickerWindow(context);
                              },
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: widget.theme.panelBackground,
                                  borderRadius: BorderRadius.circular(widget.theme.cornerRadius),
                                  border: Border.all(color: widget.theme.borderSubtle)
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(_selectedIcon != null ? IconData(_selectedIcon!, fontFamily: 'MaterialIcons') : Icons.block, color: widget.theme.textPrimary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(_selectedIcon == null ? 'None' : 'Selected', style: TextStyle(color: widget.theme.textPrimary)),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isNew)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _removeFromTree(_rootNodes, _editingNodeTarget!.id);
                              _showNodeEditor = false;
                            });
                            _saveNodes();
                          },
                          icon: Icon(Icons.delete,
                              color: widget.theme.danger, size: 18),
                          label: Text('Delete',
                              style: TextStyle(color: widget.theme.danger)),
                        ),
                      const Spacer(),
                      TextButton(
                          onPressed: () => setState(() => _showNodeEditor = false),
                          child: Text('Cancel',
                              style: TextStyle(color: widget.theme.textMuted))),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: widget.theme.accent),
                        onPressed: () {
                          if (_titleCtrl.text.trim().isEmpty) return;
                          setState(() {
                            if (isNew) {
                              final newNode = AgentNode(
                                  id: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                  title: _titleCtrl.text.trim(),
                                  description: _descCtrl.text.trim(),
                                  prompt: _promptCtrl.text.trim(),
                                  color: _selectedColor?.value,
                                  iconCodePoint: _selectedIcon,
                                  children: []);
                              if (_editingNodeParent != null) {
                                _editingNodeParent!.children.add(newNode);
                              } else {
                                _rootNodes.add(newNode);
                              }
                            } else {
                              _editingNodeTarget!.title = _titleCtrl.text.trim();
                              _editingNodeTarget!.description = _descCtrl.text.trim();
                              _editingNodeTarget!.prompt = _promptCtrl.text.trim();
                              _editingNodeTarget!.color = _selectedColor?.value;
                              _editingNodeTarget!.iconCodePoint = _selectedIcon;
                            }
                            _showNodeEditor = false;
                          });
                          _saveNodes();
                        },
                        child: Text('Save',
                            style: TextStyle(color: widget.theme.textPrimary)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _reorderBefore(AgentNode draggedNode, AgentNode targetNode,
      List<AgentNode> siblingList) {
    setState(() {
      _removeFromTree(_rootNodes, draggedNode.id);
      int index = siblingList.indexOf(targetNode);
      if (index != -1) {
        siblingList.insert(index, draggedNode);
      } else {
        siblingList.add(draggedNode);
      }
    });
    _saveNodes();
  }

  void _reorderAfter(AgentNode draggedNode, AgentNode targetNode,
      List<AgentNode> siblingList) {
    setState(() {
      _removeFromTree(_rootNodes, draggedNode.id);
      int index = siblingList.indexOf(targetNode);
      if (index != -1) {
        siblingList.insert(index + 1, draggedNode);
      } else {
        siblingList.add(draggedNode);
      }
    });
    _saveNodes();
  }

  void _dispatchPrompt(List<AgentNode> path) {
    final validPrompts =
        path.map((e) => e.prompt.trim()).where((p) => p.isNotEmpty).toList();
    if (validPrompts.isEmpty) return;

    final StringBuffer sb = StringBuffer();
    if (_commonPromptCtrl.text.trim().isNotEmpty) {
      sb.write(_commonPromptCtrl.text.trim());
      sb.write("\\n\\n");
    }
    sb.write(validPrompts.join("\\n\\n"));

    widget.onDispatch('Agents', sb.toString());
  }

  Widget _buildNode(AgentNode node, int depth, List<AgentNode> path,
      List<AgentNode> siblingList, List<String> visibleOrder) {
    int? effectiveColorInt;
    for (int i = path.length - 1; i >= 0; i--) {
      if (path[i].color != null) {
        effectiveColorInt = path[i].color;
        break;
      }
    }

    final nodeColor = effectiveColorInt != null
        ? Color(effectiveColorInt)
        : widget.theme.accent;

    int index = visibleOrder.indexOf(node.id);
    bool isEven = index % 2 == 0;

    Color bgColor = Colors.transparent;
    if (effectiveColorInt != null) {
      bgColor = nodeColor.withOpacity(isEven ? 0.08 : 0.03);
    } else if (isEven) {
      bgColor = widget.theme.textPrimary.withOpacity(0.02);
    }
    final hasPrompt =
        path.any((n) => n.prompt.trim().isNotEmpty); // The chain has a prompt
    final hasChildren = node.children.isNotEmpty;
    final isExpanded = _expandedNodes.contains(node.id);

    bool isDescendant(AgentNode potentialParent, String draggedId) {
      if (potentialParent.id == draggedId) return true;
      return potentialParent.children.any((c) => isDescendant(c, draggedId));
    }

    Widget mainRow = Row(
      children: [
        InkWell(
          onTap: hasChildren
              ? () {
                  setState(() {
                    if (isExpanded) {
                      _expandedNodes.remove(node.id);
                    } else {
                      _expandedNodes.add(node.id);
                    }
                  });
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: (!hasChildren && node.iconCodePoint != null)
                ? Icon(
                    IconData(node.iconCodePoint!, fontFamily: 'MaterialIcons'),
                    size: 16,
                    color: nodeColor)
                : Icon(
                    hasChildren
                        ? (isExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right)
                        : Icons.subdirectory_arrow_right,
                    color: hasChildren ? widget.theme.textPrimary : nodeColor,
                    size: hasChildren ? 16 : 14),
          ),
        ),
        const SizedBox(width: 4),
        if (node.iconCodePoint != null && hasChildren) ...[
          Icon(IconData(node.iconCodePoint!, fontFamily: 'MaterialIcons'),
              size: 16, color: nodeColor),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Tooltip(
            message: node.description,
            child: InkWell(
              onTap: () => showEditNodeDialog(null, node),
              child: Text(
                hasChildren && _parentLabelsUppercase
                    ? node.title.toUpperCase()
                    : (!hasChildren && _childLabelsUppercase
                        ? node.title.toUpperCase()
                        : node.title),
                style: TextStyle(
                    color: widget.theme.textPrimary,
                    fontSize: widget.theme.rootFontSize,
                    fontWeight: hasChildren
                        ? (_parentLabelsBold
                            ? FontWeight.bold
                            : FontWeight.normal)
                        : (_childLabelsBold
                            ? FontWeight.bold
                            : FontWeight.normal)),
              ),
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasPrompt)
              IconButton(
                icon: const Icon(Icons.play_arrow, size: 16),
                color: Colors.greenAccent,
                onPressed: () => _dispatchPrompt(path),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Run Chain',
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.copy, size: 14),
              color: widget.theme.accent,
              onPressed: () {
                AgentClipboard.copy(node);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied ${node.title} to Agent Clipboard'), duration: const Duration(seconds: 2)));
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Copy Agent',
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 14),
              color: widget.theme.textMuted,
              onPressed: () => showEditNodeDialog(null, node),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Edit Node',
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 16),
              color: widget.theme.accent,
              onPressed: () {
                setState(() {
                  _expandedNodes.add(node.id);
                });
                showEditNodeDialog(node, null);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Add Child',
            ),
          ],
        ),
      ],
    );

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(
              left: depth * 16.0, right: 16.0, top: 4.0, bottom: 4.0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DragTarget<AgentNode>(
                onWillAcceptWithDetails: (details) {
                  final draggedNode = details.data;
                  if (draggedNode.id == node.id) return false;
                  if (isDescendant(node, draggedNode.id)) return false;
                  return true;
                },
                onAcceptWithDetails: (details) {
                  final draggedNode = details.data;
                  setState(() {
                    _removeFromTree(_rootNodes, draggedNode.id);
                    node.children.add(draggedNode);
                    _expandedNodes
                        .add(node.id); // Auto-expand when dropping into it
                  });
                  _saveNodes();
                },
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    color: candidateData.isNotEmpty
                        ? widget.theme.accent.withOpacity(0.2)
                        : bgColor,
                    child: mainRow,
                  );
                },
              ),
              // Top DragTarget for "reorder before"
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 12,
                child: DragTarget<AgentNode>(
                  onWillAcceptWithDetails: (details) {
                    final draggedNode = details.data;
                    if (draggedNode.id == node.id) return false;
                    if (isDescendant(node, draggedNode.id)) return false;
                    return true;
                  },
                  onAcceptWithDetails: (details) =>
                      _reorderBefore(details.data, node, siblingList),
                  builder: (ctx, cand, _) => Container(
                    color: cand.isNotEmpty
                        ? widget.theme.accent.withOpacity(0.8)
                        : Colors.transparent,
                  ),
                ),
              ),
              // Bottom DragTarget for "reorder after"
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 12,
                child: DragTarget<AgentNode>(
                  onWillAcceptWithDetails: (details) {
                    final draggedNode = details.data;
                    if (draggedNode.id == node.id) return false;
                    if (isDescendant(node, draggedNode.id)) return false;
                    return true;
                  },
                  onAcceptWithDetails: (details) =>
                      _reorderAfter(details.data, node, siblingList),
                  builder: (ctx, cand, _) => Container(
                    color: cand.isNotEmpty
                        ? widget.theme.accent.withOpacity(0.8)
                        : Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isExpanded && hasChildren)
          ...node.children.map((child) => _buildNode(
              child, depth + 1, [...path, child], node.children, visibleOrder)),
      ],
    );

    return LongPressDraggable<AgentNode>(
      delay: const Duration(milliseconds: 250),
      data: node,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.theme.panelBackground.withOpacity(0.95),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: widget.theme.accent.withOpacity(0.5)),
          ),
          child: Text(node.title,
              style: TextStyle(
                  color: widget.theme.textPrimary,
                  fontWeight: FontWeight.bold)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: content),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    List<String> visibleOrder = [];
    void traverse(List<AgentNode> nodes) {
      for (var n in nodes) {
        visibleOrder.add(n.id);
        if (_expandedNodes.contains(n.id)) traverse(n.children);
      }
    }

    traverse(_rootNodes);

    final mainContent = Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _rootNodes.length,
        itemBuilder: (context, index) {
          final node = _rootNodes[index];
          return _buildNode(node, 0, [node], _rootNodes, visibleOrder);
        },
      ),
    );

    return Stack(
      children: [
        mainContent,
        if (_showNodeEditor) _buildNodeEditor(),
      ],
    );
  }
}
