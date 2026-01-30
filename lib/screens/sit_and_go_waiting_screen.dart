import 'package:flutter/material.dart';
import 'dart:async';
import '../models/game_room.dart';
import '../services/game_service.dart';
import '../widgets/mobile_wrapper.dart';
import 'multiplayer_game_screen.dart';

class SitAndGoWaitingScreen extends StatefulWidget {
  final String roomId;
  final int buyIn;
  final int requiredPlayers;

  const SitAndGoWaitingScreen({
    super.key,
    required this.roomId,
    required this.buyIn,
    this.requiredPlayers = 8,
  });

  @override
  State<SitAndGoWaitingScreen> createState() => _SitAndGoWaitingScreenState();
}

class _SitAndGoWaitingScreenState extends State<SitAndGoWaitingScreen> {
  final GameService _gameService = GameService();
  StreamSubscription? _roomSubscription;
  Timer? _heartbeatTimer;
  GameRoom? _room;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _subscribeToRoom();
    _startHeartbeat();
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _heartbeatTimer?.cancel();
    // Leave room if we're still waiting (not starting game)
    if (!_isStarting && _room != null && _room!.status == 'waiting') {
      _gameService.leaveRoom(widget.roomId);
    }
    super.dispose();
  }

  /// Start sending heartbeats every 10 seconds
  void _startHeartbeat() {
    // Send initial heartbeat
    _gameService.sendHeartbeat(widget.roomId);
    // NOTE: Disabled automatic inactive player cleanup - was causing issues
    // _gameService.removeInactivePlayers(widget.roomId);

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _isStarting) return;
      _gameService.sendHeartbeat(widget.roomId);
      // NOTE: Disabled automatic inactive player cleanup - was causing issues
      // _gameService.removeInactivePlayers(widget.roomId);
    });
  }

  void _subscribeToRoom() {
    _roomSubscription = _gameService.watchRoom(widget.roomId).listen((room) {
      if (!mounted) return;
      setState(() => _room = room);

      // Check if room is full and ready to start
      if (room != null && room.players.length >= widget.requiredPlayers && !_isStarting) {
        _startGame();
      }

      // Check if game has already started
      if (room != null && room.status == 'playing' && !_isStarting) {
        _navigateToGame();
      }
    });
  }

  Future<void> _startGame() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);

    final isHost = _room?.hostId == _gameService.currentUserId;

    if (isHost) {
      try {
        await _gameService.startGame(widget.roomId, skipReadyCheck: true);
      } catch (e) {
        // Game might have already started
      }
    }

    // Wait a moment then navigate
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _navigateToGame();
    }
  }

  void _navigateToGame() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MultiplayerGameScreen(
          roomId: widget.roomId,
          autoStart: true,
          requiredPlayers: widget.requiredPlayers,
        ),
      ),
    );
  }

  Future<void> _fillWithBots() async {
    try {
      await _gameService.fillRoomWithBots(widget.roomId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add bots: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _leaveRoom() async {
    try {
      await _gameService.leaveRoom(widget.roomId);
    } catch (e) {
      // Ignore errors when leaving
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerCount = _room?.players.length ?? 0;
    final progress = playerCount / widget.requiredPlayers;

    return MobileWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: _leaveRoom,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                ),

                const Spacer(),

                // Title
                const Text(
                  'SIT & GO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${_formatNumber(widget.buyIn)} Buy-in',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 48),

                // Player count circle
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background circle
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: CircularProgressIndicator(
                          value: 1,
                          strokeWidth: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.1)),
                        ),
                      ),
                      // Progress circle
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation(Color(0xFFEF4444)),
                        ),
                      ),
                      // Count text
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$playerCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 64,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'of ${widget.requiredPlayers}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Status text
                Text(
                  _isStarting ? 'Starting game...' : 'Waiting for players...',
                  style: TextStyle(
                    color: _isStarting ? const Color(0xFFEF4444) : Colors.white.withValues(alpha: 0.6),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 48),

                // Player list
                if (_room != null) ...[
                  Text(
                    'PLAYERS',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _room!.players.length,
                      itemBuilder: (context, index) {
                        final player = _room!.players[index];
                        final isMe = player.uid == _gameService.currentUserId;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: isMe ? 0.1 : 0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: isMe ? Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)) : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Center(
                                  child: Text(
                                    player.displayName[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  player.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isMe)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'YOU',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              if (player.uid == _room!.hostId && !isMe)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'HOST',
                                    style: TextStyle(
                                      color: Color(0xFFFFD700),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ] else
                  const Spacer(),

                // Fill with Bots button (for testing - only show if host and not full)
                if (_room?.hostId == _gameService.currentUserId &&
                    (_room?.players.length ?? 0) < widget.requiredPlayers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: _fillWithBots,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.smart_toy, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'FILL WITH BOTS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Leave button
                GestureDetector(
                  onTap: _leaveRoom,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: const Center(
                      child: Text(
                        'LEAVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number % 1000 == 0 ? 0 : 1)}K';
    }
    return number.toString();
  }
}
