import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:music_app/constants.dart';

// ---------------------------------------------------------------------------
// Segment model
// ---------------------------------------------------------------------------

abstract class _Segment {}

class _TextSegment extends _Segment {
  final String text;
  _TextSegment(this.text);
}

class _CodeSegment extends _Segment {
  final String code;
  final String language;
  _CodeSegment(this.code, this.language);
}

// ---------------------------------------------------------------------------
// Parser — splits markdown into text and fenced code block segments
// ---------------------------------------------------------------------------

List<_Segment> _parseSegments(String data) {
  final segments = <_Segment>[];

  // Two alternatives:
  //   Alt 1 — fenced triple-backtick block:   ```lang\n...\n```
  //   Alt 2 — single-backtick "standalone":   opening ` is at line-start (only
  //            optional whitespace before it) AND closing ` is at line-end.
  //            Content may span multiple lines.
  //            Inline single-backtick code (text before/after on same line) → not matched.
  final regex = RegExp(
    r'```(\w*)\n([\s\S]*?)```|(^|\n)([ \t]*)`([^`]+)`([ \t]*)(?=\n|$)',
    multiLine: true,
  );

  int lastEnd = 0;
  for (final match in regex.allMatches(data)) {
    final isFenced = match.group(2) != null;

    if (isFenced) {
      if (match.start > lastEnd) {
        final text = data.substring(lastEnd, match.start);
        if (text.trim().isNotEmpty) segments.add(_TextSegment(text));
      }
      final lang = match.group(1)?.trim() ?? '';
      final code = match.group(2) ?? '';
      segments.add(_CodeSegment(code.trimRight(), lang));
      lastEnd = match.end;
    } else {
      // Single-backtick standalone block.
      // group(3) is the leading '\n' (or '' if at string start) — keep it in the "before" text.
      final leadingNl = match.group(3) ?? '';
      final beforeEnd = match.start + leadingNl.length;
      if (beforeEnd > lastEnd) {
        final text = data.substring(lastEnd, beforeEnd);
        if (text.trim().isNotEmpty) segments.add(_TextSegment(text));
      }
      final code = match.group(5) ?? '';
      segments.add(_CodeSegment(code.trimRight(), ''));
      lastEnd = match.end;
    }
  }

  if (lastEnd < data.length) {
    final tail = data.substring(lastEnd);
    if (tail.trim().isNotEmpty) segments.add(_TextSegment(tail));
  }
  if (segments.isEmpty) segments.add(_TextSegment(data));
  return segments;
}

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

/// Drop-in replacement for [MarkdownBody] that renders fenced code blocks as
/// full-width dark containers with proper multiline text, while all other
/// markdown (including inline code) is passed through [MarkdownBody] normally.
class MarkdownRenderer extends StatelessWidget {
  const MarkdownRenderer({
    super.key,
    required this.data,
    this.fitContent = false,
    this.softLineBreak = true,
    this.styleSheet,
    this.onTapLink,
  });

  final String data;
  final bool fitContent;
  final bool softLineBreak;
  final MarkdownStyleSheet? styleSheet;
  final void Function(String text, String? href, String title)? onTapLink;

  @override
  Widget build(BuildContext context) {
    final segments = _parseSegments(data);
    return Container(
      color: AppUIConfig.markupBackgroundColor,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
        children: segments.map((seg) {
          if (seg is _CodeSegment) return _buildBlock(seg);
          final t = seg as _TextSegment;
          return MarkdownBody(
            data: t.text,
            fitContent: fitContent,
            softLineBreak: softLineBreak,
            styleSheet: styleSheet,
            onTapLink: onTapLink,
          );
        }).toList(),
        ),
      ),
    );
  }

  Widget _buildBlock(_CodeSegment seg) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppUIConfig.markupCodeBlockBackgroundColor,
        border: const Border(
          left: BorderSide(color: Color(0xFF4FC3F7), width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Language label (only shown when a language tag was provided)
          if (seg.language.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              color: const Color(0xFF13131F),
              child: Text(
                seg.language,
                style: const TextStyle(
                  color: Color(0xFF6272A4),
                  fontSize: 11,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                ),
              ),
            ),
          // Code text — full-width, newlines preserved naturally by Text widget
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SelectableText(
              seg.code,
              style: TextStyle(
                color: AppUIConfig.markupCodeBlockTextColor,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared style sheet — inline code only; block code handled by MarkdownRenderer
// ---------------------------------------------------------------------------

MarkdownStyleSheet buildMarkdownStyleSheet(double rootFontSize) {
  return MarkdownStyleSheet(
    p: TextStyle(
        color: Colors.black87,
        fontSize: rootFontSize,
        fontFamily: 'monospace'),
    h1: TextStyle(
        color: AppUIConfig.markupHeaderColor, fontSize: 24, fontWeight: FontWeight.bold),
    h2: TextStyle(
        color: AppUIConfig.markupHeaderColor, fontSize: 20, fontWeight: FontWeight.bold),
    h3: TextStyle(
        color: AppUIConfig.markupHeaderColor, fontSize: 18, fontWeight: FontWeight.bold),
    listBullet: TextStyle(color: Colors.black87, fontSize: rootFontSize),
    // Inline code — subtle dark bg, white text, readable on white page
    code: TextStyle(
      backgroundColor: AppUIConfig.markupInlineCodeColor,
      color: AppUIConfig.markupInlineTextColor,
      fontFamily: 'monospace',
      fontSize: 13,
    ),
    // Block quotes
    blockquote: TextStyle(
      color: AppUIConfig.markupBlockTextColor,
      fontSize: rootFontSize,
      fontStyle: FontStyle.italic,
    ),
    blockquoteDecoration: BoxDecoration(
      color: AppUIConfig.markupBlockBackgroundColor,
      border: const Border(
        left: BorderSide(color: Color(0xFF1976D2), width: 5),
      ),
    ),
    blockquotePadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
    horizontalRuleDecoration: const BoxDecoration(
      border: Border(
        bottom: BorderSide(color: Color(0xFFBDBDBD), width: 1),
      ),
    ),
  );
}
