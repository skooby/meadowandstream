import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/flow_node_model.dart';
import '../models/agent_models.dart';
import 'ai_bridge_service.dart';

class PipelineExecutionEngine {
  static final PipelineExecutionEngine instance = PipelineExecutionEngine._internal();
  PipelineExecutionEngine._internal() {
    AiBridgeService.instance.addListener(_onAiBridgeTasksChanged);
  }

  final ValueNotifier<bool> isRunning = ValueNotifier(false);
  final ValueNotifier<bool> isPaused = ValueNotifier(false);

  List<FlowNode> _nodes = [];
  VoidCallback? onStateUpdated;
  final Map<String, String> _nodeToTaskMap = {};

  void start(List<FlowNode> nodes, VoidCallback updateCallback) {
    _nodes = nodes;
    onStateUpdated = updateCallback;
    if (_nodes.isEmpty) return;
    
    isRunning.value = true;
    isPaused.value = false;
    _nodeToTaskMap.clear();

    for (var n in _nodes) {
      n.executionState = 'queued';
    }
    _triggerUpdate();

    // Find roots
    final roots = _nodes.where((n) => _getIncomingEdges(n.id).isEmpty).toList();
    if (roots.isEmpty) {
      roots.add(_nodes.first);
    }

    for (var root in roots) {
      _executeNode(root);
    }
  }

  void stop() {
    isRunning.value = false;
    isPaused.value = false;
    for (var n in _nodes) {
      if (n.executionState == 'running' || n.executionState == 'queued') {
        n.executionState = null;
      }
    }
    _triggerUpdate();
  }

  void resume() {
    if (!isRunning.value && isPaused.value) {
      isRunning.value = true;
      isPaused.value = false;
      
      bool resumedAny = false;
      for (var n in _nodes) {
        if (n.executionState == 'failed') {
          _executeNode(n);
          resumedAny = true;
        }
      }
      
      if (!resumedAny) {
        // If no failed node, try to start any queued node whose dependencies are success
        for (var n in _nodes) {
          if (n.executionState == 'queued') {
            final incoming = _getIncomingEdges(n.id);
            if (incoming.every((inc) => inc.executionState == 'success')) {
              _executeNode(n);
            }
          }
        }
      }
    }
  }

  List<FlowNode> _getIncomingEdges(String targetId) {
    List<FlowNode> incoming = [];
    for (var n in _nodes) {
      bool connects = false;
      if (n.connectedTo.any((id) => id == targetId || id.startsWith('$targetId|'))) connects = true;
      for (var item in n.items) {
        if (item.connectedTo.any((id) => id == targetId || id.startsWith('$targetId|'))) connects = true;
      }
      if (connects) incoming.add(n);
    }
    return incoming;
  }

  Future<void> _executeNode(FlowNode node) async {
    if (!isRunning.value) return;
    if (node.executionState == 'success') return;

    node.executionState = 'running';
    _triggerUpdate();

    if (node.type == 'agent' && node.agentPayload != null) {
      final agentId = node.agentPayload!['agentId'];
      final prompt = await _getAgentPrompt(agentId);
      if (prompt != null) {
        final task = await AiBridgeService.instance.addTask(node.title, prompt, status: AiTaskStatus.inProgress);
        _nodeToTaskMap[node.id] = task.id;
      } else {
        node.executionState = 'failed';
        _triggerUpdate();
        _pausePipeline();
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      node.executionState = 'success';
      _triggerUpdate();
      _executeChildren(node);
    }
  }

  Future<String?> _getAgentPrompt(String agentId) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('ve_agents_nodes');
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        final List<AgentNode> rootNodes = decoded.map((e) => AgentNode.fromJson(e as Map<String, dynamic>)).toList();
        AgentNode? found;
        void find(List<AgentNode> nodes) {
          for (var n in nodes) {
            if (n.id == agentId) found = n;
            find(n.children);
          }
        }
        find(rootNodes);
        return found?.prompt;
      } catch (_) {}
    }
    return null;
  }

  void _onAiBridgeTasksChanged() {
    if (!isRunning.value) return;

    bool updated = false;
    for (var n in _nodes) {
      if (n.executionState == 'running') {
        final taskId = _nodeToTaskMap[n.id];
        if (taskId != null) {
          try {
            final task = AiBridgeService.instance.tasks.firstWhere((t) => t.id == taskId);
            if (task.status == AiTaskStatus.completed) {
              n.executionState = 'success';
              updated = true;
              _executeChildren(n);
            } else if (task.status == AiTaskStatus.bug || task.status == AiTaskStatus.inReview) {
              n.executionState = 'failed';
              updated = true;
              _pausePipeline();
            }
          } catch (_) {
          }
        }
      }
    }
    if (updated) _triggerUpdate();
  }

  void _executeChildren(FlowNode node) {
    if (!isRunning.value) return;

    List<String> rawTargets = [...node.connectedTo];
    for (var i in node.items) rawTargets.addAll(i.connectedTo);

    Set<String> targetNodeIds = {};
    for (var t in rawTargets) {
      targetNodeIds.add(t.split('|')[0]);
    }

    for (var tid in targetNodeIds) {
      try {
        final target = _nodes.firstWhere((n) => n.id == tid);
        final incoming = _getIncomingEdges(target.id);
        bool allSuccess = incoming.every((inc) => inc.executionState == 'success');
        if (allSuccess && target.executionState != 'running' && target.executionState != 'success') {
          _executeNode(target);
        }
      } catch (_) {}
    }
  }

  void _pausePipeline() {
    isRunning.value = false;
    isPaused.value = true;
  }

  void _triggerUpdate() {
    if (onStateUpdated != null) {
      onStateUpdated!();
    }
  }
}
