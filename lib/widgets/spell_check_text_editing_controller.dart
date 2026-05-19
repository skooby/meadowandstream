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
}
