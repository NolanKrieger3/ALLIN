import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/game_service.dart';
import '../services/bot_service.dart';
import '../services/currency_service.dart';
import '../widgets/mobile_wrapper.dart';
import 'multiplayer_game_screen.dart';

class QuickPlayScreen extends StatefulWidget {
  const QuickPlayScreen({super.key});

  @override
  State<QuickPlayScreen> createState() => _QuickPlayScreenState();
}

class _QuickPlayScreenState extends State<QuickPlayScreen> {
  final AuthService _authService = AuthService();
  final GameService _gameService = GameService();
  final BotService _botService = BotService();

  bool _isLoading = false;
  int _selectedBlindIndex = 1; // Default to second level
  int _chipBalance = 0;

  @override
  void initState() {
    super.initState();
    _ensureAuthenticated();
    _loadChipBalance();
  }

  void _loadChipBalance() {
    setState(() {
      _chipBalance = CurrencyService.chips;
      // Auto-select the highest affordable blind level
      _selectedBlindIndex = BlindLevels.getHighestAffordableIndex(_chipBalance);
    });
  }

  /// Get the highest blind level index the user can afford
  int _getHighestAffordableIndex() {
    return BlindLevels.getHighestAffordableIndex(_chipBalance);
  }

  /// Check if user can afford a specific blind level
  bool _canAfford(int index) {
    return BlindLevels.canAfford(index, _chipBalance);
  }

  /// Show message when user tries to select unaffordable level
  void _showUnaffordableMessage(int attemptedIndex) {
    final level = BlindLevels.all[attemptedIndex];
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Need ${CurrencyService.formatChips(level.buyIn)} chips for ${level.label} blinds. You have ${CurrencyService.formatChips(_chipBalance)}.',
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
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

    final blindLevel = BlindLevels.all[_selectedBlindIndex];
    final buyIn = blindLevel.buyIn;

    // Check if user can afford the buy-in
    if (_chipBalance < buyIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Not enough chips! You need ${CurrencyService.formatChips(buyIn)} but only have ${CurrencyService.formatChips(_chipBalance)}'),
            backgroundColor: const Color(0xFFFF4444),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bigBlind = blindLevel.big;

      String? roomId;

      // Retry logic: Try to find and join a room multiple times before creating
      // Use more attempts with longer delays to handle race conditions
      for (int attempt = 0; attempt < 5; attempt++) {
        print('🔍 Matchmaking attempt ${attempt + 1}/5 for blind $bigBlind');

        // Search for joinable Quick Play rooms (separate from Cash Games)
        final rooms = await _gameService.fetchJoinableRoomsByBlind(bigBlind, gameType: 'quickplay');

        if (rooms.isNotEmpty) {
          // Try to join each room until one succeeds
          for (final room in rooms) {
            try {
              print('🎯 Attempting to join room ${room.id}');
              await _gameService.joinRoom(room.id, startingChips: buyIn);
              roomId = room.id;
              print('✅ Successfully joined room ${room.id}');
              break;
            } catch (e) {
              print('❌ Failed to join room ${room.id}: $e');
              // Room might be full or game started, try next room
              continue;
            }
          }
        }

        if (roomId != null) break;

        // Longer delay before next attempt to allow other rooms to appear
        // This helps prevent race conditions where multiple players create rooms simultaneously
        if (attempt < 4) {
          await Future.delayed(Duration(milliseconds: 800 + (attempt * 200)));
        }
      }

      // If no room found after retries, check if we should create a new one
      if (roomId == null) {
        // Only create a new room if all existing rooms for this blind are full
        final allRoomsFull = await _gameService.areAllRoomsFull(bigBlind, 'quickplay');

        if (allRoomsFull) {
          print('📦 All rooms are full, creating new room');
          final room = await _gameService.createRoom(
            bigBlind: bigBlind,
            startingChips: buyIn,
            gameType: 'quickplay',
            maxPlayers: 6, // Allow up to 6 players in Quick Play lobbies
          );
          roomId = room.id;
          print('✅ Created room ${room.id}');
        } else {
          // Wait and retry - there should be a room available
          print('⏳ Rooms exist but join failed, waiting before retry...');
          await Future.delayed(const Duration(milliseconds: 1000));
          // Do one final retry
          final rooms = await _gameService.fetchJoinableRoomsByBlind(bigBlind, gameType: 'quickplay');
          if (rooms.isNotEmpty) {
            for (final room in rooms) {
              try {
                await _gameService.joinRoom(room.id, startingChips: buyIn);
                roomId = room.id;
                print('✅ Final retry succeeded, joined room ${room.id}');
                break;
              } catch (e) {
                continue;
              }
            }
          }
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MultiplayerGameScreen(roomId: roomId!, autoStart: true),
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

  Future<void> _startGameWithBots() async {
    if (!_authService.isLoggedIn) {
      await _authService.signInAnonymously();
    }

    final blindLevel = BlindLevels.all[_selectedBlindIndex];
    final buyIn = blindLevel.buyIn;

    // Check if user can afford the buy-in
    if (_chipBalance < buyIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Not enough chips! You need ${CurrencyService.formatChips(buyIn)} but only have ${CurrencyService.formatChips(_chipBalance)}'),
            backgroundColor: const Color(0xFFFF4444),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bigBlind = blindLevel.big;

      // Create a new private room for testing
      print('🤖 Creating test room with bots');
      final room = await _gameService.createRoom(
        bigBlind: bigBlind,
        startingChips: buyIn,
        gameType: 'quickplay',
        isPrivate: true,
        maxPlayers: 5, // You + 4 bots
      );

      // Add 4 bots to the room
      await _botService.addBotsToRoom(room.id, 4);
      print('✅ Added 4 bots to room ${room.id}');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MultiplayerGameScreen(roomId: room.id, autoStart: true),
          ),
        );
      }
    } catch (e) {
      print('❌ Failed to create test game: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start test game: $e'),
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
    final blindLevel = BlindLevels.all[_selectedBlindIndex];
    final canAffordSelected = _canAfford(_selectedBlindIndex);
    final maxAffordableIndex = _getHighestAffordableIndex();

    return MobileWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Back button and chip balance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
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
                    // Chip balance display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.monetization_on, color: Colors.amber.withValues(alpha: 0.8), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyService.formatChips(_chipBalance),
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

                const Spacer(flex: 2),

                // Blinds display
                Text(
                  blindLevel.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'BLINDS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 24),

                // Buy-in display with affordability indicator
                Text(
                  '\$${blindLevel.buyInLabel}',
                  style: TextStyle(
                    color: canAffordSelected ? Colors.white.withValues(alpha: 0.6) : Colors.red.withValues(alpha: 0.8),
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!canAffordSelected) ...[
                      Icon(Icons.lock, color: Colors.red.withValues(alpha: 0.6), size: 12),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      canAffordSelected ? 'BUY-IN' : 'INSUFFICIENT CHIPS',
                      style: TextStyle(
                        color:
                            canAffordSelected ? Colors.white.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                // Slider - shows message when trying to select unaffordable levels
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: canAffordSelected ? Colors.white : Colors.red.withValues(alpha: 0.6),
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                    thumbColor: canAffordSelected ? Colors.white : Colors.red.withValues(alpha: 0.8),
                    overlayColor: Colors.white.withValues(alpha: 0.1),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: _selectedBlindIndex.toDouble(),
                    min: 0,
                    max: (BlindLevels.all.length - 1).toDouble(),
                    divisions: BlindLevels.all.length - 1,
                    onChanged: (value) {
                      final newIndex = value.round();
                      // Show message if trying to select unaffordable level
                      if (newIndex > maxAffordableIndex) {
                        _showUnaffordableMessage(newIndex);
                        // Still clamp to max affordable
                        setState(() => _selectedBlindIndex = maxAffordableIndex);
                      } else {
                        setState(() => _selectedBlindIndex = newIndex);
                      }
                    },
                  ),
                ),

                // Min/Max labels with affordability indicators
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        BlindLevels.all.first.label,
                        style: TextStyle(
                          color:
                              _canAfford(0) ? Colors.white.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        maxAffordableIndex < BlindLevels.all.length - 1
                            ? 'Max: ${BlindLevels.all[maxAffordableIndex].label}'
                            : BlindLevels.all.last.label,
                        style: TextStyle(
                          color: maxAffordableIndex < BlindLevels.all.length - 1
                              ? Colors.amber.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // Play button - disabled if can't afford
                GestureDetector(
                  onTap: (_isLoading || !canAffordSelected) ? null : _startGame,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: canAffordSelected ? Colors.white : Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF0A0A0A),
                              ),
                            )
                          : Text(
                              canAffordSelected ? 'PLAY' : 'NOT ENOUGH CHIPS',
                              style: TextStyle(
                                color: const Color(0xFF0A0A0A),
                                fontSize: canAffordSelected ? 18 : 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Test with bots button - also disabled if can't afford
                GestureDetector(
                  onTap: (_isLoading || !canAffordSelected) ? null : _startGameWithBots,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: canAffordSelected
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: canAffordSelected
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.smart_toy,
                            color: canAffordSelected
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.2),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'TEST WITH 2 BOTS',
                            style: TextStyle(
                              color: canAffordSelected
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : Colors.white.withValues(alpha: 0.3),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
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
