import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StateMachineInputType { trigger, boolean, number }

enum ConditionOp { equals, notEquals, greaterThan, lessThan, greaterThanOrEquals, lessThanOrEquals }

class StateMachineInput {
  final String name;
  final StateMachineInputType type;
  final dynamic value; // bool for boolean, double for number, null for trigger
  final String? bindFilePath;

  const StateMachineInput({
    required this.name,
    required this.type,
    required this.value,
    this.bindFilePath,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type.name,
    'value': value,
    'bindFilePath': bindFilePath,
  };

  factory StateMachineInput.fromJson(Map<String, dynamic> json) {
    return StateMachineInput(
      name: json['name'] ?? '',
      type: StateMachineInputType.values.byName(json['type'] ?? 'trigger'),
      value: json['value'],
      bindFilePath: json['bindFilePath'],
    );
  }
}

class TransitionCondition {
  final String inputName;
  final ConditionOp op;
  final dynamic value; // bool or double, null for trigger

  const TransitionCondition({
    required this.inputName,
    required this.op,
    this.value,
  });

  Map<String, dynamic> toJson() => {
    'inputName': inputName,
    'op': op.name,
    'value': value,
  };

  factory TransitionCondition.fromJson(Map<String, dynamic> json) {
    return TransitionCondition(
      inputName: json['inputName'] ?? '',
      op: ConditionOp.values.byName(json['op'] ?? 'equals'),
      value: json['value'],
    );
  }
}

class NodeStateAction {
  final String inputName;
  final dynamic value; // bool, double, or null/true for trigger

  const NodeStateAction({
    required this.inputName,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
    'inputName': inputName,
    'value': value,
  };

  factory NodeStateAction.fromJson(Map<String, dynamic> json) {
    return NodeStateAction(
      inputName: json['inputName'] ?? '',
      value: json['value'],
    );
  }
}

/// Configuration for a single node (state) in a state machine.
class StateNodeConfig {
  final String id;
  final String label;
  final IconData? icon;
  final Color color;
  final Offset position;
  final String description;
  final List<NodeStateAction> actions;

  const StateNodeConfig({
    required this.id,
    required this.label,
    this.icon,
    this.color = Colors.blueAccent,
    required this.position,
    this.description = '',
    this.actions = const [],
  });
}

/// Configuration for a transition edge between states in a state machine.
class TransitionConfig {
  final String from;
  final String to;
  final String label;
  final List<TransitionCondition> conditions;

  const TransitionConfig({
    required this.from,
    required this.to,
    this.label = '',
    this.conditions = const [],
  });
}

/// Configures the static topology (nodes and transitions) of a state machine.
class StateMachineConfig {
  final List<StateNodeConfig> nodes;
  final List<TransitionConfig> transitions;

  const StateMachineConfig({
    required this.nodes,
    required this.transitions,
  });

  StateNodeConfig? getNode(String id) {
    for (var node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }
}

/// Tracks the active runtime state of a state machine for visualization.
class StateMachineVisualState {
  final String activeStateId;
  final String? lastActiveStateId;
  final String statusMessage;
  final DateTime enteredAt;
  final bool hasError;

  StateMachineVisualState({
    required this.activeStateId,
    this.lastActiveStateId,
    this.statusMessage = '',
    required this.enteredAt,
    this.hasError = false,
  });

  StateMachineVisualState copyWith({
    String? activeStateId,
    String? lastActiveStateId,
    String? statusMessage,
    DateTime? enteredAt,
    bool? hasError,
  }) {
    return StateMachineVisualState(
      activeStateId: activeStateId ?? this.activeStateId,
      lastActiveStateId: lastActiveStateId ?? this.lastActiveStateId,
      statusMessage: statusMessage ?? this.statusMessage,
      enteredAt: enteredAt ?? this.enteredAt,
      hasError: hasError ?? this.hasError,
    );
  }
}

/// Controller to drive state machine changes and notify listeners.
class StateMachineController extends ChangeNotifier {
  final StateMachineConfig config;
  late StateMachineVisualState _visualState;

  final List<StateNodeConfig> _nodes = [];
  final List<TransitionConfig> _transitions = [];
  final Map<String, String> _nodeNotes = {};
  String? _selectedNodeId;

  Timer? _bindingTimer;
  bool enableBindingTimer = true;
  final Map<String, String> _lastTriggerContent = {};

  StateMachineVisualState get visualState => _visualState;
  List<StateNodeConfig> get allNodes => _nodes;
  List<TransitionConfig> get allTransitions => _transitions;
  Map<String, String> get nodeNotes => _nodeNotes;
  String? get selectedNodeId => _selectedNodeId;

  StateMachineController({
    required this.config,
    required String initialActiveStateId,
  }) {
    _visualState = StateMachineVisualState(
      activeStateId: initialActiveStateId,
      enteredAt: DateTime.now(),
    );
    // Initialize nodes and transitions synchronously to prevent test race conditions
    _nodes.addAll(config.nodes);
    _transitions.addAll(config.transitions);
    _loadCustomData().then((_) {
      _startBindingTimer();
    });
  }

  @override
  void dispose() {
    _bindingTimer?.cancel();
    super.dispose();
  }

  StateNodeConfig? getNode(String id) {
    for (var node in allNodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  Future<void> _loadCustomData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check for unified nodes
      final nodesStr = prefs.getString('ve_sm_nodes');
      final oldCustomNodesStr = prefs.getString('ve_sm_custom_nodes');
      final oldRemovedList = prefs.getStringList('ve_sm_removed_static_nodes');

      if (nodesStr != null) {
        final List<dynamic> list = jsonDecode(nodesStr);
        _nodes.clear();
        for (var item in list) {
          final map = item as Map<String, dynamic>;
          final actionList = map['actions'] as List<dynamic>? ?? [];
          final actions = actionList.map((a) => NodeStateAction.fromJson(a as Map<String, dynamic>)).toList();
          _nodes.add(StateNodeConfig(
            id: map['id'] ?? '',
            label: map['label'] ?? '',
            color: Color(map['color'] ?? Colors.blueAccent.value),
            position: Offset(
              (map['position_x'] as num? ?? 300.0).toDouble(),
              (map['position_y'] as num? ?? 200.0).toDouble(),
            ),
            description: map['description'] ?? '',
            actions: actions,
          ));
        }
        notifyListeners();
      } else if (oldCustomNodesStr != null || oldRemovedList != null) {
        _nodes.clear();
        final List<StateNodeConfig> oldCustom = [];
        if (oldCustomNodesStr != null) {
          final List<dynamic> list = jsonDecode(oldCustomNodesStr);
          for (var item in list) {
            final map = item as Map<String, dynamic>;
            oldCustom.add(StateNodeConfig(
              id: map['id'] ?? '',
              label: map['label'] ?? '',
              color: Color(map['color'] ?? Colors.blueAccent.value),
              position: Offset(
                (map['position_x'] as num? ?? 300.0).toDouble(),
                (map['position_y'] as num? ?? 200.0).toDouble(),
              ),
              description: map['description'] ?? '',
            ));
          }
        }
        final oldRemoved = oldRemovedList ?? [];
        for (var node in config.nodes) {
          if (!oldRemoved.contains(node.id)) {
            _nodes.add(node);
          }
        }
        _nodes.addAll(oldCustom);
        saveNodes();
        notifyListeners();
      }

      // Check for unified transitions
      final transitionsStr = prefs.getString('ve_sm_transitions');
      final oldCustomTransitionsStr = prefs.getString('ve_sm_custom_transitions');
      final oldRemovedTransList = prefs.getStringList('ve_sm_removed_static_transitions');

      if (transitionsStr != null) {
        final List<dynamic> list = jsonDecode(transitionsStr);
        _transitions.clear();
        for (var item in list) {
          final map = item as Map<String, dynamic>;
          final condList = map['conditions'] as List<dynamic>? ?? [];
          final conditions = condList.map((c) => TransitionCondition.fromJson(c as Map<String, dynamic>)).toList();
          _transitions.add(TransitionConfig(
            from: map['from'] ?? '',
            to: map['to'] ?? '',
            label: map['label'] ?? '',
            conditions: conditions,
          ));
        }
        notifyListeners();
      } else if (oldCustomTransitionsStr != null || oldRemovedTransList != null) {
        _transitions.clear();
        final List<TransitionConfig> oldCustomTrans = [];
        if (oldCustomTransitionsStr != null) {
          final List<dynamic> list = jsonDecode(oldCustomTransitionsStr);
          for (var item in list) {
            final map = item as Map<String, dynamic>;
            oldCustomTrans.add(TransitionConfig(
              from: map['from'] ?? '',
              to: map['to'] ?? '',
              label: map['label'] ?? '',
            ));
          }
        }
        final oldRemovedTrans = oldRemovedTransList ?? [];
        for (var t in config.transitions) {
          final key = '${t.from}_${t.to}';
          if (!oldRemovedTrans.contains(key)) {
            _transitions.add(t);
          }
        }
        _transitions.addAll(oldCustomTrans);
        saveTransitions();
        notifyListeners();
      }

      // Load inputs
      final inputsStr = prefs.getString('ve_sm_inputs');
      if (inputsStr != null) {
        final List<dynamic> list = jsonDecode(inputsStr);
        _inputs.clear();
        for (var item in list) {
          _inputs.add(StateMachineInput.fromJson(item as Map<String, dynamic>));
        }
      }

      final isAiBridgeMachine = config.getNode('idle')?.label == 'Standby (Idle)';
      if (isAiBridgeMachine) {
        // Ensure required inputs exist
        final requiredInputs = [
          const StateMachineInput(name: 'AgentBusy', type: StateMachineInputType.boolean, value: false),
          const StateMachineInput(name: 'AgentThinking', type: StateMachineInputType.boolean, value: false),
          const StateMachineInput(name: 'BridgeActive', type: StateMachineInputType.boolean, value: false),
          const StateMachineInput(name: 'AgentStatus', type: StateMachineInputType.boolean, value: false, bindFilePath: 'agent_status.txt'),
        ];
        bool inputsChanged = false;
        for (var req in requiredInputs) {
          if (!_inputs.any((i) => i.name == req.name)) {
            _inputs.add(req);
            inputsChanged = true;
          }
        }
        if (inputsChanged) {
          saveInputs();
        }

        // Populate accurate transition conditions if they are missing
        final defaultConditions = {
          'idle_dispatching': [const TransitionCondition(inputName: 'BridgeActive', op: ConditionOp.equals, value: true)],
          'dispatching_busy': [const TransitionCondition(inputName: 'AgentStatus', op: ConditionOp.equals, value: true)],
          'dispatching_error': [const TransitionCondition(inputName: 'BridgeActive', op: ConditionOp.equals, value: false)],
          'busy_compiling': [
            const TransitionCondition(inputName: 'AgentBusy', op: ConditionOp.equals, value: false),
            const TransitionCondition(inputName: 'AgentStatus', op: ConditionOp.equals, value: false),
          ],
          'busy_previewing': [
            const TransitionCondition(inputName: 'AgentBusy', op: ConditionOp.equals, value: false),
            const TransitionCondition(inputName: 'AgentStatus', op: ConditionOp.equals, value: true),
          ],
          'busy_error': [const TransitionCondition(inputName: 'BridgeActive', op: ConditionOp.equals, value: false)],
          'compiling_synchronizing': [const TransitionCondition(inputName: 'AgentThinking', op: ConditionOp.equals, value: false)],
          'compiling_error': [const TransitionCondition(inputName: 'BridgeActive', op: ConditionOp.equals, value: false)],
          'synchronizing_idle': [const TransitionCondition(inputName: 'AgentStatus', op: ConditionOp.equals, value: false)],
          'synchronizing_error': [const TransitionCondition(inputName: 'BridgeActive', op: ConditionOp.equals, value: false)],
          'previewing_idle': [const TransitionCondition(inputName: 'AgentStatus', op: ConditionOp.equals, value: false)],
          'previewing_dispatching': [const TransitionCondition(inputName: 'AgentThinking', op: ConditionOp.equals, value: true)],
          'error_idle': [const TransitionCondition(inputName: 'BridgeActive', op: ConditionOp.equals, value: true)],
        };

        bool transitionsChanged = false;
        for (var i = 0; i < _transitions.length; i++) {
          final t = _transitions[i];
          final key = '${t.from}_${t.to}';
          if (defaultConditions.containsKey(key)) {
            final defConds = defaultConditions[key]!;
            bool match = t.conditions.length == defConds.length;
            if (match) {
              for (int c = 0; c < defConds.length; c++) {
                if (t.conditions[c].inputName != defConds[c].inputName ||
                    t.conditions[c].op != defConds[c].op ||
                    t.conditions[c].value != defConds[c].value) {
                  match = false;
                  break;
                }
              }
            }
            if (!match) {
              _transitions[i] = TransitionConfig(
                from: t.from,
                to: t.to,
                label: t.label,
                conditions: defConds,
              );
              transitionsChanged = true;
            }
          }
        }
        if (transitionsChanged) {
          saveTransitions();
        }
      }

      // Load notes
      final notesStr = prefs.getString('ve_sm_node_notes');
      if (notesStr != null) {
        final Map<String, dynamic> map = jsonDecode(notesStr);
        _nodeNotes.clear();
        map.forEach((k, v) {
          _nodeNotes[k] = v.toString();
        });
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading custom state machine data: $e');
    }
  }

  Future<void> saveNodes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _nodes.map((node) => {
        'id': node.id,
        'label': node.label,
        'color': node.color.value,
        'position_x': node.position.dx,
        'position_y': node.position.dy,
        'description': node.description,
        'actions': node.actions.map((a) => a.toJson()).toList(),
      }).toList();
      await prefs.setString('ve_sm_nodes', jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving state machine nodes: $e');
    }
  }

  Future<void> saveTransitions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _transitions.map((t) => {
        'from': t.from,
        'to': t.to,
        'label': t.label,
        'conditions': t.conditions.map((c) => c.toJson()).toList(),
      }).toList();
      await prefs.setString('ve_sm_transitions', jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving state machine transitions: $e');
    }
  }

  Future<void> saveInputs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _inputs.map((i) => i.toJson()).toList();
      await prefs.setString('ve_sm_inputs', jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving state machine inputs: $e');
    }
  }

  Future<void> saveNodeNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ve_sm_node_notes', jsonEncode(_nodeNotes));
    } catch (e) {
      debugPrint('Error saving note notes: $e');
    }
  }

  final List<StateMachineInput> _inputs = [];
  List<StateMachineInput> get allInputs => _inputs;

  void addInput(StateMachineInput input) {
    if (!_inputs.any((i) => i.name == input.name)) {
      _inputs.add(input);
      saveInputs();
      notifyListeners();
    }
  }

  void editInput(String oldName, StateMachineInput newInput) {
    final idx = _inputs.indexWhere((i) => i.name == oldName);
    if (idx != -1) {
      _inputs[idx] = newInput;
      
      if (oldName != newInput.name) {
        for (var i = 0; i < _transitions.length; i++) {
          final t = _transitions[i];
          if (t.conditions.any((c) => c.inputName == oldName)) {
            final newConditions = t.conditions.map((c) {
              if (c.inputName == oldName) {
                return TransitionCondition(
                  inputName: newInput.name,
                  op: c.op,
                  value: c.value,
                );
              }
              return c;
            }).toList();
            _transitions[i] = TransitionConfig(
              from: t.from,
              to: t.to,
              label: t.label,
              conditions: newConditions,
            );
          }
        }
        for (var i = 0; i < _nodes.length; i++) {
          final n = _nodes[i];
          if (n.actions.any((a) => a.inputName == oldName)) {
            final newActions = n.actions.map((a) {
              if (a.inputName == oldName) {
                return NodeStateAction(
                  inputName: newInput.name,
                  value: a.value,
                );
              }
              return a;
            }).toList();
            _nodes[i] = StateNodeConfig(
              id: n.id,
              label: n.label,
              icon: n.icon,
              color: n.color,
              position: n.position,
              description: n.description,
              actions: newActions,
            );
          }
        }
        saveNodes();
        saveTransitions();
      }
      saveInputs();
      notifyListeners();
    }
  }

  void removeInput(String name) {
    _inputs.removeWhere((i) => i.name == name);
    // Remove references to this input in transition conditions
    for (var i = 0; i < _transitions.length; i++) {
      final t = _transitions[i];
      if (t.conditions.any((c) => c.inputName == name)) {
        final newConditions = t.conditions.where((c) => c.inputName != name).toList();
        _transitions[i] = TransitionConfig(
          from: t.from,
          to: t.to,
          label: t.label,
          conditions: newConditions,
        );
      }
    }
    saveInputs();
    saveTransitions();
    notifyListeners();
  }

  void _startBindingTimer() {
    if (!enableBindingTimer) return;
    _bindingTimer?.cancel();
    _bindingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      bool updated = false;
      for (var i = 0; i < _inputs.length; i++) {
        final input = _inputs[i];
        if (input.bindFilePath != null && input.bindFilePath!.isNotEmpty) {
          try {
            var file = File(input.bindFilePath!);
            if (!await file.exists() && input.bindFilePath == 'agent_status.txt') {
              file = File('.ai_bridge/agent_status.txt');
            }
            if (await file.exists()) {
              final content = (await file.readAsString()).trim();
              if (input.type == StateMachineInputType.number) {
                final val = double.tryParse(content) ?? 0.0;
                if (input.value != val) {
                  _inputs[i] = StateMachineInput(
                    name: input.name,
                    type: input.type,
                    value: val,
                    bindFilePath: input.bindFilePath,
                  );
                  updated = true;
                }
              } else if (input.type == StateMachineInputType.boolean) {
                final normalized = content.toLowerCase();
                bool val;
                if (input.name == 'AgentStatus') {
                  val = normalized != 'idle' && normalized.isNotEmpty;
                } else {
                  val = normalized == 'true' ||
                      content == '1' ||
                      normalized == 'active' ||
                      normalized == 'busy' ||
                      normalized == 'preview' ||
                      normalized == 'testing';
                }
                if (input.value != val) {
                  _inputs[i] = StateMachineInput(
                    name: input.name,
                    type: input.type,
                    value: val,
                    bindFilePath: input.bindFilePath,
                  );
                  updated = true;
                }
              } else if (input.type == StateMachineInputType.trigger) {
                final lastContent = _lastTriggerContent[input.name];
                if (content.isNotEmpty && content != lastContent) {
                  _lastTriggerContent[input.name] = content;
                  triggerInput(input.name);
                }
              }
            }
          } catch (_) {}
        }
      }
      if (updated) {
        evaluateTransitions();
        notifyListeners();
      }
    });
  }

  void evaluateTransitions() {
    int loops = 0;
    const maxLoops = 10;
    
    while (loops < maxLoops) {
      final activeId = _visualState.activeStateId;
      final outgoing = _transitions.where((t) => t.from == activeId).toList();
      
      TransitionConfig? satisfiedTransition;
      for (var t in outgoing) {
        if (t.conditions.isEmpty) continue;
        
        bool allSatisfied = true;
        for (var cond in t.conditions) {
          final input = _inputs.firstWhere(
            (i) => i.name == cond.inputName,
            orElse: () => const StateMachineInput(name: '', type: StateMachineInputType.trigger, value: null),
          );
          if (input.name.isEmpty) {
            allSatisfied = false;
            break;
          }
          
          if (input.type == StateMachineInputType.trigger) {
            if (input.value != true) {
              allSatisfied = false;
              break;
            }
          } else if (input.type == StateMachineInputType.boolean) {
            final currentVal = input.value as bool? ?? false;
            final targetVal = cond.value as bool? ?? false;
            if (cond.op == ConditionOp.equals && currentVal != targetVal) {
              allSatisfied = false;
              break;
            }
            if (cond.op == ConditionOp.notEquals && currentVal == targetVal) {
              allSatisfied = false;
              break;
            }
          } else if (input.type == StateMachineInputType.number) {
            final currentVal = (input.value as num? ?? 0.0).toDouble();
            final targetVal = (cond.value as num? ?? 0.0).toDouble();
            
            bool satisfied = false;
            switch (cond.op) {
              case ConditionOp.equals:
                satisfied = currentVal == targetVal;
                break;
              case ConditionOp.notEquals:
                satisfied = currentVal != targetVal;
                break;
              case ConditionOp.greaterThan:
                satisfied = currentVal > targetVal;
                break;
              case ConditionOp.lessThan:
                satisfied = currentVal < targetVal;
                break;
              case ConditionOp.greaterThanOrEquals:
                satisfied = currentVal >= targetVal;
                break;
              case ConditionOp.lessThanOrEquals:
                satisfied = currentVal <= targetVal;
                break;
            }
            if (!satisfied) {
              allSatisfied = false;
              break;
            }
          }
        }
        
        if (allSatisfied) {
          satisfiedTransition = t;
          break;
        }
      }
      
      if (satisfiedTransition != null) {
        transitionTo(satisfiedTransition.to);
        loops++;
      } else {
        break;
      }
    }
  }

  void updateInputValue(String name, dynamic value) {
    final idx = _inputs.indexWhere((i) => i.name == name);
    if (idx != -1) {
      final input = _inputs[idx];
      _inputs[idx] = StateMachineInput(
        name: input.name,
        type: input.type,
        value: value,
      );
      saveInputs();
      evaluateTransitions();
      notifyListeners();
    }
  }

  void triggerInput(String name) {
    final idx = _inputs.indexWhere((i) => i.name == name && i.type == StateMachineInputType.trigger);
    if (idx != -1) {
      _inputs[idx] = StateMachineInput(
        name: name,
        type: StateMachineInputType.trigger,
        value: true,
      );
      evaluateTransitions();
      notifyListeners();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final resetIdx = _inputs.indexWhere((i) => i.name == name && i.type == StateMachineInputType.trigger);
        if (resetIdx != -1) {
          _inputs[resetIdx] = StateMachineInput(
            name: name,
            type: StateMachineInputType.trigger,
            value: null,
          );
          notifyListeners();
        }
      });
    }
  }

  void addTransitionCondition(String from, String to, TransitionCondition condition) {
    final idx = _transitions.indexWhere((t) => t.from == from && t.to == to);
    if (idx != -1) {
      final t = _transitions[idx];
      final newConditions = List<TransitionCondition>.from(t.conditions)..add(condition);
      _transitions[idx] = TransitionConfig(
        from: t.from,
        to: t.to,
        label: t.label,
        conditions: newConditions,
      );
      saveTransitions();
      notifyListeners();
    }
  }

  void removeTransitionCondition(String from, String to, int conditionIndex) {
    final idx = _transitions.indexWhere((t) => t.from == from && t.to == to);
    if (idx != -1) {
      final t = _transitions[idx];
      if (conditionIndex >= 0 && conditionIndex < t.conditions.length) {
        final newConditions = List<TransitionCondition>.from(t.conditions)..removeAt(conditionIndex);
        _transitions[idx] = TransitionConfig(
          from: t.from,
          to: t.to,
          label: t.label,
          conditions: newConditions,
        );
        saveTransitions();
        notifyListeners();
      }
    }
  }



  void addCustomNode(StateNodeConfig node) {
    _nodes.add(node);
    saveNodes();
    notifyListeners();
  }

  void removeNode(String id) {
    _nodes.removeWhere((n) => n.id == id);
    _nodeNotes.remove(id);
    _transitions.removeWhere((t) => t.from == id || t.to == id);
    if (_selectedNodeId == id) {
      _selectedNodeId = null;
    }
    saveNodes();
    saveTransitions();
    saveNodeNotes();
    notifyListeners();
  }

  void addCustomTransition(TransitionConfig transition) {
    final exists = _transitions.any((t) => t.from == transition.from && t.to == transition.to && t.label == transition.label);
    if (!exists) {
      _transitions.add(transition);
      saveTransitions();
    }
    notifyListeners();
  }

  void removeTransition(String from, String to) {
    _transitions.removeWhere((t) => t.from == from && t.to == to);
    saveTransitions();
    notifyListeners();
  }

  void setNodeNote(String id, String note) {
    _nodeNotes[id] = note;
    saveNodeNotes();
    notifyListeners();
  }

  void clearNodeNote(String id) {
    _nodeNotes.remove(id);
    saveNodeNotes();
    notifyListeners();
  }

  void selectNode(String? id) {
    _selectedNodeId = id;
    notifyListeners();
  }

  /// Transitions the visualizer to a new state, updating timing and pathways.
  void transitionTo(String newStateId, {String statusMessage = ''}) {
    if (_visualState.activeStateId == newStateId) {
      if (statusMessage != _visualState.statusMessage) {
        _visualState = _visualState.copyWith(statusMessage: statusMessage);
        notifyListeners();
      }
      return;
    }

    _visualState = _visualState.copyWith(
      lastActiveStateId: _visualState.activeStateId,
      activeStateId: newStateId,
      statusMessage: statusMessage,
      enteredAt: DateTime.now(),
      hasError: newStateId == 'error',
    );

    // Evaluate entering actions
    final targetNode = getNode(newStateId);
    if (targetNode != null) {
      for (var action in targetNode.actions) {
        if (action.inputName.isNotEmpty) {
          final input = _inputs.firstWhere(
            (i) => i.name == action.inputName,
            orElse: () => const StateMachineInput(name: '', type: StateMachineInputType.trigger, value: null),
          );
          if (input.name.isNotEmpty) {
            if (input.type == StateMachineInputType.trigger) {
              triggerInput(action.inputName);
            } else {
              updateInputValue(action.inputName, action.value);
            }
          }
        }
      }
    }

    notifyListeners();
  }

  void addNodeAction(String nodeId, NodeStateAction action) {
    final idx = _nodes.indexWhere((n) => n.id == nodeId);
    if (idx != -1) {
      final n = _nodes[idx];
      final newActions = List<NodeStateAction>.from(n.actions)..add(action);
      _nodes[idx] = StateNodeConfig(
        id: n.id,
        label: n.label,
        icon: n.icon,
        color: n.color,
        position: n.position,
        description: n.description,
        actions: newActions,
      );
      saveNodes();
      notifyListeners();
    }
  }

  void removeNodeAction(String nodeId, int actionIndex) {
    final idx = _nodes.indexWhere((n) => n.id == nodeId);
    if (idx != -1) {
      final n = _nodes[idx];
      if (actionIndex >= 0 && actionIndex < n.actions.length) {
        final newActions = List<NodeStateAction>.from(n.actions)..removeAt(actionIndex);
        _nodes[idx] = StateNodeConfig(
          id: n.id,
          label: n.label,
          icon: n.icon,
          color: n.color,
          position: n.position,
          description: n.description,
          actions: newActions,
        );
        saveNodes();
        notifyListeners();
      }
    }
  }

  /// Sets the visualizer to an error state with custom diagnostic message.
  void setError(String errorMessage) {
    _visualState = _visualState.copyWith(
      lastActiveStateId: _visualState.activeStateId,
      activeStateId: 'error',
      statusMessage: errorMessage,
      enteredAt: DateTime.now(),
      hasError: true,
    );
    notifyListeners();
  }

  /// Clears any errors and resets back to a designated state.
  void clearError(String fallbackStateId) {
    _visualState = _visualState.copyWith(
      lastActiveStateId: 'error',
      activeStateId: fallbackStateId,
      statusMessage: 'Error cleared.',
      enteredAt: DateTime.now(),
      hasError: false,
    );
    notifyListeners();
  }
}
