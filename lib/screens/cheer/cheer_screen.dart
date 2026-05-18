import 'package:flutter/material.dart';
import '../../engine/ui_inspector/element_registry.dart';
import 'send_cheer_wizard.dart';

class CheerScreen extends StatelessWidget {
  const CheerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ActiveScreenScope(
      screenName: 'Cheer',
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text('Cheer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: 0.5)),
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(30),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Send encouragement through music',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          children: [
            // Top Area: Summary Badges
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSummaryChip(context, Icons.local_fire_department, 'Cheer Score', '4.2k', Colors.orangeAccent),
                  const SizedBox(width: 12),
                  _buildSummaryChip(context, Icons.mark_email_unread_outlined, 'Inbox', '3 New', Colors.purpleAccent),
                  const SizedBox(width: 12),
                  _buildSummaryChip(context, Icons.emoji_events_outlined, 'Rank', '#12', Colors.amber),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Middle Area: Primary CTA
            _buildPrimaryCtaCard(context),
            
            const SizedBox(height: 24),
            
            // Middle Area: Secondary Cards Grid
            Row(
              children: [
                Expanded(child: _buildSecondaryCard(context, Icons.inbox_outlined, 'Inbox', '3 Unread', Colors.purple)),
                const SizedBox(width: 16),
                Expanded(child: _buildSecondaryCard(context, Icons.leaderboard_outlined, 'Leaderboard', 'You are #12', Colors.blue)),
              ],
            ),
            const SizedBox(height: 16),
            _buildSecondaryCard(context, Icons.history, 'History', 'Review sent Cheers', Colors.teal, isFullWidth: true),
            
            const SizedBox(height: 48),
            
            // Lower Area: Suggested Actions
            const Padding(
              padding: EdgeInsets.only(left: 4.0, bottom: 16.0),
              child: Text(
                'Suggestions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            _buildSuggestionAction(context, 'Send comfort to someone', Icons.favorite_border),
            _buildSuggestionAction(context, 'Celebrate someone today', Icons.celebration_outlined),
            _buildSuggestionAction(context, 'Thank someone', Icons.volunteer_activism_outlined),
            _buildSuggestionAction(context, 'Share a song that lifted you', Icons.music_note_outlined),
            
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip(BuildContext context, IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w600)),
              Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPrimaryCtaCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SendCheerWizard()));
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purpleAccent.shade400, Colors.deepPurpleAccent.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.purpleAccent.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Send Cheer', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('Brighten someone\'s day right now.', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryCard(BuildContext context, IconData icon, String title, String subtitle, Color color, {bool isFullWidth = false}) {
    return GestureDetector(
      onTap: () {
        // Route to specific section
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            if (isFullWidth) Icon(Icons.chevron_right, color: Colors.grey.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionAction(BuildContext context, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          // Open Send Cheer flow with preset intent
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.purpleAccent, size: 20),
              const SizedBox(width: 16),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
