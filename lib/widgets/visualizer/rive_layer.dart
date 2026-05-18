import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

class RiveLayer extends StatefulWidget {
  final String assetPath;
  final bool isPlaying;
  final Map<String, dynamic> variables;

  const RiveLayer({
    super.key,
    required this.assetPath,
    this.isPlaying = true,
    this.variables = const {},
  });

  @override
  State<RiveLayer> createState() => _RiveLayerState();
}

class _RiveLayerState extends State<RiveLayer> {
  Artboard? _artboard;
  StateMachineController? _stateMachineController;
  String? _loadedAssetPath;

  @override
  void initState() {
    super.initState();
    _loadRiveFile();
  }

  Future<void> _loadRiveFile() async {
    try {
      final data = await rootBundle.load(widget.assetPath);
      final file = RiveFile.import(data);

      if (file.mainArtboard.stateMachines.isEmpty) {
        debugPrint("No state machine found in Rive file: ${widget.assetPath}");
        return;
      }

      final artboard = file.mainArtboard.instance();
      final stateMachineName = artboard.stateMachines.first.name;

      var controller = StateMachineController.fromArtboard(
        artboard,
        stateMachineName,
      );

      if (controller != null) {
        artboard.addController(controller);
        _stateMachineController = controller;
        controller.isActive = widget.isPlaying;
      }

      if (mounted) {
        setState(() {
          _artboard = artboard;
          _loadedAssetPath = widget.assetPath;
        });
        _applyVariables();
      }
    } catch (e) {
      debugPrint("Error loading Rive file: $e");
    }
  }

  @override
  void didUpdateWidget(covariant RiveLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.assetPath != oldWidget.assetPath) {
      _loadRiveFile();
    } else if (_artboard != null) {
      if (widget.isPlaying != oldWidget.isPlaying) {
        _stateMachineController?.isActive = widget.isPlaying;
      }
      _applyVariables();
    }
  }

  void _applyVariables() {
    if (_stateMachineController == null) return;

    widget.variables.forEach((key, variable) {
      final input = _stateMachineController!.findInput<dynamic>(key);
      if (input != null) {
        if (variable is num && input is SMINumber) {
          input.value = variable.toDouble();
        } else if (variable is bool && input is SMIBool) {
          input.value = variable;
        } else if (variable == true && input is SMITrigger) {
          input.fire();
        }
      }
    });
  }

  @override
  void dispose() {
    _stateMachineController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_artboard == null || _loadedAssetPath != widget.assetPath) {
      return const SizedBox.shrink();
    }
    return Rive(
      artboard: _artboard!,
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );
  }
}
