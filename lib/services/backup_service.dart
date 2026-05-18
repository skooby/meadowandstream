import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupService {
  static final BackupService instance = BackupService._internal();
  BackupService._internal();

  Future<String> getBackupDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final dir = prefs.getString('project_backup_directory_path');
    if (dir == null || dir.isEmpty) {
      final defaultDir = Directory(p.join(Directory.current.path, 'backups'));
      if (!await defaultDir.exists()) {
        await defaultDir.create(recursive: true);
      }
      return defaultDir.path;
    }
    final customDir = Directory(dir);
    if (!await customDir.exists()) {
      await customDir.create(recursive: true);
    }
    return customDir.path;
  }

  Future<List<File>> listBackups() async {
    final backupDirPath = await getBackupDirectory();
    final dir = Directory(backupDirPath).absolute;
    if (!await dir.exists()) return [];
    final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.zip')).toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }
  Future<(String, String)> getNextVersions() async {
    final backups = await listBackups();
    int cMaj = 1; int cMin = 0;
    final RegExp vReg = RegExp(r'v(\d+)\.(\d+)');
    for (var f in backups) {
       final match = vReg.firstMatch(p.basename(f.path));
       if (match != null) {
          int mMaj = int.parse(match.group(1)!);
          int mMin = int.parse(match.group(2)!);
          if (mMaj > cMaj || (mMaj == cMaj && mMin > cMin)) { cMaj = mMaj; cMin = mMin; }
       }
    }
    String minorStr = backups.isEmpty ? '1.0' : '$cMaj.${cMin + 1}';
    String majorStr = backups.isEmpty ? '1.0' : '${cMaj + 1}.0';
    return (minorStr, majorStr);
  }
  Future<void> createBackup(String label, {required String exactVersion}) async {
    final elements = exactVersion.split('.');
    if (elements.length != 2) throw Exception("Version string must follow X.Y format explicitly cleanly.");
    int cMaj = int.tryParse(elements[0]) ?? 1;
    int cMin = int.tryParse(elements[1]) ?? 0;

    final backupDirPath = await getBackupDirectory();
    final targetFolder = Directory(p.join(Directory(backupDirPath).absolute.path, 'Version $cMaj'));
    if (!await targetFolder.exists()) await targetFolder.create(recursive: true);

    final safeLabel = label.isEmpty ? '' : '_${label.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_')}';
    final zipPath = p.join(targetFolder.path, 'v$cMaj.$cMin$safeLabel.zip');
    
    final rootDir = Directory.current.path;

    final excludes = [
      'build',
      '.dart_tool',
      '.git',
      '.pub-cache',
      '.idea',
      '.vscode',
      'backups',
      'windows/flutter/ephemeral',
      'macos/Flutter/ephemeral',
      'linux/flutter/ephemeral',
      'ios/Pods',
      'ios/.symlinks',
      'macos/Pods',
      'macos/.symlinks',
      'android/.gradle',
      '.flutter-plugins',
      '.flutter-plugins-dependencies',
    ];

    bool shouldExclude(String relativePath) {
      final normalized = relativePath.replaceAll('\\', '/');
      const rootLevel = [
        'build', '.dart_tool', '.git', '.pub-cache', '.idea', '.vscode', 'backups',
        '.flutter-plugins', '.flutter-plugins-dependencies'
      ];
      final firstFolder = normalized.split('/').first;
      if (rootLevel.contains(firstFolder)) return true;

      if (normalized.endsWith('.tmp') || normalized.endsWith('.part')) return true;

      for (final exclude in excludes) {
        if (normalized.startsWith('$exclude/') || normalized == exclude) {
          return true;
        }
      }
      return false;
    }

    final backupDirPathAbsolute = Directory(backupDirPath).absolute.path.toLowerCase();

    // Build the transient file securely inside the fully initialized target folder.
    // Use '.part' extension so it is excluded from file iteration and antivirus heuristics.
    // FileHandle.open() in archive 4.x calls createSync(recursive:true) internally,
    // so we do NOT need to pre-create the file here.
    final tempZipFile = File(p.join(targetFolder.path, 'ai_bridge_packing_${DateTime.now().millisecondsSinceEpoch}.part'));
    if (tempZipFile.existsSync()) tempZipFile.deleteSync();

    final encoder = ZipFileEncoder();
    encoder.create(tempZipFile.path);

    final dir = Directory.current;
    final entities = dir.listSync(recursive: true, followLinks: false);
    for (var entity in entities) {
      if (entity is File) {
        if (p.isWithin(backupDirPathAbsolute, entity.absolute.path.toLowerCase())) continue;
        if (entity.absolute.path == tempZipFile.absolute.path) continue;
        if (entity.absolute.path == File(zipPath).absolute.path) continue;

        final relPath = p.relative(entity.path, from: rootDir);
        if (!shouldExclude(relPath)) {
          try {
            await encoder.addFile(entity, relPath);
          } catch (e) {
            // Silently ignore locked files or access denied errors mid-project.
          }
        }
      }
    }
    
    await encoder.close();

    // Now safely commit the fully constructed temporary file atomically back into its target .zip footprint natively upon completion.
    int retries = 3;
    while (retries > 0) {
      try {
        tempZipFile.renameSync(zipPath); // Native partition rename is practically instantaneous since it's on the exact same drive.
        break;
      } catch (e) {
        // Fallback to copy/delete if file locking still interferes, or if mount overlaps fail
        try {
           tempZipFile.copySync(zipPath);
           tempZipFile.deleteSync();
           break;
        } catch(fallbackErr) {
           retries--;
           if (retries == 0) throw Exception('Failed to finalize backup format safely. Target may be locked: $e');
           sleep(const Duration(milliseconds: 300));
        }
      }
    }
  }

  Future<void> restoreBackup(File backupFile) async {
    final rootDir = Directory.current.path;
    await extractFileToDisk(backupFile.path, rootDir);
  }

  Future<void> deleteBackup(File backupFile) async {
    if (await backupFile.exists()) {
      await backupFile.delete();
    }
  }
}
