import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import '../../../constants.dart';
import '../visual_editor_screen.dart';
import '../../../state/global_picker_state.dart';
import '../../../services/ai_bridge_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../widgets/markdown_code_block_builder.dart';

final ValueNotifier<bool> showAttachmentViewerNotifier = ValueNotifier(false);

void showAttachmentViewerWindow(BuildContext context) {
  if (showAttachmentViewerNotifier.value) return;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showAttachmentViewer'), true));
  showAttachmentViewerNotifier.value = true;
}

void hideAttachmentViewerWindow() {
  showAttachmentViewerNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showAttachmentViewer'), false));
}

class AttachmentViewerWindow extends StatefulWidget {
  final VoidCallback onClose;
  final bool isDocked;
  final VoidCallback? onFocus;
  const AttachmentViewerWindow({super.key, required this.onClose, this.onFocus, this.isDocked = false});
  @override
  State<AttachmentViewerWindow> createState() => _AttachmentViewerWindowState();
}

class _AttachmentViewerWindowState extends State<AttachmentViewerWindow> {
  bool _isLoaded = false;
  double _width = 600, _height = 700, _bgOpacity = 0.8;
  Offset _offset = const Offset(200, 80);
  Timer? _analysisPollTimer;

  // The viewer owns its own persistent list
  List<String> _attachments = [];
  int _selectedIndex = -1;
  bool _imageLoadFailed = false;
  final TextEditingController _notesController = TextEditingController();
  // Tracks whether each attachment path has a sidecar analysis file
  final Map<String, bool> _hasAnalysis = {};

  // Link context (set externally via GlobalPickerState)
  AttachmentViewerRequest? _linkRequest;

  static const String _prefsKey = 've_attachmentViewerFiles';

  @override
  void initState() {
    super.initState();
    VisualEditorScreen.currentWorkspace.addListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.addListener(_loadPreferences);
    GlobalPickerState.instance.activeAttachmentRequest.addListener(_onLinkRequestChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreferences();
      _onLinkRequestChanged();
    });
    // Periodically refresh analysis badge state while window is open
    _analysisPollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refreshAnalysisBadges());
  }

  @override
  void dispose() {
    _analysisPollTimer?.cancel();
    VisualEditorScreen.currentWorkspace.removeListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.removeListener(_loadPreferences);
    GlobalPickerState.instance.activeAttachmentRequest.removeListener(_onLinkRequestChanged);
    _notesController.dispose();
    super.dispose();
  }


  void _onLinkRequestChanged() {
    setState(() => _linkRequest = GlobalPickerState.instance.activeAttachmentRequest.value);
  }

  String get _selectedPath =>
      (_selectedIndex >= 0 && _selectedIndex < _attachments.length) ? _attachments[_selectedIndex] : '';

  bool _isImageFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp', '.ico', '.tiff'].contains(ext);
  }

  bool _isUrlPath(String path) => path.startsWith('http://') || path.startsWith('https://');

  String _analysisPath(String attachmentPath) => '$attachmentPath.analysis.md';

  bool _analysisExists(String attachmentPath) {
    try { return File(_analysisPath(attachmentPath)).existsSync(); } catch (_) { return false; }
  }

  void _refreshAnalysisBadges() {
    bool changed = false;
    for (final path in _attachments) {
      final has = _analysisExists(path);
      if (_hasAnalysis[path] != has) {
        _hasAnalysis[path] = has;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  Future<void> _persistList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_attachments));
  }


  Future<void> _loadNotes() async {
    final path = _selectedPath;
    if (path.isEmpty) { _notesController.text = ''; return; }
    final f = File('$path.notes.txt');
    _notesController.text = (await f.exists()) ? (await f.readAsString()) : '';
  }

  Future<void> _saveNotes() async {
    final path = _selectedPath;
    if (path.isEmpty) return;
    try {
      await File('$path.notes.txt').writeAsString(_notesController.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notes saved.'), duration: Duration(seconds: 1)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _addFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.any);
    if (result != null) {
      setState(() {
        for (final f in result.files) {
          if (f.path != null && !_attachments.contains(f.path!)) {
            _attachments.add(f.path!);
            _linkRequest?.onLink(f.path!);
          }
        }
        if (_selectedIndex < 0 && _attachments.isNotEmpty) _selectedIndex = 0;
      });
      await _persistList();
    }
  }

  Future<void> _pasteNewAttachment() async {
    try {
      final Uint8List? img = await Pasteboard.image;
      if (img != null && img.isNotEmpty) {
        final dir = Directory('.ai_bridge/attachments');
        if (!await dir.exists()) await dir.create(recursive: true);
        final file = File('${dir.path}/paste_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(img, flush: true);
        await Future.delayed(const Duration(milliseconds: 50)); // Ensure file lock is released
        setState(() {
          final absolutePath = file.absolute.path;
          if (!_attachments.contains(absolutePath)) _attachments.add(absolutePath);
          _selectedIndex = _attachments.length - 1;
          _imageLoadFailed = false;
        });
        await _persistList();
        _linkRequest?.onLink(file.absolute.path);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image pasted and linked.'), backgroundColor: Colors.green));
      } else {
        final List<String>? files = await Pasteboard.files();
        if (files != null && files.isNotEmpty) {
          setState(() {
            for (final f in files) {
              if (!_attachments.contains(f)) _attachments.add(f);
              _linkRequest?.onLink(f);
            }
            if (_selectedIndex < 0 && _attachments.isNotEmpty) _selectedIndex = 0;
          });
          await _persistList();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Files pasted and linked.'), backgroundColor: Colors.green));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No image or files on clipboard.'), backgroundColor: Colors.orange));
        }
      }
    } on MissingPluginException {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Native plugin missing. Please stop and completely restart the app in your IDE to compile the new Pasteboard dependency.'), backgroundColor: Colors.redAccent, duration: Duration(seconds: 5)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paste error: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _pasteImageReplaceSelected() async {
    final path = _selectedPath;
    if (path.isEmpty || !_isImageFile(path)) return;
    try {
      final Uint8List? img = await Pasteboard.image;
      if (img != null && img.isNotEmpty) {
        await File(path).writeAsBytes(img, flush: true);
        await Future.delayed(const Duration(milliseconds: 50));
        await FileImage(File(path)).evict();
        setState(() { _imageLoadFailed = false; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image replaced.'), backgroundColor: Colors.green));
      } else {
        final List<String>? files = await Pasteboard.files();
        if (files != null && files.isNotEmpty) {
          await File(files.first).copy(path);
          await Future.delayed(const Duration(milliseconds: 50));
          await FileImage(File(path)).evict();
          setState(() => _imageLoadFailed = false);
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No image on clipboard.'), backgroundColor: Colors.orange));
        }
      }
    } on MissingPluginException {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plugin missing — cold restart.'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _removeSelected() async {
    final path = _selectedPath;
    if (path.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panelBackground,
        title: Text('Remove', style: TextStyle(color: AppColors.panelTextPrimary)),
        content: Text('Remove "${p.basename(path)}" from the viewer?', style: TextStyle(color: AppColors.panelTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: AppColors.panelTextSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _attachments.removeAt(_selectedIndex);
        if (_selectedIndex >= _attachments.length) _selectedIndex = _attachments.length - 1;
        _imageLoadFailed = false;
      });
      await _persistList();
      _loadNotes();
    }
  }

  void _linkSelected() {
    final path = _selectedPath;
    if (path.isEmpty || _linkRequest == null) return;
    _linkRequest!.onLink(path);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Linked to: ${_linkRequest!.contextLabel}'),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── AI ANALYSIS ──────────────────────────────────────────────────────────

  Future<void> _analyzeAttachment() async {
    final path = _selectedPath;
    if (path.isEmpty || _isUrlPath(path)) return;
    if (_analysisExists(path)) { _viewAnalysis(); return; }

    final name   = p.basename(path);
    final ext    = p.extension(path).toLowerCase();
    final isImg  = _isImageFile(path);
    final fType  = isImg ? 'image file' : 'file (extension: $ext)';
    final outPath = _analysisPath(path);

    final prompt = '# PRIMARY DIRECTIVES\n'
        'Voice: Direct / Robotic\n'
        'Complexity: Verbose\n\n'
        'You are performing a one-shot analysis of an attachment file. '
        'Open and inspect the following file using your view_file tool and produce a comprehensive analysis.\n\n'
        'File path  : $path\n'
        'File name  : $name\n'
        'File type  : $fType\n\n'
        'Write your full analysis as markdown to the file: $outPath\n\n'
        'The analysis should cover:\n'
        '- A concise summary of what the file contains\n'
        '- Key observations, patterns, or notable elements\n'
        '- Quality issues, anomalies, or recommendations\n'
        '- For images: composition, color palette, content, and intended usage\n'
        '- For code / text: structure, purpose, and any concerns\n\n'
        'After writing $outPath, write:\n'
        '  .ai_bridge/latest_notes.json  → {"notes": "Analysis written to $outPath", "description": "AI analysis for $name"}\n'
        'Then write IDLE to .ai_bridge/agent_status.txt.';

    await AiBridgeService.instance.sendToQueue(prompt, false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Analysis queued for "$name". Open it once complete.'),
        backgroundColor: Colors.blueGrey,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  Future<void> _viewAnalysis() async {
    final path = _selectedPath;
    if (path.isEmpty) return;
    final analysisFile = File(_analysisPath(path));
    if (!analysisFile.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No analysis yet. Click Analyze to generate one.'), backgroundColor: Colors.orange));
      }
      return;
    }
    final content = await analysisFile.readAsString();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.panelBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Header
            Container(
              height: AppUIConfig.titleBarHeight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.titleBarBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppUIConfig.windowBorderRadius)),
              ),
              child: Row(children: [
                Icon(Icons.science, size: 14, color: AppUIConfig.configIconColor ?? Colors.cyanAccent),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  AppUIConfig.formatWindowTitle('ANALYSIS — ${p.basename(path)}'),
                  style: TextStyle(color: AppColors.titleBarTextPrimary, fontSize: AppUIConfig.windowTitleFontSize, fontWeight: AppUIConfig.windowTitleFontWeight),
                  overflow: TextOverflow.ellipsis,
                )),
                Tooltip(message: 'Delete & re-analyse',
                  child: InkWell(borderRadius: BorderRadius.circular(4),
                    onTap: () async {
                      Navigator.pop(ctx);
                      try { await analysisFile.delete(); } catch (_) {}
                      setState(() => _hasAnalysis[path] = false);
                      await _analyzeAttachment();
                    },
                    child: Padding(padding: const EdgeInsets.all(6),
                      child: Icon(Icons.refresh, size: 14, color: AppColors.panelTextSecondary)))),
                const SizedBox(width: 4),
                Tooltip(message: 'Open in Explorer',
                  child: InkWell(borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      final wp = _analysisPath(path).replaceAll('/', r'\');
                      try { Process.run('explorer.exe', ['/select,$wp']); } catch (_) {}
                    },
                    child: Padding(padding: const EdgeInsets.all(6),
                      child: Icon(Icons.folder_open, size: 14, color: AppColors.panelTextSecondary)))),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: AppColors.titleBarTextSecondary),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ]),
            ),
            // Markdown body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: MarkdownRenderer(
                  data: content,
                  styleSheet: buildMarkdownStyleSheet(AppUIConfig.rootFontSize),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }


  Widget _buildList() {
    if (_attachments.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.attach_file, size: 32, color: AppColors.panelTextSecondary),
        const SizedBox(height: 8),
        Text('No files added yet.', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
        const SizedBox(height: 4),
        Text('Click + to add files.', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.smallFontSize)),
      ]));
    }
    return ListView.builder(
      itemCount: _attachments.length,
      itemBuilder: (ctx, i) {
        final path = _attachments[i];
        final name = p.basename(path);
        final isImg = _isImageFile(path);
        final isUrl = _isUrlPath(path);
        final isSelected = i == _selectedIndex;
        return InkWell(
          onTap: () => setState(() { _selectedIndex = i; _imageLoadFailed = false; _loadNotes(); }),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isSelected ? AppColors.accent.withOpacity(0.5) : Colors.transparent),
            ),
            child: Row(children: [
              if (isImg)
                ClipRRect(borderRadius: BorderRadius.circular(3),
                  child: Image.file(File(path), width: 22, height: 22, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 16, color: AppColors.panelTextSecondary)))
              else
                Icon(isUrl ? Icons.link : Icons.insert_drive_file, size: 16,
                    color: isSelected ? AppColors.accent : AppColors.panelTextSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text(name, style: TextStyle(color: isSelected ? AppColors.panelTextPrimary : AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize), overflow: TextOverflow.ellipsis)),
              if (_hasAnalysis[path] == true) ...[
                const SizedBox(width: 4),
                Tooltip(message: 'Analysis available', child: Icon(Icons.science, size: 11, color: Colors.cyanAccent.withOpacity(0.8))),
              ],
              if (isSelected) ...[const SizedBox(width: 4), Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.accent)],
            ]),
          ),
        );
      },
    );
  }

  Widget _buildDetail() {
    final path = _selectedPath;
    if (path.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.touch_app, size: 28, color: AppColors.panelTextSecondary),
        const SizedBox(height: 8),
        Text('Select a file to preview', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.smallFontSize)),
      ]));
    }
    final isImg = _isImageFile(path);
    final isUrl = _isUrlPath(path);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Preview
      Expanded(flex: 3, child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.borderSubtle)),
        clipBehavior: Clip.antiAlias,
        child: isUrl
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.link, size: 32, color: AppColors.accent),
                const SizedBox(height: 8),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(path, textAlign: TextAlign.center, style: TextStyle(color: AppColors.accent, fontSize: AppUIConfig.rootFontSize), overflow: TextOverflow.ellipsis, maxLines: 3)),
              ]))
            : isImg && !_imageLoadFailed
                ? Image.file(File(path), fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) { WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _imageLoadFailed = true)); return const SizedBox.shrink(); })
                : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_imageLoadFailed ? Icons.broken_image : Icons.insert_drive_file, size: 36, color: AppColors.panelTextSecondary),
                    const SizedBox(height: 8),
                    Text(p.basename(path), style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize)),
                    const SizedBox(height: 4),
                    Text(path, style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.smallFontSize), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2),
                  ])),
      )),

      // Link-to-context banner (when a link request is active)
      if (_linkRequest != null)
        Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.accent.withOpacity(0.4)),
          ),
          child: Row(children: [
            const SizedBox(width: 10),
            Icon(Icons.task_alt, size: 13, color: AppColors.accent),
            const SizedBox(width: 6),
            Expanded(child: Text('Link to: ${_linkRequest!.contextLabel}',
                style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize), overflow: TextOverflow.ellipsis)),
            TextButton.icon(
              onPressed: _linkSelected,
              icon: const Icon(Icons.link, size: 13),
              label: const Text('Link', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 13, color: AppColors.panelTextSecondary),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              tooltip: 'Clear link context',
              onPressed: () => GlobalPickerState.instance.clearAttachmentRequest(),
            ),
          ]),
        ),

      // Commands
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Wrap(spacing: 6, runSpacing: 4, children: [
          if (isUrl) _cmdBtn(Icons.open_in_browser, 'Open URL', Colors.lightBlueAccent, () async {
            final uri = Uri.tryParse(path); if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
          })
          else _cmdBtn(Icons.folder_open, 'Explorer', AppColors.panelTextPrimary, () {
            try { Process.run('explorer.exe', ['/select,${path.replaceAll('/', r'\')}']); } catch (_) { launchUrl(Uri.file(path)); }
          }),
          if (isImg) _cmdBtn(Icons.content_paste, 'Paste Replace', Colors.lightBlueAccent, _pasteImageReplaceSelected),
          if (!isUrl) ...[
            if (_hasAnalysis[path] == true)
              _cmdBtn(Icons.science, 'View Analysis', Colors.cyanAccent, _viewAnalysis)
            else
              _cmdBtn(Icons.science, 'Analyze', AppColors.panelTextSecondary, _analyzeAttachment),
          ],
          _cmdBtn(Icons.delete_forever, 'Remove', Colors.redAccent, _removeSelected),
        ]),
      ),
      const SizedBox(height: 6),

      // Notes
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          Icon(Icons.notes, size: 11, color: AppColors.panelTextSecondary),
          const SizedBox(width: 4),
          Text('NOTES', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.smallFontSize, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const Spacer(),
          InkWell(onTap: _saveNotes, borderRadius: BorderRadius.circular(4),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(children: [Icon(Icons.save, size: 11, color: AppColors.accent), const SizedBox(width: 3), Text('Save', style: TextStyle(color: AppColors.accent, fontSize: AppUIConfig.smallFontSize))]))),
        ]),
      ),
      Expanded(flex: 2, child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: TextField(
          controller: _notesController,
          maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top,
          style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize, height: 1.5),
          decoration: InputDecoration(
            hintText: 'Notes about this file…',
            hintStyle: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
            border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.borderSubtle)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.borderSubtle)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
            filled: true, fillColor: Colors.black.withOpacity(0.15),
            contentPadding: const EdgeInsets.all(8), isDense: true,
          ),
        ),
      )),
    ]);
  }

  Widget _cmdBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 12),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color, side: BorderSide(color: color.withOpacity(0.6)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );

  Widget _buildContent() => Column(children: [
    // Header: file count + add button
    Container(
      height: AppUIConfig.titleBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.panelBackground.withOpacity(0.6),
      child: Row(children: [
        Icon(Icons.perm_media, size: 13, color: AppColors.accent),
        const SizedBox(width: 6),
        Text('${_attachments.length} file${_attachments.length == 1 ? '' : 's'}',
            style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
        const Spacer(),
        Tooltip(message: 'Paste from clipboard', child: InkWell(onTap: _pasteNewAttachment, borderRadius: BorderRadius.circular(4),
          child: Padding(padding: const EdgeInsets.all(4),
            child: Icon(Icons.content_paste, size: 16, color: AppColors.accent)))),
        const SizedBox(width: 4),
        Tooltip(message: 'Add files', child: InkWell(onTap: _addFiles, borderRadius: BorderRadius.circular(4),
          child: Padding(padding: const EdgeInsets.all(4),
            child: Icon(Icons.add, size: 16, color: AppColors.accent)))),
      ]),
    ),
    const Divider(height: 1, color: Colors.white12),
    // List (fixed ~40% height) + Detail (remaining)
    Expanded(child: Column(children: [
      SizedBox(height: 170, child: _buildList()),
      const Divider(height: 1, color: Colors.white12),
      Expanded(child: _buildDetail()),
    ])),
  ]);

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    Size? size;
    try { size = MediaQuery.of(context).size; } catch (_) {}
    final saved = prefs.getString(_prefsKey);
    List<String> loaded = [];
    if (saved != null) {
      try { loaded = List<String>.from(jsonDecode(saved)); } catch (_) {}
    }
    setState(() {
      _attachments = loaded;
      if (_selectedIndex >= _attachments.length) _selectedIndex = _attachments.isEmpty ? -1 : _attachments.length - 1;
      _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.8;
      if (!widget.isDocked) {
        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('attachmentViewerWidth')) ?? 600;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('attachmentViewerHeight')) ?? 700;
        final dx = prefs.getDouble(VisualEditorScreen.getPrefKey('attachmentViewerX'));
        final dy = prefs.getDouble(VisualEditorScreen.getPrefKey('attachmentViewerY'));
        if (dx != null && dy != null) {
          _offset = Offset(dx, dy);
        } else if (size != null) {
          _offset = Offset((size.width - _width) / 2, (size.height - _height) / 2);
        }
      }
      _isLoaded = true;
    });
  }

  Future<void> _savePreferences() async {
    if (widget.isDocked) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('attachmentViewerWidth'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('attachmentViewerHeight'), _height);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('attachmentViewerX'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('attachmentViewerY'), _offset.dy);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    Widget rz({double? t, double? b, double? l, double? r, double? w, double? h,
      required MouseCursor cursor, required void Function(DragUpdateDetails) pan}) =>
        Positioned(top: t, bottom: b, left: l, right: r, width: w, height: h,
          child: MouseRegion(cursor: cursor, child: GestureDetector(behavior: HitTestBehavior.opaque,
            onPanUpdate: pan, onPanEnd: (_) => _savePreferences(), child: Container(color: Colors.transparent))));

    return ValueListenableBuilder<double>(
      valueListenable: VisualEditorScreen.globalUiScale,
      builder: (context, scale, _) => Transform.scale(
        scale: scale, alignment: Alignment.topLeft,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(left: _offset.dx, top: _offset.dy,
            child: Listener(onPointerDown: (_) => widget.onFocus?.call(), behavior: HitTestBehavior.deferToChild,
              child: Material(color: Colors.transparent, elevation: 8,
                child: Container(
                  width: _width / scale, height: _height / scale,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.windowBackground.withOpacity(_bgOpacity),
                    borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                    border: AppUIConfig.windowBorderWidth > 0 
                        ? Border.all(
                            color: VisualEditorScreen.activeWindowNotifier.value == 'attachment_viewer' 
                                ? AppColors.activeWindowBorder 
                                : AppColors.border, 
                            width: AppUIConfig.windowBorderWidth)
                        : null,
                  ),
                  child: Column(children: [
                    GestureDetector(
                      onPanUpdate: (d) => setState(() => _offset += d.delta),
                      onPanEnd: (_) => _savePreferences(),
                      child: Container(
                        height: AppUIConfig.titleBarHeight / scale,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                              color: AppColors.titleBarBackground.withOpacity(_bgOpacity),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(AppUIConfig.windowBorderRadius)),
                        ),
                        child: Row(children: [
                          Icon(Icons.attachment, size: 16 / scale, color: AppUIConfig.configIconColor ?? AppColors.accent),
                          const SizedBox(width: 8),
                          Text(AppUIConfig.formatWindowTitle('Attachments'), style: TextStyle(color: AppColors.titleBarTextPrimary, fontSize: AppUIConfig.windowTitleFontSize / scale, fontWeight: AppUIConfig.windowTitleFontWeight)),
                          const Spacer(),
                          IconButton(icon: Icon(Icons.close, size: 18 / scale, color: AppColors.titleBarTextSecondary), onPressed: widget.onClose, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                        ]),
                      ),
                    ),
                    Expanded(child: _buildContent()),
                  ]),
                ),
              ),
            ),
          ),
          Positioned(left: _offset.dx, top: _offset.dy, width: _width / scale, height: _height / scale,
            child: Stack(clipBehavior: Clip.none, children: [
              rz(t: 0, l: 12, r: 12, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState(() { double n = _height - (d.delta.dy * scale); if (n >= 300 && n <= 1400) { _height = n; _offset += Offset(0, d.delta.dy * scale); } })),
              rz(b: 0, l: 12, r: 12, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState(() { double n = _height + (d.delta.dy * scale); if (n >= 300 && n <= 1400) _height = n; })),
              rz(l: 0, t: 12, b: 12, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState(() { double n = _width - (d.delta.dx * scale); if (n >= 300 && n <= 1600) { _width = n; _offset += Offset(d.delta.dx * scale, 0); } })),
              rz(r: 0, t: 12, b: 12, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState(() { double n = _width + (d.delta.dx * scale); if (n >= 300 && n <= 1600) _width = n; })),
            ])),
        ]),
      ),
    );
  }
}
