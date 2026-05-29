import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../widgets/markdown_code_block_builder.dart';
import '../../../constants.dart';
import '../visual_editor_screen.dart';
import '../../../state/global_picker_state.dart';

final ValueNotifier<bool> showNotesEditorNotifier = ValueNotifier(false);

void showNotesEditorWindow(BuildContext context) {
  if (showNotesEditorNotifier.value) return;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showNotesEditor'), true));
  showNotesEditorNotifier.value = true;
}

void hideNotesEditorWindow() {
  showNotesEditorNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showNotesEditor'), false));
}

class GlobalNotesEditorWindow extends StatefulWidget {
  final VoidCallback onClose;
  final bool isDocked;
  final VoidCallback? onFocus;
  
  const GlobalNotesEditorWindow({
    super.key, 
    required this.onClose, 
    this.onFocus, 
    this.isDocked = false
  });

  @override
  State<GlobalNotesEditorWindow> createState() => _GlobalNotesEditorWindowState();
}

class _GlobalNotesEditorWindowState extends State<GlobalNotesEditorWindow> {
  bool _isLoaded = false;
  double _width = 400;
  double _height = 500;
  double _bgOpacity = 0.4;
  Offset _offset = const Offset(300, 300);

  bool isPreviewingNotes = false;
  TextEditingController? _controller;
  String _title = 'NOTES EDITOR';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    VisualEditorScreen.currentWorkspace.addListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.addListener(_loadPreferences);
    VisualEditorScreen.activeWindowNotifier.addListener(_onActiveWindowChanged);
    GlobalPickerState.instance.activeNotesRequest.addListener(_onRequestChanged);
    _onRequestChanged();
  }

  @override
  void dispose() {
    VisualEditorScreen.currentWorkspace.removeListener(_loadPreferences);
    VisualEditorScreen.configRefreshNotifier.removeListener(_loadPreferences);
    GlobalPickerState.instance.activeNotesRequest.removeListener(_onRequestChanged);
    VisualEditorScreen.activeWindowNotifier.removeListener(_onActiveWindowChanged);
    super.dispose();
  }

  void _onActiveWindowChanged() {
    if (mounted) setState(() {});
  }

  void _onRequestChanged() {
    if (GlobalPickerState.instance.activeNotesRequest.value != null) {
      setState(() {
        _controller = GlobalPickerState.instance.activeNotesRequest.value!.controller;
        _title = GlobalPickerState.instance.activeNotesRequest.value!.title;
      });
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    
    setState(() {
      _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.4;
      
      if (!widget.isDocked) {
        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('notesEditorWidth')) ?? 400;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('notesEditorHeight')) ?? 500;
        
        final dx = prefs.getDouble(VisualEditorScreen.getPrefKey('notesEditorX'));
        final dy = prefs.getDouble(VisualEditorScreen.getPrefKey('notesEditorY'));
        
        if (dx != null && dy != null) {
          _offset = Offset(dx, dy);
        } else {
          final size = MediaQuery.of(context).size;
          _offset = Offset(
            (size.width - _width) / 2,
            (size.height - _height) / 2,
          );
        }
      }
      _isLoaded = true;
    });
  }

  Future<void> _savePreferences() async {
    if (widget.isDocked) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('notesEditorWidth'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('notesEditorHeight'), _height);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('notesEditorX'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('notesEditorY'), _offset.dy);
  }

  void _insertMarkdown(String prefix, [String suffix = '']) {
    if (_controller == null) return;
    final text = _controller!.text;
    final selection = _controller!.selection;
    if (selection.baseOffset == -1) return;
    
    final start = selection.start;
    final end = selection.end;
    
    final selectedText = text.substring(start, end);
    final newText = text.replaceRange(start, end, '$prefix$selectedText$suffix');
    
    _controller!.text = newText;
    _controller!.selection = TextSelection.collapsed(
      offset: start + prefix.length + selectedText.length + suffix.length,
    );
    GlobalPickerState.instance.activeNotesRequest.value?.onSaved();
  }

  Widget _buildContent() {
    if (_controller == null) {
      return const Center(child: Text('No active notes request.', style: TextStyle(color: Colors.white54)));
    }
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Colors.black12,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(isPreviewingNotes ? Icons.visibility : Icons.visibility_off, size: 16),
                  onPressed: () => setState(() => isPreviewingNotes = !isPreviewingNotes),
                  color: isPreviewingNotes ? Colors.white : Colors.white54,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Preview Markdown',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Text('H1', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _insertMarkdown('# ', ''),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Heading 1',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Text('H2', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _insertMarkdown('## ', ''),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Heading 2',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Text('H3', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _insertMarkdown('### ', ''),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Heading 3',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.format_bold, size: 16),
                  onPressed: () => _insertMarkdown('**', '**'),
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Bold',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.format_italic, size: 16),
                  onPressed: () => _insertMarkdown('*', '*'),
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Italic',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.strikethrough_s, size: 16),
                  onPressed: () => _insertMarkdown('~~', '~~'),
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Strikethrough',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.code, size: 16),
                  onPressed: () => _insertMarkdown('`', '`'),
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Inline Code',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.format_list_bulleted, size: 16),
                  onPressed: () => _insertMarkdown('- '),
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Bullet List',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.format_list_numbered, size: 16),
                  onPressed: () => _insertMarkdown('1. '),
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Numbered List',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.format_quote, size: 16),
                  onPressed: () => _insertMarkdown('> '),
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Block Quote',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.data_object, size: 16),
                  onPressed: () => _insertMarkdown('```\n', '\n```'),
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Code Block',
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: isPreviewingNotes
                ? Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppUIConfig.markupBackgroundColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _AnchorMarkdownPreview(
                      key: const Key('md_preview'),
                      data: _controller!.text.trim().isEmpty ? '*No notes provided...*' : _controller!.text,
                      styleSheet: buildMarkdownStyleSheet(AppUIConfig.rootFontSize),
                    ),
                  )
                : TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                        fontSize: AppUIConfig.rootFontSize,
                        color: Colors.white,
                        fontFamily: 'monospace',
                        height: 1.5),
                    decoration: InputDecoration(
                      hintText: 'Enter notes here...',
                      hintStyle: TextStyle(
                          color: Colors.white38,
                          fontSize: AppUIConfig.rootFontSize),
                      border: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24)),
                      enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.orange)),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.2),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    onChanged: (_) => GlobalPickerState.instance.activeNotesRequest.value?.onSaved(),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    Widget rz({
      double? t, double? b, double? l, double? r, double? w, double? h,
      required MouseCursor cursor, required void Function(DragUpdateDetails) pan,
    }) => Positioned(
      top: t, bottom: b, left: l, right: r, width: w, height: h,
      child: MouseRegion(cursor: cursor, child: GestureDetector(behavior: HitTestBehavior.opaque, onPanUpdate: pan, onPanEnd: (_) => _savePreferences(), child: Container(color: Colors.transparent)))
    );

    return ValueListenableBuilder<double>(
        valueListenable: VisualEditorScreen.globalUiScale,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, alignment: Alignment.topLeft,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: _offset.dx,
                top: _offset.dy,
                child: Listener(
                  onPointerDown: (_) => widget.onFocus?.call(),
                  behavior: HitTestBehavior.deferToChild,
                  child: Material(
                    color: Colors.transparent,
                    elevation: 8,
                    child: Container(
                      width: _width / scale,
                      height: _height / scale,
                      clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: VisualEditorScreen.activeWindowNotifier.value == 'notes_editor' ? AppColors.activeWindowBorder : AppColors.border, width: AppUIConfig.windowBorderWidth) : null,
                        color: AppColors.windowBackground.withOpacity(_bgOpacity),
                        borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                      ),
                      child: Column(children: [
                        GestureDetector(
                          onPanUpdate: (details) {
                            setState(() => _offset += details.delta);
                          },
                          onPanEnd: (_) => _savePreferences(),
                          child: Container(
                            height: AppUIConfig.titleBarHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                              color: AppColors.titleBarBackground.withOpacity(_bgOpacity),
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(AppUIConfig.windowBorderRadius))),
                            child: Row(
                              children: [
                                Icon(Icons.note,
                                    size: 16, color: AppToolWindows.getDef('notes_editor')?.color ?? Colors.amber),
                                const SizedBox(width: 8),
                                Text(AppUIConfig.formatWindowTitle('Note : ${_title.toUpperCase()}'), style: TextStyle(
                                        color: AppColors.titleBarTextPrimary,
                                        fontSize: AppUIConfig.windowTitleFontSize,
                                        fontWeight: AppUIConfig.windowTitleFontWeight)),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(Icons.close,
                                      size: 18, color: AppColors.titleBarTextSecondary),
                                  onPressed: widget.onClose,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              ],
                            ),
                          ),
                        ),
                        Expanded(child: _buildContent()),
                      ])
                    ),
                  ),
                ),
              ),
              Positioned(left: _offset.dx, top: _offset.dy, width: _width / scale, height: _height / scale, child: Stack(clipBehavior: Clip.none, children: [
                  rz(t: 0, l: 12, r: 12, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){
                      double nH = _height - (d.delta.dy * scale);
                      if (nH >= 200 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy * scale); }
                  })),
                  rz(b: 0, l: 12, r: 12, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){
                      double nH = _height + (d.delta.dy * scale);
                      if (nH >= 200 && nH <= 1200) { _height = nH; }
                  })),
                  rz(l: 0, t: 12, b: 12, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){
                      double nW = _width - (d.delta.dx * scale);
                      if (nW >= 200 && nW <= 1600) { _width = nW; _offset += Offset(d.delta.dx * scale, 0); }
                  })),
                  rz(r: 0, t: 12, b: 12, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){
                      double nW = _width + (d.delta.dx * scale);
                      if (nW >= 200 && nW <= 1600) { _width = nW; }
                  })),
                  rz(t: 0, l: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){
                      double nW = _width - (d.delta.dx * scale); double nH = _height - (d.delta.dy * scale);
                      if (nW >= 200 && nW <= 1600) { _width = nW; _offset += Offset(d.delta.dx * scale, 0); }
                      if (nH >= 200 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy * scale); }
                  })),
                  rz(t: 0, r: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (d) => setState((){
                      double nW = _width + (d.delta.dx * scale); double nH = _height - (d.delta.dy * scale);
                      if (nW >= 200 && nW <= 1600) { _width = nW; }
                      if (nH >= 200 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy * scale); }
                  })),
                  rz(b: 0, l: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (d) => setState((){
                      double nW = _width - (d.delta.dx * scale); double nH = _height + (d.delta.dy * scale);
                      if (nW >= 200 && nW <= 1600) { _width = nW; _offset += Offset(d.delta.dx * scale, 0); }
                      if (nH >= 200 && nH <= 1200) { _height = nH; }
                  })),
                  rz(b: 0, r: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){
                      double nW = _width + (d.delta.dx * scale); double nH = _height + (d.delta.dy * scale);
                      if (nW >= 200 && nW <= 1600) { _width = nW; }
                      if (nH >= 200 && nH <= 1200) { _height = nH; }
                  })),
              ])),
            ],
          ),
        );
      }
    );
  }
}

// ── Anchor slug: matches GitHub-style heading → href conversion ─────────────
String _anchorSlug(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[`*\[\](){}#]'), '')
    .trim()
    .replaceAll(RegExp(r'[^\w\s-]'), '')
    .replaceAll(RegExp(r'\s+'), '-');

// ── Anchor-aware markdown preview ────────────────────────────────────────────
// Splits the document at heading boundaries. Each heading gets its own
// Container (a RenderObjectWidget) carrying a GlobalKey so that
// RenderBox.localToGlobal and ScrollController.animateTo can precisely
// target it — unlike KeyedSubtree which has no render object of its own.
class _AnchorMarkdownPreview extends StatefulWidget {
  final String data;
  final MarkdownStyleSheet? styleSheet;
  const _AnchorMarkdownPreview({super.key, required this.data, this.styleSheet});

  @override
  State<_AnchorMarkdownPreview> createState() => _AnchorMarkdownPreviewState();
}

class _AnchorMarkdownPreviewState extends State<_AnchorMarkdownPreview> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _columnKey = GlobalKey();
  final Map<String, GlobalKey> _keys = {};

  // Each section: the heading markdown line + the body markdown below it
  List<({String slug, String heading, String body})> _sections = [];

  @override
  void initState() {
    super.initState();
    _sections = _parse(widget.data);
  }

  @override
  void didUpdateWidget(_AnchorMarkdownPreview old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) {
      setState(() => _sections = _parse(widget.data));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<({String slug, String heading, String body})> _parse(String raw) {
    final result = <({String slug, String heading, String body})>[];
    final headingRe = RegExp(r'^(#{1,4})\s+(.+)$');

    String currentSlug = '';
    String currentHeading = '';
    final bodyBuf = StringBuffer();

    void flush() {
      final body = bodyBuf.toString().trimRight();
      // Always emit — even if body is empty (heading-only section)
      result.add((slug: currentSlug, heading: currentHeading, body: body));
      _keys.putIfAbsent(currentSlug, () => GlobalKey());
      bodyBuf.clear();
    }

    bool first = true;
    for (final line in raw.split('\n')) {
      final m = headingRe.firstMatch(line);
      if (m != null) {
        if (!first) flush();
        first = false;
        currentHeading = line;
        currentSlug = _anchorSlug(m.group(2)!);
        _keys.putIfAbsent(currentSlug, () => GlobalKey());
      } else {
        if (first) {
          // Content before the first heading — emit as a preamble section
          bodyBuf.writeln(line);
        } else {
          bodyBuf.writeln(line);
        }
      }
    }
    if (!first) flush();
    // If there was only preamble with no headings, emit it
    final preamble = bodyBuf.toString().trim();
    if (first && preamble.isNotEmpty) {
      result.add((slug: '', heading: '', body: preamble));
    }
    return result;
  }

  void _scrollTo(String anchor) {
    final key = _keys[anchor];
    if (key == null) return;

    // Wait for the current frame to finish laying out before measuring.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null) return;

      final targetBox = ctx.findRenderObject() as RenderBox?;
      final columnBox = _columnKey.currentContext?.findRenderObject() as RenderBox?;
      if (targetBox == null || columnBox == null) return;

      // Position of the target widget relative to the column's top-left
      final localOffset = targetBox.localToGlobal(Offset.zero, ancestor: columnBox);
      final targetPixel = (_scroll.offset + localOffset.dy)
          .clamp(0.0, _scroll.position.maxScrollExtent);

      _scroll.animateTo(
        targetPixel,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  void _openLink(String href) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      Process.start('cmd', ['/c', 'start', '', href]);
    } else if (href.startsWith('file://')) {
      final path = href.replaceFirst('file://', '');
      Process.run('explorer.exe', [path.replaceAll('/', '\\')]);
    }
  }

  MarkdownBody _md(String data) => MarkdownBody(
        data: data,
        fitContent: false,
        softLineBreak: true,
        styleSheet: widget.styleSheet,
        onTapLink: (text, href, title) {
          if (href == null) return;
          if (href.startsWith('#')) {
            _scrollTo(href.substring(1));
          } else {
            _openLink(href);
          }
        },
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.all(8),
      child: Column(
        key: _columnKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _sections.map((s) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Heading in its own Container carrying the GlobalKey.
              // Container IS a RenderObjectWidget, so findRenderObject()
              // returns a real RenderBox that localToGlobal can measure.
              if (s.heading.isNotEmpty)
                Container(
                  key: _keys[s.slug],
                  child: _md(s.heading),
                ),
              if (s.body.trim().isNotEmpty)
                _md(s.body),
            ],
          );
        }).toList(),
      ),
    );
  }
}

