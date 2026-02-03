import 'package:flutter/material.dart';
import '../../models/game_room.dart';
import '../../services/hand_evaluator.dart';
import '../../services/user_preferences.dart';
import '../../services/bot_service.dart';
import 'game_utils.dart';

/// Build participant avatar for the players row (opponents and optionally current player)
/// Matches GameScreen's _buildParticipantAvatar visual style
class ParticipantAvatar extends StatelessWidget {
  final GamePlayer player;
  final GameRoom room;
  final bool isCurrentPlayer;
  final bool isTheirTurn;
  final double remainingSeconds;
  final bool showdownAnimationComplete;
  final VoidCallback? onTap;

  const ParticipantAvatar({
    super.key,
    required this.player,
    required this.room,
    this.isCurrentPlayer = false,
    this.isTheirTurn = false,
    this.remainingSeconds = 10.0,
    this.showdownAnimationComplete = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final botService = BotService();
    final hasFolded = player.hasFolded;
    final isShowdown = room.phase == 'showdown';
    final isWinner = room.winnerId == player.uid;
    final isLoser = isShowdown && showdownAnimationComplete && !isWinner && !hasFolded;
    final isBot = botService.isBot(player.uid);

    // Get hand evaluation for showdown
    EvaluatedHand? playerHand;
    if (isShowdown && player.cards.isNotEmpty && room.communityCards.length >= 3) {
      playerHand = HandEvaluator.evaluateBestHand(player.cards, room.communityCards);
    }

    // Display name - "You" for current player
    final displayName = isCurrentPlayer ? 'You' : player.displayName;

    final isDealer = room.players.isNotEmpty &&
        room.dealerIndex < room.players.length &&
        player.uid == room.players[room.dealerIndex].uid;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isLoser ? 0.5 : 1.0,
      child: Container(
        width: 68,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Winner glow ring
                if (isShowdown && showdownAnimationComplete && isWinner)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                // Timer ring as border (only show when it's their turn and game is active)
                if (isTheirTurn && room.status == 'playing' && room.phase != 'showdown')
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.linear,
                      tween: Tween<double>(
                        begin: remainingSeconds / room.turnTimeLimit,
                        end: remainingSeconds / room.turnTimeLimit,
                      ),
                      builder: (context, value, child) => CircularProgressIndicator(
                        value: value,
                        strokeWidth: 3,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          remainingSeconds <= 2 ? Colors.red : Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                // Winner border (solid when not showing timer)
                if (isShowdown && showdownAnimationComplete && isWinner && room.phase == 'showdown')
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 3),
                    ),
                  ),
                // Avatar circle with tap handler
                GestureDetector(
                  onTap: isCurrentPlayer ? null : onTap,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasFolded ? Colors.grey.shade800 : Colors.white.withValues(alpha: 0.1),
                      boxShadow: hasFolded
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        _getAvatar(player.displayName, isCurrentPlayer, isBot),
                        style: TextStyle(
                          fontSize: 20,
                          color: hasFolded ? Colors.grey : null,
                        ),
                      ),
                    ),
                  ),
                ),
                // Dealer badge
                if (isDealer)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('D',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                    ),
                  ),
                // Winner badge
                if (isShowdown && showdownAnimationComplete && isWinner)
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('WIN',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                  ),
                // Fold badge
                if (hasFolded && !isShowdown)
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.grey.shade600,
                          width: 1,
                        ),
                      ),
                      child: Text('FOLD',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Name - use displayName which is "You" for current player
            Text(
              displayName.length > 8 ? displayName.substring(0, 8) : displayName,
              style: TextStyle(
                color: hasFolded ? Colors.grey : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            // Chips amount
            Text(
              formatChips(player.chips),
              style: TextStyle(
                color: hasFolded ? Colors.grey : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            // Current bet underneath
            if (player.currentBet > 0)
              Text(
                formatChips(player.currentBet),
                style: TextStyle(
                  color: hasFolded ? Colors.grey.withValues(alpha: 0.6) : Colors.orange.shade400,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            // Show hole cards during showdown
            if (isShowdown && !hasFolded && player.cards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MiniCard(
                      card: player.cards[0],
                      isHighlighted: showdownAnimationComplete &&
                          isWinner &&
                          playerHand != null &&
                          playerHand.isCardInWinningHand(player.cards[0]),
                      isDimmed: isLoser,
                    ),
                    const SizedBox(width: 2),
                    if (player.cards.length > 1)
                      _MiniCard(
                        card: player.cards[1],
                        isHighlighted: showdownAnimationComplete &&
                            isWinner &&
                            playerHand != null &&
                            playerHand.isCardInWinningHand(player.cards[1]),
                        isDimmed: isLoser,
                      ),
                  ],
                ),
              ),
            // Show hand name during showdown
            if (isShowdown && showdownAnimationComplete && !hasFolded && playerHand != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  getShortHandName(playerHand.rank),
                  style: TextStyle(
                    color: isWinner ? const Color(0xFFFFD700) : Colors.white.withValues(alpha: 0.7),
                    fontSize: 9,
                    fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getAvatar(String name, bool isCurrentPlayer, bool isBot) {
    if (isCurrentPlayer) return UserPreferences.avatar;
    if (isBot) return getBotAvatar(name);
    return getAvatarForName(name);
  }
}

/// Mini card for showdown display on player avatars
class _MiniCard extends StatelessWidget {
  final PlayingCard card;
  final bool isHighlighted;
  final bool isDimmed;

  const _MiniCard({
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
