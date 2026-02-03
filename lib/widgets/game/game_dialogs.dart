import 'package:flutter/material.dart';
import '../../models/game_room.dart';
import '../../services/game_service.dart';
import '../../services/friends_service.dart';
import 'game_utils.dart';

/// Leave confirmation dialog
class LeaveConfirmationDialog extends StatelessWidget {
  final GameRoom room;
  final GameService gameService;
  final String roomId;

  const LeaveConfirmationDialog({
    super.key,
    required this.room,
    required this.gameService,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    final isGameInProgress = room.status == 'playing';

    // Guard against empty player list
    if (room.players.isEmpty) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        content: const Text('Error: No players in room', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    final myPlayer = room.players.firstWhere(
      (p) => p.uid == gameService.currentUserId,
      orElse: () => room.players.first,
    );
    final myChips = myPlayer.chips;

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            isGameInProgress ? Icons.warning_amber : Icons.exit_to_app,
            color: isGameInProgress ? const Color(0xFFEF4444) : Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text(
            'Leave Game?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isGameInProgress) ...[
            const Text(
              'You will forfeit all your chips!',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.casino, color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${formatChips(myChips)} chips at stake',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ] else
            Text(
              'Are you sure you want to leave?',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'STAY',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context); // Close dialog
            await gameService.leaveRoom(roomId);
            if (context.mounted) Navigator.pop(context); // Leave screen
          },
          child: Text(
            isGameInProgress ? 'FORFEIT & LEAVE' : 'LEAVE',
            style: const TextStyle(
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Player profile dialog
class PlayerProfileDialog extends StatelessWidget {
  final GamePlayer player;
  final bool isBot;

  const PlayerProfileDialog({
    super.key,
    required this.player,
    required this.isBot,
  });

  @override
  Widget build(BuildContext context) {
    final friendsService = FriendsService();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Player avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Player name
            Text(
              player.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Chips
            Text(
              '${formatChips(player.chips)} chips',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            if (isBot) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'BOT',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Actions
            if (!isBot) ...[
              GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  final success = await friendsService.sendFriendRequest(player.uid);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Friend request sent!' : 'Failed to send request'),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Add Friend',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Raise dialog
class RaiseDialog extends StatefulWidget {
  final GameRoom room;
  final GamePlayer player;
  final GameService gameService;
  final String roomId;
  final VoidCallback onActionStart;
  final VoidCallback onActionEnd;

  const RaiseDialog({
    super.key,
    required this.room,
    required this.player,
    required this.gameService,
    required this.roomId,
    required this.onActionStart,
    required this.onActionEnd,
  });

  @override
  State<RaiseDialog> createState() => _RaiseDialogState();
}

class _RaiseDialogState extends State<RaiseDialog> {
  late int raiseAmount;
  late int minRaise;
  late int maxRaise;

  @override
  void initState() {
    super.initState();
    // Minimum raise is current bet + last raise amount (or big blind if first raise)
    final calculatedMinRaise =
        widget.room.currentBet + (widget.room.lastRaiseAmount > 0 ? widget.room.lastRaiseAmount : widget.room.bigBlind);
    maxRaise = widget.player.chips + widget.player.currentBet;

    // Ensure minRaise doesn't exceed maxRaise
    minRaise = calculatedMinRaise > maxRaise ? maxRaise : calculatedMinRaise;
    raiseAmount = minRaise;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Amount display
              Text(
                formatChips(raiseAmount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'RAISE TO',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 32),
              // Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                  thumbColor: Colors.white,
                  overlayColor: Colors.white.withValues(alpha: 0.1),
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                ),
                child: Slider(
                  value: raiseAmount.toDouble().clamp(minRaise.toDouble(), maxRaise.toDouble()),
                  min: minRaise.toDouble(),
                  max: maxRaise.toDouble(),
                  onChanged: (value) {
                    setState(() => raiseAmount = value.toInt());
                  },
                ),
              ),
              // Min/Max labels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatChips(minRaise),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      formatChips(maxRaise),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Quick bet buttons
              Row(
                children: [
                  Expanded(
                    child: _buildQuickBetButton('½ Pot', () {
                      setState(() {
                        raiseAmount =
                            ((widget.room.pot / 2) + widget.room.currentBet).toInt().clamp(minRaise, maxRaise);
                      });
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickBetButton('Pot', () {
                      setState(() {
                        raiseAmount = (widget.room.pot + widget.room.currentBet).clamp(minRaise, maxRaise);
                      });
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickBetButton('All In', () {
                      setState(() {
                        raiseAmount = maxRaise;
                      });
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await Future.delayed(const Duration(milliseconds: 100));
                        widget.onActionStart();
                        await Future.delayed(const Duration(milliseconds: 150));
                        await widget.gameService.playerAction(
                          widget.roomId,
                          'raise',
                          raiseAmount: raiseAmount,
                        );
                        await Future.delayed(const Duration(milliseconds: 200));
                        widget.onActionEnd();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'Raise',
                            style: TextStyle(
                              color: Color(0xFF0A0A0A),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickBetButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
