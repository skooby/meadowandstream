import re

filepath = r"c:\Development\Music\Project\lib\screens\visual_editor\panels\ai_task_manager_panel.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

flashing_bg = """class _FlashingBackground extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color flashColor;
  final BoxBorder? border;
  const _FlashingBackground({required this.child, required this.baseColor, required this.flashColor, this.border});
  @override
  State<_FlashingBackground> createState() => _FlashingBackgroundState();
}

class _FlashingBackgroundState extends State<_FlashingBackground> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _colorAnim = ColorTween(begin: widget.baseColor, end: widget.flashColor).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnim,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: _colorAnim.value,
            border: widget.border,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}"""

content = content.replace("class _FlashingIcon extends StatefulWidget {", flashing_bg + "\n\nclass _FlashingIcon extends StatefulWidget {")

target_container = """                              Container(
                                  height: 28,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                      color: Colors.red.shade900.withValues(alpha: 0.8),
                                      border: Border(
                                          top: BorderSide(
                                              color: AppColors.controlBorder))),
                                  child: Row(children: ["""

new_container = """                              ListenableBuilder(
                                listenable: AiBridgeService.instance,
                                builder: (context, _) {
                                  AiTask? pendingFeedbackTask;
                                  try {
                                    pendingFeedbackTask = AiBridgeService.instance.tasks.firstWhere((t) => t.previewItems.isNotEmpty);
                                  } catch (_) {}
                                  
                                  Widget rowContent = Container(
                                      height: 28,
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: pendingFeedbackTask != null ? null : BoxDecoration(
                                          color: Colors.red.shade900.withValues(alpha: 0.8),
                                          border: Border(
                                              top: BorderSide(
                                                  color: AppColors.controlBorder))),
                                      child: Row(children: ["""

content = content.replace(target_container, new_container)

row_closing = """                                      ])
                                  ),"""

new_row_closing = """                                      ])
                                  );
                                  
                                  if (pendingFeedbackTask != null) {
                                    return _FlashingBackground(
                                      baseColor: Colors.red.shade900.withValues(alpha: 0.8),
                                      flashColor: Colors.redAccent.withValues(alpha: 0.9),
                                      border: Border(top: BorderSide(color: AppColors.controlBorder)),
                                      child: rowContent,
                                    );
                                  }
                                  return rowContent;
                                }
                              ),"""

# We need to find the specific closing of the container, which is after the children list.
# Let's use regex.
content = re.sub(
    r'(\s+)\]\),\n(\s+)\),(\s+)if \(\!_showAiQueue\)',
    r'\1]),\n\2);\n\2if (pendingFeedbackTask != null) {\n\2  return _FlashingBackground(\n\2    baseColor: Colors.red.shade900.withValues(alpha: 0.8),\n\2    flashColor: Colors.redAccent.withValues(alpha: 0.9),\n\2    border: Border(top: BorderSide(color: AppColors.controlBorder)),\n\2    child: rowContent,\n\2  );\n\2}\n\2return rowContent;\n\2}\n\2),\n\3if (!_showAiQueue)',
    content
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated ai_task_manager_panel.dart")
