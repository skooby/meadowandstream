import 'dart:convert';
import 'dart:io';
import 'supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class KaraokeGenService {
  static final KaraokeGenService instance = KaraokeGenService._internal();

  KaraokeGenService._internal();

  /// ValueNotifier to track the active transcription progress or status output
  final ValueNotifier<String> transcriptionStatus = ValueNotifier<String>('Idle');

  /// Runs `karaoke-gen` locally.
  /// Ensure Python is available and `karaoke-gen` is installed natively.
  Future<void> runTranscription(String audioPath, String artist, String title, {bool enableSeparation = false, String? referenceLyricsPath}) async {
    try {
      transcriptionStatus.value = 'Starting karaoke-gen process...';
      
      final pathRes = await Process.run('python', ['-c', "import sys, os; print(os.path.join(sys.prefix, 'Scripts', 'lyrics-transcriber.exe'))"], runInShell: true);
      final execPath = pathRes.stdout.toString().trim();
      
      final tmpOutputDir = '${audioPath}_tmp';
      final tmpCacheDir = '$tmpOutputDir\\cache';
      final targetLrcPath = audioPath.replaceAll(RegExp(r'\.[^\.]+$'), '.lrc');
      
      final args = [
        audioPath,
        '--artist',
        artist,
        '--title',
        title,
        '--output_dir',
        tmpOutputDir,
        '--cache_dir',
        tmpCacheDir,
        '--llm_model',
        'gpt-4o-mini'
      ];

      final Map<String, String> processEnv = {
          'PATH': '${Platform.environment['PATH']};${Platform.environment['USERPROFILE']}\\AppData\\Local\\Microsoft\\WinGet\\Links;${Platform.environment['USERPROFILE']}\\AppData\\Local\\Microsoft\\WindowsApps'
      };
      
      if (referenceLyricsPath != null && referenceLyricsPath.trim().isNotEmpty) {
          final refFile = File(referenceLyricsPath.trim());
          if (refFile.existsSync()) {
              final cacheDir = Directory(tmpCacheDir);
              if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);
              final hijackedPath = '$tmpCacheDir\\$artist - $title (Lyrics Genius).txt';
              refFile.copySync(hijackedPath);
              processEnv['GENIUS_API_TOKEN'] = 'local_manual_override_token';
          }
      }
      
      try {
         final openAiKey = dotenv.env['OPENAI_API_KEY'];
         if (openAiKey != null && openAiKey.trim().isNotEmpty) {
             processEnv['OPENAI_API_KEY'] = openAiKey.trim();
         }
      } catch (_) {}

      final process = await Process.start(
        execPath,
        args,
        runInShell: true,
        environment: processEnv
      );

      process.stdout.transform(utf8.decoder).listen((data) {
        if (kDebugMode) print('[KaraokeGen] $data');
        transcriptionStatus.value = data.trim();
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        if (kDebugMode) print('[KaraokeGen ERR] $data');
        transcriptionStatus.value = data.trim();
      });

      final exitCode = await process.exitCode;
      
      if (exitCode == 0) {
        // Extract strictly the LRC file from the garbage directory and delete the rest
        final outDir = Directory(tmpOutputDir);
        if (outDir.existsSync()) {
            final outputFiles = outDir.listSync(recursive: true);
            for (var entity in outputFiles) {
                if (entity is File && entity.path.toLowerCase().endsWith('.lrc')) {
                    entity.copySync(targetLrcPath);
                    break;
                }
            }
            try {
                outDir.deleteSync(recursive: true);
            } catch (_) {}
        }
        transcriptionStatus.value = 'Transcription Completed Successfully (Extracted standalone LRC).';
      } else {
        transcriptionStatus.value = 'Transcription Failed with exit code: $exitCode';
      }
    } catch (e) {
      transcriptionStatus.value = 'Error spawning transcription subprocess: $e';
      if (kDebugMode) print(e);
    }
  }

  /// Uploads configured transcription artifacts securely to the backend metadata bus
  Future<void> uploadResults(String jobId, String artifactsDirectory) async {
      try {
          transcriptionStatus.value = 'Uploading separated metadata to cloud node...';
          final bucket = SupabaseService.instance.client.storage.from('karaoke-assets');
          
          final dir = Directory(artifactsDirectory);
          if (dir.existsSync()) {
             final files = dir.listSync();
             for (var f in files) {
                if (f is File) {
                   final p = f.path.split(Platform.pathSeparator).last;
                   await bucket.upload('$jobId/$p', f);
                }
             }
          }
          transcriptionStatus.value = 'Cloud Upload Completed Successfully.';
      } catch (e) {
          transcriptionStatus.value = 'Error pushing results to metadata storage: $e';
          if (kDebugMode) print(e);
      }
  }

  /// Checks if python karaoke-gen is accessible on the system path
  Future<bool> checkInstallation() async {
    try {
      final pathRes = await Process.run('python', ['-c', "import sys, os; print(os.path.join(sys.prefix, 'Scripts', 'lyrics-transcriber.exe'))"], runInShell: true);
      final execPath = pathRes.stdout.toString().trim();
      final res = await Process.run(execPath, ['--help'], runInShell: true);
      return res.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}
