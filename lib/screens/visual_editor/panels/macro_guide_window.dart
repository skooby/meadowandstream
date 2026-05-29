import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../state/global_picker_state.dart';
import '../visual_editor_screen.dart';
import '../../../constants.dart';
import 'global_notes_editor_window.dart';

final ValueNotifier<bool> showMacroGuideNotifier = ValueNotifier(false);

/// Opens the macro guide in the shared Notes Editor window.
/// The guide is fully editable — edits are saved back to the .md file on change.
void showMacroGuideWindow(BuildContext context) {
  _openGuideInNotesEditor(context);
}

Future<void> _openGuideInNotesEditor(BuildContext context) async {
  const guidePath = '.ai_bridge/knowledge/macro_coding_guide.md';
  String content = '';
  try {
    final file = File(guidePath);
    if (await file.exists()) content = await file.readAsString();
  } catch (_) {}

  final ctrl = TextEditingController(text: content);

  GlobalPickerState.instance.requestNotes(
    controller: ctrl,
    title: 'Macro Coding Guide',
    onSaved: () async {
      try {
        await File(guidePath).writeAsString(ctrl.text);
      } catch (_) {}
    },
  );

  showNotesEditorWindow(context);
}

void hideMacroGuideWindow() {
  showMacroGuideNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showMacroGuide'), false));
}

/// Empty placeholder — kept so visual_editor_screen.dart needs no changes.
/// All UI is now handled by GlobalNotesEditorWindow.
class MacroGuideWindow extends StatelessWidget {
  final bool isDocked;
  final VoidCallback onClose;
  final VoidCallback? onFocus;
  const MacroGuideWindow({super.key, required this.onClose, this.onFocus, this.isDocked = false});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
