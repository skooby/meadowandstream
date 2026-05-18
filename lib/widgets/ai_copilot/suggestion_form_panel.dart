import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_copilot_theme.dart';

class SuggestionFormPanel extends StatefulWidget {
  final AiCopilotTheme theme;
  final void Function(String moduleName, String payload) onDispatch;

  const SuggestionFormPanel({
    super.key,
    this.theme = const AiCopilotTheme(),
    required this.onDispatch,
  });

  @override
  SuggestionFormPanelState createState() => SuggestionFormPanelState();
}

class SuggestionFormPanelState extends State<SuggestionFormPanel> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _promptCtrl = TextEditingController();
  
  List<String> _areasOfInterest = ['Flow Editor', 'Now Playing UI', 'Settings', 'General'];
  String? _selectedArea;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _areasOfInterest = prefs.getStringList('ve_suggestion_form_areas') ?? ['Flow Editor', 'Now Playing UI', 'Settings', 'General'];
        _selectedArea = prefs.getString('ve_suggestion_form_sel_area') ?? (_areasOfInterest.isNotEmpty ? _areasOfInterest.first : null);
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('ve_suggestion_form_areas', _areasOfInterest);
    if (_selectedArea != null) {
      await prefs.setString('ve_suggestion_form_sel_area', _selectedArea!);
    }
  }

  void _dispatchSuggestion() {
    if (_titleCtrl.text.trim().isEmpty || _promptCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please provide a Title and Suggestion Details.'),
        duration: Duration(seconds: 2),
      ));
      return;
    }

    final moduleName = _selectedArea ?? 'General';
    final payload = """
[Title]: \${_titleCtrl.text.trim()}
[Area]: \$moduleName

[Suggestion Details]:
\${_promptCtrl.text.trim()}
""";

    widget.onDispatch(moduleName, payload);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Suggestion Dispatched!'),
        duration: Duration(seconds: 2),
      ));
      _titleCtrl.clear();
      _promptCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Module / Area', style: TextStyle(color: widget.theme.textMuted, fontSize: widget.theme.smallFontSize)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _areasOfInterest.map((e) => ChoiceChip(
              showCheckmark: false,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              label: Text(e),
              selected: _selectedArea == e,
              onSelected: (sel) {
                if (sel) {
                  setState(() => _selectedArea = e);
                  _savePreferences();
                }
              },
              backgroundColor: widget.theme.panelBackground,
              selectedColor: widget.theme.accent.withValues(alpha: 0.3),
              labelStyle: TextStyle(color: _selectedArea == e ? widget.theme.accent : widget.theme.textPrimary),
              side: BorderSide(color: _selectedArea == e ? widget.theme.accent : Colors.transparent),
            )).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            style: TextStyle(color: widget.theme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Short Title',
              labelStyle: TextStyle(color: widget.theme.textMuted),
              filled: true,
              fillColor: widget.theme.panelBackground,
              border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.zero),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptCtrl,
            style: TextStyle(color: widget.theme.textPrimary),
            maxLines: 8,
            decoration: InputDecoration(
              labelText: 'Detailed Suggestion / Hint',
              labelStyle: TextStyle(color: widget.theme.textMuted),
              filled: true,
              fillColor: widget.theme.panelBackground,
              border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.zero),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.theme.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _dispatchSuggestion,
            child: Text('Submit Suggestion', style: TextStyle(color: widget.theme.textPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
