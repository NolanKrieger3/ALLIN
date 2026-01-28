import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/game_service.dart';
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

  bool _isLoading = false;
  int _selectedBlindIndex = 2; // Default to medium blinds

  // Blind levels (small blind / big blind / buy-in)
  static const List<Map<String, dynamic>> _blindLevels = [
    {'small': 10, 'big': 20, 'label': '10/20', 'buyIn': 1000, 'buyInLabel': '1K'},
    {'small': 25, 'big': 50, 'label': '25/50', 'buyIn': 2500, 'buyInLabel': '2.5K'},
    {'small': 50, 'big': 100, 'label': '50/100', 'buyIn': 5000, 'buyInLabel': '5K'},
    {'small': 100, 'big': 200, 'label': '100/200', 'buyIn': 10000, 'buyInLabel': '10K'},
    {'small': 250, 'big': 500, 'label': '250/500', 'buyIn': 25000, 'buyInLabel': '25K'},
    {'small': 500, 'big': 1000, 'label': '500/1K', 'buyIn': 50000, 'buyInLabel': '50K'},
    {'small': 1000, 'big': 2000, 'label': '1K/2K', 'buyIn': 100000, 'buyInLabel': '100K'},
  ];

  @override
  void initState() {
    super.initState();
    _ensureAuthenticated();
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

    setState(() => _isLoading = true);

    try {
      final blindLevel = _blindLevels[_selectedBlindIndex];
      final bigBlind = blindLevel['big'] as int;
      final buyIn = blindLevel['buyIn'] as int;

      // Try to find a joinable room with the same blind level
      final rooms = await _gameService.fetchJoinableRoomsByBlind(bigBlind);

      String roomId;
      if (rooms.isNotEmpty) {
        // Join existing room
        final room = rooms.first;
        await _gameService.joinRoom(room.id, startingChips: buyIn);
        roomId = room.id;
      } else {
        // Create new room
        final room = await _gameService.createRoom(bigBlind: bigBlind, startingChips: buyIn);
        roomId = room.id;
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MultiplayerGameScreen(roomId: roomId, autoStart: true),
          ),
        );
      }
    } catch (e) {
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
    final blindLevel = _blindLevels[_selectedBlindIndex];

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
                ),

                const Spacer(flex: 2),

                // Blinds display
                Text(
                  blindLevel['label'] as String,
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

                // Buy-in display
                Text(
                  '\$${blindLevel['buyInLabel']}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'BUY-IN',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 3,
                  ),
                ),

                const SizedBox(height: 48),

                // Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: 0.1),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: _selectedBlindIndex.toDouble(),
                    min: 0,
                    max: (_blindLevels.length - 1).toDouble(),
                    divisions: _blindLevels.length - 1,
                    onChanged: (value) {
                      setState(() => _selectedBlindIndex = value.round());
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
                        _blindLevels.first['label'] as String,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _blindLevels.last['label'] as String,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // Play button
                GestureDetector(
                  onTap: _isLoading ? null : _startGame,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                          : const Text(
                              'PLAY',
                              style: TextStyle(
                                color: Color(0xFF0A0A0A),
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
