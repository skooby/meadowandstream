import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'backup_service.dart';

/// Automatic rolling backup service.
///
/// Takes fast snapshots of source-only directories (lib/, .ai_bridge/,
/// pubspec.yaml) into [projectRoot]/auto_backups/, retaining the last
/// [maxSnapshots] archives.  All operations are best-effort — exceptions
/// are swallowed so the caller workflow is never interrupted.
class AutoBackupService {
  static final AutoBackupService instance = AutoBackupService._internal();
  AutoBackupService._internal();

  static const int maxSnapshots = 10;
  static const String _autoBackupDirName = 'auto_backups';
  static const Duration _minInterval = Duration(minutes: 2);

  DateTime? _lastBackupTime;
  bool _isRunning = false;

  /// Trigger a snapshot.  [reason] is embedded in the filename for traceability.
  /// Silently returns early when:
  ///   - another snapshot is already running
  ///   - less than [_minInterval] has elapsed since the last one (unless [force] is true)
  Future<void> snapshot({String reason = 'auto', bool force = false, String? outputDirName}) async {
    if (_isRunning) return;

    final now = DateTime.now();
    if (!force && _lastBackupTime != null &&
        now.difference(_lastBackupTime!) < _minInterval) {
      return;
    }

    _isRunning = true;
    _lastBackupTime = now;

    try {
      await _runSnapshot(reason, now, outputDirName ?? _autoBackupDirName);
    } catch (_) {
      // Best-effort — never surface errors to the caller.
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _runSnapshot(String reason, DateTime now, String targetDirName) async {
    final root = Directory.current.path;

    // Resolve the configured backup directory (same as BackupService uses),
    // then nest the targetDirName inside it.
    final configuredBackupDir = await BackupService.instance.getBackupDirectory();
    final autoDir = Directory(p.join(configuredBackupDir, targetDirName));
    if (!await autoDir.exists()) {
      await autoDir.create(recursive: true);
    }

    // Build a timestamp-embedded output path.
    final safeReason =
        reason.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final ts =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final zipPath =
        p.join(autoDir.path, 'auto_${safeReason}_$ts.zip');

    // Use a .part file so that the iterator and antivirus heuristics
    // never pick it up mid-write.
    final partFile = File(
        p.join(autoDir.path, 'auto_packing_${now.millisecondsSinceEpoch}.part'));

    final encoder = ZipFileEncoder();
    encoder.create(partFile.path);

    // Directories / files to include in the snapshot.
    final includes = [
      Directory(p.join(root, 'lib')),
      Directory(p.join(root, '.ai_bridge')),
    ];
    final singleFiles = [
      File(p.join(root, 'pubspec.yaml')),
    ];

    // Add directories.
    for (final dir in includes) {
      if (!dir.existsSync()) continue;
      final entities =
          dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is! File) continue;
        // Skip the in-progress part file itself (shouldn't be inside lib,
        // but guard anyway).
        if (entity.absolute.path == partFile.absolute.path) continue;
        final relPath = p.relative(entity.path, from: root);
        try {
          await encoder.addFile(entity, relPath);
        } catch (_) {
          // Skip locked / inaccessible files.
        }
      }
    }

    // Add top-level single files.
    for (final file in singleFiles) {
      if (!file.existsSync()) continue;
      final relPath = p.relative(file.path, from: root);
      try {
        await encoder.addFile(file, relPath);
      } catch (_) {}
    }

    await encoder.close();

    // Atomic rename to final .zip path.
    try {
      partFile.renameSync(zipPath);
    } catch (_) {
      try {
        partFile.copySync(zipPath);
        partFile.deleteSync();
      } catch (_) {}
    }

    // Prune oldest snapshots beyond [maxSnapshots].
    await _pruneOldSnapshots(autoDir);
  }

  Future<void> _pruneOldSnapshots(Directory autoDir) async {
    try {
      final files = autoDir
          .listSync()
          .whereType<File>()
          .where((f) =>
              p.basename(f.path).startsWith('auto_') &&
              f.path.endsWith('.zip'))
          .toList()
        ..sort((a, b) =>
            b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      for (var i = maxSnapshots; i < files.length; i++) {
        try {
          await files[i].delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<File?> getTaskBackupFile(String taskName) async {
    final configuredBackupDir = await BackupService.instance.getBackupDirectory();
    final autoDir = Directory(p.join(configuredBackupDir, 'Task Backup'));
    if (!await autoDir.exists()) return null;

    final safeReason = 'task_$taskName'.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final prefix = 'auto_${safeReason}_';

    final files = autoDir.listSync().whereType<File>().where((f) => f.path.endsWith('.zip') && p.basename(f.path).startsWith(prefix)).toList();
    if (files.isEmpty) return null;
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files.first;
  }
}
