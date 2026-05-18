import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'ai_copilot_theme.dart';
import 'suggestion_entry.dart';

class AiCopilotPanel extends StatefulWidget {
  final AiCopilotTheme theme;
  final void Function(String moduleName, String payload) onDispatch;
  
  const AiCopilotPanel({
    super.key,
    this.theme = const AiCopilotTheme(),
    required this.onDispatch,
  });

  @override
  AiCopilotPanelState createState() => AiCopilotPanelState();
}

class AiCopilotPanelState extends State<AiCopilotPanel> {
  bool _isLoaded = false;
  List<SuggestionEntry> _entries = [];
  final TextEditingController _commonPromptCtrl = TextEditingController();
  final TextEditingController _hintCtrl = TextEditingController();

  List<String> _complexities = ['Simple', 'Medium', 'Complex'];
  List<String> _categories = ['Cosmetic', 'Usability', 'System', 'Application'];
  List<String> _areasOfInterest = ['Flow Editor', 'Now Playing UI', 'Settings'];

  String? _selectedGlobalComplexity;
  String? _selectedGlobalCategory;
  String? _selectedGlobalArea;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _commonPromptCtrl.dispose();
    _hintCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _commonPromptCtrl.text = prefs.getString('ve_suggestionengine_common_prompt') ?? "You are a Senior System Architect and AI Coding Assistant.\n\nYour objective is to return a detailed task suggestion based on the provided context. Your response MUST be formatted as a formal, actionable task.\n\nFormat your response exactly as follows:\n- Set the DESCRIPTION to a brief, 1-2 paragraph explanation of what the suggestion is and why it is necessary.\n- Place all detailed, step-by-step implementation guides and architectural explanations into the NOTES section.";

        _complexities = prefs.getStringList('ve_suggestionengine_complexities') ?? ['Simple', 'Medium', 'Complex'];
        _categories = prefs.getStringList('ve_suggestionengine_categories') ?? ['Cosmetic', 'Usability', 'System', 'Application'];
        _areasOfInterest = prefs.getStringList('ve_suggestionengine_areas') ?? ['Flow Editor', 'Now Playing UI', 'Settings'];
        
        _selectedGlobalComplexity = prefs.getString('ve_suggestionengine_sel_complexity') ?? (_complexities.isNotEmpty ? _complexities.first : null);
        _selectedGlobalCategory = prefs.getString('ve_suggestionengine_sel_category') ?? (_categories.isNotEmpty ? _categories.first : null);
        _selectedGlobalArea = prefs.getString('ve_suggestionengine_sel_area') ?? (_areasOfInterest.isNotEmpty ? _areasOfInterest.first : null);

        final entriesStr = prefs.getString('ve_suggestionengine_entries');
        if (entriesStr != null) {
          try {
            final List<dynamic> decoded = jsonDecode(entriesStr);
            _entries = decoded.map((e) => SuggestionEntry.fromJson(e)).toList();
          } catch (_) {
            _populateDefaultEntries();
          }
        } else {
          _populateDefaultEntries();
        }
        _isLoaded = true;
      });
    }
  }

  void _populateDefaultEntries() {
    _entries = [
      SuggestionEntry(
        id: 'arch',
        title: 'Architecture',
        description: 'Analyze codebase architecture, identify bottlenecks, and suggest structural improvements.',
        prompt: 'Please review the current codebase architecture. Identify any structural bottlenecks, anti-patterns, or areas for improvement, and provide a detailed list of actionable suggestions.'
      ),
      SuggestionEntry(
        id: 'uiux',
        title: 'UI/UX',
        description: 'Review user interface components, UX flows, and suggest design or usability enhancements.',
        prompt: 'Please review the UI/UX components in the active context. Suggest enhancements for usability, design aesthetics, or user flows.'
      ),
      SuggestionEntry(
        id: 'perf',
        title: 'Performance',
        description: 'Profile logic, suggest optimizations, and identify potential memory or rendering issues.',
        prompt: 'Please analyze the code for performance bottlenecks. Suggest optimizations for rendering speed, memory usage, or algorithm efficiency.'
      ),
    ];
    _saveEntries();
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final str = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString('ve_suggestionengine_entries', str);
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ve_suggestionengine_common_prompt', _commonPromptCtrl.text);
    await prefs.setStringList('ve_suggestionengine_complexities', _complexities);
    await prefs.setStringList('ve_suggestionengine_categories', _categories);
    await prefs.setStringList('ve_suggestionengine_areas', _areasOfInterest);
    if (_selectedGlobalComplexity != null) await prefs.setString('ve_suggestionengine_sel_complexity', _selectedGlobalComplexity!);
    if (_selectedGlobalCategory != null) await prefs.setString('ve_suggestionengine_sel_category', _selectedGlobalCategory!);
    if (_selectedGlobalArea != null) await prefs.setString('ve_suggestionengine_sel_area', _selectedGlobalArea!);
  }

  void _dispatchPrompt(SuggestionEntry entry) {
    final common = _commonPromptCtrl.text.trim();
    final hint = _hintCtrl.text.trim();
    final hintSection = hint.isNotEmpty ? "\n[User Hint]\n$hint\n" : "";

    final combinedPrompt = """
$common

[Suggestion Parameters]
- Complexity: ${_selectedGlobalComplexity ?? 'None'}
- Category: ${_selectedGlobalCategory ?? 'None'}
- Area of Interest: ${_selectedGlobalArea ?? 'General'}
$hintSection
${entry.prompt}
""";
    final moduleName = _selectedGlobalArea ?? 'General';
    widget.onDispatch(moduleName, combinedPrompt);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Dispatched ${entry.title} analysis to AI Bridge.'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void showEditDialog(SuggestionEntry? entry) {
    final isNew = entry == null;
    final titleCtrl = TextEditingController(text: entry?.title ?? '');
    final descCtrl = TextEditingController(text: entry?.description ?? '');
    final promptCtrl = TextEditingController(text: entry?.prompt ?? '');
    int? selectedColor = entry?.color;
    final colors = [
      widget.theme.accent, Colors.blue, Colors.green, Colors.orange, Colors.purple, 
      Colors.teal, Colors.red, Colors.pink, Colors.cyan,
      Colors.amber, Colors.indigo, Colors.brown, Colors.blueGrey,
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: widget.theme.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(widget.theme.cornerRadius)),
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isNew ? 'New Suggestion Entry' : 'Edit Suggestion Entry',
                        style: TextStyle(color: widget.theme.textPrimary, fontSize: widget.theme.headerFontSize, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: titleCtrl,
                        style: TextStyle(color: widget.theme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Title',
                          labelStyle: TextStyle(color: widget.theme.textMuted),
                          filled: true,
                          fillColor: widget.theme.panelBackground,
                          border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.zero),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descCtrl,
                        style: TextStyle(color: widget.theme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Short Description',
                          labelStyle: TextStyle(color: widget.theme.textMuted),
                          filled: true,
                          fillColor: widget.theme.panelBackground,
                          border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.zero),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: promptCtrl,
                        style: TextStyle(color: widget.theme.textPrimary),
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'AI Prompt',
                          labelStyle: TextStyle(color: widget.theme.textMuted),
                          filled: true,
                          fillColor: widget.theme.panelBackground,
                          border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.zero),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Action Button Color', style: TextStyle(color: widget.theme.textMuted)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: colors.map((c) => GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = c.value),
                          child: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: c, shape: BoxShape.circle,
                              border: Border.all(color: selectedColor == c.value ? widget.theme.textPrimary : Colors.transparent, width: 2),
                            ),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!isNew)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _entries.removeWhere((e) => e.id == entry.id);
                                });
                                _saveEntries();
                                Navigator.of(ctx).pop();
                              },
                              icon: Icon(Icons.delete, color: widget.theme.danger, size: 18),
                              label: Text('Delete', style: TextStyle(color: widget.theme.danger)),
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text('Cancel', style: TextStyle(color: widget.theme.textMuted)),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: widget.theme.accent),
                            onPressed: () {
                              if (titleCtrl.text.trim().isEmpty) return;
                              setState(() {
                                if (isNew) {
                                  _entries.add(SuggestionEntry(
                                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                                    title: titleCtrl.text.trim(),
                                    description: descCtrl.text.trim(),
                                    prompt: promptCtrl.text.trim(),
                                    color: selectedColor,
                                  ));
                                } else {
                                  entry.title = titleCtrl.text.trim();
                                  entry.description = descCtrl.text.trim();
                                  entry.prompt = promptCtrl.text.trim();
                                  entry.color = selectedColor;
                                }
                              });
                              _saveEntries();
                              Navigator.of(ctx).pop();
                            },
                            child: Text('Save', style: TextStyle(color: widget.theme.textPrimary, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }

  void showManageParametersDialog() {
    final compCtrl = TextEditingController(text: _complexities.join(', '));
    final catCtrl = TextEditingController(text: _categories.join(', '));
    final areaCtrl = TextEditingController(text: _areasOfInterest.join(', '));
    final commonPromptCtrl = TextEditingController(text: _commonPromptCtrl.text);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: widget.theme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(widget.theme.cornerRadius)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Manage Parameters', style: TextStyle(color: widget.theme.textPrimary, fontSize: widget.theme.headerFontSize, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Comma-separated lists of values:', style: TextStyle(color: widget.theme.textMuted)),
              const SizedBox(height: 16),
              TextField(
                controller: commonPromptCtrl,
                style: TextStyle(color: widget.theme.textPrimary),
                maxLines: 4,
                decoration: InputDecoration(labelText: 'System Instructions (Hidden from Users)', filled: true, fillColor: widget.theme.panelBackground, border: OutlineInputBorder(borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: compCtrl,
                style: TextStyle(color: widget.theme.textPrimary),
                decoration: InputDecoration(labelText: 'Complexities', filled: true, fillColor: widget.theme.panelBackground, border: OutlineInputBorder(borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: catCtrl,
                style: TextStyle(color: widget.theme.textPrimary),
                decoration: InputDecoration(labelText: 'Categories', filled: true, fillColor: widget.theme.panelBackground, border: OutlineInputBorder(borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: areaCtrl,
                style: TextStyle(color: widget.theme.textPrimary),
                decoration: InputDecoration(labelText: 'Areas of Interest', filled: true, fillColor: widget.theme.panelBackground, border: OutlineInputBorder(borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel', style: TextStyle(color: widget.theme.textMuted))),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: widget.theme.accent),
                    onPressed: () {
                      setState(() {
                        _complexities = compCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                        _categories = catCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                        _areasOfInterest = areaCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                        _commonPromptCtrl.text = commonPromptCtrl.text;
                        if (!_complexities.contains(_selectedGlobalComplexity)) _selectedGlobalComplexity = _complexities.isNotEmpty ? _complexities.first : null;
                        if (!_categories.contains(_selectedGlobalCategory)) _selectedGlobalCategory = _categories.isNotEmpty ? _categories.first : null;
                        if (!_areasOfInterest.contains(_selectedGlobalArea)) _selectedGlobalArea = _areasOfInterest.isNotEmpty ? _areasOfInterest.first : null;
                      });
                      _savePreferences();
                      Navigator.of(ctx).pop();
                    },
                    child: Text('Save', style: TextStyle(color: widget.theme.textPrimary)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(SuggestionEntry entry) {
    final entryColor = entry.color != null ? Color(entry.color!) : widget.theme.accent;
    bool isHovered = false;
    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: Tooltip(
            message: entry.description,
            child: InkWell(
              onTap: () => _dispatchPrompt(entry),
              borderRadius: BorderRadius.zero,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: entryColor,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: entryColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 20),
                    Text(
                      entry.title.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.theme.smallFontSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Opacity(
                      opacity: isHovered ? 1.0 : 0.0,
                      child: InkWell(
                        onTap: () => showEditDialog(entry),
                        child: const Icon(Icons.edit, color: Colors.white70, size: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Priority', style: TextStyle(color: widget.theme.textMuted, fontSize: widget.theme.smallFontSize)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _complexities.map((e) => ChoiceChip(
                showCheckmark: false,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              label: Text(e),
              selected: _selectedGlobalComplexity == e,
              onSelected: (sel) {
                if (sel) {
                  setState(() => _selectedGlobalComplexity = e);
                  _savePreferences();
                }
              },
              backgroundColor: widget.theme.panelBackground,
              selectedColor: widget.theme.accent.withValues(alpha: 0.3),
              labelStyle: TextStyle(color: _selectedGlobalComplexity == e ? widget.theme.accent : widget.theme.textPrimary),
              side: BorderSide(color: _selectedGlobalComplexity == e ? widget.theme.accent : Colors.transparent),
            )).toList(),
          ),
          const SizedBox(height: 16),
          Text('Type', style: TextStyle(color: widget.theme.textMuted, fontSize: widget.theme.smallFontSize)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _categories.map((e) => ChoiceChip(
                showCheckmark: false,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              label: Text(e),
              selected: _selectedGlobalCategory == e,
              onSelected: (sel) {
                if (sel) {
                  setState(() => _selectedGlobalCategory = e);
                  _savePreferences();
                }
              },
              backgroundColor: widget.theme.panelBackground,
              selectedColor: widget.theme.accent.withValues(alpha: 0.3),
              labelStyle: TextStyle(color: _selectedGlobalCategory == e ? widget.theme.accent : widget.theme.textPrimary),
              side: BorderSide(color: _selectedGlobalCategory == e ? widget.theme.accent : Colors.transparent),
            )).toList(),
          ),
          const SizedBox(height: 16),
          Text('Module', style: TextStyle(color: widget.theme.textMuted, fontSize: widget.theme.smallFontSize)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _areasOfInterest.map((e) => ChoiceChip(
                showCheckmark: false,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              label: Text(e),
              selected: _selectedGlobalArea == e,
              onSelected: (sel) {
                if (sel) {
                  setState(() => _selectedGlobalArea = e);
                  _savePreferences();
                }
              },
              backgroundColor: widget.theme.panelBackground,
              selectedColor: widget.theme.accent.withValues(alpha: 0.3),
              labelStyle: TextStyle(color: _selectedGlobalArea == e ? widget.theme.accent : widget.theme.textPrimary),
              side: BorderSide(color: _selectedGlobalArea == e ? widget.theme.accent : Colors.transparent),
            )).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hintCtrl,
            style: TextStyle(color: widget.theme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Hint / Steer Direction (Optional)',
              labelStyle: TextStyle(color: widget.theme.textMuted),
              filled: true,
              fillColor: widget.theme.panelBackground,
              border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.zero),
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: widget.theme.borderSubtle),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _entries.map((entry) => _buildActionCard(entry)).toList(),
          ),
        ],
      ),
    );
  }
}
