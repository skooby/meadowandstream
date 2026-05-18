import re

filepath = r"c:\Development\Music\Project\lib\screens\visual_editor\panels\ai_task_manager_panel.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'final TextEditingController _systemHooksInstController = TextEditingController();',
    'final TextEditingController _systemHooksInstController = TextEditingController();\n  final TextEditingController _missingFilesInstController = TextEditingController();'
)

# Replace all occurrences of updateInstructions(..., _systemHooksInstController.text) with adding _missingFilesInstController.text
content = re.sub(
    r'updateInstructions\(([\s\S]*?)_systemHooksInstController\.text\)',
    r'updateInstructions(\1_systemHooksInstController.text,\n                                                        _missingFilesInstController.text)',
    content
)

# In initState, initialize _missingFilesInstController.text
init_code = """    _systemHooksInstController.text = AiBridgeService.instance.systemHooksInstructions;"""
new_init_code = """    _systemHooksInstController.text = AiBridgeService.instance.systemHooksInstructions;
    _missingFilesInstController.text = AiBridgeService.instance.missingFilesInstructions;"""
content = content.replace(init_code, new_init_code)

# Insert the buildRule for Missing Files Instructions
# We will insert it right after the systemHooks buildRule

system_hooks_rule = """                                              buildRule(
                                                'System Hooks Helper:',
                                                _systemHooksInstController,
                                                'Core system hooks and rules...',
                                                (val) => AiBridgeService
                                                    .instance
                                                    .updateInstructions(
                                                        _instController.text,
                                                        _quickInstController.text,
                                                        _previewModeInstController.text,
                                                        _previewApprovedInstController.text,
                                                        _previewRejectedInstController.text,
                                                        val,
                                                        _missingFilesInstController.text),
                                                Colors.blueAccent,
                                              ),"""

missing_files_rule = """                                              buildRule(
                                                'System Hooks Helper:',
                                                _systemHooksInstController,
                                                'Core system hooks and rules...',
                                                (val) => AiBridgeService
                                                    .instance
                                                    .updateInstructions(
                                                        _instController.text,
                                                        _quickInstController.text,
                                                        _previewModeInstController.text,
                                                        _previewApprovedInstController.text,
                                                        _previewRejectedInstController.text,
                                                        val,
                                                        _missingFilesInstController.text),
                                                Colors.blueAccent,
                                              ),
                                              buildRule(
                                                'Missing Files Recovery Prompt:',
                                                _missingFilesInstController,
                                                'Prompt sent when required output files are missing after IDLE... Use {missingList} for the file list.',
                                                (val) => AiBridgeService
                                                    .instance
                                                    .updateInstructions(
                                                        _instController.text,
                                                        _quickInstController.text,
                                                        _previewModeInstController.text,
                                                        _previewApprovedInstController.text,
                                                        _previewRejectedInstController.text,
                                                        _systemHooksInstController.text,
                                                        val),
                                                Colors.redAccent,
                                              ),"""
                                              
content = content.replace(system_hooks_rule, missing_files_rule)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated ai_task_manager_panel.dart")
