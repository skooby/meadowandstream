import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/state_machine_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StateMachineController Tests', () {
    late StateMachineConfig config;
    late StateMachineController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      config = const StateMachineConfig(
        nodes: [
          StateNodeConfig(id: 'idle', label: 'Idle', position: Offset(0, 0)),
          StateNodeConfig(id: 'running', label: 'Running', position: Offset(10, 10)),
          StateNodeConfig(id: 'success', label: 'Success', position: Offset(20, 20)),
        ],
        transitions: [
          TransitionConfig(from: 'idle', to: 'running', label: 'start'),
          TransitionConfig(from: 'running', to: 'success', label: 'complete'),
        ],
      );
      controller = StateMachineController(
        config: config,
        initialActiveStateId: 'idle',
      );
    });

    test('Loads initial state machine from config', () {
      expect(controller.allNodes.length, equals(3));
      expect(controller.allTransitions.length, equals(2));
    });

    test('removeTransition removes transition and persists in SharedPreferences', () async {
      // Initially, transitions contain static ones
      expect(controller.allTransitions.any((t) => t.from == 'idle' && t.to == 'running'), isTrue);

      controller.removeTransition('idle', 'running');

      // Now it should be filtered out
      expect(controller.allTransitions.any((t) => t.from == 'idle' && t.to == 'running'), isFalse);

      // Wait a short time for the asynchronous write to finish
      await Future.delayed(const Duration(milliseconds: 10));

      // Verify saving to SharedPreferences under the unified key
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('ve_sm_transitions');
      expect(savedStr, isNotNull);
      final List<dynamic> savedList = jsonDecode(savedStr!);
      expect(savedList.any((t) => t['from'] == 'idle' && t['to'] == 'running'), isFalse);
    });

    test('addCustomTransition adds transition and persists in SharedPreferences', () async {
      const customT = TransitionConfig(from: 'idle', to: 'success', label: 'shortcut');
      controller.addCustomTransition(customT);

      expect(controller.allTransitions.any((t) => t.from == 'idle' && t.to == 'success'), isTrue);

      // Wait a short time for the asynchronous write to finish
      await Future.delayed(const Duration(milliseconds: 10));

      // Verify saving to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('ve_sm_transitions');
      expect(savedStr, isNotNull);
      final List<dynamic> savedList = jsonDecode(savedStr!);
      expect(savedList.any((t) => t['from'] == 'idle' && t['to'] == 'success' && t['label'] == 'shortcut'), isTrue);
    });

    test('Loads custom nodes with integer position coordinates successfully', () async {
      SharedPreferences.setMockInitialValues({
        've_sm_nodes': jsonEncode([
          {
            'id': 'node_int_coord',
            'label': 'Int Coord Node',
            'color': 4282384383,
            'position_x': 300,
            'position_y': 200,
            'description': 'Test node'
          }
        ])
      });

      final controller2 = StateMachineController(
        config: config,
        initialActiveStateId: 'idle',
      );

      // Give SharedPreferences dynamic load a tick to resolve async call
      await Future.delayed(const Duration(milliseconds: 10));

      final node = controller2.getNode('node_int_coord');
      expect(node, isNotNull);
      expect(node!.position.dx, equals(300.0));
      expect(node.position.dy, equals(200.0));
    });

    test('Add, update, and remove State Machine Inputs', () async {
      final input = StateMachineInput(
        name: 'speed',
        type: StateMachineInputType.number,
        value: 10.0,
      );
      controller.addInput(input);
      expect(controller.allInputs.length, equals(1));
      expect(controller.allInputs.first.name, equals('speed'));
      expect(controller.allInputs.first.value, equals(10.0));

      controller.updateInputValue('speed', 15.5);
      expect(controller.allInputs.first.value, equals(15.5));

      controller.removeInput('speed');
      expect(controller.allInputs.isEmpty, isTrue);
    });

    test('Add and remove Transition Conditions', () async {
      final input = StateMachineInput(
        name: 'isDead',
        type: StateMachineInputType.boolean,
        value: false,
      );
      controller.addInput(input);

      final condition = TransitionCondition(
        inputName: 'isDead',
        op: ConditionOp.equals,
        value: true,
      );
      controller.addTransitionCondition('idle', 'running', condition);

      final trans = controller.allTransitions.firstWhere((t) => t.from == 'idle' && t.to == 'running');
      expect(trans.conditions.length, equals(1));
      expect(trans.conditions.first.inputName, equals('isDead'));
      expect(trans.conditions.first.op, equals(ConditionOp.equals));
      expect(trans.conditions.first.value, equals(true));

      controller.removeTransitionCondition('idle', 'running', 0);
      final transAfter = controller.allTransitions.firstWhere((t) => t.from == 'idle' && t.to == 'running');
      expect(transAfter.conditions.isEmpty, isTrue);
    });

    test('Add entering action and trigger on transitionTo', () {
      final input = StateMachineInput(
        name: 'level',
        type: StateMachineInputType.number,
        value: 1.0,
      );
      controller.addInput(input);

      final action = NodeStateAction(
        inputName: 'level',
        value: 5.0,
      );
      controller.addNodeAction('running', action);

      final runningNode = controller.getNode('running');
      expect(runningNode!.actions.length, equals(1));
      expect(runningNode.actions.first.inputName, equals('level'));
      expect(runningNode.actions.first.value, equals(5.0));

      // Transition to 'running' to trigger the action
      controller.transitionTo('running');
      expect(controller.allInputs.firstWhere((i) => i.name == 'level').value, equals(5.0));
    });

    test('Automatic transition when updating input value satisfies condition', () {
      final input = StateMachineInput(
        name: 'goNext',
        type: StateMachineInputType.boolean,
        value: false,
      );
      controller.addInput(input);

      final condition = TransitionCondition(
        inputName: 'goNext',
        op: ConditionOp.equals,
        value: true,
      );
      controller.addTransitionCondition('idle', 'running', condition);

      expect(controller.visualState.activeStateId, equals('idle'));

      // Update the input value to satisfy the condition
      controller.updateInputValue('goNext', true);

      // It should automatically evaluate and transition to 'running'
      expect(controller.visualState.activeStateId, equals('running'));
    });

    test('File binding updates input value dynamically', () async {
      final file = File('.ai_scratch/agent_status.txt');
      await Directory('.ai_scratch').create(recursive: true);
      await file.writeAsString('100.5');

      final input = StateMachineInput(
        name: 'AgentStatus',
        type: StateMachineInputType.number,
        value: 0.0,
        bindFilePath: file.path,
      );
      controller.addInput(input);

      // Wait for binding timer check (runs every 1 second)
      await Future.delayed(const Duration(milliseconds: 1200));

      final updatedInput = controller.allInputs.firstWhere((i) => i.name == 'AgentStatus');
      expect(updatedInput.value, equals(100.5));

      if (await file.exists()) {
        await file.delete();
      }
    });

    test('editInput updates name and propagates changes to transition conditions and node actions', () {
      final input = StateMachineInput(
        name: 'oldName',
        type: StateMachineInputType.boolean,
        value: false,
      );
      controller.addInput(input);

      controller.addTransitionCondition(
        'idle',
        'running',
        TransitionCondition(inputName: 'oldName', op: ConditionOp.equals, value: true),
      );

      controller.addNodeAction(
        'idle',
        NodeStateAction(inputName: 'oldName', value: true),
      );

      controller.editInput(
        'oldName',
        StateMachineInput(name: 'newName', type: StateMachineInputType.boolean, value: false),
      );

      expect(controller.allInputs.any((i) => i.name == 'oldName'), isFalse);
      expect(controller.allInputs.any((i) => i.name == 'newName'), isTrue);

      final trans = controller.allTransitions.firstWhere((t) => t.from == 'idle' && t.to == 'running');
      expect(trans.conditions.first.inputName, equals('newName'));

      final node = controller.getNode('idle');
      expect(node!.actions.first.inputName, equals('newName'));
    });
  });
}
