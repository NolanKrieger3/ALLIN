import 'package:flutter/material.dart';
import '../../models/game_room.dart';

/// Build a mini card for showdown display on player avatars
class MiniCard extends StatelessWidget {
  final PlayingCard card;
  final bool isHighlighted;
  final bool isDimmed;

  const MiniCard({
    super.key,
    required this.card,
    this.isHighlighted = false,
    this.isDimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    const width = 28.0;
    const height = 38.0;
    final isRed = card.suit == '♥' || card.suit == '♦';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDimmed ? Colors.grey.shade300 : Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          if (isHighlighted) ...[
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.6),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ] else
            BoxShadow(
              color: Colors.black.withValues(alpha: isDimmed ? 0.1 : 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
        border: isHighlighted ? Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5) : null,
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isDimmed ? 0.5 : 1.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.rank,
              style: TextStyle(
                color: isDimmed ? Colors.grey : (isRed ? Colors.red.shade700 : Colors.black),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              card.suit,
              style: TextStyle(
                color: isDimmed ? Colors.grey : (isRed ? Colors.red.shade700 : Colors.black),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Community card or hole card widget
class PokerCard extends StatelessWidget {
  final PlayingCard? card;
  final bool isEmpty;
  final bool isHoleCard;
  final bool isHighlighted;
  final bool isDimmed;
  final bool isGhost;

  const PokerCard({
    super.key,
    this.card,
    this.isEmpty = false,
    this.isHoleCard = false,
    this.isHighlighted = false,
    this.isDimmed = false,
    this.isGhost = false,
  });

  @override
  Widget build(BuildContext context) {
    // Match game_screen.dart sizes: 58x82 for community cards, 70x98 for hole cards
    final width = isHoleCard ? 70.0 : 58.0;
    final height = isHoleCard ? 98.0 : 82.0;

    if (isEmpty || card == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 2),
        ),
      );
    }

    final isRed = card!.suit == '♥' || card!.suit == '♦';

    // Ghost card style for folded cards
    if (isGhost) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card!.rank,
              style: TextStyle(
                color: (isRed ? Colors.red.shade300 : Colors.white).withValues(alpha: 0.4),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              card!.suit,
              style: TextStyle(
                color: (isRed ? Colors.red.shade300 : Colors.white).withValues(alpha: 0.4),
                fontSize: 26,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDimmed ? Colors.grey.shade300 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          if (isHighlighted) ...[
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.8),
              blurRadius: 12,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ] else
            BoxShadow(
              color: Colors.black.withValues(alpha: isDimmed ? 0.1 : 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
        border: isHighlighted ? Border.all(color: const Color(0xFFFFD700), width: 2) : null,
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isDimmed ? 0.5 : 1.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card!.rank,
              style: TextStyle(
                color: isDimmed ? Colors.grey : (isRed ? Colors.red.shade700 : Colors.black),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              card!.suit,
              style: TextStyle(
                color: isDimmed ? Colors.grey : (isRed ? Colors.red.shade700 : Colors.black),
                fontSize: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Large card for player's hole cards at bottom of screen
class LargePokerCard extends StatelessWidget {
  final PlayingCard card;
  final bool isHighlighted;
  final bool isDimmed;

  const LargePokerCard({
    super.key,
    required this.card,
    this.isHighlighted = false,
    this.isDimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    const width = 90.0;
    const height = 126.0;
    final isRed = card.suit == '♥' || card.suit == '♦';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDimmed ? Colors.grey.shade300 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (isHighlighted) ...[
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.6),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ] else
            BoxShadow(
              color: Colors.black.withValues(alpha: isDimmed ? 0.1 : 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
        border: isHighlighted ? Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2) : null,
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isDimmed ? 0.5 : 1.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.rank,
              style: TextStyle(
                color: isDimmed ? Colors.grey : (isRed ? Colors.red.shade700 : Colors.black),
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              card.suit,
              style: TextStyle(
                color: isDimmed ? Colors.grey : (isRed ? Colors.red.shade700 : Colors.black),
                fontSize: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card back for unrevealed cards
class CardBack extends StatelessWidget {
  final double width;
  final double height;

  const CardBack({
    super.key,
    this.width = 56,
    this.height = 78,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE57373), Color(0xFFEF5350)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Icon(
          Icons.radio_button_checked,
          color: Colors.white.withValues(alpha: 0.6),
          size: 28,
        ),
      ),
    );
  }
}

/// Empty card slot
class EmptyCardSlot extends StatelessWidget {
  final double width;
  final double height;

  const EmptyCardSlot({
    super.key,
    this.width = 58,
    this.height = 82,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 2),
      ),
    );
  }
}
