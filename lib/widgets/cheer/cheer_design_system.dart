import 'package:flutter/material.dart';

/// Defines core intent categories for cheers
enum CheerIntent {
  comfort(Icons.favorite_border, Colors.pink),
  celebrate(Icons.celebration_outlined, Colors.orange),
  encourage(Icons.star_border, Colors.amber),
  thank(Icons.volunteer_activism_outlined, Colors.teal),
  hope(Icons.wb_sunny_outlined, Colors.yellow),
  friendship(Icons.group_outlined, Colors.purple),
  strength(Icons.fitness_center, Colors.deepOrange),
  justBecause(Icons.card_giftcard, Colors.blue);

  final IconData icon;
  final Color color;
  const CheerIntent(this.icon, this.color);
}

/// 1. Cheer Category Chip
/// Used in the Send Wizard to select an intent.
class CheerCategoryChip extends StatelessWidget {
  final CheerIntent intent;
  final bool isSelected;
  final VoidCallback onTap;

  const CheerCategoryChip({
    super.key,
    required this.intent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? intent.color.withValues(alpha: 0.15) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? intent.color : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: intent.color.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(intent.icon, color: isSelected ? intent.color : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(
              intent.name.toUpperCase(),
              style: TextStyle(
                color: isSelected ? intent.color : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 1.1,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2. Inbox Card
/// Used to display a received cheer in the Inbox list.
class CheerInboxCard extends StatelessWidget {
  final String senderName;
  final String? senderAvatarUrl;
  final String timeAgo;
  final CheerIntent intent;
  final String trackTitle;
  final String? personalNote;
  final bool isUnread;

  const CheerInboxCard({
    super.key,
    required this.senderName,
    this.senderAvatarUrl,
    required this.timeAgo,
    required this.intent,
    required this.trackTitle,
    this.personalNote,
    this.isUnread = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnread ? intent.color.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: intent.color.withValues(alpha: 0.1),
                child: Icon(Icons.person, color: intent.color, size: 20), // Mock avatar
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(senderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(timeAgo, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              if (isUnread)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: intent.color, shape: BoxShape.circle),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.music_note, color: Colors.grey.withValues(alpha: 0.8), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(trackTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
          if (personalNote != null && personalNote!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '"$personalNote"',
              style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white70, fontSize: 14, height: 1.4),
            ),
          ]
        ],
      ),
    );
  }
}

/// 3. Preview Card
/// Represents a large preview of the cheer contents before sending.
class CheerPreviewCard extends StatelessWidget {
  final CheerIntent intent;
  final String trackInfo;
  final String personalNote;
  final String recipientName;

  const CheerPreviewCard({
    super.key,
    required this.intent,
    required this.trackInfo,
    required this.personalNote,
    required this.recipientName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: intent.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: intent.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(intent.icon, color: intent.color, size: 48),
          const SizedBox(height: 16),
          Text(
            intent.name.toUpperCase(),
            style: TextStyle(color: intent.color, fontWeight: FontWeight.w900, letterSpacing: 2.0),
          ),
          const SizedBox(height: 24),
          const Text('To:', style: TextStyle(color: Colors.grey, fontSize: 12)),
          Text(recipientName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Text(
            '"$personalNote"',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic, height: 1.3),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_circle_fill, size: 24),
                const SizedBox(width: 8),
                Text(trackInfo, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

/// 4. Score Badge
/// Reusable UI representation of a user's total Cheer or Impact score.
class CheerScoreBadge extends StatelessWidget {
  final int score;
  final Color baseColor;

  const CheerScoreBadge({
    super.key,
    required this.score,
    this.baseColor = Colors.orangeAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: baseColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, color: baseColor, size: 16),
          const SizedBox(width: 4),
          Text(
            score.toString(),
            style: TextStyle(color: baseColor, fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// 5. Leaderboard Row
/// Ranked row showing user standings within the session or globally.
class CheerLeaderboardRow extends StatelessWidget {
  final int rank;
  final String name;
  final int score;
  final bool isCurrentUser;

  const CheerLeaderboardRow({
    super.key,
    required this.rank,
    required this.name,
    required this.score,
    this.isCurrentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPodium = rank <= 3;
    final Color rankColor = rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey.shade300 : (rank == 3 ? Colors.brown.shade300 : Colors.grey));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.purpleAccent.withValues(alpha: 0.1) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isCurrentUser ? Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontWeight: isPodium ? FontWeight.w900 : FontWeight.bold,
                color: isPodium ? rankColor : Colors.grey,
                fontSize: isPodium ? 18 : 14,
              ),
            ),
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            child: Icon(Icons.person, color: isPodium ? rankColor : Colors.white70, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                color: isCurrentUser ? Colors.purpleAccent.shade100 : Colors.white,
              ),
            ),
          ),
          CheerScoreBadge(score: score, baseColor: isPodium ? rankColor : Colors.orangeAccent),
        ],
      ),
    );
  }
}
