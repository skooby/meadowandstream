import 'lrc_parser.dart';

class LyricsSyncResult {
  final int currentLineIndex;
  final int currentWordIndex;

  const LyricsSyncResult({
    required this.currentLineIndex,
    required this.currentWordIndex,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricsSyncResult &&
          runtimeType == other.runtimeType &&
          currentLineIndex == other.currentLineIndex &&
          currentWordIndex == other.currentWordIndex;

  @override
  int get hashCode => currentLineIndex.hashCode ^ currentWordIndex.hashCode;
}

class LyricsSyncEngine {
  /// Computes the active indices for the given timestamp
  static LyricsSyncResult compute({
    required List<LyricLine> linesSorted,
    required int positionMs,
  }) {
    int currentLineIndex = -1;

    // Find the last line whose startMs is <= positionMs
    for (int i = 0; i < linesSorted.length; i++) {
      if (linesSorted[i].startMs <= positionMs) {
        currentLineIndex = i;
      } else {
        break; // Array is sorted, so we can exit early.
      }
    }

    int currentWordIndex = -1;

    // If we have an active line, check its words
    if (currentLineIndex != -1) {
      final activeLine = linesSorted[currentLineIndex];
      if (activeLine.words.isNotEmpty) {
        for (int w = 0; w < activeLine.words.length; w++) {
          if (activeLine.words[w].startMs <= positionMs) {
            currentWordIndex = w;
          } else {
            break; // Words represent contiguous temporal blocks
          }
        }
      }
    }

    return LyricsSyncResult(
      currentLineIndex: currentLineIndex,
      currentWordIndex: currentWordIndex,
    );
  }
}
