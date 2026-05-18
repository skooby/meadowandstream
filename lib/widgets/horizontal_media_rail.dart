import 'package:flutter/material.dart';
import '../engine/ui_inspector/element_registry.dart';

class HorizontalMediaRail extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final List<Widget> items;
  final int? reorderIndex;

  const HorizontalMediaRail({
    super.key,
    required this.title,
    this.onSeeAll,
    required this.items,
    this.reorderIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    Widget titleWidget = RegisteredElement(
      id: 'rail_title_${title.replaceAll(' ', '_').toLowerCase()}',
      meta: const {'type': 'Text'},
      child: Text(
        title,
        style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
              fontSize: 22,
              letterSpacing: 0.5,
            ) ??
            const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      )
    );

    if (reorderIndex != null) {
      titleWidget = ReorderableDragStartListener(
        index: reorderIndex!,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_indicator, size: 20, color: Colors.grey),
            const SizedBox(width: 8),
            Flexible(child: titleWidget),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleWidget),
              if (onSeeAll != null)
                RegisteredElement(
                  id: 'rail_btn_see_all_${title.replaceAll(' ', '_').toLowerCase()}',
                  meta: const {'type': 'Button'},
                  child: TextButton(
                    onPressed: onSeeAll,
                    child: const Text('See All'),
                  ),
                )
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: items[index],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
