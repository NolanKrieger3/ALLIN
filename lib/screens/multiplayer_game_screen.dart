import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import '../models/game_room.dart';
import '../services/game_service.dart';
import '../services/hand_evaluator.dart';
import '../services/user_preferences.dart';
import '../widgets/mobile_wrapper.dart';

class MultiplayerGameScreen extends StatefulWidget {
  final String roomId;
  final bool autoStart;
  final int requiredPlayers;

  const MultiplayerGameScreen({
    super.key,
    required this.roomId,
    this.autoStart = false,
    this.requiredPlayers = 2,
  });

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> with TickerProviderStateMixin {
  final GameService _gameService = GameService();
  final TextEditingController _chatController = TextEditingController();
  bool _isLoading = false;
  bool _hasAutoStarted = false;
  bool _hasTriggeredNewHand = false;

  // Fold animation
  late AnimationController _foldAnimationController;
  late Animation<Offset> _foldSlideAnimation;
  late Animation<double> _foldOpacityAnimation;
  bool _isFolding = false;

  // Turn timer
  Timer? _turnTimer;
  double _remainingSeconds = 6.0;
  String? _lastTurnPlayerId;
  bool _hasAutoFolded = false;

  // Showdown animation
  bool _showdownAnimationComplete = false;
  String? _lastShowdownPhase;
  EvaluatedHand? _winningHand;

  // Bot handling
  bool _isBotActing = false;
  String? _lastBotTurnId;

  // Cache the stream to prevent flickering on rebuild
  late final Stream<GameRoom?> _roomStream;

  @override
  void initState() {
    super.initState();
    // Cache the stream once - prevents recreation on every build which causes flickering
    _roomStream = _gameService.watchRoom(widget.roomId);
    _foldAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _foldSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -2),
    ).animate(CurvedAnimation(
      parent: _foldAnimationController,
      curve: Curves.easeInBack,
    ));
    _foldOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _foldAnimationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    _foldAnimationController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  /// Start or update the turn timer based on room state
  void _updateTurnTimer(GameRoom room) {
    final currentTurnId = room.currentTurnPlayerId;
    final isMyTurn = currentTurnId == _gameService.currentUserId;
    final isHost = room.hostId == _gameService.currentUserId;
    final isBotTurn = currentTurnId != null && _gameService.isBot(currentTurnId);

    // Handle bot turns - host controls bot actions
    if (isBotTurn && isHost && currentTurnId != _lastBotTurnId && !_isBotActing) {
      _lastBotTurnId = currentTurnId;
      _triggerBotAction(room);
    }

    // Reset auto-fold flag when it's a new turn
    if (currentTurnId != _lastTurnPlayerId) {
      _hasAutoFolded = false;
      _lastTurnPlayerId = currentTurnId;

      // Calculate remaining time from turnStartTime
      if (room.turnStartTime != null && room.status == 'playing' && room.phase != 'showdown') {
        final elapsed = DateTime.now().millisecondsSinceEpoch - room.turnStartTime!;
        final elapsedSeconds = elapsed / 1000;
        _remainingSeconds = (room.turnTimeLimit - elapsedSeconds).clamp(0.0, room.turnTimeLimit.toDouble());

        // Cancel existing timer
        _turnTimer?.cancel();

        // Start new timer (100ms for smooth animation)
        _turnTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }

          setState(() {
            _remainingSeconds -= 0.1;
          });

          // Auto-fold when time runs out (only if it's my turn)
          if (_remainingSeconds <= 0 && isMyTurn && !_hasAutoFolded) {
            timer.cancel();
            _hasAutoFolded = true;
            _gameService.playerAction(widget.roomId, 'fold');
          }
        });
      }
    }
  }

  /// Trigger a bot action with some simple AI logic
  Future<void> _triggerBotAction(GameRoom room) async {
    if (_isBotActing) return;
    _isBotActing = true;

    // Variable delay to make bots feel more human (1-4 seconds)
    final delay = Random().nextInt(3000) + 1000; // 1 - 4 seconds
    await Future.delayed(Duration(milliseconds: delay));

    if (!mounted) {
      _isBotActing = false;
      return;
    }

    try {
      final currentTurnId = room.currentTurnPlayerId;
      if (currentTurnId == null || !_gameService.isBot(currentTurnId)) {
        _isBotActing = false;
        return;
      }

      // Find the bot player
      final bot = room.players.firstWhere(
        (p) => p.uid == currentTurnId,
        orElse: () => room.players.first,
      );

      // Simple bot AI
      final random = Random();
      final highestBet = room.currentBet;
      final botCurrentBet = bot.currentBet;
      final callAmount = highestBet - botCurrentBet;
      final canCheck = callAmount == 0;
      final potSize = room.pot;

      // Calculate action probabilities based on situation
      String action;
      int? raiseAmount;

      if (canCheck) {
        // Can check - 50% check, 35% raise, 15% fold (sometimes fold even when can check)
        final roll = random.nextDouble();
        if (roll < 0.50) {
          action = 'check';
        } else if (roll < 0.85) {
          action = 'raise';
          // More variety in raise amounts (0.5x to 3x pot)
          final raiseMultiplier = random.nextDouble() * 2.5 + 0.5;
          raiseAmount = (potSize * raiseMultiplier).toInt().clamp(room.bigBlind, bot.chips);
        } else {
          action = 'fold';
        }
      } else {
        // Must call or fold
        final potOdds = callAmount / (potSize + callAmount);
        final chipRatio = callAmount / bot.chips; // How much of stack is needed

        if (callAmount > bot.chips) {
          // All-in situation - 60% call (all-in), 40% fold (more conservative)
          action = random.nextDouble() < 0.60 ? 'call' : 'fold';
        } else if (chipRatio > 0.3) {
          // Large bet relative to stack - 25% call, 10% raise, 65% fold
          final roll = random.nextDouble();
          if (roll < 0.25) {
            action = 'call';
          } else if (roll < 0.35) {
            action = 'raise';
            raiseAmount = (callAmount * (random.nextDouble() * 1.5 + 1.5)).toInt().clamp(room.bigBlind, bot.chips);
          } else {
            action = 'fold';
          }
        } else if (potOdds > 0.4) {
          // Moderate pot odds - 35% call, 15% raise, 50% fold
          final roll = random.nextDouble();
          if (roll < 0.35) {
            action = 'call';
          } else if (roll < 0.50) {
            action = 'raise';
            raiseAmount = (potSize * (random.nextDouble() * 1.5 + 0.8)).toInt().clamp(room.bigBlind, bot.chips);
          } else {
            action = 'fold';
          }
        } else {
          // Good pot odds - 55% call, 30% raise, 15% fold
          final roll = random.nextDouble();
          if (roll < 0.55) {
            action = 'call';
          } else if (roll < 0.85) {
            action = 'raise';
            raiseAmount = (potSize * (random.nextDouble() * 2 + 0.8)).toInt().clamp(room.bigBlind, bot.chips);
          } else {
            action = 'fold';
          }
        }
      }

      // Execute the bot action
      await _gameService.botAction(widget.roomId, currentTurnId, action, raiseAmount: raiseAmount);
    } catch (e) {
      print('❌ Bot action error: $e');
    }

    _isBotActing = false;
  }

  /// Animate cards flying away then trigger fold action
  Future<void> _animateFold() async {
    if (_isFolding) return;
    setState(() => _isFolding = true);

    await _foldAnimationController.forward();
    await _gameService.playerAction(widget.roomId, 'fold');

    // Reset animation for next hand
    _foldAnimationController.reset();
    if (mounted) setState(() => _isFolding = false);
  }

  /// Start a new hand after the current one finishes
  Future<void> _triggerNewHand(GameRoom room) async {
    if (_hasTriggeredNewHand || _isLoading) return;
    final isHost = room.hostId == _gameService.currentUserId;
    if (!isHost) return;

    _hasTriggeredNewHand = true;

    // Wait 3 seconds to show the result
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    try {
      await _gameService.newHand(widget.roomId);
      _hasAutoStarted = false; // Reset so startGame can trigger again
      // Reset showdown animation state for new hand
      _showdownAnimationComplete = false;
      _lastShowdownPhase = null;
      _winningHand = null;
    } catch (e) {
      print('❌ Failed to start new hand: $e');
    }

    if (mounted) {
      _hasTriggeredNewHand = false;
    }
  }

  /// Handle showdown animation - triggered when phase becomes showdown
  void _handleShowdownAnimation(GameRoom room) {
    // Check if we just entered showdown
    if (room.phase == 'showdown' && _lastShowdownPhase != 'showdown') {
      _lastShowdownPhase = 'showdown';
      _showdownAnimationComplete = false;

      // Calculate the winning hand
      if (room.winnerId != null) {
        final winner = room.players.firstWhere(
          (p) => p.uid == room.winnerId,
          orElse: () => room.players.first,
        );
        if (winner.cards.isNotEmpty && room.communityCards.length >= 3) {
          _winningHand = HandEvaluator.evaluateBestHand(winner.cards, room.communityCards);
        }
      }

      // Start the animation delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() => _showdownAnimationComplete = true);
        }
      });
    } else if (room.phase != 'showdown') {
      _lastShowdownPhase = room.phase;
    }
  }

  /// Check if a card is part of the winning hand during showdown
  bool _isCardInWinningHand(PlayingCard card, GameRoom room) {
    if (!_showdownAnimationComplete || _winningHand == null) return false;
    return _winningHand!.isCardInWinningHand(card);
  }

  /// Attempt auto-start when conditions are met
  Future<void> _tryAutoStart(GameRoom room) async {
    if (_hasAutoStarted || _isLoading) return;

    final isHost = room.hostId == _gameService.currentUserId;
    final requiredPlayers = widget.requiredPlayers;

    // Case 1: Room doesn't have enough players yet - wait for more
    if (room.status == 'waiting' && room.players.length < requiredPlayers) {
      print('⏳ Waiting for more players (${room.players.length}/$requiredPlayers)...');
      return;
    }

    // Case 2: Room is in 'waiting' status with required players - HOST starts the game!
    if (room.status == 'waiting' && room.players.length >= requiredPlayers) {
      if (isHost) {
        _hasAutoStarted = true;
        setState(() => _isLoading = true);
        print('🎮 HOST starting game with ${room.players.length} players!');
        try {
          // Skip ready check for auto-matched games - players are auto-ready when joining
          await _gameService.startGame(widget.roomId, skipReadyCheck: true);
        } catch (e) {
          print('❌ Failed to start game: $e');
          _hasAutoStarted = false; // Allow retry
        }
        if (mounted) setState(() => _isLoading = false);
      } else {
        // Non-host: Just wait, the host will start the game
        print('⏳ Waiting for host to start game...');
      }
      return;
    }

    // Case 3: Room is 'playing' but in 'waiting_for_players' phase and has required players
    // This means enough players joined - start the real game
    if (room.status == 'playing' &&
        room.phase == 'waiting_for_players' &&
        room.players.length >= requiredPlayers &&
        isHost) {
      _hasAutoStarted = true;
      setState(() => _isLoading = true);
      print('🎮 Starting game from waiting_for_players phase!');
      try {
        await _gameService.startGameFromWaiting(widget.roomId);
      } catch (e) {
        print('❌ Failed to start from waiting: $e');
        _hasAutoStarted = false; // Allow retry
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileWrapper(
      child: StreamBuilder<GameRoom?>(
        stream: _roomStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }

          final room = snapshot.data;
          if (room == null) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Room not found',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to Lobby'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Auto-start the game immediately (skip waiting room)
          // Also handle when 2nd player joins a 'waiting_for_players' room
          if (room.status == 'waiting' ||
              (room.status == 'playing' && room.phase == 'waiting_for_players' && room.players.length >= 2)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _tryAutoStart(room);
            });
          }

          // Auto-start new hand after game finishes
          if (room.status == 'finished' && room.players.length >= 2) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _triggerNewHand(room);
            });
          }

          // Update turn timer
          if (room.status == 'playing' && room.phase != 'showdown') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateTurnTimer(room);
            });
          }

          // Always show the game table - no waiting room
          return _buildGameTable(room);
        },
      ),
    );
  }

  // ============================================================================
  // WAITING ROOM
  // ============================================================================

  Widget _buildWaitingRoom(GameRoom room) {
    final isHost = room.hostId == _gameService.currentUserId;
    final currentPlayer = room.players.firstWhere(
      (p) => p.uid == _gameService.currentUserId,
      orElse: () => room.players.first,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            await _gameService.leaveRoom(widget.roomId);
            if (mounted) Navigator.pop(context);
          },
        ),
        title: const Text(
          'GAME ROOM',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Room Code Card - Only show for private rooms
            if (room.isPrivate)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'ROOM CODE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          room.id.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(
                            Icons.copy,
                            color: Color(0xFFD4AF37),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: room.id));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Room code copied!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share this code with your friend',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

            // Waiting for players message for public games
            if (!room.isPrivate)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Waiting for players to join...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // Players List
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PLAYERS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 12),

            ...room.players.map((player) => _buildPlayerCard(player, room.hostId)),

            if (room.players.length < room.maxPlayers)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        Icons.person_add,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Waiting for player...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

            const Spacer(),

            // Ready / Start Button
            if (!isHost)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _gameService.toggleReady(widget.roomId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentPlayer.isReady ? Colors.grey : const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    currentPlayer.isReady ? 'CANCEL READY' : 'READY',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            if (isHost)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: room.canStart && !_isLoading
                      ? () async {
                          setState(() => _isLoading = true);
                          try {
                            await _gameService.startGame(widget.roomId);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                          setState(() => _isLoading = false);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          room.canStart ? 'START GAME' : 'WAITING FOR PLAYERS...',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard(GamePlayer player, String hostId) {
    final isMe = player.uid == _gameService.currentUserId;
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
                      '${player.chips} chips',
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

  // ============================================================================
  // EMOTE PANEL
  // ============================================================================

  void _showEmotePanel(BuildContext context) {
    final emotes = [
      {'emoji': '👍', 'label': 'GG'},
      {'emoji': '😎', 'label': 'Cool'},
      {'emoji': '🤣', 'label': 'LOL'},
      {'emoji': '😱', 'label': 'Shocked'},
      {'emoji': '🎉', 'label': 'Nice!'},
      {'emoji': '🃏', 'label': 'Bluff?'},
      {'emoji': '💀', 'label': 'RIP'},
      {'emoji': '🤔', 'label': 'Hmm'},
    ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Quick Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: emotes.map((emote) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _sendEmote(emote['emoji']!, emote['label']!);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            emote['emoji']!,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            emote['label']!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Text Chat Input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        maxLength: 50,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        onSubmitted: (text) {
                          if (text.trim().isNotEmpty) {
                            Navigator.pop(context);
                            _sendChatMessage(text.trim());
                            _chatController.clear();
                          }
                        },
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final text = _chatController.text.trim();
                        if (text.isNotEmpty) {
                          Navigator.pop(context);
                          _sendChatMessage(text);
                          _chatController.clear();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.send, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendChatMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💬', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      ),
    );
    // TODO: Send message to other players via Firebase
  }

  void _sendEmote(String emoji, String label) {
    // Display the emote on screen briefly
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
      ),
    );
    // TODO: Send emote to other players via Firebase
  }

  // ============================================================================
  // GAME TABLE
  // ============================================================================

  Widget _buildGameTable(GameRoom room) {
    final currentPlayer = room.players.firstWhere(
      (p) => p.uid == _gameService.currentUserId,
      orElse: () => room.players.first,
    );
    final opponents = room.players.where((p) => p.uid != _gameService.currentUserId).toList();
    final isMyTurn = room.currentTurnPlayerId == _gameService.currentUserId;
    final isHost = room.hostId == _gameService.currentUserId;
    final isWaitingForPlayers = room.phase == 'waiting_for_players';

    // Handle showdown animation
    _handleShowdownAnimation(room);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar - Back button and status
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      await _gameService.leaveRoom(widget.roomId);
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            // Players Row
            _buildPlayersRow(room, opponents, currentPlayer),

            const Spacer(flex: 2),

            // Community Cards with Pot
            _buildCommunityCardsMinimal(room),

            const Spacer(flex: 3),

            // Action Bar / Wait Message
            // Show fold animation if folding, otherwise check normal conditions
            if (_isFolding)
              _buildFoldingAnimation(currentPlayer, room)
            else if (isWaitingForPlayers || room.status != 'playing' || currentPlayer.hasFolded)
              _buildWaitMessage(room, currentPlayer)
            else if (isMyTurn)
              _buildSwipeablePlayerArea(currentPlayer, room)
            else
              _buildPlayerAreaWithCards(currentPlayer, room),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersRow(GameRoom room, List<GamePlayer> opponents, GamePlayer currentPlayer) {
    final isShowdown = room.phase == 'showdown';
    final isSitAndGo = room.gameType.contains('sitandgo');
    final totalPlayers = opponents.length + 1; // Include current player count

    // Include player in row when we have 6+ total players (like practice mode)
    final includePlayerInRow = isSitAndGo && totalPlayers > 5;

    // Build all participants when including player in row
    final allParticipants = <GamePlayer>[];
    if (includePlayerInRow) {
      // Find player's position in the original player order
      final myIndex = room.players.indexWhere((p) => p.uid == _gameService.currentUserId);
      // Rebuild the list in seat order with current player included
      for (final player in room.players) {
        allParticipants.add(player);
      }
    }

    final displayList = includePlayerInRow ? allParticipants : opponents;
    final shouldCenterActivePlayer = displayList.length >= 4 && isSitAndGo;
    const maxVisible = 5;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: isShowdown ? 170 : 110, // Match GameScreen heights
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // For Sit and Go with many participants, center on active player with sliding animation
          if (shouldCenterActivePlayer) {
            // Find the index of the current turn player in display list
            int activeIndex = displayList.indexWhere((p) => p.uid == room.currentTurnPlayerId);

            // If current turn player not found, find the next player who will act
            if (activeIndex == -1) {
              final allPlayers = room.players;
              final currentTurnIdx = allPlayers.indexWhere((p) => p.uid == room.currentTurnPlayerId);

              if (currentTurnIdx != -1) {
                // Find this player in display list
                activeIndex = displayList.indexWhere((p) => p.uid == allPlayers[currentTurnIdx].uid);
              }

              if (activeIndex == -1) {
                // Find the next non-folded player in turn order
                for (int i = 0; i < allPlayers.length; i++) {
                  final player = allPlayers[i];
                  if (!player.hasFolded) {
                    activeIndex = displayList.indexWhere((p) => p.uid == player.uid);
                    if (activeIndex != -1) break;
                  }
                }
              }

              // Fallback to middle if we still can't find one
              if (activeIndex == -1) {
                activeIndex = displayList.length ~/ 2;
              }
            }

            final totalParticipants = displayList.length;

            // Calculate the offset to center the active player
            // Active player should be at position 2 (middle of 5 visible slots: 0,1,2,3,4)
            const centerSlot = maxVisible ~/ 2; // = 2

            // Calculate where each participant should be positioned
            // The active player goes to centerSlot, others are relative to that
            final availableWidth = constraints.maxWidth;
            const avatarWidth = 80.0;
            const avatarMargin = 8.0;
            const slotWidth = avatarWidth + avatarMargin;
            final rowWidth = maxVisible * slotWidth;
            final rowStartX = (availableWidth - rowWidth) / 2;

            // Build visible slots with circular wrapping
            // E.g., if activeIndex=0 and total=7, show: 5, 6, 0, 1, 2
            final visibleIndices = <int>[];
            for (int slot = 0; slot < maxVisible; slot++) {
              final offset = slot - centerSlot; // -2, -1, 0, 1, 2
              final idx = (activeIndex + offset + totalParticipants) % totalParticipants;
              visibleIndices.add(idx);
            }

            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (int slot = 0; slot < visibleIndices.length; slot++)
                  Builder(
                    key: ValueKey(displayList[visibleIndices[slot]].uid),
                    builder: (context) {
                      final participantIndex = visibleIndices[slot];
                      final participant = displayList[participantIndex];
                      final isCurrentPlayer = participant.uid == _gameService.currentUserId;

                      // Calculate x position for this slot
                      final xPos = rowStartX + (slot * slotWidth);

                      return AnimatedPositioned(
                        key: ValueKey('pos_${participant.uid}'),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        left: xPos,
                        top: 0,
                        bottom: 0,
                        child: _buildParticipantAvatar(participant, room, isCurrentPlayer: isCurrentPlayer),
                      );
                    },
                  ),
              ],
            );
          }

          // Default behavior for smaller games - simple row
          final totalWidth = displayList.length * 88.0; // 80 width + 8 margin
          final needsScroll = totalWidth > constraints.maxWidth;

          final row = Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: displayList.map((player) {
              final isCurrentPlayer = player.uid == _gameService.currentUserId;
              return _buildParticipantAvatar(player, room, isCurrentPlayer: isCurrentPlayer);
            }).toList(),
          );

          if (needsScroll) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: row,
            );
          } else {
            return Center(child: row);
          }
        },
      ),
    );
  }

  /// Build participant avatar (handles both opponents and current player)
  /// Matches GameScreen's _buildParticipantAvatar visual style
  Widget _buildParticipantAvatar(GamePlayer player, GameRoom room, {bool isCurrentPlayer = false}) {
    final isTheirTurn = room.currentTurnPlayerId == player.uid;
    final hasFolded = player.hasFolded;
    final isShowdown = room.phase == 'showdown';
    final isWinner = room.winnerId == player.uid;
    final isLoser = isShowdown && _showdownAnimationComplete && !isWinner && !hasFolded;
    final isBot = _gameService.isBot(player.uid);

    // Calculate this player's hand for card highlighting
    EvaluatedHand? playerHand;
    if (isShowdown && player.cards.isNotEmpty && room.communityCards.length >= 3) {
      playerHand = HandEvaluator.evaluateBestHand(player.cards, room.communityCards);
    }

    // Bot-specific avatars (matching practice mode)
    String getBotAvatar(String name) {
      final botAvatars = ['🤖', '🦊', '🐸', '🦁', '🐼', '🐮', '🐧', '🐯', '🐻', '🦄', '🐵', '🐺'];
      // Extract number from bot name or use hash
      final numMatch = RegExp(r'\d+').firstMatch(name);
      if (numMatch != null) {
        final num = int.tryParse(numMatch.group(0)!) ?? 0;
        return botAvatars[num % botAvatars.length];
      }
      // Use name hash for consistent avatar
      return botAvatars[name.hashCode.abs() % botAvatars.length];
    }

    // Avatar emojis - use user's selected avatar for current player, bot avatars for bots, letter-based for others
    String getAvatar(String name) {
      if (isCurrentPlayer) return UserPreferences.avatar;
      if (isBot) return getBotAvatar(name);
      if (name.isEmpty) return '👤';
      final firstChar = name[0].toLowerCase();
      final avatars = {
        'a': '👨',
        'b': '🧔',
        'c': '👩',
        'd': '🧑',
        'e': '👴',
        'f': '👵',
        'g': '🦊',
        'h': '🦄',
        'i': '🐸',
        'j': '🐵',
        'k': '🐻',
        'l': '🐼',
        'm': '🦁',
        'n': '🐯',
        'o': '🐨',
        'p': '🐷',
        'q': '🐰',
        'r': '🐶',
        's': '🐱',
        't': '🐲',
        'u': '🦋',
        'v': '🦅',
        'w': '🐺',
        'x': '🦈',
        'y': '🦜',
        'z': '🦎',
      };
      return avatars[firstChar] ?? '👤';
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
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Winner glow ring
                if (isShowdown && _showdownAnimationComplete && isWinner)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.6),
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
                        begin: _remainingSeconds / room.turnTimeLimit,
                        end: _remainingSeconds / room.turnTimeLimit,
                      ),
                      builder: (context, value, child) => CircularProgressIndicator(
                        value: value,
                        strokeWidth: 3,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _remainingSeconds <= 2 ? Colors.red : Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                // Winner border (solid when not showing timer)
                if (isShowdown && _showdownAnimationComplete && isWinner && room.phase == 'showdown')
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF6366F1), width: 3),
                    ),
                  ),
                Container(
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
                      getAvatar(player.displayName),
                      style: TextStyle(
                        fontSize: 20,
                        color: hasFolded ? Colors.grey : null,
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
                if (isShowdown && _showdownAnimationComplete && isWinner)
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
            // Chips on one line
            Text(
              player.currentBet > 0
                  ? '${_formatChips(player.chips)} (${_formatChips(player.currentBet)})'
                  : _formatChips(player.chips),
              style: TextStyle(
                color: hasFolded ? Colors.grey : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Show hole cards during showdown
            if (isShowdown && !hasFolded && player.cards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMiniCard(
                      player.cards[0],
                      isHighlighted: _showdownAnimationComplete &&
                          isWinner &&
                          playerHand != null &&
                          playerHand.isCardInWinningHand(player.cards[0]),
                      isDimmed: isLoser,
                    ),
                    const SizedBox(width: 2),
                    if (player.cards.length > 1)
                      _buildMiniCard(
                        player.cards[1],
                        isHighlighted: _showdownAnimationComplete &&
                            isWinner &&
                            playerHand != null &&
                            playerHand.isCardInWinningHand(player.cards[1]),
                        isDimmed: isLoser,
                      ),
                  ],
                ),
              ),
            // Show hand name during showdown
            if (isShowdown && _showdownAnimationComplete && !hasFolded && playerHand != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _getShortHandName(playerHand.rank),
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

  /// Build a mini card for showdown display on player avatars
  Widget _buildMiniCard(PlayingCard card, {bool isHighlighted = false, bool isDimmed = false}) {
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
              color: const Color(0xFFFFD700).withValues(alpha: 0.8),
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
        border: isHighlighted ? Border.all(color: const Color(0xFFFFD700), width: 1.5) : null,
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

  String _formatChips(int chips) {
    if (chips >= 1000000) return '${(chips / 1000000).toStringAsFixed(1)}M';
    if (chips >= 1000) return '${(chips / 1000).toStringAsFixed(chips % 1000 == 0 ? 0 : 1)}k';
    return chips.toString();
  }

  Widget _buildCommunityCardsMinimal(GameRoom room) {
    final isShowdown = room.phase == 'showdown' && _showdownAnimationComplete;

    return Column(
      children: [
        // Community Cards Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: () {
                  final card = i < room.communityCards.length ? room.communityCards[i] : null;
                  final isHighlighted = isShowdown && card != null && _isCardInWinningHand(card, room);
                  final isDimmed = isShowdown && card != null && !_isCardInWinningHand(card, room);
                  return _buildMinimalCard(
                    card,
                    isEmpty: i >= room.communityCards.length,
                    isHighlighted: isHighlighted,
                    isDimmed: isDimmed,
                  );
                }(),
              ),
            const SizedBox(width: 16),
            // Pot amount
            Text(
              room.pot.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMinimalCard(PlayingCard? card,
      {bool isEmpty = false, bool isHoleCard = false, bool isHighlighted = false, bool isDimmed = false}) {
    // Use larger size for hole cards (player's cards at bottom)
    final width = isHoleCard ? 70.0 : 56.0;
    final height = isHoleCard ? 98.0 : 78.0;

    if (isEmpty || card == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 2),
        ),
        child: Center(
          child: Icon(
            Icons.casino_outlined,
            color: Colors.white.withValues(alpha: 0.1),
            size: 24,
          ),
        ),
      );
    }

    final isRed = card.suit == '♥' || card.suit == '♦';

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
              card.rank,
              style: TextStyle(
                color: isDimmed ? Colors.grey : (isRed ? Colors.red.shade700 : Colors.black),
                fontSize: isHoleCard ? 24 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              card.suit,
              style: TextStyle(
                color: isDimmed ? Colors.grey : (isRed ? Colors.red.shade700 : Colors.black),
                fontSize: isHoleCard ? 26 : 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBack({double width = 56, double height = 78}) {
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

  Widget _buildWaitMessage(GameRoom room, GamePlayer player) {
    String message = 'Wait for the next hand';
    bool showSpinner = false;

    if (room.status == 'waiting' && room.players.length == 1) {
      message = 'Finding opponent...';
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
              // Player's cards (face down when waiting)
              Row(
                children: [
                  _buildCardBack(width: 70, height: 98),
                  Transform.translate(
                    offset: const Offset(-20, 0),
                    child: _buildCardBack(width: 70, height: 98),
                  ),
                ],
              ),
              const Spacer(),
              // Player info
              _buildPlayerInfoMinimal(player, room: room),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeablePlayerArea(GamePlayer player, GameRoom room) {
    final callAmount = room.currentBet - player.currentBet;
    final canCheck = room.currentBet == player.currentBet;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Action buttons row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _gameService.playerAction(widget.roomId, canCheck ? 'check' : 'call'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(
                        canCheck ? 'Check' : 'Call ${_formatChips(callAmount)}',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showRaiseDialog(room, player),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Raise',
                        style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
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
              // Swipeable cards with fold animation
              GestureDetector(
                onVerticalDragEnd: (details) {
                  // Swipe up to fold
                  if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
                    _animateFold();
                  }
                },
                child: SlideTransition(
                  position: _foldSlideAnimation,
                  child: FadeTransition(
                    opacity: _foldOpacityAnimation,
                    child: Column(
                      children: [
                        Text(
                          '↑ Swipe to fold',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (player.cards.isNotEmpty) _buildMinimalCard(player.cards[0], isHoleCard: true),
                            if (player.cards.length > 1)
                              Transform.translate(
                                offset: const Offset(-20, 0),
                                child: _buildMinimalCard(player.cards[1], isHoleCard: true),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Player info
              _buildPlayerInfoMinimal(player, room: room),
            ],
          ),
        ],
      ),
    );
  }

  /// Widget shown during fold animation - cards flying away
  Widget _buildFoldingAnimation(GamePlayer player, GameRoom room) {
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
              border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
            ),
            child: const Center(
              child: Text(
                'Folding...',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Animated cards flying away
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SlideTransition(
                position: _foldSlideAnimation,
                child: FadeTransition(
                  opacity: _foldOpacityAnimation,
                  child: Row(
                    children: [
                      if (player.cards.isNotEmpty) _buildMinimalCard(player.cards[0], isHoleCard: true),
                      if (player.cards.length > 1)
                        Transform.translate(
                          offset: const Offset(-20, 0),
                          child: _buildMinimalCard(player.cards[1], isHoleCard: true),
                        ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _buildPlayerInfoMinimal(player, room: room),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerAreaWithCards(GamePlayer player, GameRoom room) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Waiting indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                'Waiting for opponent...',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Cards and player info
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Player's cards with overlapping layout
              Row(
                children: [
                  if (player.cards.isNotEmpty) _buildMinimalCard(player.cards[0], isHoleCard: true),
                  if (player.cards.length > 1)
                    Transform.translate(
                      offset: const Offset(-20, 0),
                      child: _buildMinimalCard(player.cards[1], isHoleCard: true),
                    ),
                ],
              ),
              const Spacer(),
              _buildPlayerInfoMinimal(player, room: room),
            ],
          ),
        ],
      ),
    );
  }

  /// Build player avatar for bottom right - matches GameScreen's _buildPlayerAvatar
  Widget _buildPlayerInfoMinimal(GamePlayer player, {GameRoom? room}) {
    // Use the user's selected avatar for current player
    final playerAvatar = UserPreferences.avatar;

    final isMyTurn = room != null && room.currentTurnPlayerId == player.uid;
    final isDealer = room != null &&
        room.players.isNotEmpty &&
        room.dealerIndex < room.players.length &&
        player.uid == room.players[room.dealerIndex].uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: isMyTurn ? const Color(0xFFD4AF37) : const Color(0xFF3B82F6),
                  width: 3,
                ),
              ),
              child: Center(
                child: Text(playerAvatar, style: const TextStyle(fontSize: 40)),
              ),
            ),
            // Dealer badge
            if (isDealer)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('D',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _formatChips(player.chips),
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _getShortHandName(HandRank rank) {
    switch (rank) {
      case HandRank.royalFlush:
        return 'Royal!';
      case HandRank.straightFlush:
        return 'Str Flush';
      case HandRank.fourOfAKind:
        return 'Quads';
      case HandRank.fullHouse:
        return 'Full House';
      case HandRank.flush:
        return 'Flush';
      case HandRank.straight:
        return 'Straight';
      case HandRank.threeOfAKind:
        return 'Trips';
      case HandRank.twoPair:
        return 'Two Pair';
      case HandRank.onePair:
        return 'Pair';
      case HandRank.highCard:
        return 'High Card';
    }
  }

  void _showRaiseDialog(GameRoom room, GamePlayer player) {
    // Minimum raise is current bet + last raise amount (or big blind if first raise)
    final calculatedMinRaise = room.currentBet + (room.lastRaiseAmount > 0 ? room.lastRaiseAmount : room.bigBlind);
    final maxRaise = player.chips + player.currentBet;

    // Ensure minRaise doesn't exceed maxRaise (player might not have enough chips)
    final minRaise = calculatedMinRaise > maxRaise ? maxRaise : calculatedMinRaise;
    var raiseAmount = minRaise;

    // Don't show slider if player can only go all-in
    if (minRaise >= maxRaise) {
      // Just go all-in directly
      _gameService.playerAction(widget.roomId, 'raise', raiseAmount: maxRaise);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Raise Amount',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: raiseAmount.toDouble(),
                min: minRaise.toDouble(),
                max: maxRaise.toDouble(),
                activeColor: const Color(0xFFD4AF37),
                onChanged: (value) {
                  setDialogState(() => raiseAmount = value.toInt());
                },
              ),
              Text(
                'Raise to: $raiseAmount',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Min: $minRaise | Max: $maxRaise (All-in)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _gameService.playerAction(
                  widget.roomId,
                  'raise',
                  raiseAmount: raiseAmount,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
              ),
              child: const Text('Raise', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverArea(GameRoom room, bool isHost) {
    final didWin = room.winnerId == _gameService.currentUserId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: didWin ? const Color(0xFF4CAF50).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: didWin ? const Color(0xFF4CAF50).withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            didWin ? Icons.emoji_events : Icons.sentiment_dissatisfied,
            color: didWin ? const Color(0xFFD4AF37) : Colors.red,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            didWin ? 'YOU WIN!' : 'YOU LOSE',
            style: TextStyle(
              color: didWin ? const Color(0xFF4CAF50) : Colors.red,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (room.winningHandName != null) ...[
            const SizedBox(height: 8),
            Text(
              'Winning Hand: ${room.winningHandName}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (isHost)
            ElevatedButton(
              onPressed: () => _gameService.newHand(widget.roomId),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'PLAY AGAIN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (!isHost)
            Text(
              'Waiting for host to start next hand...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(PlayingCard? card, {bool faceDown = false, bool large = false}) {
    final width = large ? 60.0 : 40.0;
    final height = large ? 84.0 : 56.0;

    if (card == null && !faceDown) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      );
    }

    if (faceDown || card == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24),
        ),
        child: Center(
          child: Icon(
            Icons.style,
            color: Colors.white.withValues(alpha: 0.3),
            size: large ? 24 : 16,
          ),
        ),
      );
    }

    final isRed = card.suit == '♥' || card.suit == '♦';

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            card.rank,
            style: TextStyle(
              color: isRed ? Colors.red : Colors.black,
              fontSize: large ? 18 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            card.suit,
            style: TextStyle(
              color: isRed ? Colors.red : Colors.black,
              fontSize: large ? 20 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIndicator(String action) {
    Color bgColor;
    Color textColor = Colors.white;

    switch (action) {
      case 'FOLD':
        bgColor = Colors.red.shade700;
        break;
      case 'CHECK':
        bgColor = Colors.blue.shade600;
        break;
      case 'CALL':
        bgColor = Colors.green.shade600;
        break;
      case 'RAISE':
        bgColor = Colors.orange.shade700;
        break;
      case 'ALL-IN':
        bgColor = Colors.purple.shade700;
        break;
      default:
        bgColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Text(
        action,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
