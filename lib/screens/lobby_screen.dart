import 'package:flutter/material.dart';
import '../models/game_room.dart';
import '../services/auth_service.dart';
import '../services/game_service.dart';
import '../widgets/mobile_wrapper.dart';
import 'multiplayer_game_screen.dart';

// Stake level definition
class StakeLevel {
  final String name;
  final int smallBlind;
  final int bigBlind;
  final int minBuyIn;
  final int maxBuyIn;
  final Color color;

  const StakeLevel({
    required this.name,
    required this.smallBlind,
    required this.bigBlind,
    required this.minBuyIn,
    required this.maxBuyIn,
    required this.color,
  });

  String get blindsDisplay => '${_formatNumber(smallBlind)}/${_formatNumber(bigBlind)}';
  String get buyInDisplay => '${_formatNumber(minBuyIn)} - ${_formatNumber(maxBuyIn)}';

  static String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    return '$n';
  }
}

// Sit & Go buy-in level
class SitAndGoBuyIn {
  final String name;
  final int buyIn;
  final int prizePool;
  final Color color;

  const SitAndGoBuyIn({
    required this.name,
    required this.buyIn,
    required this.prizePool,
    required this.color,
  });
}

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final AuthService _authService = AuthService();
  final GameService _gameService = GameService();
  final TextEditingController _roomCodeController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  String? _loadingAction;

  // Stake levels for Cash Games
  static const List<StakeLevel> _cashGameStakes = [
    StakeLevel(
      name: 'Micro',
      smallBlind: 10,
      bigBlind: 20,
      minBuyIn: 200,
      maxBuyIn: 2000,
      color: Color(0xFF4CAF50),
    ),
    StakeLevel(
      name: 'Low',
      smallBlind: 25,
      bigBlind: 50,
      minBuyIn: 500,
      maxBuyIn: 5000,
      color: Color(0xFF2196F3),
    ),
    StakeLevel(
      name: 'Medium',
      smallBlind: 100,
      bigBlind: 200,
      minBuyIn: 2000,
      maxBuyIn: 20000,
      color: Color(0xFF9C27B0),
    ),
    StakeLevel(
      name: 'High',
      smallBlind: 500,
      bigBlind: 1000,
      minBuyIn: 10000,
      maxBuyIn: 100000,
      color: Color(0xFFFF9800),
    ),
    StakeLevel(
      name: 'VIP',
      smallBlind: 2500,
      bigBlind: 5000,
      minBuyIn: 50000,
      maxBuyIn: 500000,
      color: Color(0xFFD4AF37),
    ),
  ];

  // Stake levels for Heads-Up Duel
  static const List<StakeLevel> _headsUpStakes = [
    StakeLevel(
      name: 'Bronze',
      smallBlind: 10,
      bigBlind: 20,
      minBuyIn: 500,
      maxBuyIn: 500,
      color: Color(0xFFCD7F32),
    ),
    StakeLevel(
      name: 'Silver',
      smallBlind: 50,
      bigBlind: 100,
      minBuyIn: 2500,
      maxBuyIn: 2500,
      color: Color(0xFFC0C0C0),
    ),
    StakeLevel(
      name: 'Gold',
      smallBlind: 250,
      bigBlind: 500,
      minBuyIn: 12500,
      maxBuyIn: 12500,
      color: Color(0xFFD4AF37),
    ),
    StakeLevel(
      name: 'Platinum',
      smallBlind: 1000,
      bigBlind: 2000,
      minBuyIn: 50000,
      maxBuyIn: 50000,
      color: Color(0xFFE5E4E2),
    ),
    StakeLevel(
      name: 'Diamond',
      smallBlind: 5000,
      bigBlind: 10000,
      minBuyIn: 250000,
      maxBuyIn: 250000,
      color: Color(0xFF00BCD4),
    ),
    StakeLevel(
      name: 'Champion',
      smallBlind: 25000,
      bigBlind: 50000,
      minBuyIn: 1250000,
      maxBuyIn: 1250000,
      color: Color(0xFFFF6B35),
    ),
    StakeLevel(
      name: 'Legend',
      smallBlind: 100000,
      bigBlind: 200000,
      minBuyIn: 5000000,
      maxBuyIn: 5000000,
      color: Color(0xFF9C27B0),
    ),
  ];

  // Sit & Go buy-in levels
  static const List<SitAndGoBuyIn> _sitAndGoBuyIns = [
    SitAndGoBuyIn(name: 'Freeroll', buyIn: 0, prizePool: 1000, color: Color(0xFF4CAF50)),
    SitAndGoBuyIn(name: 'Bronze', buyIn: 100, prizePool: 500, color: Color(0xFFCD7F32)),
    SitAndGoBuyIn(name: 'Silver', buyIn: 500, prizePool: 2500, color: Color(0xFFC0C0C0)),
    SitAndGoBuyIn(name: 'Gold', buyIn: 2500, prizePool: 12500, color: Color(0xFFD4AF37)),
    SitAndGoBuyIn(name: 'Platinum', buyIn: 10000, prizePool: 50000, color: Color(0xFFE5E4E2)),
    SitAndGoBuyIn(name: 'Diamond', buyIn: 50000, prizePool: 250000, color: Color(0xFF00BCD4)),
    SitAndGoBuyIn(name: 'Champion', buyIn: 250000, prizePool: 1250000, color: Color(0xFFFF6B35)),
    SitAndGoBuyIn(name: 'Legend', buyIn: 1000000, prizePool: 5000000, color: Color(0xFF9C27B0)),
  ];

  @override
  void initState() {
    super.initState();
    _ensureAuthenticated();
  }

  Future<void> _ensureAuthenticated() async {
    if (!_authService.isLoggedIn) {
      setState(() => _isLoading = true);
      try {
        await _authService.signInAnonymously();
        setState(() => _error = null);
      } catch (e) {
        setState(() => _error = 'Failed to connect. Please try again.');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createRoom() async {
    if (!_authService.isLoggedIn) {
      setState(() => _error = 'Not connected. Please try again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingAction = 'Creating room...';
      _error = null;
    });

    try {
      final room = await _gameService.createRoom(isPrivate: true);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MultiplayerGameScreen(roomId: room.id),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Failed to create room');
    }

    setState(() {
      _isLoading = false;
      _loadingAction = null;
    });
  }

  Future<void> _joinRoom(String roomId) async {
    if (roomId.isEmpty) {
      setState(() => _error = 'Please enter a room code');
      return;
    }

    if (!_authService.isLoggedIn) {
      setState(() => _error = 'Not connected. Please try again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingAction = 'Joining room...';
      _error = null;
    });

    try {
      await _gameService.joinRoom(roomId);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MultiplayerGameScreen(roomId: roomId),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Room not found or full');
    }

    setState(() {
      _isLoading = false;
      _loadingAction = null;
    });
  }

  Future<void> _joinCashGame(StakeLevel stake) async {
    if (!_authService.isLoggedIn) {
      setState(() => _error = 'Not connected. Please try again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingAction = 'Finding ${stake.name} table...';
      _error = null;
    });

    try {
      // Try to find an available room at this stake level
      final rooms = await _gameService.getAvailableRooms().first.timeout(
            const Duration(seconds: 10),
            onTimeout: () => <GameRoom>[],
          );

      if (rooms.isNotEmpty) {
        await _gameService.joinRoom(rooms.first.id);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MultiplayerGameScreen(roomId: rooms.first.id),
            ),
          );
        }
      } else {
        // No rooms available, create one
        final room = await _gameService.createRoom();
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MultiplayerGameScreen(roomId: room.id),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _error = 'Failed to join table');
    }

    setState(() {
      _isLoading = false;
      _loadingAction = null;
    });
  }

  Future<void> _joinHeadsUp(StakeLevel stake) async {
    if (!_authService.isLoggedIn) {
      setState(() => _error = 'Not connected. Please try again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingAction = 'Finding ${stake.name} duel...';
      _error = null;
    });

    try {
      final rooms = await _gameService.getAvailableRooms().first.timeout(
            const Duration(seconds: 10),
            onTimeout: () => <GameRoom>[],
          );

      if (rooms.isNotEmpty) {
        await _gameService.joinRoom(rooms.first.id);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MultiplayerGameScreen(roomId: rooms.first.id),
            ),
          );
        }
      } else {
        final room = await _gameService.createRoom();
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MultiplayerGameScreen(roomId: room.id),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _error = 'Failed to find duel');
    }

    setState(() {
      _isLoading = false;
      _loadingAction = null;
    });
  }

  Future<void> _joinSitAndGo(SitAndGoBuyIn buyIn) async {
    if (!_authService.isLoggedIn) {
      setState(() => _error = 'Not connected. Please try again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingAction = 'Joining ${buyIn.name} tournament...';
      _error = null;
    });

    try {
      final rooms = await _gameService.getAvailableSitAndGoRooms().first.timeout(
            const Duration(seconds: 10),
            onTimeout: () => <GameRoom>[],
          );

      if (rooms.isNotEmpty) {
        await _gameService.joinRoom(rooms.first.id);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MultiplayerGameScreen(roomId: rooms.first.id),
            ),
          );
        }
      } else {
        final room = await _gameService.createSitAndGoRoom();
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MultiplayerGameScreen(roomId: room.id),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _error = 'Failed to join tournament');
    }

    setState(() {
      _isLoading = false;
      _loadingAction = null;
    });
  }

  void _showCashGameDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          width: 340,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('💰', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Cash Games',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.5)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Select your stakes',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _cashGameStakes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final stake = _cashGameStakes[index];
                    return _StakeLevelCard(
                      stake: stake,
                      onTap: () {
                        Navigator.pop(context);
                        _joinCashGame(stake);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHeadsUpDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          width: 340,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('⚔️', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Heads-Up Duel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.5)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '1v1 winner takes all',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _headsUpStakes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final stake = _headsUpStakes[index];
                    return _HeadsUpCard(
                      stake: stake,
                      onTap: () {
                        Navigator.pop(context);
                        _joinHeadsUp(stake);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSitAndGoDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          width: 340,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Sit & Go',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.5)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '6 players • Winner takes all',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _sitAndGoBuyIns.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final buyIn = _sitAndGoBuyIns[index];
                    return _SitAndGoCard(
                      buyIn: buyIn,
                      onTap: () {
                        Navigator.pop(context);
                        _joinSitAndGo(buyIn);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Join Room',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the room code from your friend',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _roomCodeController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                letterSpacing: 4,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'XXXXXX',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  letterSpacing: 4,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _joinRoom(_roomCodeController.text.trim());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Join',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTournamentDetails(BuildContext context, String tournamentId) {
    final tournaments = {
      'daily_freeroll': {
        'title': 'Daily Freeroll',
        'prize': '10,000',
        'buyIn': 'FREE',
        'players': '24/100',
        'startsIn': '15 min',
        'blinds': '10 min levels',
        'structure': 'No Limit Hold\'em',
      },
      'high_roller': {
        'title': 'High Roller',
        'prize': '500,000',
        'buyIn': '50,000',
        'players': '8/20',
        'startsIn': '1 hr',
        'blinds': '15 min levels',
        'structure': 'No Limit Hold\'em',
      },
      'weekend_major': {
        'title': 'Weekend Major',
        'prize': '1,000,000',
        'buyIn': '10,000',
        'players': '156/500',
        'startsIn': 'Sat 8PM',
        'blinds': '20 min levels',
        'structure': 'No Limit Hold\'em',
      },
    };

    final t = tournaments[tournamentId]!;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('🏆', style: TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t['title']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t['structure']!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.5)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _tournamentInfoRow('Prize Pool', '🪙 ${t['prize']}'),
              _tournamentInfoRow('Buy-in', t['buyIn']!),
              _tournamentInfoRow('Players', t['players']!),
              _tournamentInfoRow('Starts', t['startsIn']!),
              _tournamentInfoRow('Blind Levels', t['blinds']!),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Registered for tournament!'),
                            backgroundColor: Color(0xFF4CAF50),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Register',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _tournamentInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showSpectateGame(BuildContext context, String gameId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text('👁️', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Spectate Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Watch the game without participating.\nCards will be hidden until showdown.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Joining as spectator...'),
                            backgroundColor: Color(0xFF2196F3),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Watch Game',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Stack(
          children: [
            SafeArea(
              child: CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Multiplayer',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4CAF50),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  '24 online',
                                  style: TextStyle(
                                    color: Color(0xFF4CAF50),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Featured - Cash Games
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CASH GAMES',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Cash Games - Featured
                          GestureDetector(
                            onTap: _showCashGameDialog,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Center(
                                      child: Text('💰', style: TextStyle(fontSize: 28)),
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Cash Games',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Choose your stakes',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.8),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Game Modes Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GAME MODES',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),

                  // Game Mode Cards
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _GameModeCard(
                          emoji: '⚔️',
                          title: 'Heads-Up Duel',
                          subtitle: '1v1 winner takes all',
                          tag: '2 Players',
                          tagColor: const Color(0xFF2196F3),
                          onTap: _showHeadsUpDialog,
                        ),
                        const SizedBox(height: 10),
                        _GameModeCard(
                          emoji: '🏆',
                          title: 'Sit & Go',
                          subtitle: '6 players tournament',
                          tag: 'Tournament',
                          tagColor: const Color(0xFFE91E63),
                          onTap: _showSitAndGoDialog,
                        ),
                      ]),
                    ),
                  ),

                  // Tournaments Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOURNAMENTS',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),

                  // Tournament Cards
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _TournamentCard(
                          title: 'Daily Freeroll',
                          prize: '10,000',
                          players: '24/100',
                          startsIn: '15 min',
                          buyIn: 'FREE',
                          isFeatured: true,
                          onTap: () => _showTournamentDetails(context, 'daily_freeroll'),
                        ),
                        const SizedBox(height: 10),
                        _TournamentCard(
                          title: 'High Roller',
                          prize: '500,000',
                          players: '8/20',
                          startsIn: '1 hr',
                          buyIn: '50,000',
                          onTap: () => _showTournamentDetails(context, 'high_roller'),
                        ),
                        const SizedBox(height: 10),
                        _TournamentCard(
                          title: 'Weekend Major',
                          prize: '1,000,000',
                          players: '156/500',
                          startsIn: 'Sat 8PM',
                          buyIn: '10,000',
                          isWeekend: true,
                          onTap: () => _showTournamentDetails(context, 'weekend_major'),
                        ),
                      ]),
                    ),
                  ),

                  // Error Display
                  if (_error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFFF4444).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFFF4444), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: Color(0xFFFF4444), fontSize: 14),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _error = null),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Bottom spacing
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 40),
                  ),
                ],
              ),
            ),

            // Loading Overlay
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFFD4AF37),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _loadingAction ?? 'Loading...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }
}

// ============================================================================
// STAKE LEVEL CARD (Cash Games)
// ============================================================================

class _StakeLevelCard extends StatelessWidget {
  final StakeLevel stake;
  final VoidCallback onTap;

  const _StakeLevelCard({required this.stake, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              stake.color.withValues(alpha: 0.15),
              stake.color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stake.color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: stake.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  stake.name[0],
                  style: TextStyle(
                    color: stake.color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stake.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Blinds: ${stake.blindsDisplay}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Buy-in',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stake.buyInDisplay,
                  style: TextStyle(
                    color: stake.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HEADS-UP CARD
// ============================================================================

class _HeadsUpCard extends StatelessWidget {
  final StakeLevel stake;
  final VoidCallback onTap;

  const _HeadsUpCard({required this.stake, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              stake.color.withValues(alpha: 0.15),
              stake.color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stake.color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: stake.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('⚔️', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stake.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Blinds: ${stake.blindsDisplay}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: stake.color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                StakeLevel._formatNumber(stake.minBuyIn),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SIT & GO CARD
// ============================================================================

class _SitAndGoCard extends StatelessWidget {
  final SitAndGoBuyIn buyIn;
  final VoidCallback onTap;

  const _SitAndGoCard({required this.buyIn, required this.onTap});

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              buyIn.color.withValues(alpha: 0.15),
              buyIn.color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: buyIn.color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: buyIn.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('🏆', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    buyIn.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('🏅', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        'Prize: ${_formatNumber(buyIn.prizePool)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: buyIn.buyIn == 0 ? const Color(0xFF4CAF50) : buyIn.color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                buyIn.buyIn == 0 ? 'FREE' : _formatNumber(buyIn.buyIn),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GAME MODE CARD
// ============================================================================

class _GameModeCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String tag;
  final Color tagColor;
  final VoidCallback onTap;

  const _GameModeCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.tagColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  color: tagColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TOURNAMENT CARD
// ============================================================================

class _TournamentCard extends StatelessWidget {
  final String title;
  final String prize;
  final String players;
  final String startsIn;
  final String buyIn;
  final bool isFeatured;
  final bool isWeekend;
  final VoidCallback onTap;

  const _TournamentCard({
    required this.title,
    required this.prize,
    required this.players,
    required this.startsIn,
    required this.buyIn,
    this.isFeatured = false,
    this.isWeekend = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: isFeatured
              ? const LinearGradient(
                  colors: [Color(0xFF1A3A1A), Color(0xFF0D2010)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : isWeekend
                  ? const LinearGradient(
                      colors: [Color(0xFF3A1A3A), Color(0xFF20102A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
          color: isFeatured || isWeekend ? null : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isFeatured
                ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                : isWeekend
                    ? const Color(0xFF9C27B0).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isFeatured
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                        : isWeekend
                            ? const Color(0xFF9C27B0).withValues(alpha: 0.2)
                            : const Color(0xFFD4AF37).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      isFeatured ? '🎁' : isWeekend ? '👑' : '🏆',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isFeatured) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'FREE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$players players • Starts in $startsIn',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          prize,
                          style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Buy-in: $buyIn',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SPECTATE CARD
// ============================================================================

class _SpectateCard extends StatelessWidget {
  final String playerName;
  final String stakes;
  final int viewers;
  final bool isLive;
  final VoidCallback onTap;

  const _SpectateCard({
    required this.playerName,
    required this.stakes,
    required this.viewers,
    this.isLive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('👁️', style: TextStyle(fontSize: 22)),
                  ),
                ),
                if (isLive)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE91E63),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF0D0D0D), width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        playerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isLive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE91E63),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stakes: $stakes',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Icon(Icons.visibility, color: Colors.white.withValues(alpha: 0.4), size: 16),
                const SizedBox(width: 4),
                Text(
                  '$viewers',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }
}
