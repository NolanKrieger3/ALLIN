import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import 'dart:math';
import '../models/game_room.dart';
import '../services/game_service.dart';
import '../services/bot_service.dart';
import '../services/hand_evaluator.dart';
import '../services/user_preferences.dart';
import '../services/friends_service.dart';
import '../widgets/mobile_wrapper.dart';
import '../widgets/game/game_widgets.dart';

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

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final GameService _gameService = GameService();
  final BotService _botService = BotService();
  final TextEditingController _chatController = TextEditingController();
  bool _isLoading = false;
  bool _hasAutoStarted = false;
  bool _hasTriggeredNewHand = false;

  // Heartbeat timer for presence detection
  Timer? _heartbeatTimer;

  // Fold animation
  late AnimationController _foldAnimationController;
  late Animation<Offset> _foldSlideAnimation;
  late Animation<double> _foldOpacityAnimation;
  bool _isFolding = false;
  double _dragOffset = 0.0; // Track drag distance for swipe-to-fold
  List<PlayingCard> _foldedCards = []; // Store cards when folded to show ghost outline

  // Stats panel
  bool _showStatsPanel = false;
  double _statsPanelOffset = 0.0;

  // Turn timer
  Timer? _turnTimer;
  double _remainingSeconds = 10.0;
  String? _lastTurnPlayerId;
  bool _hasAutoFolded = false;
  bool _timerStarted = false;
  GameRoom? _currentRoom; // Store latest room state for timer checks

  // Action debouncing
  bool _isProcessingAction = false;
  DateTime? _lastActionTime;

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
    // Register for app lifecycle events
    WidgetsBinding.instance.addObserver(this);

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

    // Start heartbeat to show we're active (every 5 seconds)
    _startHeartbeat();
  }

  @override
  void dispose() {
    // Stop observing app lifecycle
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _turnTimer?.cancel();
    _foldAnimationController.dispose();
    _chatController.dispose();
    // Leave room when disposed
    _gameService.leaveRoom(widget.roomId);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.hidden) {
      // App is going to background or closing - leave the room immediately
      _gameService.leaveRoom(widget.roomId);
    } else if (state == AppLifecycleState.resumed) {
      // App is back - restart heartbeat
      _startHeartbeat();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Send heartbeat immediately
    _gameService.sendHeartbeat(widget.roomId);
    // Then every 3 seconds (reduced from 5s for faster presence detection)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _gameService.sendHeartbeat(widget.roomId);
        // Check for inactive players every heartbeat (any player can trigger this now)
        _gameService.removeInactivePlayers(widget.roomId);
      }
    });
  }

  /// Start or update the turn timer based on room state
  void _updateTurnTimer(GameRoom room) {
    // CRITICAL: Store latest room state so timer can check fresh data
    _currentRoom = room;

    final currentTurnId = room.currentTurnPlayerId;
    final isHost = room.hostId == _gameService.currentUserId;
    final isBotTurn = currentTurnId != null && _botService.isBot(currentTurnId);
    final isMyTurn = currentTurnId == _gameService.currentUserId;

    // Handle bot turns - host controls bot actions
    if (isBotTurn && isHost && currentTurnId != _lastBotTurnId && !_isBotActing) {
      _lastBotTurnId = currentTurnId;
      _triggerBotAction(room);
    }

    // Reset auto-fold flag and timer when it's a new turn
    if (currentTurnId != _lastTurnPlayerId) {
      _hasAutoFolded = false;
      _lastTurnPlayerId = currentTurnId;
      _timerStarted = false;

      // Cancel existing timer immediately to prevent it from firing for wrong player
      _turnTimer?.cancel();
      _turnTimer = null;

      // CRITICAL FIX: Reset to FULL turn time for new turns
      // Don't calculate elapsed - client polling delay causes premature timeouts
      _remainingSeconds = room.turnTimeLimit.toDouble();

      print('🔄 NEW TURN: Player ${currentTurnId?.substring(0, 8)}, Full time: ${room.turnTimeLimit}s');
    }

    // CRITICAL: Only run timer when it's MY turn
    // Stop timer if it's not my turn anymore
    if (!isMyTurn && _turnTimer != null) {
      _turnTimer?.cancel();
      _turnTimer = null;
      _timerStarted = false;
      return;
    }

    // Start timer only once per turn AND only if it's my turn
    if (!_timerStarted &&
        isMyTurn &&
        room.turnStartTime != null &&
        room.status == 'playing' &&
        room.phase != 'showdown') {
      _timerStarted = true;

      // Start new timer (100ms for smooth animation)
      _turnTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        // CRITICAL FIX: Check FRESH room state, not stale captured variable
        // Use _currentRoom which is updated every 500ms by StreamBuilder
        final freshRoom = _currentRoom;
        if (freshRoom == null) {
          timer.cancel();
          return;
        }

        final currentlyMyTurn = freshRoom.currentTurnPlayerId == _gameService.currentUserId;

        // Stop timer immediately if it's no longer my turn
        if (!currentlyMyTurn) {
          timer.cancel();
          _turnTimer = null;
          _timerStarted = false;
          return;
        }

        setState(() {
          _remainingSeconds -= 0.1;
        });

        // Auto-fold when time runs out (ONLY if it's CURRENTLY my turn, not stale check)
        if (_remainingSeconds <= 0 && currentlyMyTurn && !_hasAutoFolded && freshRoom.status == 'playing') {
          timer.cancel();
          _turnTimer = null;
          _timerStarted = false;
          _hasAutoFolded = true;
          print('⏰ AUTO-FOLD: Time expired for ${_gameService.currentUserId}');
          _gameService.playerAction(widget.roomId, 'fold');
        }
      });
    }

    // Stop timer if phase changes to showdown
    if (room.phase == 'showdown' && _turnTimer != null) {
      _turnTimer?.cancel();
      _turnTimer = null;
      _timerStarted = false;
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
      if (currentTurnId == null || !_botService.isBot(currentTurnId)) {
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

  /// Show leave confirmation dialog
  void _showLeaveConfirmation(GameRoom room) {
    final isGameInProgress = room.status == 'playing';
    final myPlayer = room.players.firstWhere(
      (p) => p.uid == _gameService.currentUserId,
      orElse: () => room.players.first,
    );
    final myChips = myPlayer.chips;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                      '${_formatChips(myChips)} chips at stake',
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
              await _gameService.leaveRoom(widget.roomId);
              if (mounted) Navigator.pop(context); // Leave screen
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
      ),
    );
  }

  /// Animate cards flying away then trigger fold action
  Future<void> _animateFold(List<PlayingCard> cards) async {
    if (_isFolding) return;

    // Save the cards before folding so we can show ghost outline
    setState(() {
      _isFolding = true;
      _foldedCards = List.from(cards);
    });

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
      _foldedCards = []; // Clear folded cards for new hand
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

    // IMPORTANT: Once game is 'playing', we don't need requiredPlayers anymore!
    // Players can leave mid-game and the game continues with remaining players.
    // Only check requiredPlayers when room is still in 'waiting' status.

    // Case 1: Room is waiting and doesn't have enough players yet
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

    // Case 3: Room is 'playing' but in 'waiting_for_players' phase
    // Only need 2+ players to continue, not the original requiredPlayers
    if (room.status == 'playing' && room.phase == 'waiting_for_players' && room.players.length >= 2 && isHost) {
      _hasAutoStarted = true;
      setState(() => _isLoading = true);
      print('🎮 Starting game from waiting_for_players phase with ${room.players.length} players!');
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

          // Check for tournament victory (only 1 player with chips remaining)
          final playersWithChips = room.players.where((p) => p.chips > 0).toList();
          if (room.status == 'finished' && playersWithChips.length == 1) {
            // Tournament is over! Show victory screen
            return _buildTournamentVictoryScreen(room, playersWithChips.first);
          }

          // Auto-start new hand after game finishes (if 2+ players still have chips)
          if (room.status == 'finished' && playersWithChips.length >= 2) {
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

  Widget _buildPlayerCard(GamePlayer player, String hostId) {
    return LobbyPlayerCard(
      player: player,
      hostId: hostId,
      currentUserId: _gameService.currentUserId ?? '',
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
  // TOURNAMENT VICTORY SCREEN
  // ============================================================================

  Widget _buildTournamentVictoryScreen(GameRoom room, GamePlayer winner) {
    return TournamentVictoryOverlay(
      room: room,
      winner: winner,
      currentUserId: _gameService.currentUserId ?? '',
      onLeave: () => Navigator.pop(context),
    );
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
                    onTap: () => _showLeaveConfirmation(room),
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
                      final isTheirTurn = room.currentTurnPlayerId == participant.uid;

                      // Calculate x position for this slot
                      final xPos = rowStartX + (slot * slotWidth);

                      return AnimatedPositioned(
                        key: ValueKey('pos_${participant.uid}'),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        left: xPos,
                        top: 0,
                        bottom: 0,
                        child: ParticipantAvatar(
                          player: participant,
                          room: room,
                          isCurrentPlayer: isCurrentPlayer,
                          isTheirTurn: isTheirTurn,
                          remainingSeconds: _remainingSeconds,
                          showdownAnimationComplete: _showdownAnimationComplete,
                          onTap: () => _showPlayerProfile(participant),
                        ),
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
              final isTheirTurn = room.currentTurnPlayerId == player.uid;
              return ParticipantAvatar(
                player: player,
                room: room,
                isCurrentPlayer: isCurrentPlayer,
                isTheirTurn: isTheirTurn,
                remainingSeconds: _remainingSeconds,
                showdownAnimationComplete: _showdownAnimationComplete,
                onTap: () => _showPlayerProfile(player),
              );
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

  // Use formatChips from game_utils.dart
  String _formatChips(int chips) => formatChips(chips);

  Widget _buildCommunityCardsMinimal(GameRoom room) {
    final isShowdown = room.phase == 'showdown' && _showdownAnimationComplete;

    return Column(
      children: [
        // Winner text that fades in during showdown (matching game_screen.dart)
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
        // Community Cards Row - using spaceBetween like game_screen.dart
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 5; i++)
                () {
                  final card = i < room.communityCards.length ? room.communityCards[i] : null;
                  final isHighlighted = isShowdown && card != null && _isCardInWinningHand(card, room);
                  final isDimmed = isShowdown && card != null && !_isCardInWinningHand(card, room);
                  if (card == null) {
                    return _buildEmptyCardSlot();
                  }
                  return _buildMinimalCard(
                    card,
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

  /// Empty card slot matching game_screen.dart style
  Widget _buildEmptyCardSlot() {
    return Container(
      width: 58,
      height: 82,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 2),
      ),
    );
  }

  Widget _buildMinimalCard(PlayingCard? card,
      {bool isEmpty = false,
      bool isHoleCard = false,
      bool isHighlighted = false,
      bool isDimmed = false,
      bool isGhost = false}) {
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

    final isRed = card.suit == '♥' || card.suit == '♦';

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
              card.rank,
              style: TextStyle(
                color: (isRed ? Colors.red.shade300 : Colors.white).withValues(alpha: 0.4),
                fontSize: isHoleCard ? 24 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              card.suit,
              style: TextStyle(
                color: (isRed ? Colors.red.shade300 : Colors.white).withValues(alpha: 0.4),
                fontSize: isHoleCard ? 26 : 26,
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
              card.rank,
              style: TextStyle(
                color: isDimmed ? Colors.grey : (isRed ? Colors.red.shade700 : Colors.black),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              card.suit,
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
                width: 120, // Fixed width for 2 overlapping cards (70 * 2 - 20 overlap)
                height: 98,
                child: player.hasFolded && _foldedCards.isNotEmpty
                    ? Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildMinimalCard(_foldedCards[0], isHoleCard: true, isGhost: true),
                          if (_foldedCards.length > 1)
                            Positioned(
                              left: 50, // 70 - 20 overlap
                              child: _buildMinimalCard(_foldedCards[1], isHoleCard: true, isGhost: true),
                            ),
                        ],
                      )
                    : Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildCardBack(width: 70, height: 98),
                          Positioned(
                            left: 50, // 70 - 20 overlap
                            child: _buildCardBack(width: 70, height: 98),
                          ),
                        ],
                      ),
              ),
              const Spacer(),
              // Player info
              _buildPlayerAvatarLarge(player, room: room),
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
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          // Action buttons row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    // Debounce: prevent rapid button presses
                    if (_isProcessingAction) return;
                    final now = DateTime.now();
                    if (_lastActionTime != null && now.difference(_lastActionTime!).inMilliseconds < 300) {
                      return;
                    }

                    setState(() {
                      _isProcessingAction = true;
                      _lastActionTime = now;
                    });

                    // Add slight delay for smoother feel
                    await Future.delayed(const Duration(milliseconds: 150));
                    await _gameService.playerAction(widget.roomId, canCheck ? 'check' : 'call');

                    // Reset after action completes
                    await Future.delayed(const Duration(milliseconds: 200));
                    if (mounted) {
                      setState(() => _isProcessingAction = false);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _isProcessingAction ? Colors.grey.withValues(alpha: 0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(
                        canCheck ? 'Check' : 'Call ${_formatChips(callAmount)}',
                        style: TextStyle(
                          color: _isProcessingAction ? Colors.white.withValues(alpha: 0.5) : Colors.white,
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
                  onTap: () {
                    // Prevent opening dialog during action processing
                    if (_isProcessingAction) return;
                    _showRaiseDialog(room, player);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _isProcessingAction ? Colors.grey.withValues(alpha: 0.5) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Raise',
                        style: TextStyle(
                          color: _isProcessingAction ? Colors.black.withValues(alpha: 0.5) : Colors.black,
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
          // Cards area with swipe to fold (no text)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Swipeable cards with fold animation - fixed width
              // Using Listener for universal mouse + touch support
              SizedBox(
                width: 165, // Fixed width for 2 overlapping large cards
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: GestureDetector(
                    // Enable all pointer kinds for drag (including mouse)
                    supportedDevices: const {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                    onVerticalDragUpdate: (details) {
                      // Don't allow drag if processing action
                      if (_isProcessingAction) return;
                      setState(() {
                        _dragOffset += details.delta.dy;
                        // Clamp to only allow upward drag
                        if (_dragOffset > 0) _dragOffset = 0;
                      });
                    },
                    onVerticalDragEnd: (details) async {
                      // Prevent multiple fold actions
                      if (_isProcessingAction) {
                        setState(() => _dragOffset = 0);
                        return;
                      }

                      // If swiped up enough (past threshold) or fast enough, trigger fold
                      if (_dragOffset < -80 || (details.primaryVelocity != null && details.primaryVelocity! < -300)) {
                        setState(() => _isProcessingAction = true);
                        await Future.delayed(const Duration(milliseconds: 100));
                        _animateFold(player.cards);
                        await Future.delayed(const Duration(milliseconds: 300));
                        if (mounted) {
                          setState(() => _isProcessingAction = false);
                        }
                      }
                      // Reset drag offset
                      setState(() => _dragOffset = 0);
                    },
                    child: _isFolding
                        ? SlideTransition(
                            position: _foldSlideAnimation,
                            child: FadeTransition(
                              opacity: _foldOpacityAnimation,
                              child: _buildPlayerCardsLarge(player),
                            ),
                          )
                        : Transform.translate(
                            offset: Offset(0, _dragOffset * 0.5),
                            child: Opacity(
                              opacity: (1.0 + _dragOffset / 200).clamp(0.3, 1.0),
                              child: _buildPlayerCardsLarge(player),
                            ),
                          ),
                  ),
                ),
              ),
              const Spacer(),
              _buildPlayerAvatarLarge(player, room: room),
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
                  child: SizedBox(
                    width: 120, // 70 * 2 - 20 overlap
                    height: 98,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (player.cards.isNotEmpty) _buildMinimalCard(player.cards[0], isHoleCard: true),
                        if (player.cards.length > 1)
                          Positioned(
                            left: 50, // 70 - 20 overlap
                            child: _buildMinimalCard(player.cards[1], isHoleCard: true),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              _buildPlayerAvatarLarge(player, room: room),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerAreaWithCards(GamePlayer player, GameRoom room) {
    final isShowdown = room.phase == 'showdown';
    final isPlayerWinner = isShowdown && room.winnerId == player.uid;
    final isPlayerLoser = isShowdown && _showdownAnimationComplete && room.winnerId != player.uid && !player.hasFolded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Waiting indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isShowdown && _showdownAnimationComplete && isPlayerWinner
                  ? const Color(0xFFFFD700).withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isShowdown && _showdownAnimationComplete && isPlayerWinner
                    ? const Color(0xFFFFD700).withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: Center(
              child: Text(
                isShowdown && _showdownAnimationComplete && isPlayerWinner ? 'You win!' : 'Waiting for opponent...',
                style: TextStyle(
                  color: isShowdown && _showdownAnimationComplete && isPlayerWinner
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
                  child: _buildPlayerCardsLarge(player),
                ),
                const Spacer(),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Hand strength indicator - always show "High Card" until a better hand is made
                    if (player.cards.length >= 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          _getCurrentHandStrength(player.cards, room.communityCards),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    _buildPlayerAvatarLarge(player, room: room),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build large player cards for bottom area
  Widget _buildPlayerCardsLarge(GamePlayer player) {
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
            _buildCardBack(width: cardWidth, height: cardHeight),
            Positioned(
              left: cardWidth - overlap,
              child: _buildCardBack(width: cardWidth, height: cardHeight),
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
          _buildLargeCard(player.cards[0]),
          Positioned(
            left: cardWidth - overlap,
            child: _buildLargeCard(player.cards[1]),
          ),
        ],
      ),
    );
  }

  /// Build large card matching GameScreen's style
  Widget _buildLargeCard(PlayingCard card, {bool isHighlighted = false, bool isDimmed = false}) {
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

  /// Build player avatar for bottom right - matches GameScreen's _buildPlayerAvatarLarge
  Widget _buildPlayerAvatarLarge(GamePlayer player, {GameRoom? room}) {
    final playerAvatar = UserPreferences.avatar;
    final isMyTurn = room != null && room.currentTurnPlayerId == player.uid && room.phase != 'showdown';
    final isDealer = room != null &&
        room.players.isNotEmpty &&
        room.dealerIndex < room.players.length &&
        player.uid == room.players[room.dealerIndex].uid;

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
              if (isMyTurn && room.status == 'playing' && room.phase != 'showdown')
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.linear,
                  tween: Tween<double>(
                    begin: _remainingSeconds / room.turnTimeLimit,
                    end: _remainingSeconds / room.turnTimeLimit,
                  ),
                  builder: (context, value, child) => CustomPaint(
                    size: const Size(100, 126),
                    painter: RoundedRectProgressPainter(
                      progress: value,
                      color: _remainingSeconds <= 2 ? Colors.red : Colors.white,
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
                                    _formatChips(player.chips),
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
                                  _buildStatRow('Chips', _formatChips(player.chips)),
                                  _buildStatRow('Bet', _formatChips(player.currentBet)),
                                  _buildStatRow('Total', _formatChips(player.totalContributed)),
                                  if (player.lastAction != null) _buildStatRow('Action', player.lastAction!),
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

  Widget _buildStatRow(String label, String value) {
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

  // Use getShortHandName from game_utils.dart
  String _getShortHandName(HandRank rank) => getShortHandName(rank);

  String _getCurrentHandStrength(List<PlayingCard> holeCards, List<PlayingCard> communityCards) {
    if (holeCards.length < 2 || communityCards.length < 3) return 'High Card';

    final hand = HandEvaluator.evaluateBestHand(holeCards, communityCards);
    return _getShortHandName(hand.rank);
  }

  void _showPlayerProfile(GamePlayer player) {
    final friendsService = FriendsService();
    final isBot = _botService.isBot(player.uid);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => Dialog(
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
                '${_formatChips(player.chips)} chips',
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
                    if (mounted) {
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
      ),
    );
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
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
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
                    _formatChips(raiseAmount),
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
                        setDialogState(() => raiseAmount = value.toInt());
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
                          _formatChips(minRaise),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatChips(maxRaise),
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
                          setDialogState(() {
                            raiseAmount = ((room.pot / 2) + room.currentBet).toInt().clamp(minRaise, maxRaise);
                          });
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickBetButton('Pot', () {
                          setDialogState(() {
                            raiseAmount = (room.pot + room.currentBet).clamp(minRaise, maxRaise);
                          });
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickBetButton('All In', () {
                          setDialogState(() {
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
                            // Add delay for smoother transition
                            await Future.delayed(const Duration(milliseconds: 100));
                            setState(() => _isProcessingAction = true);
                            await Future.delayed(const Duration(milliseconds: 150));
                            await _gameService.playerAction(
                              widget.roomId,
                              'raise',
                              raiseAmount: raiseAmount,
                            );
                            await Future.delayed(const Duration(milliseconds: 200));
                            if (mounted) {
                              setState(() => _isProcessingAction = false);
                            }
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

// RoundedRectProgressPainter is now imported from timer_progress_painter.dart
