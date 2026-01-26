import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_room.dart';
import '../services/game_service.dart';
import '../widgets/mobile_wrapper.dart';

class MultiplayerGameScreen extends StatefulWidget {
  final String roomId;

  const MultiplayerGameScreen({
    super.key,
    required this.roomId,
  });

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  final GameService _gameService = GameService();
  final TextEditingController _chatController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
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

          if (room.status == 'waiting') {
            return _buildWaitingRoom(room);
          } else {
            return _buildGameTable(room);
          }
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
                    backgroundColor: currentPlayer.isReady
                        ? Colors.grey
                        : const Color(0xFF4CAF50),
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
        color: isMe
            ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? const Color(0xFFD4AF37).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
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
                player.displayName.isNotEmpty
                    ? player.displayName[0].toUpperCase()
                    : '?',
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
    final opponent = room.players.firstWhere(
      (p) => p.uid != _gameService.currentUserId,
      orElse: () => room.players.last,
    );
    final isMyTurn = room.currentTurnPlayerId == _gameService.currentUserId;
    final isHost = room.hostId == _gameService.currentUserId;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Leave Game?'),
                          content: const Text('You will forfeit the current hand.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Leave'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        await _gameService.leaveRoom(widget.roomId);
                        Navigator.pop(context);
                      }
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      room.phase.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  // Chat/Emotes button
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white),
                    onPressed: () => _showEmotePanel(context),
                  ),
                ],
              ),
            ),

            // Opponent Area
            _buildOpponentArea(opponent, room),

            const Spacer(),

            // Community Cards & Pot
            _buildCommunityArea(room),

            const Spacer(),

            // Player Cards
            _buildPlayerCards(currentPlayer, room),

            const SizedBox(height: 16),

            // Player Info & Chips
            _buildPlayerInfo(currentPlayer),

            const SizedBox(height: 16),

            // Action Buttons
            if (room.status == 'playing' && !currentPlayer.hasFolded)
              _buildActionButtons(room, currentPlayer, isMyTurn),

            // Game Over
            if (room.status == 'finished')
              _buildGameOverArea(room, isHost),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOpponentArea(GamePlayer opponent, GameRoom room) {
    final isOpponentTurn = room.currentTurnPlayerId == opponent.uid;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOpponentTurn
            ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOpponentTurn
              ? const Color(0xFFD4AF37).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: isOpponentTurn ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                opponent.displayName.isNotEmpty
                    ? opponent.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Name & Chips
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opponent.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${opponent.chips} chips',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Cards (face down or revealed)
          Row(
            children: [
              _buildCard(
                room.status == 'finished' && opponent.cards.isNotEmpty
                    ? opponent.cards[0]
                    : null,
                faceDown: room.status != 'finished',
              ),
              const SizedBox(width: 4),
              _buildCard(
                room.status == 'finished' && opponent.cards.length > 1
                    ? opponent.cards[1]
                    : null,
                faceDown: room.status != 'finished',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityArea(GameRoom room) {
    return Column(
      children: [
        // Pot
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monetization_on,
                color: Color(0xFFD4AF37),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'POT: ${room.pot}',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Community Cards
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildCard(
                  i < room.communityCards.length ? room.communityCards[i] : null,
                  large: true,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayerCards(GamePlayer player, GameRoom room) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (player.cards.isNotEmpty)
          _buildCard(player.cards[0], large: true),
        const SizedBox(width: 8),
        if (player.cards.length > 1)
          _buildCard(player.cards[1], large: true),
      ],
    );
  }

  Widget _buildPlayerInfo(GamePlayer player) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_balance_wallet,
            color: Colors.white70,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '${player.chips} chips',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(GameRoom room, GamePlayer player, bool isMyTurn) {
    final callAmount = room.currentBet - player.currentBet;
    final canCheck = room.currentBet == player.currentBet;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Fold
          Expanded(
            child: _buildActionButton(
              'FOLD',
              Colors.red,
              isMyTurn ? () => _gameService.playerAction(widget.roomId, 'fold') : null,
            ),
          ),
          const SizedBox(width: 8),
          // Check / Call
          Expanded(
            child: _buildActionButton(
              canCheck ? 'CHECK' : 'CALL $callAmount',
              Colors.blue,
              isMyTurn
                  ? () => _gameService.playerAction(
                        widget.roomId,
                        canCheck ? 'check' : 'call',
                      )
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          // Raise
          Expanded(
            child: _buildActionButton(
              'RAISE',
              const Color(0xFF4CAF50),
              isMyTurn
                  ? () => _showRaiseDialog(room, player)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          // All In
          Expanded(
            child: _buildActionButton(
              'ALL IN',
              const Color(0xFFD4AF37),
              isMyTurn
                  ? () => _gameService.playerAction(widget.roomId, 'allin')
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: onPressed != null ? 0.2 : 0.05),
        foregroundColor: color,
        disabledForegroundColor: color.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: color.withValues(alpha: onPressed != null ? 0.5 : 0.1),
          ),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showRaiseDialog(GameRoom room, GamePlayer player) {
    final minRaise = room.currentBet * 2;
    var raiseAmount = minRaise;

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
                max: (player.chips + player.currentBet).toDouble(),
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
        color: didWin
            ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: didWin
              ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
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
}
