import '../constants.dart';

class LyricWord {
  final int startMs;
  final String text;

  LyricWord({required this.startMs, required this.text});
}

class LyricLine {
  final int startMs;
  int get timeMs => startMs;
  final String text;
  final List<LyricWord> words;

  LyricLine({
    required this.startMs,
    required this.text,
    this.words = const [],
  });
  
  LyricLine copyWith({
    int? startMs,
    String? text,
    List<LyricWord>? words,
  }) {
    return LyricLine(
      startMs: startMs ?? this.startMs,
      text: text ?? this.text,
      words: words ?? this.words,
    );
  }
}

class LrcParser {
  static final RegExp _lineTimestampRegex =
      RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');
  static final RegExp _wordTimestampRegex =
      RegExp(r'<(\d{2}):(\d{2})\.(\d{2,3})>');

  static String generateLrc(List<LyricLine> lines) {
    final buffer = StringBuffer();
    for (var line in lines) {
      if (line.text.trim().isEmpty) continue; // skip generated silences
      final min = (line.startMs ~/ 60000).toString().padLeft(2, '0');
      final sec = ((line.startMs % 60000) ~/ 1000).toString().padLeft(2, '0');
      final ms = (line.startMs % 1000).toString().padLeft(3, '0').substring(0, 2);
      buffer.writeln('[$min:$sec.$ms]${line.text}');
    }
    return buffer.toString();
  }

  static List<LyricLine> parse(String lrcText) {
    lrcText = lrcText.replaceAll('...', '…');
    final lines = lrcText.split('\n');
    final List<LyricLine> parsedLines = [];

    for (final line in lines) {
      final lineMatches = _lineTimestampRegex.allMatches(line);
      if (lineMatches.isEmpty) {
        continue; // Ignore metadata or empty/malformed lines
      }

      // Clean the text from line-level timestamps to isolate the lyrics/words segment
      String remainingText = line.replaceAll(_lineTimestampRegex, '').trim();

      // Parse Word-Level Timings
      final words = <LyricWord>[];
      final wordMatches =
          _wordTimestampRegex.allMatches(remainingText).toList();
      String displayText = '';

      if (wordMatches.isNotEmpty) {
        // Parse segments bounded by tags
        for (int i = 0; i < wordMatches.length; i++) {
          final match = wordMatches[i];
          final startMs = _parseTimestampToMs(match);

          final startIdx = match.end;
          final endIdx = (i + 1 < wordMatches.length)
              ? wordMatches[i + 1].start
              : remainingText.length;

          final wordText = remainingText.substring(startIdx, endIdx);
          words.add(LyricWord(startMs: startMs, text: wordText));
          displayText += wordText;
        }
      } else {
        // Fallback: no word timings, raw text
        displayText = remainingText;
      }

      // Add a LyricLine for each line-level timestamp found (e.g., duplicated lyrics)
      for (final match in lineMatches) {
        final totalMs = _parseTimestampToMs(match);
        parsedLines.add(LyricLine(
          startMs: totalMs,
          text: displayText,
          words: words,
        ));
      }
    }

    parsedLines.sort((a, b) => a.startMs.compareTo(b.startMs));

    // Pass 1: Split long lines smartly into up to 3 lines
    List<LyricLine> splitLines = [];
    for (int i = 0; i < parsedLines.length; i++) {
      final current = parsedLines[i];
      if (current.text.length <= AppLyricsConfig.maxLineLength) {
        splitLines.add(current);
        continue;
      }

      int nextStart = (i + 1 < parsedLines.length)
          ? parsedLines[i + 1].startMs
          : current.startMs + AppLyricsConfig.splitFallbackNextLineDiffMs;

      splitLines.addAll(_splitLineIteratively(
          current, nextStart, AppLyricsConfig.maxStackedLines));
    }

    // Pass 2: Inject blank lines for gaps (so lines don't stay onscreen indefinitely)
    List<LyricLine> finalLines = [];
    for (int i = 0; i < splitLines.length; i++) {
      final line = splitLines[i];
      finalLines.add(line);

      if (line.text.trim().isNotEmpty && i + 1 < splitLines.length) {
        final nextLine = splitLines[i + 1];
        if (nextLine.text.trim().isEmpty) {
          continue; // Next line is already an explicit blank
        }

        int endMs;
        if (line.words.isNotEmpty) {
          endMs = line.words.last.startMs +
              AppLyricsConfig.defaultWordLeewayMs; // leeway after last word
        } else {
          endMs = line.startMs +
              AppLyricsConfig
                  .defaultLineLeewayMs; // leeway for unstructured line
        }

        if (endMs <= line.startMs) {
          endMs = line.startMs + AppLyricsConfig.defaultWordLeewayMs;
        }

        // If the gap to the next vocal line is significant enough silence gap, drop a blank payload
        if (nextLine.startMs - endMs > AppLyricsConfig.minSilenceGapMs &&
            endMs < nextLine.startMs) {
          finalLines.add(LyricLine(startMs: endMs, text: '', words: []));
        }
      }
    }

    if (finalLines.isNotEmpty && finalLines.last.text.trim().isNotEmpty) {
      final last = finalLines.last;
      int endMs = last.words.isNotEmpty
          ? last.words.last.startMs + AppLyricsConfig.defaultLineLeewayMs
          : last.startMs + AppLyricsConfig.itemEndLeewayMs;
      finalLines.add(LyricLine(startMs: endMs, text: '', words: []));
    }

    return finalLines;
  }

  static List<LyricLine> _splitLineIteratively(
      LyricLine line, int overrideNextStartMs, int maxLines) {
    if (!AppLyricsConfig.temporalLineSplitting) {
      return [_injectNewlinesIteratively(line, maxLines)];
    }

    List<LyricLine> result = [line];

    while (result.length < maxLines) {
      int toSplitIdx = -1;
      for (int i = 0; i < result.length; i++) {
        if (result[i].text.length > AppLyricsConfig.maxLineLength) {
          toSplitIdx = i;
          break; // split the earliest long one to simulate left-to-right wrapping
        }
      }

      if (toSplitIdx == -1) break; // All lines are within maxLineLength

      LyricLine toSplit = result[toSplitIdx];
      // Target length is `maxLineLength` to ensure the first chunk fits neatly
      int splitIndex = _findSplitIndex(toSplit.text,
          targetLength: AppLyricsConfig.maxLineLength);

      if (splitIndex <= AppLyricsConfig.minSplitEdgeChars ||
          splitIndex >=
              toSplit.text.length - AppLyricsConfig.minSplitEdgeChars) {
        break; // Cannot split gracefully using safe edge spacing bounds
      }

      int currentNextStartMs = (toSplitIdx + 1 < result.length)
          ? result[toSplitIdx + 1].startMs
          : overrideNextStartMs;

      final halves = _splitLineInTwo(toSplit, currentNextStartMs, splitIndex);
      result.replaceRange(toSplitIdx, toSplitIdx + 1, halves);
    }

    return result;
  }

  static LyricLine _injectNewlinesIteratively(LyricLine line, int maxLines) {
    String currentText = line.text;
    List<LyricWord> currentWords = List.from(line.words);

    while (true) {
      final segments = currentText.split('\n');
      if (segments.length >= maxLines) break;

      int toSplitIdx = -1;
      for (int i = 0; i < segments.length; i++) {
        if (segments[i].length > AppLyricsConfig.maxLineLength) {
          toSplitIdx = i;
          break; // split earliest long one
        }
      }

      if (toSplitIdx == -1) break;

      int segStartOffset = 0;
      for (int i = 0; i < toSplitIdx; i++) {
        segStartOffset +=
            segments[i].length + 1; // +1 for the \n char we split on
      }

      String toSplit = segments[toSplitIdx];
      int relativeSplitIdx =
          _findSplitIndex(toSplit, targetLength: AppLyricsConfig.maxLineLength);

      if (relativeSplitIdx <= AppLyricsConfig.minSplitEdgeChars ||
          relativeSplitIdx >=
              toSplit.length - AppLyricsConfig.minSplitEdgeChars) {
        break; // can't split gracefully
      }

      int absoluteSplitIdx = segStartOffset + relativeSplitIdx;

      bool isSpace = absoluteSplitIdx < currentText.length &&
          currentText[absoluteSplitIdx] == ' ';

      if (isSpace) {
        currentText = '${currentText.substring(0, absoluteSplitIdx)}\n${currentText.substring(absoluteSplitIdx + 1)}';
      } else {
        currentText = '${currentText.substring(0, absoluteSplitIdx)}\n${currentText.substring(absoluteSplitIdx)}';
      }

      if (currentWords.isNotEmpty) {
        int charCount = 0;
        for (int wIdx = 0; wIdx < currentWords.length; wIdx++) {
          final w = currentWords[wIdx];
          if (charCount + w.text.length > absoluteSplitIdx) {
            int localOffset = absoluteSplitIdx - charCount;
            if (localOffset >= 0 && localOffset <= w.text.length) {
              if (isSpace &&
                  localOffset < w.text.length &&
                  w.text[localOffset] == ' ') {
                String newWText = '${w.text.substring(0, localOffset)}\n${w.text.substring(localOffset + 1)}';
                currentWords[wIdx] =
                    LyricWord(startMs: w.startMs, text: newWText);
              } else {
                String newWText = '${w.text.substring(0, localOffset)}\n${w.text.substring(localOffset)}';
                currentWords[wIdx] =
                    LyricWord(startMs: w.startMs, text: newWText);
              }
            }
            break;
          }
          charCount += w.text.length;
        }
      }
    }

    return LyricLine(
        startMs: line.startMs, text: currentText, words: currentWords);
  }

  static List<LyricLine> _splitLineInTwo(
      LyricLine current, int nextStartMs, int splitIndex) {
    final firstHalfText = current.text.substring(0, splitIndex).trim();
    final secondHalfText = current.text.substring(splitIndex).trim();

    List<LyricWord> firstWords = [];
    List<LyricWord> secondWords = [];
    int secondHalfStartMs = current.startMs;

    if (current.words.isNotEmpty) {
      int currentTextLen = 0;
      for (final w in current.words) {
        if (currentTextLen + (w.text.length / 2).round() <= splitIndex) {
          firstWords.add(w);
        } else {
          if (secondWords.isEmpty) secondHalfStartMs = w.startMs;
          secondWords.add(w);
        }
        currentTextLen += w.text.length;
      }
    } else {
      int diff = nextStartMs - current.startMs;
      if (diff > AppLyricsConfig.splitFallbackMaxDiffMs) {
        diff = AppLyricsConfig.splitFallbackMaxDiffMs;
      }
      secondHalfStartMs = current.startMs + (diff ~/ 2);
    }

    return [
      LyricLine(
          startMs: current.startMs, text: firstHalfText, words: firstWords),
      LyricLine(
          startMs: secondHalfStartMs, text: secondHalfText, words: secondWords),
    ];
  }

  static int _findSplitIndex(String text, {int? targetLength}) {
    final target = targetLength ?? (text.length ~/ 2);
    int bestIdx = -1;
    int minDiff = 999;

    for (int i = AppLyricsConfig.minSplitEdgeChars;
        i < text.length - AppLyricsConfig.minSplitEdgeChars;
        i++) {
      if (AppLyricsConfig.splitPunctuation.contains(text[i])) {
        // We found a punctuation mark. The split should ideally occur right after it.
        int splitPos = i + 1;
        int diff = (splitPos - target).abs();

        // Penalize splits that overflow the string bounds massively
        if (splitPos > target) {
          diff += 5;
        }

        if (diff < minDiff) {
          minDiff = diff;
          bestIdx = splitPos;
        }
      }
    }

    return bestIdx;
  }

  static int _parseTimestampToMs(RegExpMatch match) {
    final minutes = int.parse(match.group(1)!);
    final seconds = int.parse(match.group(2)!);
    String millisStr = match.group(3)!;
    if (millisStr.length == 2) millisStr += '0'; // Pad .xx to .xxx
    final milliseconds = int.parse(millisStr);
    return (minutes * 60 * 1000) + (seconds * 1000) + milliseconds;
  }
}
