import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_room.dart';
import '../services/game_service.dart';
import '../widgets/mobile_wrapper.dart';

class MultiplayerGameScreen extends StatefulWidget {
  final String roomId;
  final bool autoStart;

  const MultiplayerGameScreen({
    super.key,
    required this.roomId,
    this.autoStart = false,
  });

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  final GameService _gameService = GameService();
  final TextEditingController _chatController = TextEditingController();
  bool _isLoading = false;
  bool _hasAutoStarted = false;

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  /// Attempt auto-start when conditions are met
  Future<void> _tryAutoStart(GameRoom room) async {
    if (_hasAutoStarted || _isLoading) return;

    final isHost = room.hostId == _gameService.currentUserId;

    // Case 1: Room is in 'waiting' status with only 1 player - wait a bit for others to join
    if (room.status == 'waiting' && isHost && room.players.length == 1) {
      // Don't auto-start immediately - wait for another player
      // The room will stay in 'waiting' status so others can find it
      print('⏳ Waiting for more players to join room ${widget.roomId}...');
      return;
    }

    // Case 2: Room is in 'waiting' status with 2+ players - start the game!
    if (room.status == 'waiting' && isHost && room.players.length >= 2) {
      _hasAutoStarted = true;
      setState(() => _isLoading = true);
      print('🎮 Starting game with ${room.players.length} players!');
      try {
        // Skip ready check for auto-matched games - players are auto-ready when joining
        await _gameService.startGame(widget.roomId, skipReadyCheck: true);
      } catch (e) {
        print('❌ Failed to start game: $e');
        _hasAutoStarted = false; // Allow retry
      }
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Case 3: Room is 'playing' but in 'waiting_for_players' phase and has 2+ players
    // This means a second player joined a solo-started game - start the real game
    if (room.status == 'playing' && room.phase == 'waiting_for_players' && room.players.length >= 2 && isHost) {
      _hasAutoStarted = true;
      setState(() => _isLoading = true);
      try {
        await _gameService.startGameFromWaiting(widget.roomId);
      } catch (e) {
        _hasAutoStarted = false; // Allow retry
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileWrapper(
      child: StreamBuilder<GameRoom?>(
        stream: _gameService.watchRoom(widget.roomId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
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
                  // Online indicator
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pie_chart, color: Color(0xFF22C55E), size: 14),
                  ),
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
            if (isWaitingForPlayers || room.status != 'playing' || currentPlayer.hasFolded)
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
    final allPlayers = [...opponents];

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: allPlayers.length + 1, // +1 for add button
              itemBuilder: (context, index) {
                if (index < allPlayers.length) {
                  return _buildPlayerAvatar(allPlayers[index], room);
                }
                // Add player button
                return Container(
                  width: 56,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                        ),
                        child: Icon(Icons.add, color: Colors.white.withValues(alpha: 0.4), size: 28),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerAvatar(GamePlayer player, GameRoom room) {
    final isTheirTurn = room.currentTurnPlayerId == player.uid;
    final hasFolded = player.hasFolded;

    // Avatar emojis based on display name first letter
    String getAvatar(String name) {
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

    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasFolded ? Colors.grey.shade800 : Colors.white.withValues(alpha: 0.1),
                  border: isTheirTurn ? Border.all(color: const Color(0xFFD4AF37), width: 3) : null,
                ),
                child: Center(
                  child: Text(
                    getAvatar(player.displayName),
                    style: TextStyle(
                      fontSize: 28,
                      color: hasFolded ? Colors.grey : null,
                    ),
                  ),
                ),
              ),
              // Dealer badge
              if (player.uid == room.players[room.dealerIndex].uid)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('D',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Name
          Text(
            player.displayName.length > 8 ? '${player.displayName.substring(0, 8)}' : player.displayName,
            style: TextStyle(
              color: hasFolded ? Colors.grey : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          // Chips
          Text(
            _formatChips(player.chips),
            style: TextStyle(
              color: hasFolded ? Colors.grey : Colors.yellow.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Current bet badge
          if (player.currentBet > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.yellow.shade800,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _formatChips(player.currentBet),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatChips(int chips) {
    if (chips >= 1000000) return '${(chips / 1000000).toStringAsFixed(1)}M';
    if (chips >= 1000) return '${(chips / 1000).toStringAsFixed(chips % 1000 == 0 ? 0 : 1)}k';
    return chips.toString();
  }

  Widget _buildCommunityCardsMinimal(GameRoom room) {
    return Column(
      children: [
        // Community Cards Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildMinimalCard(
                  i < room.communityCards.length ? room.communityCards[i] : null,
                  isEmpty: i >= room.communityCards.length,
                ),
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

  Widget _buildMinimalCard(PlayingCard? card, {bool isEmpty = false, bool isHoleCard = false}) {
    const width = 56.0;
    const height = 78.0;

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

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            card.rank,
            style: TextStyle(
              color: isRed ? Colors.red.shade700 : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            card.suit,
            style: TextStyle(
              color: isRed ? Colors.red.shade700 : Colors.black,
              fontSize: 22,
            ),
          ),
        ],
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
              _buildPlayerInfoMinimal(player),
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
              // Swipeable cards
              GestureDetector(
                onVerticalDragEnd: (details) {
                  // Swipe up to fold
                  if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
                    _gameService.playerAction(widget.roomId, 'fold');
                  }
                },
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
                        if (player.cards.isNotEmpty) _buildMinimalCard(player.cards[0]),
                        const SizedBox(width: 8),
                        if (player.cards.length > 1) _buildMinimalCard(player.cards[1]),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Player info
              _buildPlayerInfoMinimal(player),
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
              // Player's cards
              Row(
                children: [
                  if (player.cards.isNotEmpty) _buildMinimalCard(player.cards[0]),
                  const SizedBox(width: 8),
                  if (player.cards.length > 1) _buildMinimalCard(player.cards[1]),
                ],
              ),
              const Spacer(),
              _buildPlayerInfoMinimal(player),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerInfoMinimal(GamePlayer player) {
    String getAvatar(String name) {
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          Text(getAvatar(player.displayName), style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          // Chips
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatChips(player.chips),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Emoji button
          GestureDetector(
            onTap: () => _showEmotePanel(context),
            child: Icon(
              Icons.emoji_emotions_outlined,
              color: Colors.white.withValues(alpha: 0.5),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  void _showRaiseDialog(GameRoom room, GamePlayer player) {
    // Minimum raise is current bet + last raise amount (or big blind if first raise)
    final minRaise = room.currentBet + (room.lastRaiseAmount > 0 ? room.lastRaiseAmount : room.bigBlind);
    var raiseAmount = minRaise;
    final maxRaise = player.chips + player.currentBet;

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
                value: raiseAmount.toDouble().clamp(minRaise.toDouble(), maxRaise.toDouble()),
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
