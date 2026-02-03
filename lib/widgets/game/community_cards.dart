import 'package:flutter/material.dart';
import '../../models/game_room.dart';
import '../../services/hand_evaluator.dart';
import 'playing_card_widgets.dart';

/// Community cards display with pot
class CommunityCards extends StatelessWidget {
  final GameRoom room;
  final bool showdownAnimationComplete;
  final EvaluatedHand? winningHand;

  const CommunityCards({
    super.key,
    required this.room,
    required this.showdownAnimationComplete,
    this.winningHand,
  });

  bool _isCardInWinningHand(PlayingCard card) {
    if (!showdownAnimationComplete || winningHand == null) return false;
    return winningHand!.isCardInWinningHand(card);
  }

  @override
  Widget build(BuildContext context) {
    final isShowdown = room.phase == 'showdown' && showdownAnimationComplete;

    return Column(
      children: [
        // Winner text that fades in during showdown
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: isShowdown && room.winningHandName != null ? 1.0 : 0.0,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              room.winningHandName ?? '',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        // Community Cards Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 5; i++)
                () {
                  final card = i < room.communityCards.length ? room.communityCards[i] : null;
                  final isHighlighted = isShowdown && card != null && _isCardInWinningHand(card);
                  final isDimmed = isShowdown && card != null && !_isCardInWinningHand(card);
                  if (card == null) {
                    return const EmptyCardSlot();
                  }
                  return PokerCard(
                    card: card,
                    isHighlighted: isHighlighted,
                    isDimmed: isDimmed,
                  );
                }(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Pot amount below cards
        Text(
          room.pot.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
