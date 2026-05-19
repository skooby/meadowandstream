import 'package:flutter/material.dart';
import 'package:simple_spell_checker/simple_spell_checker.dart';
import 'package:simple_spell_checker_en_lan/simple_spell_checker_en_lan.dart';

class SpellCheckTextEditingController extends TextEditingController {
  static SimpleSpellChecker? _spellChecker;
  bool isEditing = false;

  SpellCheckTextEditingController({String? text}) : super(text: text) {
    _initSpellChecker();
  }

  static void _initSpellChecker() {
    if (_spellChecker == null) {
      SimpleSpellCheckerEnRegister.registerLan(preferEnglish: 'en');
      _spellChecker = SimpleSpellChecker(
        language: 'en',
        whiteList: <String>[],
        caseSensitive: false,
      );
    }
  }

  void setEditing(bool editing) {
    if (isEditing != editing) {
      isEditing = editing;
      notifyListeners();
    }
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (!isEditing || _spellChecker == null || text.isEmpty) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }

    try {
      final spans = _spellChecker!.check(
        text,
        wrongStyle: style?.copyWith(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.wavy,
          decorationColor: Colors.redAccent,
        ) ?? const TextStyle(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.wavy,
          decorationColor: Colors.redAccent,
        ),
        commonStyle: style ?? const TextStyle(),
      );

      if (spans != null && spans.isNotEmpty) {
        return TextSpan(style: style, children: spans);
      }
    } catch (e) {
      debugPrint('Spell check error: $e');
    }

    return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
  }

  static Map<String, int>? getRawDictionary() {
    return _spellChecker?.getDictionary();
  }

  static List<String> getSuggestions(String word) {
    if (_spellChecker == null) return [];
    final dictionary = _spellChecker!.getDictionary();
    if (dictionary == null) return [];

    final target = word.toLowerCase();

    int levenshtein(String a, String b) {
      if (a.isEmpty) return b.length;
      if (b.isEmpty) return a.length;

      List<int> v0 = List<int>.generate(b.length + 1, (i) => i);
      List<int> v1 = List<int>.filled(b.length + 1, 0);

      for (int i = 0; i < a.length; i++) {
        v1[0] = i + 1;
        for (int j = 0; j < b.length; j++) {
          int cost = (a[i] == b[j]) ? 0 : 1;
          int min = v1[j] + 1;
          if (v0[j + 1] + 1 < min) min = v0[j + 1] + 1;
          if (v0[j] + cost < min) min = v0[j] + cost;
          v1[j + 1] = min;
        }
        for (int j = 0; j < v0.length; j++) v0[j] = v1[j];
      }
      return v1[b.length];
    }

    final candidates = <String, int>{};
    for (var entry in dictionary.keys) {
      if ((entry.length - target.length).abs() > 2) continue;
      if (entry.isEmpty) continue;

      int dist = levenshtein(target, entry);
      if (dist <= 2) {
        candidates[entry] = dist;
      }
    }

    var sorted = candidates.keys.toList()..sort((a, b) => candidates[a]!.compareTo(candidates[b]!));
    return sorted.take(4).toList();
  }

  static Widget buildContextMenu(BuildContext context, EditableTextState editableTextState) {
    final TextEditingValue value = editableTextState.textEditingValue;
    final TextSelection selection = value.selection;
    final String text = value.text;

    int cursor = selection.baseOffset;
    if (cursor < 0 || cursor > text.length) cursor = 0;

    int start = cursor;
    while (start > 0 && RegExp(r"[a-zA-Z']").hasMatch(text[start - 1])) {
      start--;
    }
    int end = cursor;
    while (end < text.length && RegExp(r"[a-zA-Z']").hasMatch(text[end])) {
      end++;
    }

    String word = '';
    if (start < end) {
      word = text.substring(start, end);
    }

    List<ContextMenuButtonItem> buttonItems = editableTextState.contextMenuButtonItems.toList();

    if (word.isNotEmpty) {
      final dictionary = getRawDictionary();
      if (dictionary != null && !dictionary.containsKey(word.toLowerCase())) {
        final suggestions = getSuggestions(word);
        if (suggestions.isNotEmpty) {
          final suggestionItems = suggestions.map((s) {
            final properCaseS = (word.isNotEmpty && word[0].toUpperCase() == word[0])
                ? (s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s)
                : s;
            return ContextMenuButtonItem(
              label: '\"$properCaseS\"',
              onPressed: () {
                ContextMenuController.removeAny();
                final newValue = value.replaced(TextRange(start: start, end: end), properCaseS);
                editableTextState.updateEditingValue(newValue);
              },
            );
          }).toList();
          
          buttonItems.insertAll(0, suggestionItems);
        }
      }
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }
}
