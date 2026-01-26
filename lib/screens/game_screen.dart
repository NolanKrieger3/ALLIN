import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/mobile_wrapper.dart';

class GameScreen extends StatefulWidget {
  final String gameMode;
  
  const GameScreen({
    super.key,
    required this.gameMode,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Game state
  int _pot = 0;
  int _playerChips = 50000;
  int _currentBet = 0;
  final int _bigBlind = 100;
  bool _isPlayerTurn = true;
  String _gamePhase = 'preflop'; // preflop, flop, turn, river, showdown
  
  // Cards
  List<PlayingCard> _playerCards = [];
  List<PlayingCard> _communityCards = [];
  List<PlayingCard> _deck = [];
  
  // Opponent
  int _opponentChips = 50000;
  List<PlayingCard> _opponentCards = [];
  bool _showOpponentCards = false;

  @override
  void initState() {
    super.initState();
    _startNewHand();
  }

  void _startNewHand() {
    setState(() {
      _deck = _createDeck();
      _deck.shuffle(Random());
      
      _playerCards = [_deck.removeLast(), _deck.removeLast()];
      _opponentCards = [_deck.removeLast(), _deck.removeLast()];
      _communityCards = [];
      
      _pot = _bigBlind + (_bigBlind ~/ 2); // Big blind + small blind
      _playerChips -= _bigBlind ~/ 2; // Player is small blind
      _opponentChips -= _bigBlind; // Opponent is big blind
      _currentBet = _bigBlind;
      _gamePhase = 'preflop';
      _isPlayerTurn = true;
      _showOpponentCards = false;
    });
  }

  List<PlayingCard> _createDeck() {
    List<PlayingCard> deck = [];
    for (var suit in ['♠', '♥', '♣', '♦']) {
      for (var rank in ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K']) {
        deck.add(PlayingCard(rank: rank, suit: suit));
      }
    }
    return deck;
  }

  void _dealCommunityCards() {
    setState(() {
      if (_gamePhase == 'preflop') {
        // Flop - deal 3 cards
        _communityCards = [
          _deck.removeLast(),
          _deck.removeLast(),
          _deck.removeLast(),
        ];
        _gamePhase = 'flop';
      } else if (_gamePhase == 'flop') {
        // Turn - deal 1 card
        _communityCards.add(_deck.removeLast());
        _gamePhase = 'turn';
      } else if (_gamePhase == 'turn') {
        // River - deal 1 card
        _communityCards.add(_deck.removeLast());
        _gamePhase = 'river';
      }
      _currentBet = 0;
      _isPlayerTurn = true;
    });
  }

  void _playerAction(String action, {int? amount}) {
    if (!_isPlayerTurn) return;
    
    setState(() {
      switch (action) {
        case 'fold':
          _endHand(playerWins: false);
          break;
        case 'check':
          if (_currentBet == 0) {
            _opponentTurn();
          }
          break;
        case 'call':
          int callAmount = _currentBet;
          _playerChips -= callAmount;
          _pot += callAmount;
          _opponentTurn();
          break;
        case 'raise':
          int raiseAmount = amount ?? _bigBlind * 2;
          _playerChips -= raiseAmount;
          _pot += raiseAmount;
          _currentBet = raiseAmount;
          _opponentTurn();
          break;
        case 'allin':
          _pot += _playerChips;
          _playerChips = 0;
          _opponentTurn();
          break;
      }
    });
  }

  void _opponentTurn() {
    setState(() {
      _isPlayerTurn = false;
    });
    
    // Simulate opponent thinking
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      
      // Simple AI - random decision
      final random = Random();
      final decision = random.nextInt(100);
      
      setState(() {
        if (decision < 10) {
          // Fold 10% of the time
          _endHand(playerWins: true);
        } else if (decision < 50) {
          // Check/Call 40% of the time
          if (_currentBet > 0) {
            _opponentChips -= _currentBet;
            _pot += _currentBet;
          }
          _advancePhase();
        } else {
          // Raise 50% of the time
          int raiseAmount = _bigBlind * (random.nextInt(3) + 1);
          _opponentChips -= raiseAmount;
          _pot += raiseAmount;
          _currentBet = raiseAmount;
          _isPlayerTurn = true;
        }
      });
    });
  }

  void _advancePhase() {
    if (_gamePhase == 'river') {
      _showdown();
    } else {
      _dealCommunityCards();
    }
  }

  void _showdown() {
    setState(() {
      _showOpponentCards = true;
      _gamePhase = 'showdown';
      
      // Simple winner determination (random for now)
      bool playerWins = Random().nextBool();
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _endHand(playerWins: playerWins);
        }
      });
    });
  }

  void _endHand({required bool playerWins}) {
    setState(() {
      if (playerWins) {
        _playerChips += _pot;
      } else {
        _opponentChips += _pot;
      }
      _pot = 0;
    });
    
    // Show result and start new hand
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(playerWins ? 'You win!' : 'Opponent wins'),
        backgroundColor: playerWins ? Colors.green.shade800 : Colors.red.shade800,
        duration: const Duration(seconds: 2),
      ),
    );
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _startNewHand();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MobileWrapper(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              _buildTopBar(),
              
              // Game table
              Expanded(
                child: _buildGameTable(),
              ),
              
              // Player cards and actions
              _buildPlayerArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            widget.gameMode,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  _formatChips(_playerChips),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameTable() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Opponent area
          _buildOpponentArea(),
          
          const Spacer(),
          
          // Community cards
          _buildCommunityCards(),
          
          // Pot
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pot: ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                Text(
                  _formatChips(_pot),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildOpponentArea() {
    return Column(
      children: [
        // Opponent info
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white54,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Opponent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatChips(_opponentChips),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Opponent cards
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_opponentCards.isNotEmpty) ...[
              _buildCard(_opponentCards[0], faceDown: !_showOpponentCards),
              const SizedBox(width: 8),
              _buildCard(_opponentCards[1], faceDown: !_showOpponentCards),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCommunityCards() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 5; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          if (i < _communityCards.length)
            _buildCard(_communityCards[i])
          else
            _buildEmptyCardSlot(),
        ],
      ],
    );
  }

  Widget _buildPlayerArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Column(
        children: [
          // Player cards
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_playerCards.isNotEmpty) ...[
                _buildCard(_playerCards[0], isLarge: true),
                const SizedBox(width: 12),
                _buildCard(_playerCards[1], isLarge: true),
              ],
            ],
          ),
          const SizedBox(height: 20),
          // Action buttons
          if (_isPlayerTurn && _gamePhase != 'showdown')
            _buildActionButtons()
          else if (!_isPlayerTurn)
            Text(
              'Opponent is thinking...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          label: 'Fold',
          color: Colors.red.shade400,
          onTap: () => _playerAction('fold'),
        ),
        if (_currentBet == 0)
          _ActionButton(
            label: 'Check',
            color: Colors.white,
            onTap: () => _playerAction('check'),
          )
        else
          _ActionButton(
            label: 'Call ${_formatChips(_currentBet)}',
            color: Colors.white,
            onTap: () => _playerAction('call'),
          ),
        _ActionButton(
          label: 'Raise',
          color: Colors.green.shade400,
          onTap: () => _playerAction('raise', amount: _bigBlind * 2),
        ),
      ],
    );
  }

  Widget _buildCard(PlayingCard card, {bool faceDown = false, bool isLarge = false}) {
    final isRed = card.suit == '♥' || card.suit == '♦';
    final width = isLarge ? 70.0 : 50.0;
    final height = isLarge ? 100.0 : 72.0;
    
    if (faceDown) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Center(
          child: Text(
            '🂠',
            style: TextStyle(fontSize: isLarge ? 32 : 24),
          ),
        ),
      );
    }
    
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
              color: isRed ? Colors.red.shade600 : Colors.black,
              fontSize: isLarge ? 22 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            card.suit,
            style: TextStyle(
              color: isRed ? Colors.red.shade600 : Colors.black,
              fontSize: isLarge ? 20 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCardSlot() {
    return Container(
      width: 50,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
    );
  }

  String _formatChips(int chips) {
    if (chips >= 1000000) {
      return '${(chips / 1000000).toStringAsFixed(1)}M';
    } else if (chips >= 1000) {
      return '${(chips / 1000).toStringAsFixed(1)}K';
    }
    return chips.toString();
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWhite = color == Colors.white;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isWhite ? Colors.white : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
          border: isWhite ? null : Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isWhite ? Colors.black : color,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class PlayingCard {
  final String rank;
  final String suit;

  PlayingCard({required this.rank, required this.suit});
  
  @override
  String toString() => '$rank$suit';
}
