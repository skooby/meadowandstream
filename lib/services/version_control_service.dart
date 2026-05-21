import 'dart:io';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'system_logs_service.dart';
import 'sandbox_service.dart';
import 'ai_bridge_service.dart';

class VersionControlService {
  static final VersionControlService instance = VersionControlService._internal();

  VersionControlService._internal();

  Future<String?> getGithubToken() async {
    final envFile = File('.env');
    if (await envFile.exists()) {
      final lines = await envFile.readAsLines();
      for (var line in lines) {
        if (line.trim().startsWith('GITHUB_TOKEN=')) {
          return line.substring(line.indexOf('=') + 1).trim();
        }
      }
    }
    return dotenv.env['GITHUB_TOKEN'];
  }

  Future<String?> getLocalRepositoryPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('project_local_repository_path');
  }

  Future<bool> hasValidConfig() async {
    final token = await getGithubToken();
    final path = await getLocalRepositoryPath();
    return (token != null && token.isNotEmpty) && (path != null && path.isNotEmpty);
  }

  Future<String> getMissingConfigMessage() async {
    final token = await getGithubToken();
    final path = await getLocalRepositoryPath();
    
    if (token == null || token.isEmpty) {
      return 'GitHub Token is missing. Please configure it in the Project Configuration panel under External API Bindings.';
    }
    if (path == null || path.isEmpty) {
      return 'Local Repository Path is missing. Please configure it in the Project Configuration panel.';
    }
    return '';
  }

  Future<String> _getAuthenticatedUrl(String url) async {
    String cleanUrl = url.trim();
    if (cleanUrl.startsWith('http') && !cleanUrl.endsWith('.git')) {
      cleanUrl += '.git';
    }
    final token = await getGithubToken();
    if (token != null && token.isNotEmpty) {
      if (cleanUrl.startsWith('https://github.com')) {
         return cleanUrl.replaceFirst('https://', 'https://$token@');
      }
    }
    return cleanUrl;
  }

  Future<String> cloneRepository(String repoUrl) async {
    final cleanUrl = await _getAuthenticatedUrl(repoUrl);
    final path = await getLocalRepositoryPath();
    if (path == null || path.isEmpty) throw Exception('Local repository path not set.');
    
    final dir = Directory(path);
    if (await dir.exists()) {
      final entities = await dir.list().toList();
      if (entities.isNotEmpty) {
        throw Exception('The target local directory is not empty. Please select an empty directory in Project Configuration to prevent overwriting local files.');
      }
    } else {
      await dir.create(recursive: true);
    }
    
    final result = await Process.run('git', ['clone', cleanUrl, '.'], workingDirectory: path, runInShell: true);
    if (result.exitCode != 0) {
      throw Exception('Failed to clone repository:\n${result.stderr}');
    }
    return 'Repository cloned successfully.';
  }

  Future<String> syncRepository(String repoUrl) async {
    final cleanUrl = await _getAuthenticatedUrl(repoUrl);
    final path = await getLocalRepositoryPath();
    if (path == null || path.isEmpty) throw Exception('Local repository path not set.');

    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final currentBranch = await getCurrentBranch();

    final checkRepo = await Process.run('git', ['rev-parse', '--is-inside-work-tree'], workingDirectory: path, runInShell: true);
    if (checkRepo.exitCode != 0) {
      // It's a new local repo. Let's make sure the remote is empty before we push to it.
      final lsRemote = await Process.run('git', ['ls-remote', cleanUrl], runInShell: true);
      if (lsRemote.exitCode != 0) {
        throw Exception('Unable to access remote repository. It may not exist, or your token lacks permissions.\n${lsRemote.stderr}');
      }
      if (lsRemote.stdout.toString().trim().isNotEmpty) {
        throw Exception('The remote repository already contains data. To prevent overwriting, please provide an empty repository URL or clone it first.');
      }

      final init = await Process.run('git', ['init'], workingDirectory: path, runInShell: true);
      if (init.exitCode != 0) throw Exception('Failed to initialize repository:\n${init.stderr}');
      
      final remote = await Process.run('git', ['remote', 'add', 'origin', cleanUrl], workingDirectory: path, runInShell: true);
      if (remote.exitCode != 0) throw Exception('Failed to add remote origin:\n${remote.stderr}');
    }

    // 1. Fetch latest changes from remote branch
    await Process.run('git', ['fetch', 'origin', currentBranch], workingDirectory: path, runInShell: true);

    // 2. Programmatically merge remote state files to avoid git conflicts
    await _mergeRemoteStateFiles(path, currentBranch);

    await _scrubTemporaryFiles(path);

    final add = await Process.run('git', ['add', '.'], workingDirectory: path, runInShell: true);
    if (add.exitCode != 0) throw Exception('Failed to add files:\n${add.stderr}');

    final status = await Process.run('git', ['status', '--porcelain'], workingDirectory: path, runInShell: true);
    if (status.stdout.toString().trim().isNotEmpty) {
      final commit = await Process.run('git', ['commit', '-m', 'Auto-sync from Antigravity Visual Editor'], workingDirectory: path, runInShell: true);
      if (commit.exitCode != 0) {
        throw Exception('Failed to commit local changes:\n${commit.stderr}');
      }
    }

    // 3. Pull/rebase to integrate remote changes
    final pull = await Process.run('git', ['pull', '--rebase', 'origin', currentBranch], workingDirectory: path, runInShell: true);
    if (pull.exitCode != 0) {
      await Process.run('git', ['rebase', '--abort'], workingDirectory: path, runInShell: true);
      throw Exception('Failed to pull remote changes due to git conflicts. Please merge/rebase manually.\n${pull.stderr}');
    }

    // 4. Push to remote
    final push = await Process.run('git', ['push', '-u', 'origin', currentBranch], workingDirectory: path, runInShell: true);
    if (push.exitCode != 0) {
      throw Exception('Failed to push changes:\n${push.stderr}');
    }

    return 'Repository synced successfully.';
  }

  Future<void> _scrubTemporaryFiles(String basePath) async {
    final dir = Directory(basePath);
    if (!await dir.exists()) return;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final path = entity.path;
        if (path.endsWith('.bak') || path.endsWith('.tmp') || path.endsWith('.scratch.dart')) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    }

    final scratchDir = Directory('$basePath/.ai_scratch');
    if (await scratchDir.exists()) {
      await for (final entity in scratchDir.list()) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<String> testGithubState(String repoUrl) async {
    final cleanUrl = await _getAuthenticatedUrl(repoUrl);
    final path = await getLocalRepositoryPath();
    if (path == null || path.isEmpty) throw Exception('Local repository path not set.');
    
    final buffer = StringBuffer();
    buffer.writeln('=== LOCAL STATE ===');
    final dir = Directory(path);
    if (!await dir.exists()) {
      buffer.writeln('Directory does not exist: $path');
    } else {
      final checkRepo = await Process.run('git', ['rev-parse', '--is-inside-work-tree'], workingDirectory: path, runInShell: true);
      if (checkRepo.exitCode == 0) {
        buffer.writeln('Git Repository: Initialized');
        final branch = await Process.run('git', ['branch', '--show-current'], workingDirectory: path, runInShell: true);
        buffer.writeln('Current Branch: ${branch.stdout.toString().trim()}');
        
        final status = await Process.run('git', ['status', '--short'], workingDirectory: path, runInShell: true);
        final changes = status.stdout.toString().trim();
        buffer.writeln(changes.isEmpty ? 'Changes: None (Clean)' : 'Changes: Pending uncommitted changes');
      } else {
        buffer.writeln('Git Repository: Not Initialized');
      }
    }

    buffer.writeln('\n=== REMOTE STATE ===');
    if (repoUrl.isEmpty) {
      buffer.writeln('Remote URL not provided.');
    } else {
      try {
        final lsRemote = await Process.run('git', ['ls-remote', cleanUrl], runInShell: true);
        if (lsRemote.exitCode == 0) {
          buffer.writeln('Connection: Successful');
          final out = lsRemote.stdout.toString().trim();
          buffer.writeln(out.isEmpty ? 'Status: Empty Repository' : 'Status: Contains Data / Commits');
        } else {
          buffer.writeln('Connection: Failed');
          buffer.writeln('Error: ${lsRemote.stderr.toString().trim()}');
        }
      } catch (e) {
        buffer.writeln('Connection: Failed ($e)');
      }
    }

    return buffer.toString();
  }

  Future<String> stashChanges({String message = 'Auto-stash'}) async {
    final path = await getLocalRepositoryPath();
    if (path == null || path.isEmpty) throw Exception('Local repository path not set.');
    final result = await Process.run('git', ['stash', 'save', message], workingDirectory: path, runInShell: true);
    if (result.exitCode != 0) {
      throw Exception('Failed to stash changes:\n${result.stderr}');
    }
    return 'Changes stashed successfully.';
  }

  Future<String> checkoutBranch(String branchName, {bool create = false}) async {
    final path = await getLocalRepositoryPath();
    if (path == null || path.isEmpty) throw Exception('Local repository path not set.');
    
    List<String> args = ['checkout'];
    if (create) args.add('-b');
    args.add(branchName);
    
    final result = await Process.run('git', args, workingDirectory: path, runInShell: true);
    if (result.exitCode == 0) {
      SystemLogsService.instance.addLog('Checked out $branchName (create: $create)', category: LogCategory.VC);
      return 'Checked out branch $branchName successfully.';
    } else {
      SystemLogsService.instance.addLog('Failed to checkout $branchName: ${result.stderr}', category: LogCategory.ERROR);
      throw Exception('Failed to checkout branch $branchName:\n${result.stderr}');
    }
  }

  Future<String> getCurrentBranch() async {
    final path = await getLocalRepositoryPath();
    if (path == null || path.isEmpty) return 'main';
    final result = await Process.run('git', ['branch', '--show-current'], workingDirectory: path, runInShell: true);
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
    return await getDefaultBranch();
  }

  Future<String> getDefaultBranch() async {
    final path = await getLocalRepositoryPath();
    if (path == null || path.isEmpty) return 'master';
    
    final checkMain = await Process.run('git', ['show-ref', '--verify', '--quiet', 'refs/heads/main'], workingDirectory: path, runInShell: true);
    if (checkMain.exitCode == 0) return 'main';
    
    return 'master';
  }

  Future<String> commitTimelineTasks(List<String> taskIds, String name, String description, String summary, String verifiedNotes) async {
    try {
      final path = await getLocalRepositoryPath();
      if (path == null || path.isEmpty) return 'Local repository path not set.';
      
      final addResult = await Process.run('git', ['add', '.'], workingDirectory: path, runInShell: true);
      if (addResult.exitCode != 0) {
        throw Exception('Failed to add files:\n${addResult.stderr}');
      }

      final statusResult = await Process.run('git', ['status', '--porcelain'], workingDirectory: path, runInShell: true);
      if (statusResult.stdout.toString().trim().isNotEmpty) {
        // Append verified checklist to the commit message
        final commitTitle = summary.isNotEmpty ? summary : name;
        final idsString = taskIds.map((id) => 'Task ID: $id').join('\n');
        String fullCommitMsg = '$commitTitle\n\n$description\n\n$idsString\n\nVerified Items:\n$verifiedNotes';
        
        final tempFile = File('$path/temp_commit_msg.txt');
        await tempFile.writeAsString(fullCommitMsg);
        await Process.run('git', ['commit', '-F', tempFile.path], workingDirectory: path, runInShell: true);
        if (await tempFile.exists()) await tempFile.delete();
        
        final hashResult = await Process.run('git', ['rev-parse', 'HEAD'], workingDirectory: path, runInShell: true);
        final commitHash = hashResult.exitCode == 0 ? hashResult.stdout.toString().trim() : '';
        
        final defaultBranch = await getDefaultBranch();
        SystemLogsService.instance.addLog('Committed Tasks ${taskIds.join(", ")} to $defaultBranch successfully. Hash: $commitHash', category: LogCategory.VC);
        
        // Push in the background, ignoring errors
        Process.run('git', ['push', 'origin', defaultBranch], workingDirectory: path, runInShell: true).then((_) {
           SystemLogsService.instance.addLog('Pushed $defaultBranch to origin.', category: LogCategory.VC);
        });
        
        return commitHash.isNotEmpty ? commitHash : 'Committed successfully.';
      } else {
        return 'No changes to commit.';
      }
    } finally {
      for (final id in taskIds) {
        await SandboxService.instance.commitTaskToTimeline(id);
      }
    }
  }

  Future<List<String>> getSandboxDiffFiles(String taskId) async {
    final path = await getLocalRepositoryPath();
    if (path == null || path.isEmpty) return [];
    
    final defaultBranch = await getDefaultBranch();
    final branchName = 'task_sandbox_$taskId';
    final result = await Process.run('git', ['diff', '--name-only', '$defaultBranch...$branchName'], workingDirectory: path, runInShell: true);
    if (result.exitCode == 0) {
      final out = result.stdout.toString().trim();
      if (out.isEmpty) return [];
      return out.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  Future<String> getSpecificFileDiff(String taskId, String fileName) async {
    final path = await getLocalRepositoryPath();
    if (path == null || path.isEmpty) return '';
    
    final defaultBranch = await getDefaultBranch();
    final branchName = 'task_sandbox_$taskId';
    final result = await Process.run('git', ['diff', '$defaultBranch...$branchName', '--', fileName], workingDirectory: path, runInShell: true);
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
    return '';
  }

  Future<List<Map<String, String>>> getTaskCommitHistory(String taskId) async {
    final path = await getLocalRepositoryPath();
    if (path == null || path.isEmpty) {
      SystemLogsService.instance.addLog('getTaskCommitHistory failed: path is null or empty', category: LogCategory.VC);
      return [];
    }

    try {
      final result = await Process.run('git', ['log', '--grep=Task ID: $taskId', '--format=%H===%s===%an===%ad', '--date=iso'], workingDirectory: path, runInShell: false);
      if (result.exitCode == 0) {
        final out = result.stdout.toString().trim();
        if (out.isEmpty) {
          SystemLogsService.instance.addLog('getTaskCommitHistory: stdout is empty for Task ID: $taskId', category: LogCategory.VC);
          return [];
        }
        final lines = out.split('\n');
        return lines.map((line) {
          final parts = line.split('===');
          if (parts.length >= 4) {
            return {
              'hash': parts[0],
              'message': parts[1],
              'author': parts[2],
              'date': parts[3],
            };
          }
          return {'hash': '', 'message': 'Unknown format', 'author': '', 'date': ''};
        }).toList();
      } else {
        SystemLogsService.instance.addLog('getTaskCommitHistory exitCode != 0: ${result.exitCode}\n${result.stderr}', category: LogCategory.VC);
      }
    } catch (e) {
      SystemLogsService.instance.addLog('getTaskCommitHistory exception: $e', category: LogCategory.VC);
    }
    return [];
  }

  Future<String?> getGithubCommitUrl(String hash) async {
    final path = await getLocalRepositoryPath();
    if (path == null || path.isEmpty) return null;
    final result = await Process.run('git', ['remote', 'get-url', 'origin'], workingDirectory: path, runInShell: true);
    if (result.exitCode == 0) {
      String url = result.stdout.toString().trim();
      if (url.isEmpty) return null;
      if (url.endsWith('.git')) url = url.substring(0, url.length - 4);
      if (url.startsWith('git@github.com:')) {
        url = 'https://github.com/${url.substring(15)}';
      }
      return '$url/commit/$hash';
    }
    return null;
  }

  Future<void> openGithubCommit(String hash) async {
    final url = await getGithubCommitUrl(hash);
    if (url != null) {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
    }
  }

  Future<String> createRestorePoint(String description) async {
    final path = await getLocalRepositoryPath();
    if (path == null || path.isEmpty) return 'Local repository path not set.';
    
    final addResult = await Process.run('git', ['add', '.'], workingDirectory: path, runInShell: true);
    if (addResult.exitCode != 0) {
      throw Exception('Failed to add files:\n${addResult.stderr}');
    }
    
    final commitMsg = '[CHECKPOINT] - $description';
    final commitResult = await Process.run('git', ['commit', '-m', commitMsg], workingDirectory: path, runInShell: true);
    if (commitResult.exitCode != 0 && commitResult.stdout.toString().contains('nothing to commit')) {
      return 'No changes to create a checkpoint.';
    } else if (commitResult.exitCode != 0) {
      throw Exception('Failed to create checkpoint:\n${commitResult.stderr}');
    }
    
    final revResult = await Process.run('git', ['rev-parse', 'HEAD'], workingDirectory: path, runInShell: true);
    return revResult.stdout.toString().trim();
  }

  Future<void> restoreToCommit(String commitHash) async {
    final path = await getLocalRepositoryPath();
    if (path == null || path.isEmpty) throw Exception('Local repository path not set.');

    // 1. Add all uncommitted changes
    await Process.run('git', ['add', '.'], workingDirectory: path, runInShell: true);

    // 2. Commit them so we don't lose them
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await Process.run('git', ['commit', '-m', 'Auto-backup before hard reset'], workingDirectory: path, runInShell: true);

    // 3. Create a branch to hold the backup
    await Process.run('git', ['branch', 'auto-backup/before-restore-$timestamp'], workingDirectory: path, runInShell: true);

    // 4. Hard reset to the requested commit
    final resetResult = await Process.run('git', ['reset', '--hard', commitHash], workingDirectory: path, runInShell: true);
    if (resetResult.exitCode != 0) {
      throw Exception('Failed to hard reset:\n${resetResult.stderr}');
    }
  }

  Future<void> cleanupTimelineHistory(int keepCount) async {
    final path = await getLocalRepositoryPath();
    if (path == null || path.isEmpty) throw Exception('Local repository path not set.');

    final timelineHistory = AiBridgeService.instance.timelineHistory;
    if (timelineHistory.length <= keepCount) return;

    // timelineHistory is sorted newest to oldest.
    // The oldest we want to KEEP is at index keepCount - 1.
    // The base we checkout as orphan is the commit just BEFORE that, which is at index keepCount.
    final squashBaseCommit = timelineHistory[keepCount].commitHash;
    final oldHeadResult = await Process.run('git', ['rev-parse', 'HEAD'], workingDirectory: path, runInShell: true);
    final oldHead = oldHeadResult.stdout.toString().trim();

    final tempBranch = 'cleanup-temp-${DateTime.now().millisecondsSinceEpoch}';
    final originalBranchResult = await Process.run('git', ['rev-parse', '--abbrev-ref', 'HEAD'], workingDirectory: path, runInShell: true);
    final originalBranch = originalBranchResult.stdout.toString().trim();

    final statusResult = await Process.run('git', ['status', '--porcelain'], workingDirectory: path, runInShell: true);
    final hasChanges = statusResult.stdout.toString().trim().isNotEmpty;

    try {
      if (hasChanges) {
        await Process.run('git', ['stash', 'push', '-u', '-m', 'temp-squash-stash'], workingDirectory: path, runInShell: true);
      }

      // 1. Create orphan branch at squash base
      await Process.run('git', ['checkout', '--orphan', tempBranch, squashBaseCommit], workingDirectory: path, runInShell: true);

      // 2. Commit as squashed baseline
      await Process.run('git', ['commit', '-m', 'Squashed History Baseline'], workingDirectory: path, runInShell: true);
      final newBaseResult = await Process.run('git', ['rev-parse', 'HEAD'], workingDirectory: path, runInShell: true);
      final newBase = newBaseResult.stdout.toString().trim();

      // 3. Cherry pick
      final cherryResult = await Process.run('git', ['cherry-pick', '--keep-redundant-commits', '--strategy-option=theirs', '$squashBaseCommit..$oldHead'], workingDirectory: path, runInShell: true);
      if (cherryResult.exitCode != 0) {
        throw Exception('Failed to cherry-pick: ${cherryResult.stderr}');
      }

      final newHeadResult = await Process.run('git', ['rev-parse', 'HEAD'], workingDirectory: path, runInShell: true);
      final newHead = newHeadResult.stdout.toString().trim();

      // 4. Map hashes
      final oldLogResult = await Process.run('git', ['log', '--format=%H', '$squashBaseCommit..$oldHead', '--reverse'], workingDirectory: path, runInShell: true);
      final newLogResult = await Process.run('git', ['log', '--format=%H', '$newBase..$newHead', '--reverse'], workingDirectory: path, runInShell: true);

      final oldHashes = oldLogResult.stdout.toString().trim().split('\n').where((s) => s.isNotEmpty).toList();
      final newHashes = newLogResult.stdout.toString().trim().split('\n').where((s) => s.isNotEmpty).toList();

      Map<String, String> hashMap = {};
      for (int i = 0; i < oldHashes.length && i < newHashes.length; i++) {
        hashMap[oldHashes[i]] = newHashes[i];
      }

      // 5. Hard reset original branch
      await Process.run('git', ['checkout', originalBranch], workingDirectory: path, runInShell: true);
      await Process.run('git', ['reset', '--hard', newHead], workingDirectory: path, runInShell: true);

      // 6. Delete temp branch
      await Process.run('git', ['branch', '-D', tempBranch], workingDirectory: path, runInShell: true);

      // 7. Update timeline JSON
      await AiBridgeService.instance.applyTimelineCleanup(keepCount, hashMap);

      if (hasChanges) {
        await Process.run('git', ['stash', 'pop'], workingDirectory: path, runInShell: true);
      }
    } catch (e) {
      await Process.run('git', ['cherry-pick', '--abort'], workingDirectory: path, runInShell: true);
      await Process.run('git', ['checkout', originalBranch], workingDirectory: path, runInShell: true);
      await Process.run('git', ['branch', '-D', tempBranch], workingDirectory: path, runInShell: true);
      if (hasChanges) {
        await Process.run('git', ['stash', 'pop'], workingDirectory: path, runInShell: true);
      }
      throw Exception('Failed timeline cleanup: $e');
    }
  }

  String _getRelativePath(String repoPath, String filePath) {
    var r = repoPath.replaceAll('\\', '/').toLowerCase();
    if (r.endsWith('/')) {
      r = r.substring(0, r.length - 1);
    }
    var f = filePath.replaceAll('\\', '/');
    var fLower = f.toLowerCase();
    String rel = f;
    if (fLower.startsWith(r)) {
      rel = f.substring(r.length);
    }
    while (rel.startsWith('/')) {
      rel = rel.substring(1);
    }
    return rel;
  }

  Future<List<Map<String, String>>> getFileCommitHistory(String filePath) async {
    final path = await getLocalRepositoryPath();
    if (path == null || path.isEmpty) {
      SystemLogsService.instance.addLog('getFileCommitHistory failed: path is null or empty', category: LogCategory.VC);
      return [];
    }

    final relPath = _getRelativePath(path, filePath);
    try {
      final result = await Process.run(
        'git',
        ['log', '--follow', '--format=%H===%s===%an===%ad', '--date=iso', '--', relPath],
        workingDirectory: path,
        runInShell: false,
        stdoutEncoding: null,
        stderrEncoding: null,
      );

      if (result.exitCode == 0) {
        final bytes = result.stdout as List<int>;
        final out = utf8.decode(bytes, allowMalformed: true).trim();
        if (out.isEmpty) return [];
        final lines = out.split('\n');
        return lines.map((line) {
          final parts = line.split('===');
          if (parts.length >= 4) {
            return {
              'sha': parts[0],
              'hash': parts[0],
              'message': parts[1],
              'author': parts[2],
              'date': parts[3],
            };
          }
          return {'sha': '', 'hash': '', 'message': 'Unknown format', 'author': '', 'date': ''};
        }).toList();
      } else {
        final stderrStr = result.stderr is List<int>
            ? utf8.decode(result.stderr as List<int>, allowMalformed: true)
            : result.stderr.toString();
        SystemLogsService.instance.addLog('getFileCommitHistory exitCode != 0: ${result.exitCode}\n$stderrStr', category: LogCategory.VC);
      }
    } catch (e) {
      SystemLogsService.instance.addLog('getFileCommitHistory exception: $e', category: LogCategory.VC);
    }
    return [];
  }

  Future<String> getFileContentAtCommit(String filePath, String commitSha) async {
    final path = await getLocalRepositoryPath();
    if (path == null || path.isEmpty) throw Exception('Local repository path not set.');
    
    final relPath = _getRelativePath(path, filePath);

    final result = await Process.run(
      'git',
      ['show', '$commitSha:$relPath'],
      workingDirectory: path,
      runInShell: false,
      stdoutEncoding: null,
      stderrEncoding: null,
    );

    if (result.exitCode != 0) {
      final stderrStr = result.stderr is List<int>
          ? utf8.decode(result.stderr as List<int>, allowMalformed: true)
          : result.stderr.toString();
      throw Exception('Failed to get file content at commit $commitSha:\n$stderrStr');
    }
    final bytes = result.stdout as List<int>;
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<void> _mergeRemoteStateFiles(String path, String branchName) async {
    try {
      // 1. Fetch remote content of timeline_history.json
      final remoteTimelineResult = await Process.run(
        'git',
        ['show', 'origin/$branchName:.ai_bridge/timeline_history.json'],
        workingDirectory: path,
        runInShell: true,
      );
      if (remoteTimelineResult.exitCode == 0) {
        final remoteContent = remoteTimelineResult.stdout.toString().trim();
        final localFile = File('$path/.ai_bridge/timeline_history.json');
        if (remoteContent.isNotEmpty && await localFile.exists()) {
          final localContent = await localFile.readAsString();
          final List<dynamic> localList = jsonDecode(localContent);
          final List<dynamic> remoteList = jsonDecode(remoteContent);

          // Merge by commitHash or id
          final Map<String, dynamic> mergedMap = {};
          
          String getKey(dynamic commit) {
            final hash = commit['commitHash'] ?? '';
            if (hash.isNotEmpty && hash != 'No Git Changes') {
              return hash;
            }
            return commit['id'] ?? '';
          }

          for (var commit in remoteList) {
            final key = getKey(commit);
            if (key.isNotEmpty) {
              mergedMap[key] = commit;
            }
          }

          for (var commit in localList) {
            final key = getKey(commit);
            if (key.isNotEmpty) {
              // Local changes overwrite remote details for matching commits
              mergedMap[key] = commit;
            }
          }

          // Sort by commitDate descending
          final mergedList = mergedMap.values.toList();
          mergedList.sort((a, b) {
            final dateA = DateTime.tryParse(a['commitDate'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dateB = DateTime.tryParse(b['commitDate'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA); // Descending (newest first)
          });

          await localFile.writeAsString(const JsonEncoder.withIndent('  ').convert(mergedList));
        }
      }
    } catch (e) {
      SystemLogsService.instance.addLog('Failed to merge remote timeline history: $e', category: LogCategory.VC);
    }

    try {
      // 2. Fetch remote content of tasks.json
      final remoteTasksResult = await Process.run(
        'git',
        ['show', 'origin/$branchName:.ai_bridge/tasks.json'],
        workingDirectory: path,
        runInShell: true,
      );
      if (remoteTasksResult.exitCode == 0) {
        final remoteContent = remoteTasksResult.stdout.toString().trim();
        final localFile = File('$path/.ai_bridge/tasks.json');
        if (remoteContent.isNotEmpty && await localFile.exists()) {
          final localContent = await localFile.readAsString();
          final localMap = jsonDecode(localContent) as Map<String, dynamic>;
          final remoteMap = jsonDecode(remoteContent) as Map<String, dynamic>;

          final List<dynamic> localTasks = localMap['tasks'] ?? [];
          final List<dynamic> remoteTasks = remoteMap['tasks'] ?? [];

          final Map<String, dynamic> mergedTasksMap = {};
          for (var task in remoteTasks) {
            final id = task['id'] ?? '';
            if (id.isNotEmpty) {
              mergedTasksMap[id] = task;
            }
          }

          for (var task in localTasks) {
            final id = task['id'] ?? '';
            if (id.isNotEmpty) {
              mergedTasksMap[id] = task;
            }
          }

          localMap['tasks'] = mergedTasksMap.values.toList();
          
          if (localMap['primaryDirectives'] == null || localMap['primaryDirectives'].toString().isEmpty) {
            localMap['primaryDirectives'] = remoteMap['primaryDirectives'];
          }
          if (localMap['instructions'] == null || localMap['instructions'].toString().isEmpty) {
            localMap['instructions'] = remoteMap['instructions'];
          }

          await localFile.writeAsString(const JsonEncoder.withIndent('  ').convert(localMap));
        }
      }
    } catch (e) {
      SystemLogsService.instance.addLog('Failed to merge remote tasks: $e', category: LogCategory.VC);
    }
  }
}
