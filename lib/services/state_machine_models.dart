import 'package:flutter/material.dart';

/// Configuration for a single node (state) in a state machine.
class StateNodeConfig {
  final String id;
  final String label;
  final IconData? icon;
  final Color color;
  final Offset position;
  final String description;

  const StateNodeConfig({
    required this.id,
    required this.label,
    this.icon,
    this.color = Colors.blueAccent,
    required this.position,
    this.description = '',
  });
}

/// Configuration for a transition edge between states in a state machine.
class TransitionConfig {
  final String from;
  final String to;
  final String label;

  const TransitionConfig({
    required this.from,
    required this.to,
    this.label = '',
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

  StateMachineVisualState get visualState => _visualState;

  StateMachineController({
    required this.config,
    required String initialActiveStateId,
  }) {
    _visualState = StateMachineVisualState(
      activeStateId: initialActiveStateId,
      enteredAt: DateTime.now(),
    );
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
    notifyListeners();
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
