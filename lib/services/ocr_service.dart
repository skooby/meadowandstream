import 'dart:io';
import 'package:path/path.dart' as p;

// ── Data models ──────────────────────────────────────────────────────────────

/// A single word recognized by OCR, with its screen-space bounding box and
/// recognition confidence.
class OcrWord {
  final String text;

  /// Bounding box in image pixel coordinates.
  final int left;
  final int top;
  final int right;
  final int bottom;

  /// Tesseract confidence 0-100, or -1 if not available.
  final double confidence;

  const OcrWord({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.confidence,
  });

  int get width => right - left;
  int get height => bottom - top;
  int get centerX => left + width ~/ 2;
  int get centerY => top + height ~/ 2;

  /// Returns true if the image-space point ([x], [y]) falls within this word.
  bool contains(int x, int y) =>
      x >= left && x <= right && y >= top && y <= bottom;

  @override
  String toString() =>
      '"$text" @($left,$top)-($right,$bottom) '
      'conf:${confidence >= 0 ? "${confidence.toStringAsFixed(1)}%" : "n/a"}';
}

/// Full OCR result for one image: plain text, per-word bounding boxes, and
/// line-level strings.
class OcrResult {
  /// Full recognized text, lines joined by newline.
  final String fullText;

  /// All recognized words with their individual bounding boxes.
  final List<OcrWord> words;

  /// Plain-text lines (whitespace-normalized, HTML stripped).
  final List<String> lines;

  const OcrResult({
    required this.fullText,
    required this.words,
    required this.lines,
  });

  bool get isEmpty => words.isEmpty;

  // ── Search ────────────────────────────────────────────────────────────────

  /// Returns all words whose text contains [query].
  /// Case-insensitive by default; set [caseSensitive] = true to override.
  List<OcrWord> search(String query, {bool caseSensitive = false}) {
    if (query.isEmpty) return [];
    final q = caseSensitive ? query : query.toLowerCase();
    return words.where((w) {
      final t = caseSensitive ? w.text : w.text.toLowerCase();
      return t.contains(q);
    }).toList();
  }

  /// Returns all words that exactly match [text] (whole-word comparison).
  List<OcrWord> findExact(String text, {bool caseSensitive = false}) {
    final q = caseSensitive ? text : text.toLowerCase();
    return words.where((w) {
      final t = caseSensitive ? w.text : w.text.toLowerCase();
      return t == q;
    }).toList();
  }

  // ── Hitbox ────────────────────────────────────────────────────────────────

  /// Returns the first word whose bounding box contains the image point ([x], [y]),
  /// or null if no word covers that point.
  OcrWord? hitTest(int x, int y) {
    for (final w in words) {
      if (w.contains(x, y)) return w;
    }
    return null;
  }

  /// Returns all words within the rectangle defined by (x1,y1)-(x2,y2).
  List<OcrWord> wordsInRect(int x1, int y1, int x2, int y2) {
    return words.where((w) {
      return w.left >= x1 && w.right <= x2 &&
             w.top  >= y1 && w.bottom <= y2;
    }).toList();
  }

  // ── Convenience ───────────────────────────────────────────────────────────

  /// Returns words with confidence >= [minConfidence] (0-100).
  List<OcrWord> withMinConfidence(double minConfidence) =>
      words.where((w) => w.confidence >= minConfidence).toList();

  @override
  String toString() =>
      'OcrResult(${words.length} words, ${lines.length} lines)\n$fullText';
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Integrates [Tesseract OCR](https://github.com/tesseract-ocr/tesseract)
/// into Flutter via the Tesseract command-line interface.
///
/// ## Windows Setup
///
/// 1. Install **Tesseract 5.x for Windows** from the UB-Mannheim builds:
///    https://github.com/UB-Mannheim/tesseract/wiki
///    The installer adds `tesseract` to your PATH and includes English data.
///
/// 2. Additional language packs can be installed via the same installer or
///    downloaded from https://github.com/tesseract-ocr/tessdata and placed in
///    the Tesseract `tessdata/` directory.
///
/// ## Usage
///
/// ```dart
/// // Recognize text in an image file
/// final result = await OcrService.instance.recognize('/path/to/image.png');
/// print(result.fullText);
///
/// // Search for a word
/// final hits = result.search('Submit');
///
/// // Hit-test a screen coordinate
/// final word = result.hitTest(320, 240);
///
/// // Recognize the last macro screenshot
/// final shot = await OcrService.instance.recognizeLastScreenshot();
/// ```
class OcrService {
  OcrService._();

  /// Singleton instance.
  static final OcrService instance = OcrService._();

  // ── Configuration ─────────────────────────────────────────────────────────

  /// Path to the Tesseract executable.
  /// Defaults to `'tesseract'` which works when the installer has added it to PATH.
  /// Override if Tesseract is installed to a non-standard location, e.g.:
  /// `OcrService.instance.executablePath = r'C:\Program Files\Tesseract-OCR\tesseract.exe';`
  String executablePath = 'tesseract';

  /// Default language(s). Supports multi-language, e.g. `'eng+fra'`.
  String defaultLanguage = 'eng';

  /// Optional explicit path to the `tessdata/` directory.
  /// If null, Tesseract uses its own default (set by the installer).
  String? tessdataPath;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns true if the configured Tesseract executable can be found and run.
  Future<bool> isAvailable() async {
    try {
      final r = await Process.run(executablePath, ['--version'],
          runInShell: false);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Returns the Tesseract version string, or null if not available.
  Future<String?> version() async {
    try {
      final r = await Process.run(executablePath, ['--version'],
          runInShell: false);
      if (r.exitCode != 0) return null;
      return (r.stdout as String).split('\n').first.trim();
    } catch (_) {
      return null;
    }
  }

  /// Run OCR on [imagePath] and return structured results.
  ///
  /// [language] overrides [defaultLanguage] for this single call.
  /// Supported image types: PNG, JPG, BMP, TIFF.
  Future<OcrResult> recognize(
    String imagePath, {
    String? language,
  }) async {
    final imageFile = File(imagePath);
    if (!imageFile.existsSync()) {
      throw Exception('OcrService: Image file not found: $imagePath');
    }

    final lang = language ?? defaultLanguage;
    final tmpBase = p.join(
      Directory.systemTemp.path,
      'ocr_${DateTime.now().millisecondsSinceEpoch}',
    );

    final Map<String, String>? env =
        tessdataPath != null ? {'TESSDATA_PREFIX': tessdataPath!} : null;

    // Run Tesseract, requesting HOCR output which carries bounding boxes.
    final result = await Process.run(
      executablePath,
      [imagePath, tmpBase, '-l', lang, 'hocr'],
      environment: env,
      runInShell: false,
    );

    if (result.exitCode != 0) {
      throw Exception(
          'OcrService: Tesseract failed (exit ${result.exitCode}):\n'
          '${result.stderr}');
    }

    final hocrFile = File('$tmpBase.hocr');
    if (!hocrFile.existsSync()) {
      throw Exception(
          'OcrService: HOCR output not found at $tmpBase.hocr');
    }

    final hocr = await hocrFile.readAsString();
    try { await hocrFile.delete(); } catch (_) {}

    return _parseHocr(hocr);
  }

  /// Convenience: reads the last screenshot path from `.ai_bridge/last_screenshot.txt`
  /// (written by the macro ScreenShot / ActiveWindowScreenShot commands) and
  /// runs OCR on it.
  Future<OcrResult> recognizeLastScreenshot({String? language}) async {
    const screenshotRef = '.ai_bridge/last_screenshot.txt';
    final ref = File(screenshotRef);
    if (!ref.existsSync()) {
      throw Exception(
          'OcrService: No screenshot reference found at $screenshotRef. '
          'Run a ScreenShot() or ActiveWindowScreenShot() macro first.');
    }
    final path = ref.readAsStringSync().trim();
    if (path.isEmpty) {
      throw Exception('OcrService: Screenshot path in $screenshotRef is empty.');
    }
    if (!File(path).existsSync()) {
      throw Exception('OcrService: Screenshot file not found: $path');
    }
    return recognize(path, language: language);
  }

  // ── HOCR parser ───────────────────────────────────────────────────────────

  // Matches <span class='ocrx_word' ... title='bbox x0 y0 x1 y1 ... x_wconf N ...'>text</span>
  // The title attribute ordering is not guaranteed, so we match bbox and x_wconf separately.
  static final _wordSpanRegex = RegExp(
    r'''<span[^>]+class=['"]ocrx_word['"][^>]+title=['"]([^'"]+)['"][^>]*>(.*?)</span>''',
    dotAll: true,
  );

  static final _bboxRegex =
      RegExp(r'bbox\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)');
  static final _confRegex = RegExp(r'x_wconf\s+(\d+)');

  // Matches a complete ocr_line span to extract line-level text
  static final _lineSpanRegex = RegExp(
    r'''<span[^>]+class=['"]ocr_line['"][^>]*>(.*?)</span>''',
    dotAll: true,
  );

  static final _htmlTagRegex = RegExp(r'<[^>]+>');

  static String _stripHtml(String raw) => raw
      .replaceAll(_htmlTagRegex, '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  OcrResult _parseHocr(String hocr) {
    final words = <OcrWord>[];

    for (final m in _wordSpanRegex.allMatches(hocr)) {
      final title = m.group(1)!;
      final inner = m.group(2)!;

      final bboxM = _bboxRegex.firstMatch(title);
      if (bboxM == null) continue;

      final left   = int.parse(bboxM.group(1)!);
      final top    = int.parse(bboxM.group(2)!);
      final right  = int.parse(bboxM.group(3)!);
      final bottom = int.parse(bboxM.group(4)!);

      final confM = _confRegex.firstMatch(title);
      final confidence = confM != null
          ? double.parse(confM.group(1)!)
          : -1.0;

      final text = _stripHtml(inner);
      if (text.isNotEmpty) {
        words.add(OcrWord(
          text: text,
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          confidence: confidence,
        ));
      }
    }

    final lines = <String>[];
    for (final m in _lineSpanRegex.allMatches(hocr)) {
      final lineText = _stripHtml(m.group(1)!);
      if (lineText.isNotEmpty) lines.add(lineText);
    }

    return OcrResult(
      fullText: lines.join('\n'),
      words: words,
      lines: lines,
    );
  }
}
