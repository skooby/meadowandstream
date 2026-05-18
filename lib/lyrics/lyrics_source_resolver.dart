import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

enum SourceLocation { localCache, asset, missing }

class LyricsSources {
  final String baseName;
  final String? lrcText;
  final String? jsonText;
  final SourceLocation lrcLocation;
  final SourceLocation jsonLocation;

  LyricsSources({
    required this.baseName,
    this.lrcText,
    this.jsonText,
    required this.lrcLocation,
    required this.jsonLocation,
  });
}

class LyricsSourceResolver {
  Future<LyricsSources> loadForItem({required String audioUrl}) async {
    final uri = Uri.tryParse(audioUrl);
    String baseName;
    if (uri != null && uri.pathSegments.isNotEmpty) {
      baseName = p.basenameWithoutExtension(uri.pathSegments.last);
    } else {
      baseName = p.basenameWithoutExtension(audioUrl);
    }

    final lrcName = '$baseName.lrc';
    final jsonName = '$baseName.json';

    debugPrint(
        'LyricsSourceResolver: Resolving for audioUrl=$audioUrl -> jsonName=$jsonName');

    final lrcResult = await _resolveAndReadFile(lrcName, audioUrl: audioUrl);
    final jsonResult = await _resolveAndReadFile(jsonName, audioUrl: audioUrl);

    return LyricsSources(
      baseName: baseName,
      lrcText: lrcResult.text,
      jsonText: jsonResult.text,
      lrcLocation: lrcResult.location,
      jsonLocation: jsonResult.location,
    );
  }

  Future<String?> loadJson(String baseName) async {
    final jsonResult = await _resolveAndReadFile('$baseName.json');
    return jsonResult.text;
  }

  Future<_ResolveResult> _resolveAndReadFile(String fileName, {String? audioUrl}) async {
    // 0. Check adjacent to local audio file
    if (audioUrl != null && !audioUrl.startsWith('http')) {
      try {
        final uri = Uri.tryParse(audioUrl);
        String pathToCheck;
        if (uri != null && uri.scheme == 'file') {
          pathToCheck = uri.toFilePath();
        } else {
          pathToCheck = audioUrl;
        }
        
        final audioDir = p.dirname(pathToCheck);
        final siblingFile = File(p.join(audioDir, fileName));
        debugPrint('LyricsSourceResolver: Checking strictly adjacent bounding: \${siblingFile.path}');
        if (await siblingFile.exists()) {
          debugPrint('LyricsSourceResolver: SUCCESS! Resolved perfectly adjacent asset natively: \${siblingFile.path}');
          final content = await siblingFile.readAsString();
          return _ResolveResult(
              text: content, location: SourceLocation.localCache);
        }
      } catch (e) {
        debugPrint('LyricsSourceResolver: ERRORED probing locally: $e');
      }
    }

    // 1. Check local docs / lyrics cache
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final localFile = File(p.join(docsDir.path, 'lyrics', fileName));
      debugPrint('LyricsSourceResolver: Checking App Cache fallback: \${localFile.path}');
      if (await localFile.exists()) {
        debugPrint('LyricsSourceResolver: SUCCESS! Loaded correctly from isolated App Cache: \${localFile.path}');
        final content = await localFile.readAsString();
        return _ResolveResult(
            text: content, location: SourceLocation.localCache);
      }
    } catch (e) {
      debugPrint('LyricsSourceResolver: ERRORED resolving isolated cache: $e');
    }

    // 2. Check Flutter assets
    try {
      final assetPath = 'assets/lyrics/$fileName';
      debugPrint('LyricsSourceResolver: Trying asset $assetPath');
      final assetContent = await rootBundle.loadString(assetPath);
      debugPrint('LyricsSourceResolver: Found asset $assetPath');
      return _ResolveResult(text: assetContent, location: SourceLocation.asset);
    } catch (e) {
      debugPrint('LyricsSourceResolver: Asset missing $fileName - $e');
    }

    return _ResolveResult(text: null, location: SourceLocation.missing);
  }
}

class _ResolveResult {
  final String? text;
  final SourceLocation location;

  _ResolveResult({this.text, required this.location});
}
