import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/player_controller.dart';
import '../../widgets/cheer/cheer_design_system.dart';

class SendCheerWizard extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> payload)? onComplete;

  const SendCheerWizard({super.key, this.onComplete});

  @override
  State<SendCheerWizard> createState() => _SendCheerWizardState();
}

class _SendCheerWizardState extends State<SendCheerWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Wizard State
  String? _selectedContent; // e.g. track title
  CheerIntent? _selectedIntent;
  String _personalNote = '';
  String? _selectedRecipient;
  
  final TextEditingController _noteController = TextEditingController();

  void _nextStep() {
    if (_currentStep < 4) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _submitCheer();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submitCheer() async {
    // Show success dialog natively
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 64),
            const SizedBox(height: 16),
            const Text('Cheer Sent!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('A little light goes a long way.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close wizard
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Return to Music'),
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        title: Text('Step ${_currentStep + 1} of 5', style: const TextStyle(fontSize: 14, color: Colors.grey)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: (_currentStep + 1) / 5.0,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
            ),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Prevent manual swipe to control flow
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: [
                  _buildContentStep(),
                  _buildIntentStep(),
                  _buildNoteStep(),
                  _buildRecipientStep(),
                  _buildPreviewStep(),
                ],
              ),
            ),
            
            // Bottom Action Bar
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _prevStep,
                    child: Text(_currentStep == 0 ? 'Cancel' : 'Back', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: _canProceed() ? _nextStep : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text(
                      _currentStep == 4 ? 'Send Cheer' : 'Continue',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  bool _canProceed() {
    if (_currentStep == 0) return _selectedContent != null;
    if (_currentStep == 1) return _selectedIntent != null;
    if (_currentStep == 2) return true; // Note is optional
    if (_currentStep == 3) return _selectedRecipient != null;
    return true;
  }

  Widget _buildContentStep() {
    final currentItem = context.read<PlayerController>().currentItem;
    final trackTitle = currentItem?.title ?? 'No active track';
    
    // Automatically select the active track if not selected
    if (_selectedContent == null && currentItem != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedContent = trackTitle);
      });
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What inspired you?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Select the music or lyric that moves you.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 32),
          
          GestureDetector(
            onTap: () => setState(() => _selectedContent = trackTitle),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _selectedContent == trackTitle ? Colors.purpleAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _selectedContent == trackTitle ? Colors.purpleAccent : Colors.transparent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.white),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current Track', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(trackTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (_selectedContent == trackTitle) const Icon(Icons.check_circle, color: Colors.purpleAccent),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildIntentStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose the intent', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('How do you want them to feel?', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 16,
            children: CheerIntent.values.map((intent) {
              return CheerCategoryChip(
                intent: intent,
                isSelected: _selectedIntent == intent,
                onTap: () => setState(() => _selectedIntent = intent),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add a personal note', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('A short message makes a huge difference. (Optional)', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 32),
          TextField(
            controller: _noteController,
            onChanged: (val) => setState(() => _personalNote = val),
            maxLength: 240,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: "E.g. This made me think of you...",
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickInsert('You\'ve got this!'),
              _buildQuickInsert('Proud of you.'),
              _buildQuickInsert('Hope this lifts your day.'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildQuickInsert(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      onPressed: () {
        setState(() {
          _noteController.text = text;
          _personalNote = text;
        });
      },
    );
  }

  Widget _buildRecipientStep() {
    final mockContacts = ['Sarah Jensen', 'Alex Mercer', 'Team Alpha'];
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Who is this for?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Select an in-app friend or prepare an external link.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 32),
          
          const Text('Recent Contacts', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 16),
          ...mockContacts.map((name) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: Colors.purpleAccent.withValues(alpha: 0.2), child: Text(name[0])),
            title: Text(name),
            trailing: _selectedRecipient == name ? const Icon(Icons.check_circle, color: Colors.purpleAccent) : null,
            onTap: () => setState(() => _selectedRecipient = name),
          )),
          
          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.share, color: Colors.white)),
            title: const Text('Share Externally'),
            subtitle: const Text('Generate a secure link to send via SMS or WhatsApp.'),
            trailing: _selectedRecipient == 'External Share' ? const Icon(Icons.check_circle, color: Colors.purpleAccent) : null,
            onTap: () => setState(() => _selectedRecipient = 'External Share'),
          )
        ],
      ),
    );
  }

  Widget _buildPreviewStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('Preview', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Looks great. Ready to send?', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 48),
          if (_selectedIntent != null && _selectedContent != null && _selectedRecipient != null)
            CheerPreviewCard(
              intent: _selectedIntent!,
              trackInfo: _selectedContent!,
              personalNote: _personalNote.isEmpty ? 'Just sending some warm thoughts.' : _personalNote,
              recipientName: _selectedRecipient!,
            ),
        ],
      ),
    );
  }
}
