import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../models/game_room.dart';
import '../../services/user_preferences.dart';
import 'game_utils.dart';
import 'timer_progress_painter.dart';

/// Large card for player's hole cards in bottom area
class LargeHoleCard extends StatelessWidget {
  final PlayingCard card;
  final bool isHighlighted;
  final bool isDimmed;

  const LargeHoleCard({
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

/// Large card back for hidden cards
class LargeCardBack extends StatelessWidget {
  final double width;
  final double height;

  const LargeCardBack({
    super.key,
    this.width = 90,
    this.height = 126,
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

/// Build player's large cards for bottom area
class PlayerCardsLarge extends StatelessWidget {
  final GamePlayer player;

  const PlayerCardsLarge({
    super.key,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    const cardWidth = 90.0;
    const cardHeight = 126.0;
    const overlap = 15.0;
    const totalWidth = cardWidth * 2 - overlap;

    // If player has no cards yet or phase is waiting, show card backs
    if (player.cards.isEmpty || player.cards.length < 2) {
      return SizedBox(
        width: totalWidth,
        height: cardHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const LargeCardBack(width: cardWidth, height: cardHeight),
            Positioned(
              left: cardWidth - overlap,
              child: const LargeCardBack(width: cardWidth, height: cardHeight),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: totalWidth,
      height: cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          LargeHoleCard(card: player.cards[0]),
          Positioned(
            left: cardWidth - overlap,
            child: LargeHoleCard(card: player.cards[1]),
          ),
        ],
      ),
    );
  }
}

/// Player avatar box for bottom right with stats panel
class PlayerAvatarLarge extends StatefulWidget {
  final GamePlayer player;
  final GameRoom? room;
  final double remainingSeconds;

  const PlayerAvatarLarge({
    super.key,
    required this.player,
    this.room,
    this.remainingSeconds = 10.0,
  });

  @override
  State<PlayerAvatarLarge> createState() => _PlayerAvatarLargeState();
}

class _PlayerAvatarLargeState extends State<PlayerAvatarLarge> {
  bool _showStatsPanel = false;
  double _statsPanelOffset = 0.0;

  @override
  Widget build(BuildContext context) {
    final playerAvatar = UserPreferences.avatar;
    final isMyTurn = widget.room != null &&
        widget.room!.currentTurnPlayerId == widget.player.uid &&
        widget.room!.phase != 'showdown';
    final isDealer = widget.room != null &&
        widget.room!.players.isNotEmpty &&
        widget.room!.dealerIndex < widget.room!.players.length &&
        widget.player.uid == widget.room!.players[widget.room!.dealerIndex].uid;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          // Drag up to reveal stats (negative delta.dy = upward drag)
          _statsPanelOffset -= details.delta.dy;
          // Clamp to only allow upward drag to reveal stats
          _statsPanelOffset = _statsPanelOffset.clamp(0.0, 126.0);
        });
      },
      onVerticalDragEnd: (details) {
        setState(() {
          // If dragged up enough, snap to show stats
          if (_statsPanelOffset > 50) {
            _statsPanelOffset = 126;
            _showStatsPanel = true;
          } else {
            _statsPanelOffset = 0;
            _showStatsPanel = false;
          }
        });
      },
      onTap: () {
        setState(() {
          _showStatsPanel = !_showStatsPanel;
          _statsPanelOffset = _showStatsPanel ? 126 : 0;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Timer border progress around the box
              if (isMyTurn && widget.room!.status == 'playing' && widget.room!.phase != 'showdown')
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.linear,
                  tween: Tween<double>(
                    begin: widget.remainingSeconds / widget.room!.turnTimeLimit,
                    end: widget.remainingSeconds / widget.room!.turnTimeLimit,
                  ),
                  builder: (context, value, child) => CustomPaint(
                    size: const Size(100, 126),
                    painter: RoundedRectProgressPainter(
                      progress: value,
                      color: widget.remainingSeconds <= 2 ? Colors.red : Colors.white,
                      strokeWidth: 4,
                    ),
                  ),
                ),
              // Fixed container that stays in place
              Container(
                width: 100,
                height: 126, // Fixed height
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMyTurn ? Colors.white.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.1),
                    width: isMyTurn ? 2 : 1,
                  ),
                  boxShadow: isMyTurn
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
                            blurRadius: 16,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      // Scrollable content inside
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        top: -_statsPanelOffset,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            // Avatar section (scrolls up)
                            Container(
                              height: 126,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(playerAvatar, style: const TextStyle(fontSize: 40)),
                                  const SizedBox(height: 8),
                                  Text(
                                    formatChips(widget.player.chips),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Stats section (revealed when scrolled up)
                            Container(
                              height: 126,
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _StatRow(label: 'Chips', value: formatChips(widget.player.chips)),
                                  _StatRow(label: 'Bet', value: formatChips(widget.player.currentBet)),
                                  _StatRow(label: 'Total', value: formatChips(widget.player.totalContributed)),
                                  if (widget.player.lastAction != null)
                                    _StatRow(label: 'Action', value: widget.player.lastAction!),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Dealer badge
              if (isDealer)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('D',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Swipeable player area with action buttons and fold gesture
class SwipeablePlayerArea extends StatelessWidget {
  final GamePlayer player;
  final GameRoom room;
  final bool isProcessingAction;
  final double dragOffset;
  final bool isFolding;
  final Animation<Offset> foldSlideAnimation;
  final Animation<double> foldOpacityAnimation;
  final VoidCallback onCheckCall;
  final VoidCallback onRaise;
  final Function(double) onDragUpdate;
  final Function(DragEndDetails) onDragEnd;
  final double remainingSeconds;

  const SwipeablePlayerArea({
    super.key,
    required this.player,
    required this.room,
    required this.isProcessingAction,
    required this.dragOffset,
    required this.isFolding,
    required this.foldSlideAnimation,
    required this.foldOpacityAnimation,
    required this.onCheckCall,
    required this.onRaise,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.remainingSeconds = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    final callAmount = room.currentBet - player.currentBet;
    final canCheck = room.currentBet == player.currentBet;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          // Action buttons row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: isProcessingAction ? null : onCheckCall,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isProcessingAction ? Colors.grey.withValues(alpha: 0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(
                        canCheck ? 'Check' : 'Call ${formatChips(callAmount)}',
                        style: TextStyle(
                          color: isProcessingAction ? Colors.white.withValues(alpha: 0.5) : Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: isProcessingAction ? null : onRaise,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isProcessingAction ? Colors.grey.withValues(alpha: 0.5) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Raise',
                        style: TextStyle(
                          color: isProcessingAction ? Colors.black.withValues(alpha: 0.5) : Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Cards area with swipe to fold
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Swipeable cards with fold animation - fixed width
              SizedBox(
                width: 165, // Fixed width for 2 overlapping large cards
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: GestureDetector(
                    supportedDevices: const {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                    onVerticalDragUpdate: isProcessingAction ? null : (details) => onDragUpdate(details.delta.dy),
                    onVerticalDragEnd: onDragEnd,
                    child: isFolding
                        ? SlideTransition(
                            position: foldSlideAnimation,
                            child: FadeTransition(
                              opacity: foldOpacityAnimation,
                              child: PlayerCardsLarge(player: player),
                            ),
                          )
                        : Transform.translate(
                            offset: Offset(0, dragOffset * 0.5),
                            child: Opacity(
                              opacity: (1.0 + dragOffset / 200).clamp(0.3, 1.0),
                              child: PlayerCardsLarge(player: player),
                            ),
                          ),
                  ),
                ),
              ),
              const Spacer(),
              PlayerAvatarLarge(player: player, room: room, remainingSeconds: remainingSeconds),
            ],
          ),
        ],
      ),
    );
  }
}

/// Player area when waiting (not their turn)
class PlayerAreaWithCards extends StatelessWidget {
  final GamePlayer player;
  final GameRoom room;
  final bool showdownAnimationComplete;
  final String Function(List<PlayingCard>, List<PlayingCard>) getCurrentHandStrength;
  final double remainingSeconds;

  const PlayerAreaWithCards({
    super.key,
    required this.player,
    required this.room,
    required this.showdownAnimationComplete,
    required this.getCurrentHandStrength,
    this.remainingSeconds = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    final isShowdown = room.phase == 'showdown';
    final isPlayerWinner = isShowdown && room.winnerId == player.uid;
    final isPlayerLoser = isShowdown && showdownAnimationComplete && room.winnerId != player.uid && !player.hasFolded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Waiting indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isShowdown && showdownAnimationComplete && isPlayerWinner
                  ? const Color(0xFFFFD700).withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isShowdown && showdownAnimationComplete && isPlayerWinner
                    ? const Color(0xFFFFD700).withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: Center(
              child: Text(
                isShowdown && showdownAnimationComplete && isPlayerWinner ? 'You win!' : 'Waiting for opponent...',
                style: TextStyle(
                  color: isShowdown && showdownAnimationComplete && isPlayerWinner
                      ? const Color(0xFFFFD700)
                      : Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                  fontWeight: isPlayerWinner ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Cards and player info with large cards
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isPlayerLoser ? 0.5 : 1.0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Player's large cards with overlapping layout - fixed width
                SizedBox(
                  width: 165, // Fixed width for 2 overlapping large cards (90 + 75)
                  child: PlayerCardsLarge(player: player),
                ),
                const Spacer(),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Hand strength indicator
                    if (player.cards.length >= 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          getCurrentHandStrength(player.cards, room.communityCards),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    PlayerAvatarLarge(player: player, room: room, remainingSeconds: remainingSeconds),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wait message widget (shown when folded or waiting for game)
class WaitMessageWidget extends StatelessWidget {
  final GameRoom room;
  final GamePlayer player;
  final List<PlayingCard> foldedCards;
  final double remainingSeconds;

  const WaitMessageWidget({
    super.key,
    required this.room,
    required this.player,
    required this.foldedCards,
    this.remainingSeconds = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    String message = 'Wait for the next hand';
    bool showSpinner = false;

    // Priority 1: Not enough players to start - show waiting message
    if (room.status == 'waiting' && room.players.length < 2) {
      message = 'Waiting for opponent...';
      showSpinner = true;
    } else if (room.status == 'waiting') {
      // Waiting status but have 2+ players - game should start soon
      message = 'Starting game...';
      showSpinner = true;
    } else if (room.phase == 'waiting_for_players') {
      message = 'Waiting for players...';
      showSpinner = true;
    } else if (player.hasFolded) {
      message = 'You folded';
    } else if (room.status == 'finished') {
      message = room.winnerId == player.uid ? 'You won!' : 'Hand complete';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Message bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showSpinner) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Bottom area: cards and player info
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Player's cards - fixed width to prevent shifting
              SizedBox(
                width: 120, // Fixed width for 2 overlapping cards
                height: 98,
                child: player.hasFolded && foldedCards.isNotEmpty
                    ? Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _GhostCard(card: foldedCards[0]),
                          if (foldedCards.length > 1)
                            Positioned(
                              left: 50,
                              child: _GhostCard(card: foldedCards[1]),
                            ),
                        ],
                      )
                    : Stack(
                        clipBehavior: Clip.none,
                        children: const [
                          LargeCardBack(width: 70, height: 98),
                          Positioned(
                            left: 50,
                            child: LargeCardBack(width: 70, height: 98),
                          ),
                        ],
                      ),
              ),
              const Spacer(),
              // Player info
              PlayerAvatarLarge(player: player, room: room, remainingSeconds: remainingSeconds),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ghost card for showing folded cards
class _GhostCard extends StatelessWidget {
  final PlayingCard card;

  const _GhostCard({required this.card});

  @override
  Widget build(BuildContext context) {
    final isRed = card.suit == '♥' || card.suit == '♦';

    return Opacity(
      opacity: 0.3,
      child: Container(
        width: 70,
        height: 98,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade500, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.rank,
              style: TextStyle(
                color: isRed ? Colors.red.shade300 : Colors.grey.shade600,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              card.suit,
              style: TextStyle(
                color: isRed ? Colors.red.shade300 : Colors.grey.shade600,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
