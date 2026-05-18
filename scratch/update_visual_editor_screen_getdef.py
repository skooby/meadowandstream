import os
import re

filepath = r"c:\Development\Music\Project\lib\screens\visual_editor\visual_editor_screen.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

mapping = {
    'simulator': 'simulator',
    'layer_tree': 'layers',
    'timeline': 'timeline',
    'logs': 'system_logs',
    'profiler': 'profiler',
    'backup': 'backup',
    'macro': 'macro',
    'macro_guide': 'macro_guide',
    'unit_testing': 'unit_testing',
    'assets': 'assets',
    'localization': 'localization',
    'subscriptions': 'subscriptions',
    'properties': 'properties',
    'project_modules': 'project_modules',
    'flow': 'flow_editor',
    'ui_helper': 'ui_helper',
    'ai_bridge': 'ai_bridge',
    'test_bed': 'test_bed',
    'cli_terminal': 'cli_terminal',
    'project_config': 'project_config',
    'task_editor': 'task_editor',
    'color_picker': 'color_picker',
    'icon_picker': 'icon_picker',
    'notes_editor': 'notes_editor',
    'suggestion_engine': 'suggestion_engine',
    'agents': 'agents',
    'control_types_editor': 'control_types_editor',
    'attachment_viewer': 'attachment_viewer'
}

def repl(m):
    original_id = m.group(1)
    rest = m.group(2)
    
    getdef_id = mapping.get(original_id, original_id)
    
    return f"('{original_id}', AppToolWindows.getDef('{getdef_id}').name, AppToolWindows.getDef('{getdef_id}').icon, AppToolWindows.getDef('{getdef_id}').color, {rest}"

new_content = re.sub(r"\('([a-z_]+)',\s*'[^']+',\s*Icons\.[a-zA-Z0-9_]+,\s*Colors\.[a-zA-Z0-9_]+,\s*(.*?\(bool isDocked\))", repl, content)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_content)
print("Done!")
