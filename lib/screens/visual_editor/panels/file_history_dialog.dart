import 'dart:io';
import 'package:flutter/material.dart';
import '../../../constants.dart';
import '../../../services/version_control_service.dart';

class DiffLine {
  final String text;
  final String type; // 'added', 'deleted', 'unchanged'

  DiffLine(this.text, this.type);
}

List<DiffLine> computeDiff(String oldText, String newText) {
  final oldLines = oldText.split('\n');
  final newLines = newText.split('\n');

  int m = oldLines.length;
  int n = newLines.length;

  if (m * n > 150000) {
    // Simple line-by-line fallback for large files
    List<DiffLine> result = [];
    int minLen = m < n ? m : n;
    for (int i = 0; i < minLen; i++) {
      if (oldLines[i] == newLines[i]) {
        result.add(DiffLine(oldLines[i], 'unchanged'));
      } else {
        result.add(DiffLine(oldLines[i], 'deleted'));
        result.add(DiffLine(newLines[i], 'added'));
      }
    }
    if (m > minLen) {
      for (int i = minLen; i < m; i++) {
        result.add(DiffLine(oldLines[i], 'deleted'));
      }
    }
    if (n > minLen) {
      for (int i = minLen; i < n; i++) {
        result.add(DiffLine(newLines[i], 'added'));
      }
    }
    return result;
  }

  // Standard LCS DP algorithm
  List<List<int>> dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
  for (int i = 1; i <= m; i++) {
    for (int j = 1; j <= n; j++) {
      if (oldLines[i - 1] == newLines[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
      }
    }
  }

  List<DiffLine> result = [];
  int i = m, j = n;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && oldLines[i - 1] == newLines[j - 1]) {
      result.add(DiffLine(oldLines[i - 1], 'unchanged'));
      i--;
      j--;
    } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
      result.add(DiffLine(newLines[j - 1], 'added'));
      j--;
    } else {
      result.add(DiffLine(oldLines[i - 1], 'deleted'));
      i--;
    }
  }
  return result.reversed.toList();
}

class DiffViewer extends StatelessWidget {
  final String oldText;
  final String newText;

  const DiffViewer({super.key, required this.oldText, required this.newText});

  @override
  Widget build(BuildContext context) {
    final diffs = computeDiff(oldText, newText);

    int oldLineNum = 1;
    int newLineNum = 1;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151515), // Dark editor color
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: ListView.builder(
          itemCount: diffs.length,
          itemBuilder: (context, index) {
            final line = diffs[index];
            Color? bgColor;
            Color textColor = Colors.grey[300]!;
            String prefix = ' ';
            String oldNumStr = '';
            String newNumStr = '';

            if (line.type == 'added') {
              bgColor = Colors.green.withOpacity(0.1);
              textColor = Colors.greenAccent[400]!;
              prefix = '+';
              newNumStr = '${newLineNum++}';
            } else if (line.type == 'deleted') {
              bgColor = Colors.red.withOpacity(0.1);
              textColor = Colors.redAccent[100]!;
              prefix = '-';
              oldNumStr = '${oldLineNum++}';
            } else {
              prefix = ' ';
              oldNumStr = '${oldLineNum++}';
              newNumStr = '${newLineNum++}';
            }

            return Container(
              color: bgColor,
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      oldNumStr,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    child: Text(
                      newNumStr,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    prefix,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: textColor.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line.text,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class FileHistoryDialog extends StatefulWidget {
  final String filePath;
  final String fileName;

  const FileHistoryDialog({
    super.key,
    required this.filePath,
    required this.fileName,
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

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      final commits = await VersionControlService.instance.getFileCommitHistory(widget.filePath);
      final file = File(widget.filePath);
      String localContent = '';
      if (await file.exists()) {
        localContent = await file.readAsString();
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
      final content = await VersionControlService.instance.getFileContentAtCommit(widget.filePath, sha);
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
        final file = File(widget.filePath);
        await file.writeAsString(_selectedCommitContent!);
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
                    Icon(Icons.history, color: AppColors.accent, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'File History: ${widget.fileName}',
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
