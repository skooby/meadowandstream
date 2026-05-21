import 'package:flutter/material.dart';
import 'package:simple_spell_checker/simple_spell_checker.dart';
import 'package:simple_spell_checker_en_lan/simple_spell_checker_en_lan.dart';

class SpellCheckTextEditingController extends TextEditingController {
  static SimpleSpellChecker? _spellChecker;
  bool isEditing = false;

  // Regular expression components for custom word tokenization
  static const String _whitespaces = r'''\p{Z}''';
  static const String _allWords =
      r'''\p{L}\p{M}\p{Lm}\p{Lo}\p{Script=Arabic}\p{Script=Armenian}\p{Script=Bengali}\p{Script=Bopomofo}\p{Script=Braille}\p{Script=Buhid}\p{Script=Canadian_Aboriginal}\p{Script=Cherokee}\p{Script=Cyrillic}\p{Script=Devanagari}\p{Script=Ethiopic}\p{Script=Georgian}\p{Script=Greek}\p{Script=Gujarati}\p{Script=Gurmukhi}\p{Script=Han}\p{Script=Hangul}\p{Script=Hanunoo}\p{Script=Hebrew}\p{Script=Hiragana}\p{Script=Inherited}\p{Script=Kannada}\p{Script=Katakana}\p{Script=Khmer}\p{Script=Lao}\p{Script=Latin}\p{Script=Limbu}\p{Script=Malayalam}\p{Script=Mongolian}\p{Script=Myanmar}\p{Script=Ogham}\p{Script=Oriya}\p{Script=Runic}\p{Script=Sinhala}\p{Script=Syriac}\p{Script=Tagalog}\p{Script=Tagbanwa}\p{Script=Tamil}\p{Script=Telugu}\p{Script=Thaana}\p{Script=Thai}\p{Script=Tibetan}\p{Script=Yi}''';
  static const String _nonWordsCharacters =
      r'''\p{P}\p{N}\p{Pd}\p{Nd}\p{Nl}\p{Pi}\p{No}\p{Pf}\p{Pc}\p{Ps}\p{Cf}\p{Co}\p{Cn}\p{Cs}\p{Pe}\p{S}\p{Sm}\p{Sc}\p{Sk}\p{So}\p{Cc}\p{Po}\p{Mc}''';

  // Matches word blocks, allowing words to optionally contain embedded apostrophes for contractions.
  static final RegExp _wordTokenizerRegex = RegExp(
      '''([$_whitespaces]+|[$_allWords]+(?:['’][$_allWords]+)*|[$_nonWordsCharacters])''',
      unicode: true);

  static final RegExp _letterRegex = RegExp(r'\p{L}', unicode: true);

  // Common English contractions to whitelist if they are missing from the raw dictionary
  static const Set<String> _standardContractions = {
    "don't", "doesn't", "isn't", "aren't", "wasn't", "weren't",
    "hasn't", "haven't", "hadn't", "won't", "wouldn't", "can't",
    "couldn't", "shouldn't", "mightn't", "mustn't",
    "it's", "i'm", "you're", "he's", "she's", "we're", "they're",
    "i've", "you've", "we've", "they've",
    "i'd", "you'd", "he'd", "she'd", "we'd", "they'd",
    "i'll", "you'll", "he'll", "she'll", "we'll", "they'll",
    "let's", "there's", "here's", "that's",
    "who's", "what's", "where's", "when's", "why's", "how's"
  };

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

  static bool _isWordValid(String word) {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return true;

    final lower = trimmed.toLowerCase();
    
    // Whitelist standard contractions
    if (_standardContractions.contains(lower)) return true;

    // Check if it's a number or contains numbers
    if (RegExp(r'\d').hasMatch(trimmed)) return true;

    // Lookup in loaded dictionary
    final dictionary = _spellChecker?.getDictionary();
    if (dictionary != null) {
      final valid = dictionary[lower];
      return valid != null && valid == 1;
    }
    return true;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (!isEditing || _spellChecker == null || text.isEmpty) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }

    try {
      final spans = <TextSpan>[];
      final matches = _wordTokenizerRegex.allMatches(text);
      final defaultWrongStyle = style?.copyWith(
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.wavy,
        decorationColor: Colors.redAccent,
      ) ?? const TextStyle(
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.wavy,
        decorationColor: Colors.redAccent,
      );
      final commonStyle = style ?? const TextStyle();

      for (final match in matches) {
        final token = match.group(0)!;
        
        // If it doesn't contain any letters, treat as general whitespace/punctuation
        if (!_letterRegex.hasMatch(token)) {
          spans.add(TextSpan(text: token, style: commonStyle));
        } else {
          // Check spelling
          if (_isWordValid(token)) {
            spans.add(TextSpan(text: token, style: commonStyle));
          } else {
            spans.add(TextSpan(
              text: token,
              style: defaultWrongStyle,
            ));
          }
        }
      }

      if (spans.isNotEmpty) {
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
    while (start > 0 && RegExp(r"[a-zA-Z'’]").hasMatch(text[start - 1])) {
      start--;
    }
    int end = cursor;
    while (end < text.length && RegExp(r"[a-zA-Z'’]").hasMatch(text[end])) {
      end++;
    }

    String word = '';
    if (start < end) {
      word = text.substring(start, end);
    }

    List<ContextMenuButtonItem> buttonItems = editableTextState.contextMenuButtonItems.toList();

    if (word.isNotEmpty) {
      final dictionary = getRawDictionary();
      final lowerWord = word.toLowerCase();
      
      final isInvalid = dictionary != null && 
          !dictionary.containsKey(lowerWord) && 
          !_standardContractions.contains(lowerWord);

      if (isInvalid) {
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
