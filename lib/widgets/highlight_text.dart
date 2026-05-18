import 'package:flutter/material.dart';

class HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;

  const HighlightText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (query.trim().isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final tokens = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final defaultStyle = style ?? DefaultTextStyle.of(context).style;
    final hStyle = highlightStyle ??
        defaultStyle.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary);

    List<TextSpan> spans = [];
    String remaining = text;

    while (remaining.isNotEmpty) {
      int bestIndex = -1;
      int bestLength = 0;

      for (var token in tokens) {
        int index = remaining.toLowerCase().indexOf(token);
        if (index != -1) {
          if (bestIndex == -1 || index < bestIndex) {
            bestIndex = index;
            bestLength = token.length;
          } else if (index == bestIndex && token.length > bestLength) {
            bestLength = token.length;
          }
        }
      }

      if (bestIndex == -1) {
        spans.add(TextSpan(text: remaining, style: defaultStyle));
        break;
      } else {
        if (bestIndex > 0) {
          spans.add(TextSpan(
              text: remaining.substring(0, bestIndex), style: defaultStyle));
        }
        spans.add(TextSpan(
            text: remaining.substring(bestIndex, bestIndex + bestLength),
            style: hStyle));
        remaining = remaining.substring(bestIndex + bestLength);
      }
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
