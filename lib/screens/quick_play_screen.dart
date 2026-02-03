import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/game_service.dart';
import '../services/user_preferences.dart';
import '../widgets/mobile_wrapper.dart';
import 'multiplayer_game_screen.dart';

// Blind levels matching the Practice mode structure
const List<Map<String, dynamic>> _blindLevels = [
  {'name': 'Micro', 'bigBlind': 100, 'minBuyIn': 5000, 'maxBuyIn': 10000},
  {'name': 'Low', 'bigBlind': 500, 'minBuyIn': 25000, 'maxBuyIn': 50000},
  {'name': 'Medium', 'bigBlind': 1000, 'minBuyIn': 50000, 'maxBuyIn': 100000},
  {'name': 'High', 'bigBlind': 5000, 'minBuyIn': 250000, 'maxBuyIn': 500000},
  {'name': 'VIP', 'bigBlind': 10000, 'minBuyIn': 500000, 'maxBuyIn': 1000000},
];

class QuickPlayScreen extends StatefulWidget {
  const QuickPlayScreen({super.key});

  @override
  State<QuickPlayScreen> createState() => _QuickPlayScreenState();
}

class _QuickPlayScreenState extends State<QuickPlayScreen> {
  final AuthService _authService = AuthService();
  final GameService _gameService = GameService();

  bool _isLoading = false;
  int _selectedBlindIndex = 0;
  int _buyInAmount = 5000;
  int _chipBalance = 0;

  @override
  void initState() {
    super.initState();
    _ensureAuthenticated();
    _loadChipBalance();
  }

  void _loadChipBalance() {
    final balance = UserPreferences.chips;
    setState(() {
      _chipBalance = balance;
      // Auto-select highest affordable level
      for (int i = _blindLevels.length - 1; i >= 0; i--) {
        if (balance >= (_blindLevels[i]['minBuyIn'] as int)) {
          _selectedBlindIndex = i;
          _buyInAmount = _blindLevels[i]['minBuyIn'] as int;
          break;
        }
      }
    });
  }

  String _formatChipsLong(int chips) {
    if (chips >= 1000000) {
      return '${(chips / 1000000).toStringAsFixed(1)}M';
    } else if (chips >= 1000) {
      final k = chips / 1000;
      if (k == k.roundToDouble()) {
        return '${k.toInt()}K';
      }
      return '${k.toStringAsFixed(1)}K';
    }
    return chips.toString();
  }

  Future<void> _ensureAuthenticated() async {
    if (!_authService.isLoggedIn) {
      await _authService.signInAnonymously();
    }
  }

  Future<void> _startGame() async {
    if (!_authService.isLoggedIn) {
      await _authService.signInAnonymously();
    }

    final selectedLevel = _blindLevels[_selectedBlindIndex];
    final minBuyIn = selectedLevel['minBuyIn'] as int;

    // Check if user can afford the buy-in
    if (_chipBalance < minBuyIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Not enough chips! You need ${_formatChipsLong(minBuyIn)} but only have ${_formatChipsLong(_chipBalance)}'),
            backgroundColor: const Color(0xFFFF4444),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bigBlind = selectedLevel['bigBlind'] as int;

      String? roomId;

      // FAST matchmaking: Try to find a room immediately, create if none exist
      print('🔍 Quick matchmaking for blind $bigBlind with buy-in $_buyInAmount');

      // Step 1: Search for joinable rooms
      final rooms = await _gameService.fetchJoinableRoomsByBlind(bigBlind, gameType: 'quickplay');

      if (rooms.isNotEmpty) {
        // Try to join the first available room
        for (final room in rooms) {
          try {
            print('🎯 Joining room ${room.id}');
            await _gameService.joinRoom(room.id, startingChips: _buyInAmount);
            roomId = room.id;
            print('✅ Joined room ${room.id}');
            break;
          } catch (e) {
            print('❌ Room ${room.id} unavailable: $e');
            continue;
          }
        }
      }

      // Step 2: If no room found, create one immediately
      if (roomId == null) {
        print('📦 Creating new room');
        final room = await _gameService.createRoom(
          bigBlind: bigBlind,
          startingChips: _buyInAmount,
          gameType: 'quickplay',
          maxPlayers: 6,
        );
        roomId = room.id;
        print('✅ Created room ${room.id}');
      }

      // Deduct buy-in from user balance
      final newBalance = _chipBalance - _buyInAmount;
      await UserPreferences.setChips(newBalance);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MultiplayerGameScreen(
              roomId: roomId!,
              autoStart: true,
              allowRebuy: true,
              bigBlind: bigBlind,
              minBuyIn: minBuyIn,
              maxBuyIn: selectedLevel['maxBuyIn'] as int,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Matchmaking failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start game: $e'),
            backgroundColor: const Color(0xFFFF4444),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userBalance = _chipBalance;
    final selectedLevel = _blindLevels[_selectedBlindIndex];
    final minBuyIn = selectedLevel['minBuyIn'] as int;
    final maxBuyIn = selectedLevel['maxBuyIn'] as int;
    final canAfford = userBalance >= minBuyIn;

    return MobileWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Top bar with back button and balance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _AnimatedPressButton(
                      onTap: () => Navigator.pop(context),
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
                    // User balance
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Text('💰', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            _formatChipsLong(userBalance),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Title
                const Text(
                  'PLAY NOW',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Play against real players',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 32),

                // Blind Level Selection
                Text(
                  'SELECT STAKES',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 12),

                // Blind level cards
                ...List.generate(_blindLevels.length, (index) {
                  final level = _blindLevels[index];
                  final isSelected = _selectedBlindIndex == index;
                  final levelMinBuyIn = level['minBuyIn'] as int;
                  final isLocked = userBalance < levelMinBuyIn;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AnimatedPressButton(
                      onTap: isLocked
                          ? null
                          : () {
                              setState(() {
                                _selectedBlindIndex = index;
                                _buyInAmount = levelMinBuyIn;
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: isLocked ? 0.02 : 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected ? Border.all(color: const Color(0xFF3B82F6), width: 2) : null,
                        ),
                        child: Row(
                          children: [
                            // Level info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        level['name'] as String,
                                        style: TextStyle(
                                          color: isLocked ? Colors.white38 : Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (isLocked) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.lock, color: Colors.white38, size: 16),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Blinds: ${_formatChipsLong((level['bigBlind'] as int) ~/ 2)}/${_formatChipsLong(level['bigBlind'] as int)}',
                                    style: TextStyle(
                                      color: isLocked ? Colors.white24 : Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Buy-in range
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${_formatChipsLong(level['minBuyIn'] as int)} - ${_formatChipsLong(level['maxBuyIn'] as int)}',
                                  style: TextStyle(
                                    color: isLocked ? Colors.white24 : Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (isLocked)
                                  Text(
                                    'Need ${_formatChipsLong(levelMinBuyIn)}',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Buy-in slider (only if can afford selected level)
                if (canAfford) ...[
                  Text(
                    'BUY-IN AMOUNT',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatChipsLong(_buyInAmount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF3B82F6),
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                      thumbColor: const Color(0xFF3B82F6),
                      overlayColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                    ),
                    child: Slider(
                      value: _buyInAmount
                          .toDouble()
                          .clamp(minBuyIn.toDouble(), userBalance.clamp(minBuyIn, maxBuyIn).toDouble()),
                      min: minBuyIn.toDouble(),
                      max: userBalance.clamp(minBuyIn, maxBuyIn).toDouble(),
                      onChanged: (value) {
                        setState(() => _buyInAmount = value.toInt());
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatChipsLong(minBuyIn),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                        Text(_formatChipsLong(userBalance.clamp(minBuyIn, maxBuyIn)),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Info about rebuy
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.refresh, color: const Color(0xFF3B82F6).withValues(alpha: 0.8), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You can buy back in if you lose all your chips',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Play button
                _AnimatedPressButton(
                  onTap: canAfford && !_isLoading ? _startGame : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: canAfford ? const Color(0xFF3B82F6) : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              canAfford ? 'FIND MATCH' : 'NOT ENOUGH CHIPS',
                              style: TextStyle(
                                color: canAfford ? Colors.white : Colors.white38,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated press button widget (same as GameScreen)
class _AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _AnimatedPressButton({
    required this.child,
    this.onTap,
  });

  @override
  State<_AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<_AnimatedPressButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.onTap != null ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: widget.onTap == null ? 0.5 : (_isPressed ? 0.8 : 1.0),
          duration: const Duration(milliseconds: 100),
          child: widget.child,
        ),
      ),
    );
  }
}
