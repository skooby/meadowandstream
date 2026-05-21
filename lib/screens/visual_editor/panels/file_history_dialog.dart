import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../constants.dart';
import '../../../services/version_control_service.dart';
import '../../../services/auto_backup_service.dart';
import '../../../services/github_service.dart';
import '../../../state/editor_state_controller.dart';
import '../../../choreography/choreography_engine.dart';

class DiffViewer extends StatefulWidget {
  final String oldText;
  final String newText;

  const DiffViewer({super.key, required this.oldText, required this.newText});

  @override
  State<DiffViewer> createState() => _DiffViewerState();
}

class _DiffViewerState extends State<DiffViewer> {
  final ScrollController _scrollController = ScrollController();
  bool _copied = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.oldText));
    setState(() {
      _copied = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied content to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanText = widget.oldText.replaceAll('\r\n', '\n');
    final lines = cleanText.split('\n');

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117), // GitHub dark background
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF30363D)), // GitHub dark border
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Theme(
              data: Theme.of(context).copyWith(
                scrollbarTheme: ScrollbarThemeData(
                  thumbColor: WidgetStateProperty.all(Theme.of(context).colorScheme.primary),
                ),
              ),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                interactive: true,
                thickness: 8.0,
                radius: const Radius.circular(4),
                child: SelectionArea(
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final lineNumStr = '${index + 1}';
                      final lineText = lines[index];

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(
                                lineNumStr,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Color(0xFF8B949E), // GitHub style line number color
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  lineText,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: Color(0xFFC9D1D9), // GitHub body text color
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 20,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161B22).withOpacity(0.85),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: IconButton(
              icon: Icon(
                _copied ? Icons.check : Icons.copy,
                size: 16,
                color: _copied ? const Color(0xFF56D364) : const Color(0xFF8B949E),
              ),
              onPressed: _copyToClipboard,
              tooltip: 'Copy code to clipboard',
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

class FileHistoryDialog extends StatefulWidget {
  final String filePath;
  final String fileName;
  final bool isGithub;

  const FileHistoryDialog({
    super.key,
    required this.filePath,
    required this.fileName,
    this.isGithub = false,
  });

  @override
  State<FileHistoryDialog> createState() => _FileHistoryDialogState();
}

class _FileHistoryDialogState extends State<FileHistoryDialog> {
  bool _isLoading = true;
  List<Map<String, String>> _commits = [];
  Map<String, String>? _selectedCommit;
  String? _selectedCommitContent;
  String _localFileContent = '';
  bool _isLoadingContent = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<String> _getRelativePath(String absolutePath) async {
    try {
      final repoPath = await VersionControlService.instance.getLocalRepositoryPath();
      if (repoPath == null || repoPath.isEmpty) return absolutePath;
      String normAbsolute = absolutePath.replaceAll('\\', '/');
      String normRepo = repoPath.replaceAll('\\', '/');
      if (normAbsolute.startsWith(normRepo)) {
        String rel = normAbsolute.substring(normRepo.length);
        if (rel.startsWith('/')) {
          rel = rel.substring(1);
        }
        return rel;
      }
    } catch (_) {}
    return absolutePath;
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      List<Map<String, String>> commits;
      if (widget.isGithub) {
        final relPath = await _getRelativePath(widget.filePath);
        commits = await GithubService.instance.fetchCommits(relPath);
      } else {
        commits = await VersionControlService.instance.getFileCommitHistory(widget.filePath);
      }

      final file = File(widget.filePath);
      String localContent = '';
      if (await file.exists()) {
        try {
          final bytes = await file.readAsBytes();
          localContent = utf8.decode(bytes, allowMalformed: true);
        } catch (e) {
          localContent = 'Error reading file: $e';
        }
      }

      setState(() {
        _commits = commits;
        _localFileContent = localContent;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Failed to load file history: $e';
      });
    }
  }

  Future<void> _loadCommitContent(Map<String, String> commit) async {
    setState(() {
      _selectedCommit = commit;
      _isLoadingContent = true;
      _selectedCommitContent = null;
    });

    try {
      final sha = commit['sha'] ?? commit['hash'] ?? '';
      String content;
      if (widget.isGithub) {
        final relPath = await _getRelativePath(widget.filePath);
        content = await GithubService.instance.fetchFileContent(relPath, sha);
      } else {
        content = await VersionControlService.instance.getFileContentAtCommit(widget.filePath, sha);
      }
      setState(() {
        _selectedCommitContent = content;
        _isLoadingContent = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingContent = false;
        _selectedCommitContent = 'Error fetching content: $e';
      });
    }
  }

  Future<void> _launchGitHubDiff(String sha) async {
    try {
      await VersionControlService.instance.openGithubCommit(sha);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open commit in browser: $e')),
        );
      }
    }
  }

  Future<void> _restoreToSelectedRevision() async {
    if (_selectedCommit == null || _selectedCommitContent == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.windowBackground,
        title: Text('Restore File', style: TextStyle(color: AppColors.panelTextPrimary)),
        content: Text(
          'Are you sure you want to restore the local file to the selected revision? Unsaved local modifications will be overwritten.',
          style: TextStyle(color: AppColors.panelTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.panelTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Safe overwrite sequence: create pre-restore backup using AutoBackupService
        await AutoBackupService.instance.snapshot(
          reason: 'pre_restore_${widget.fileName}',
          force: true,
          outputDirName: 'Restore Backup',
        );

        final file = File(widget.filePath);
        await file.writeAsString(_selectedCommitContent!);

        // Dynamically trigger reload in EditorStateController if current file matches
        if (mounted) {
          final editor = Provider.of<EditorStateController>(context, listen: false);
          if (editor.currentFilePath == widget.filePath || editor.localMirrorPath == widget.filePath) {
            try {
              final jsonStr = _selectedCommitContent!;
              final configObj = ChoreographyConfig.fromJson(jsonDecode(jsonStr));
              editor.loadConfig(
                editor.currentFilePath!,
                configObj,
                targetType: editor.loadedTargetType,
                targetName: editor.loadedTargetName,
                localPath: editor.localMirrorPath,
              );
            } catch (ex) {
              debugPrint("Failed to dynamically reload config: $ex");
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File restored to selected revision successfully.')),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to restore file: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.windowBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border, width: 1.5),
      ),
      child: Container(
        width: 1000,
        height: 650,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(widget.isGithub ? Icons.cloud_download : Icons.history, color: AppColors.accent, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      '${widget.isGithub ? "GitHub" : "Git"} File History: ${widget.fileName}',
                      style: TextStyle(
                        color: AppColors.panelTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: AppColors.panelTextSecondary, size: 20),
                ),
              ],
            ),
            Divider(height: 24, color: AppColors.borderSubtle),

            // Content Panel
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMsg.isNotEmpty
                      ? Center(
                          child: Text(
                            _errorMsg,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left Column: Commits List
                            Container(
                              width: 320,
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: AppColors.borderSubtle),
                                ),
                              ),
                              child: _commits.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No commit history found.',
                                        style: TextStyle(color: AppColors.panelTextSecondary),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _commits.length,
                                      itemBuilder: (context, index) {
                                        final commit = _commits[index];
                                        final sha = commit['sha'] ?? commit['hash'] ?? '';
                                        final shortSha = sha.length > 7 ? sha.substring(0, 7) : sha;
                                        final author = commit['author'] ?? 'Unknown';
                                        final date = commit['date'] ?? '';
                                        final message = commit['message'] ?? '';
                                        final isSelected = _selectedCommit == commit;

                                        return InkWell(
                                          onTap: () => _loadCommitContent(commit),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppColors.accent.withOpacity(0.15)
                                                  : Colors.transparent,
                                              border: Border(
                                                bottom: BorderSide(color: AppColors.borderSubtle.withOpacity(0.5)),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.accent.withOpacity(0.3),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        shortSha,
                                                        style: const TextStyle(
                                                          fontFamily: 'monospace',
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      date.split(' ').first,
                                                      style: TextStyle(
                                                        color: AppColors.panelTextSecondary,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  message,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: AppColors.panelTextPrimary,
                                                    fontSize: 12,
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'by $author',
                                                  style: TextStyle(
                                                    color: AppColors.panelTextSecondary,
                                                    fontSize: 10,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),

                            // Right Column: Commit Details and Diff Viewer
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: _selectedCommit == null
                                    ? Center(
                                        child: Text(
                                          'Select a commit revision from the list to view diff vs local version.',
                                          style: TextStyle(color: AppColors.panelTextSecondary),
                                        ),
                                      )
                                    : _isLoadingContent
                                        ? const Center(child: CircularProgressIndicator())
                                        : Builder(
                                            builder: (context) {
                                              final commit = _selectedCommit!;
                                              final sha = commit['sha'] ?? commit['hash'] ?? '';
                                              final shortSha = sha.length > 7 ? sha.substring(0, 7) : sha;
                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  // Action buttons
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          'Comparing: Local File vs SHA $shortSha',
                                                          style: TextStyle(
                                                            color: AppColors.panelTextPrimary,
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      Row(
                                                        children: [
                                                          TextButton.icon(
                                                            onPressed: () => _launchGitHubDiff(sha),
                                                            icon: const Icon(Icons.open_in_browser, size: 16),
                                                            label: const Text('View Diff on GitHub'),
                                                            style: TextButton.styleFrom(
                                                              foregroundColor: Colors.blueAccent,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          ElevatedButton.icon(
                                                            onPressed: _restoreToSelectedRevision,
                                                            icon: const Icon(Icons.restore, size: 16),
                                                            label: const Text('Restore File'),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.orange,
                                                              foregroundColor: Colors.white,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),

                                                  // Diff Viewer Panel
                                                  Expanded(
                                                    child: DiffViewer(
                                                      oldText: _selectedCommitContent ?? '',
                                                      newText: _localFileContent,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                      ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
