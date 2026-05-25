import 'dart:io';
import 'package:flutter/material.dart';
import 'package:statemachine/statemachine.dart' as sm;
import 'state_machine_models.dart';

/// Concrete state machine manager for the AI Bridge pipeline.
/// Integrates statemachine.dart with our general-purpose StateMachineController.
class AiBridgeStateMachine {
  final sm.Machine<String> _machine = sm.Machine<String>();

  // StateMachine Controller for Visualizer
  late final StateMachineController visualController;

  // statemachine.dart State Nodes
  late final sm.State idleState;
  late final sm.State dispatchingState;
  late final sm.State busyState;
  late final sm.State compilingState;
  late final sm.State synchronizingState;
  late final sm.State previewingState;
  late final sm.State errorState;

  // Callbacks hooked to actual AiBridgeService actions
  VoidCallback? onDispatchStart;
  VoidCallback? onBusyStart;
  VoidCallback? onCompileStart;
  VoidCallback? onSyncStart;
  VoidCallback? onPreviewStart;
  VoidCallback? onErrorStart;
  VoidCallback? onIdleStart;

  AiBridgeStateMachine() {
    _setupTopology();
  }

  void _setupTopology() {
    // 1. Setup generic config for visualizer layout (hexagon coordinates)
    const config = StateMachineConfig(
      nodes: [
        StateNodeConfig(
          id: 'idle',
          label: 'Standby (Idle)',
          icon: Icons.pause_circle_outline,
          color: Colors.blueGrey,
          position: Offset(50, 180),
          description: 'AI Bridge is idle. Waiting for tasks to be queued.',
        ),
        StateNodeConfig(
          id: 'dispatching',
          label: 'Dispatching',
          icon: Icons.send_outlined,
          color: Colors.amberAccent,
          position: Offset(250, 60),
          description: 'Preparing task payload and invoking the LLM agent.',
        ),
        StateNodeConfig(
          id: 'busy',
          label: 'Agent Busy',
          icon: Icons.cached,
          color: Colors.greenAccent,
          position: Offset(450, 180),
          description: 'LLM Agent is actively performing execution work.',
        ),
        StateNodeConfig(
          id: 'previewing',
          label: 'Awaiting Preview',
          icon: Icons.rate_review_outlined,
          color: Colors.deepOrangeAccent,
          position: Offset(250, 300),
          description: 'Agent requires user review or answer clarification.',
        ),
        StateNodeConfig(
          id: 'compiling',
          label: 'Compiling Check',
          icon: Icons.science_outlined,
          color: Colors.cyanAccent,
          position: Offset(650, 60),
          description: 'Running dart analyze to verify compilation build.',
        ),
        StateNodeConfig(
          id: 'synchronizing',
          label: 'Synchronizing',
          icon: Icons.sync,
          color: Colors.purpleAccent,
          position: Offset(650, 300),
          description: 'Ingesting notes and verification logs to database.',
        ),
        StateNodeConfig(
          id: 'error',
          label: 'System Error',
          icon: Icons.warning_amber_rounded,
          color: Colors.redAccent,
          position: Offset(450, 300),
          description: 'AI Bridge pipeline encountered an error or timeout.',
        ),
      ],
      transitions: [
        const TransitionConfig(
          from: 'idle',
          to: 'dispatching',
          label: 'queueTask',
          conditions: [TransitionCondition(inputName: 'BridgeActive', op: ConditionOp.equals, value: true)],
        ),
        const TransitionConfig(
          from: 'dispatching',
          to: 'busy',
          label: 'onAgyBusy',
          conditions: [TransitionCondition(inputName: 'AgentStatus', op: ConditionOp.equals, value: true)],
        ),
        const TransitionConfig(
          from: 'dispatching',
          to: 'error',
          label: 'timeout/focusLoss',
          conditions: [TransitionCondition(inputName: 'BridgeActive', op: ConditionOp.equals, value: false)],
        ),
        const TransitionConfig(
          from: 'busy',
          to: 'compiling',
          label: 'onAgyIdle',
          conditions: [
            TransitionCondition(inputName: 'AgentBusy', op: ConditionOp.equals, value: false),
            TransitionCondition(inputName: 'AgentStatus', op: ConditionOp.equals, value: false),
          ],
        ),
        const TransitionConfig(
          from: 'busy',
          to: 'previewing',
          label: 'onAgyPreview',
          conditions: [
            TransitionCondition(inputName: 'AgentBusy', op: ConditionOp.equals, value: false),
            TransitionCondition(inputName: 'AgentStatus', op: ConditionOp.equals, value: true),
          ],
        ),
        const TransitionConfig(
          from: 'busy',
          to: 'error',
          label: 'crash/timeout',
          conditions: [TransitionCondition(inputName: 'BridgeActive', op: ConditionOp.equals, value: false)],
        ),
        const TransitionConfig(
          from: 'compiling',
          to: 'synchronizing',
          label: 'analyzePass',
          conditions: [TransitionCondition(inputName: 'AgentThinking', op: ConditionOp.equals, value: false)],
        ),
        const TransitionConfig(
          from: 'compiling',
          to: 'error',
          label: 'analyzeFail',
          conditions: [TransitionCondition(inputName: 'BridgeActive', op: ConditionOp.equals, value: false)],
        ),
        const TransitionConfig(
          from: 'synchronizing',
          to: 'idle',
          label: 'syncCompleted',
          conditions: [TransitionCondition(inputName: 'AgentStatus', op: ConditionOp.equals, value: false)],
        ),
        const TransitionConfig(
          from: 'synchronizing',
          to: 'error',
          label: 'missingFiles',
          conditions: [TransitionCondition(inputName: 'BridgeActive', op: ConditionOp.equals, value: false)],
        ),
        const TransitionConfig(
          from: 'previewing',
          to: 'idle',
          label: 'userSubmit',
          conditions: [TransitionCondition(inputName: 'AgentStatus', op: ConditionOp.equals, value: false)],
        ),
        const TransitionConfig(
          from: 'previewing',
          to: 'dispatching',
          label: 'retryTask',
          conditions: [TransitionCondition(inputName: 'AgentThinking', op: ConditionOp.equals, value: true)],
        ),
        const TransitionConfig(
          from: 'error',
          to: 'idle',
          label: 'reset',
          conditions: [TransitionCondition(inputName: 'BridgeActive', op: ConditionOp.equals, value: true)],
        ),
      ],
    );

    visualController = StateMachineController(
      config: config,
      initialActiveStateId: 'idle',
    );
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      visualController.enableBindingTimer = false;
    }

    // 2. Initialize statemachine.dart states
    idleState = _machine.newState('idle');
    dispatchingState = _machine.newState('dispatching');
    busyState = _machine.newState('busy');
    compilingState = _machine.newState('compiling');
    synchronizingState = _machine.newState('synchronizing');
    previewingState = _machine.newState('previewing');
    errorState = _machine.newState('error');

    // 3. Define Entry Callbacks to sync with visualizer
    idleState.onEntry(() {
      visualController.transitionTo('idle', statusMessage: 'Standing by for prompts.');
      onIdleStart?.call();
    });

    dispatchingState.onEntry(() {
      visualController.transitionTo('dispatching', statusMessage: 'Pasting instructions via VBScript...');
      onDispatchStart?.call();
    });

    busyState.onEntry(() {
      visualController.transitionTo('busy', statusMessage: 'Agent is executing...');
      onBusyStart?.call();
    });

    compilingState.onEntry(() {
      visualController.transitionTo('compiling', statusMessage: 'Running dart analyze check...');
      onCompileStart?.call();
    });

    synchronizingState.onEntry(() {
      visualController.transitionTo('synchronizing', statusMessage: 'Ingesting verification outcomes...');
      onSyncStart?.call();
    });

    previewingState.onEntry(() {
      visualController.transitionTo('previewing', statusMessage: 'Awaiting user input for clarification.');
      onPreviewStart?.call();
    });

    errorState.onEntry(() {
      visualController.transitionTo('error', statusMessage: 'Pipeline stuck or broken.');
      onErrorStart?.call();
    });
  }

  /// Starts the state machine.
  void start() {
    _machine.start();
  }

  /// Current state ID.
  String get state => _machine.current?.identifier ?? 'idle';

  // State transition triggers
  void enterIdle() => idleState.enter();
  void enterDispatching() => dispatchingState.enter();
  void enterBusy() => busyState.enter();
  void enterCompiling() => compilingState.enter();
  void enterSynchronizing() => synchronizingState.enter();
  void enterPreviewing() => previewingState.enter();
  
  void enterError(String errorMessage) {
    errorState.enter();
    visualController.setError(errorMessage);
  }
}
