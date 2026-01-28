import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/game_service.dart';
import '../widgets/mobile_wrapper.dart';
import 'sit_and_go_waiting_screen.dart';

class SitAndGoScreen extends StatefulWidget {
  const SitAndGoScreen({super.key});

  @override
  State<SitAndGoScreen> createState() => _SitAndGoScreenState();
}

class _SitAndGoScreenState extends State<SitAndGoScreen> {
  final AuthService _authService = AuthService();
  final GameService _gameService = GameService();

  bool _isLoading = false;
  int _selectedBuyInIndex = 1; // Default to medium buy-in
  static const int _tableSize = 8; // Fixed 8-player tables

  // Buy-in levels for Sit & Go (entry fee + prize pool contribution)
  static const List<Map<String, dynamic>> _buyInLevels = [
    {'entry': 100, 'label': '\$100', 'startingChips': 1500},
    {'entry': 500, 'label': '\$500', 'startingChips': 1500},
    {'entry': 1000, 'label': '\$1K', 'startingChips': 1500},
    {'entry': 5000, 'label': '\$5K', 'startingChips': 1500},
    {'entry': 10000, 'label': '\$10K', 'startingChips': 1500},
    {'entry': 50000, 'label': '\$50K', 'startingChips': 1500},
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

  Future<void> _registerForSitAndGo() async {
    if (!_authService.isLoggedIn) {
      await _authService.signInAnonymously();
    }

    setState(() => _isLoading = true);

    try {
      final buyInLevel = _buyInLevels[_selectedBuyInIndex];
      final entry = buyInLevel['entry'] as int;
      final startingChips = buyInLevel['startingChips'] as int;

      String? roomId;

      // Search for a Sit & Go room with matching buy-in that isn't full
      for (int attempt = 0; attempt < 3; attempt++) {
        final rooms = await _gameService.fetchJoinableRoomsByBlind(
          entry, // Using entry fee as the "blind" matcher for Sit & Go
          gameType: 'sitandgo_8max',
        );

        if (rooms.isNotEmpty) {
          for (final room in rooms) {
            // Check if room has space
            if (room.players.length < _tableSize) {
              try {
                await _gameService.joinRoom(room.id, startingChips: startingChips);
                roomId = room.id;
                break;
              } catch (e) {
                continue;
              }
            }
          }
        }

        if (roomId != null) break;

        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      // If no room found, create a new one
      if (roomId == null) {
        final room = await _gameService.createRoom(
          bigBlind: entry, // Store entry fee as bigBlind for matching
          startingChips: startingChips,
          gameType: 'sitandgo_8max',
        );
        roomId = room.id;
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SitAndGoWaitingScreen(
              roomId: roomId!,
              buyIn: entry,
              requiredPlayers: _tableSize,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register: $e'),
            backgroundColor: const Color(0xFFEF4444),
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
    final buyInLevel = _buyInLevels[_selectedBuyInIndex];

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

                const SizedBox(height: 32),

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
                  '8-Player Tables',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),

                const Spacer(),

                // Buy-in display
                Text(
                  buyInLevel['label'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'BUY-IN',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 16),

                // Prize pool estimate
                Text(
                  'Prize Pool: ${buyInLevel['label']} × $_tableSize',
                  style: TextStyle(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 40),

                // Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFEF4444),
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                    thumbColor: const Color(0xFFEF4444),
                    overlayColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: _selectedBuyInIndex.toDouble(),
                    min: 0,
                    max: (_buyInLevels.length - 1).toDouble(),
                    divisions: _buyInLevels.length - 1,
                    onChanged: (value) {
                      setState(() => _selectedBuyInIndex = value.round());
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
                        _buyInLevels.first['label'] as String,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _buyInLevels.last['label'] as String,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Register button
                GestureDetector(
                  onTap: _isLoading ? null : _registerForSitAndGo,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
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
                          : const Text(
                              'REGISTER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
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
}
