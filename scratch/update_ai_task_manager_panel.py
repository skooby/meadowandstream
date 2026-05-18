import re

filepath = r"c:\Development\Music\Project\lib\screens\visual_editor\panels\ai_task_manager_panel.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'e.status != AiVerificationStatus.verified',
    '(e.status != AiVerificationStatus.verified && e.status != AiVerificationStatus.ignored)'
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated ai_task_manager_panel.dart")
