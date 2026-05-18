import 'package:flutter/material.dart';

class ColorPickerRequest {
  final Color initialColor;
  final ValueChanged<Color?> onColorSelected;
  ColorPickerRequest({required this.initialColor, required this.onColorSelected});
}

class IconPickerRequest {
  final IconData? initialIcon;
  final ValueChanged<IconData?> onIconSelected;
  IconPickerRequest({this.initialIcon, required this.onIconSelected});
}

class NotesEditorRequest {
  final TextEditingController controller;
  final String title;
  final VoidCallback onSaved;
  NotesEditorRequest({required this.controller, required this.title, required this.onSaved});
}

/// Simplified: the viewer owns its attachment list.
/// A request just provides a link target — the task/checklist item context
/// that the user wants to link a selected attachment INTO.
class AttachmentViewerRequest {
  /// Display label for the link target (e.g. task name or checklist item text)
  final String contextLabel;

  /// Called when the user clicks "Link" — passes the selected file path
  final void Function(String path) onLink;

  AttachmentViewerRequest({required this.contextLabel, required this.onLink});
}

class GlobalPickerState {
  static final GlobalPickerState instance = GlobalPickerState._internal();
  GlobalPickerState._internal();

  final ValueNotifier<ColorPickerRequest?> activeColorRequest = ValueNotifier(null);
  final ValueNotifier<IconPickerRequest?> activeIconRequest = ValueNotifier(null);
  final ValueNotifier<NotesEditorRequest?> activeNotesRequest = ValueNotifier(null);
  final ValueNotifier<AttachmentViewerRequest?> activeAttachmentRequest = ValueNotifier(null);

  void requestColor({required Color initialColor, required ValueChanged<Color?> onColorSelected}) {
    activeColorRequest.value = ColorPickerRequest(initialColor: initialColor, onColorSelected: onColorSelected);
  }

  void requestIcon({IconData? initialIcon, required ValueChanged<IconData?> onIconSelected}) {
    activeIconRequest.value = IconPickerRequest(initialIcon: initialIcon, onIconSelected: onIconSelected);
  }

  void requestNotes({required TextEditingController controller, required String title, required VoidCallback onSaved}) {
    activeNotesRequest.value = NotesEditorRequest(controller: controller, title: title, onSaved: onSaved);
  }

  /// Open viewer and set a link context. The viewer's own list is always shown;
  /// when a context is set, a "Link to [contextLabel]" button appears.
  void requestAttachmentViewer({required String contextLabel, required void Function(String) onLink}) {
    activeAttachmentRequest.value = AttachmentViewerRequest(contextLabel: contextLabel, onLink: onLink);
  }

  /// Clear the link context (viewer stays open in standalone mode)
  void clearAttachmentRequest() {
    activeAttachmentRequest.value = null;
  }
}
