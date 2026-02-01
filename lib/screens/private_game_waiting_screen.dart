import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/game_room.dart';
import '../services/room_service.dart';
import '../services/game_service.dart';
import '../widgets/mobile_wrapper.dart';
import '../widgets/animated_buttons.dart';
import 'multiplayer_game_screen.dart';

class PrivateGameWaitingScreen extends StatefulWidget {
  final String roomId;
  final String roomPin;
  final bool isHost;

  const PrivateGameWaitingScreen({
    super.key,
    required this.roomId,
    required this.roomPin,
    required this.isHost,
  });

  @override
  State<PrivateGameWaitingScreen> createState() => _PrivateGameWaitingScreenState();
}

class _PrivateGameWaitingScreenState extends State<PrivateGameWaitingScreen> {
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

  void _startHeartbeat() {
    _gameService.sendHeartbeat(widget.roomId);
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _isStarting) return;
      _gameService.sendHeartbeat(widget.roomId);
    });
  }

  void _subscribeToRoom() {
    _roomSubscription = _gameService.watchRoom(widget.roomId).listen((room) {
      if (!mounted) return;
      setState(() => _room = room);

      // Check if game has started (host clicked start)
      if (room != null && room.status == 'playing' && !_isStarting) {
        _navigateToGame();
      }
    });
  }

  Future<void> _startGame() async {
    if (_isStarting) return;
    if (_room == null || _room!.players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need at least 2 players to start'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isStarting = true);

    try {
      await _gameService.startGame(widget.roomId, skipReadyCheck: true);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _navigateToGame();
      }
    } catch (e) {
      setState(() => _isStarting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start game: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _navigateToGame() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MultiplayerGameScreen(
          roomId: widget.roomId,
          autoStart: true,
        ),
      ),
    );
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

  void _copyRoomPin() {
    Clipboard.setData(ClipboardData(text: widget.roomPin));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check, color: Colors.white),
            const SizedBox(width: 8),
            Text('Room PIN ${widget.roomPin} copied!'),
          ],
        ),
        backgroundColor: const Color(0xFF8B5CF6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerCount = _room?.players.length ?? 1;
    final maxPlayers = _room?.maxPlayers ?? 8;

    return MobileWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedTapButton(
                      onTap: _leaveRoom,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      ),
                    ),
                    const Text(
                      'Private Game',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 44), // Balance the back button
                  ],
                ),

                const SizedBox(height: 40),

                // Room PIN Display
                AnimatedTapButton(
                  onTap: _copyRoomPin,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'ROOM PIN',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.roomPin,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy, color: Colors.white.withValues(alpha: 0.7), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Tap to copy',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Players Section
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Players',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$playerCount / $maxPlayers',
                                style: const TextStyle(
                                  color: Color(0xFF8B5CF6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _room == null
                              ? const Center(
                                  child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                                )
                              : ListView.builder(
                                  itemCount: _room!.players.length,
                                  itemBuilder: (context, index) {
                                    final player = _room!.players[index];
                                    final isHost = player.uid == _room!.hostId;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isHost
                                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                            : Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(12),
                                        border: isHost
                                            ? Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3))
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Center(
                                              child: Text(
                                                player.displayName.isNotEmpty
                                                    ? player.displayName[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Color(0xFF8B5CF6),
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  player.displayName,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                if (isHost)
                                                  Text(
                                                    'Host',
                                                    style: TextStyle(
                                                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.8),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.check_circle,
                                            color: const Color(0xFF22C55E).withValues(alpha: 0.8),
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Start Game Button (Host only)
                if (widget.isHost)
                  AnimatedTapButton(
                    onTap: _isStarting ? null : _startGame,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: _isStarting || (_room?.players.length ?? 0) < 2
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                              ),
                        color: _isStarting || (_room?.players.length ?? 0) < 2
                            ? Colors.white.withValues(alpha: 0.1)
                            : null,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: _isStarting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                (_room?.players.length ?? 0) < 2 ? 'Waiting for players...' : 'Start Game',
                                style: TextStyle(
                                  color: (_room?.players.length ?? 0) < 2
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white.withValues(alpha: 0.5),
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Waiting for host to start...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
