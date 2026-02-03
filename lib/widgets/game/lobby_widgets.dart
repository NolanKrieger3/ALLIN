import 'package:flutter/material.dart';
import '../../models/game_room.dart';
import 'game_utils.dart';

/// Lobby player card shown in waiting room
class LobbyPlayerCard extends StatelessWidget {
  final GamePlayer player;
  final String hostId;
  final String currentUserId;

  const LobbyPlayerCard({
    super.key,
    required this.player,
    required this.hostId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = player.uid == currentUserId;
    final isHost = player.uid == hostId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFD4AF37).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? const Color(0xFFD4AF37).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      player.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isMe)
                      const Text(
                        ' (You)',
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (isHost)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'HOST',
                          style: TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (isHost) const SizedBox(width: 8),
                    Text(
                      '${formatChips(player.chips)} chips',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (player.isReady)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'READY',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Folding animation widget
class FoldingAnimationWidget extends StatelessWidget {
  final GamePlayer player;
  final GameRoom room;
  final Animation<Offset> slideAnimation;
  final Animation<double> opacityAnimation;
  final Widget cardsWidget;
  final Widget avatarWidget;

  const FoldingAnimationWidget({
    super.key,
    required this.player,
    required this.room,
    required this.slideAnimation,
    required this.opacityAnimation,
    required this.cardsWidget,
    required this.avatarWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // "Folding..." message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                'Folding...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Cards flying away animation
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 165,
                child: SlideTransition(
                  position: slideAnimation,
                  child: FadeTransition(
                    opacity: opacityAnimation,
                    child: cardsWidget,
                  ),
                ),
              ),
              const Spacer(),
              avatarWidget,
            ],
          ),
        ],
      ),
    );
  }
}
