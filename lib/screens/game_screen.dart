import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/mobile_wrapper.dart';

// Bot class to manage individual bot state
class Bot {
  final int id;
  final String name;
  int chips;
  List<PlayingCard> cards;
  int currentBet;
  bool hasFolded;
  bool hasActed;
  String? lastAction;

  Bot({
    required this.id,
    required this.name,
    this.chips = 50000,
    List<PlayingCard>? cards,
    this.currentBet = 0,
    this.hasFolded = false,
    this.hasActed = false,
    this.lastAction,
  }) : cards = cards ?? [];

  void reset() {
    cards = [];
    currentBet = 0;
    hasFolded = false;
    hasActed = false;
    lastAction = null;
  }

  bool get isAllIn => chips == 0 && !hasFolded;
  bool get isActive => !hasFolded && chips >= 0;
}

class GameScreen extends StatefulWidget {
  final String gameMode;

  const GameScreen({
    super.key,
    required this.gameMode,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Game settings
  bool _gameStarted = false;
  int _numberOfBots = 1;
  String _difficulty = 'Medium'; // Easy, Medium, Hard

  // Game state
  int _pot = 0;
  int _playerChips = 50000;
  int _playerBet = 0; // Player's current bet this round
  int _currentBet = 0; // The current bet to match
  int _lastRaiseAmount = 0; // For minimum raise calculation
  final int _bigBlind = 100;
  bool _isPlayerTurn = true;
  String _gamePhase = 'preflop'; // preflop, flop, turn, river, showdown
  int _dealerPosition = 0; // 0 = player, 1+ = bots
  bool _bbHasOption = true; // Big blind's option to raise preflop
  bool _playerHasActed = false; // Track if player has acted this betting round
  bool _playerHasFolded = false; // Track if player has folded
  int _currentActorIndex = 0; // Index of current actor (0 = player, 1+ = bot index + 1)

  // Cards
  List<PlayingCard> _playerCards = [];
  List<PlayingCard> _communityCards = [];
  List<PlayingCard> _deck = [];

  // Bots
  List<Bot> _bots = [];
  bool _showBotCards = false;
  String _winnerDescription = '';

  // Fold animation
  late AnimationController _foldAnimationController;
  late Animation<Offset> _foldSlideAnimation;
  late Animation<double> _foldOpacityAnimation;
  bool _isFolding = false;
  double _dragOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _foldAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _foldSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -2),
    ).animate(CurvedAnimation(
      parent: _foldAnimationController,
      curve: Curves.easeInBack,
    ));
    _foldOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _foldAnimationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _foldAnimationController.dispose();
    super.dispose();
  }

  /// Animate cards flying away then trigger fold action
  Future<void> _animateFold() async {
    if (_isFolding) return;
    setState(() => _isFolding = true);

    await _foldAnimationController.forward();
    _playerAction('fold');

    // Reset animation for next hand
    _foldAnimationController.reset();
    if (mounted) setState(() => _isFolding = false);
  }

  void _showGameSettingsDialog() {
    int selectedBots = _numberOfBots;
    String selectedDifficulty = _difficulty;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
            ),
          ),
          title: const Row(
            children: [
              Icon(Icons.settings, color: Color(0xFFD4AF37)),
              SizedBox(width: 12),
              Text(
                'Game Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Number of Bots
              const Text(
                'Number of Opponents',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [1, 2, 3, 4, 5].map((num) {
                  final isSelected = selectedBots == num;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() => selectedBots = num);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFD4AF37) : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFD4AF37) : Colors.white.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$num',
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // Difficulty
              const Text(
                'Bot Difficulty',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: ['Easy', 'Medium', 'Hard'].map((diff) {
                  final isSelected = selectedDifficulty == diff;
                  Color diffColor;
                  switch (diff) {
                    case 'Easy':
                      diffColor = Colors.green;
                      break;
                    case 'Medium':
                      diffColor = Colors.orange;
                      break;
                    case 'Hard':
                      diffColor = Colors.red;
                      break;
                    default:
                      diffColor = Colors.grey;
                  }
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setDialogState(() => selectedDifficulty = diff);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? diffColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? diffColor : Colors.white.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              diff == 'Easy'
                                  ? Icons.sentiment_satisfied
                                  : diff == 'Medium'
                                      ? Icons.sentiment_neutral
                                      : Icons.sentiment_very_dissatisfied,
                              color: isSelected ? diffColor : Colors.white54,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              diff,
                              style: TextStyle(
                                color: isSelected ? diffColor : Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Difficulty description
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white38, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedDifficulty == 'Easy'
                            ? 'Bots play passively and make mistakes often.'
                            : selectedDifficulty == 'Medium'
                                ? 'Bots play a balanced style with some bluffs.'
                                : 'Bots play aggressively and rarely make mistakes.',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _numberOfBots = selectedBots;
                  _difficulty = selectedDifficulty;
                  _gameStarted = true;
                });
                _startNewHand();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Start Game',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _initializeBots() {
    _bots = List.generate(
        _numberOfBots,
        (index) => Bot(
              id: index,
              name: 'Bot ${index + 1}',
              chips: 50000,
            ));
  }

  int _getTotalPlayers() => 1 + _bots.length; // Player + bots

  // Get position index relative to dealer (0 = dealer, 1 = SB, 2 = BB, etc.)
  int _getPositionFromDealer(int seatIndex) {
    final totalPlayers = _getTotalPlayers();
    return (seatIndex - _dealerPosition + totalPlayers) % totalPlayers;
  }

  // Get seat index from position relative to dealer
  int _getSeatFromPosition(int position) {
    final totalPlayers = _getTotalPlayers();
    return (_dealerPosition + position) % totalPlayers;
  }

  // Get list of active players (not folded and have chips or are all-in)
  List<int> _getActivePlayers() {
    List<int> active = [];
    if (!_playerHasFolded) active.add(0);
    for (int i = 0; i < _bots.length; i++) {
      if (_bots[i].isActive) active.add(i + 1);
    }
    return active;
  }

  void _startNewHand() {
    // Initialize bots if not done
    if (_bots.isEmpty) {
      _initializeBots();
    }

    setState(() {
      _deck = _createDeck();
      _deck.shuffle(Random());

      // Reset player state
      _playerCards = [_deck.removeLast(), _deck.removeLast()];
      _playerBet = 0;
      _playerHasActed = false;
      _playerHasFolded = false;

      // Reset and deal to bots
      for (var bot in _bots) {
        bot.reset();
        if (bot.chips > 0) {
          bot.cards = [_deck.removeLast(), _deck.removeLast()];
        }
      }

      _communityCards = [];

      // Rotate dealer position each hand
      _dealerPosition = (_dealerPosition + 1) % _getTotalPlayers();

      // Post blinds based on positions
      final smallBlind = _bigBlind ~/ 2;
      final totalPlayers = _getTotalPlayers();

      // In heads-up (2 players): dealer = SB, other = BB
      // In 3+ players: dealer, then SB, then BB
      int sbSeat, bbSeat;
      if (totalPlayers == 2) {
        sbSeat = _dealerPosition;
        bbSeat = (_dealerPosition + 1) % totalPlayers;
      } else {
        sbSeat = (_dealerPosition + 1) % totalPlayers;
        bbSeat = (_dealerPosition + 2) % totalPlayers;
      }

      // Post small blind
      if (sbSeat == 0) {
        int sb = smallBlind > _playerChips ? _playerChips : smallBlind;
        _playerBet = sb;
        _playerChips -= sb;
        _pot = sb;
      } else {
        final bot = _bots[sbSeat - 1];
        int sb = smallBlind > bot.chips ? bot.chips : smallBlind;
        bot.currentBet = sb;
        bot.chips -= sb;
        _pot = sb;
      }

      // Post big blind
      if (bbSeat == 0) {
        int bb = _bigBlind > _playerChips ? _playerChips : _bigBlind;
        _playerBet = bb;
        _playerChips -= bb;
        _pot += bb;
        _currentBet = bb > _playerBet ? bb : _playerBet;
      } else {
        final bot = _bots[bbSeat - 1];
        int bb = _bigBlind > bot.chips ? bot.chips : _bigBlind;
        bot.currentBet = bb;
        bot.chips -= bb;
        _pot += bb;
        _currentBet = bb;
      }

      // Ensure currentBet is at least the big blind
      if (_currentBet < _bigBlind) _currentBet = _bigBlind;

      _lastRaiseAmount = _bigBlind;
      _gamePhase = 'preflop';
      _showBotCards = false;
      _winnerDescription = '';
      _bbHasOption = true;

      // First to act preflop is left of BB (UTG)
      // In heads-up: SB (dealer) acts first preflop
      int firstToAct;
      if (totalPlayers == 2) {
        firstToAct = sbSeat;
      } else {
        firstToAct = (bbSeat + 1) % totalPlayers;
      }

      _currentActorIndex = firstToAct;
      _isPlayerTurn = firstToAct == 0;

      // If it's a bot's turn, start their action
      if (!_isPlayerTurn) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _botTurn(_currentActorIndex - 1);
        });
      }
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
        // Burn one card, then deal flop (3 cards)
        _deck.removeLast(); // Burn
        _communityCards = [
          _deck.removeLast(),
          _deck.removeLast(),
          _deck.removeLast(),
        ];
        _gamePhase = 'flop';
      } else if (_gamePhase == 'flop') {
        // Burn one card, then deal turn (1 card)
        _deck.removeLast(); // Burn
        _communityCards.add(_deck.removeLast());
        _gamePhase = 'turn';
      } else if (_gamePhase == 'turn') {
        // Burn one card, then deal river (1 card)
        _deck.removeLast(); // Burn
        _communityCards.add(_deck.removeLast());
        _gamePhase = 'river';
      }

      // Reset bets and action flags for new betting round
      _currentBet = 0;
      _playerBet = 0;
      _playerHasActed = false;
      for (var bot in _bots) {
        bot.currentBet = 0;
        bot.hasActed = false;
        bot.lastAction = null;
      }
      _lastRaiseAmount = _bigBlind; // Reset min raise to big blind

      // Post-flop: first active player left of dealer acts first
      final totalPlayers = _getTotalPlayers();
      int firstToAct = (_dealerPosition + 1) % totalPlayers;

      // Find first active player
      for (int i = 0; i < totalPlayers; i++) {
        int seat = (firstToAct + i) % totalPlayers;
        if (seat == 0 && !_playerHasFolded && _playerChips >= 0) {
          _currentActorIndex = 0;
          _isPlayerTurn = true;
          break;
        } else if (seat > 0 && _bots[seat - 1].isActive) {
          _currentActorIndex = seat;
          _isPlayerTurn = false;
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _botTurn(seat - 1);
          });
          break;
        }
      }
    });
  }

  void _playerAction(String action, {int? amount}) {
    if (!_isPlayerTurn || _playerHasFolded) return;

    setState(() {
      _playerHasActed = true; // Mark player as having acted

      switch (action) {
        case 'fold':
          _playerHasFolded = true;
          _checkForWinner();
          break;
        case 'check':
          // Can only check if current bet equals player's bet
          if (_currentBet <= _playerBet) {
            _bbHasOption = false; // BB used their option
            _moveToNextPlayer();
          }
          break;
        case 'call':
          // Call the difference between current bet and what player has already bet
          int callAmount = _currentBet - _playerBet;
          if (callAmount > _playerChips) {
            callAmount = _playerChips; // All-in if not enough
          }
          _playerChips -= callAmount;
          _playerBet += callAmount;
          _pot += callAmount;
          _moveToNextPlayer();
          break;
        case 'raise':
          // amount is the TOTAL bet they want to make
          int totalBet = amount ?? (_currentBet + _lastRaiseAmount);
          // Ensure minimum raise is respected
          int minRaise = _currentBet + _lastRaiseAmount;
          if (totalBet < minRaise && totalBet < _playerChips + _playerBet) {
            totalBet = minRaise;
          }
          int raiseBy = totalBet - _currentBet;
          int addAmount = totalBet - _playerBet;
          if (addAmount > _playerChips) {
            addAmount = _playerChips;
            totalBet = _playerBet + addAmount;
            raiseBy = totalBet - _currentBet;
          }
          _playerChips -= addAmount;
          _playerBet = totalBet;
          _pot += addAmount;
          _lastRaiseAmount = raiseBy > 0 ? raiseBy : _bigBlind;
          _currentBet = totalBet;
          _bbHasOption = false;
          // Reset all other players' acted flags since there's a new bet to respond to
          for (var bot in _bots) {
            if (bot.isActive && !bot.isAllIn) {
              bot.hasActed = false;
            }
          }
          _moveToNextPlayer();
          break;
        case 'allin':
          int allInAmount = _playerChips;
          int newTotalBet = _playerBet + allInAmount;
          _pot += allInAmount;
          _playerBet = newTotalBet;
          _playerChips = 0;
          // If this is a raise, update the current bet and last raise
          if (newTotalBet > _currentBet) {
            int raiseBy = newTotalBet - _currentBet;
            if (raiseBy >= _lastRaiseAmount) {
              _lastRaiseAmount = raiseBy;
            }
            _currentBet = newTotalBet;
            _bbHasOption = false;
            // Reset all other players' acted flags
            for (var bot in _bots) {
              if (bot.isActive && !bot.isAllIn) {
                bot.hasActed = false;
              }
            }
          }
          _moveToNextPlayer();
          break;
      }
    });
  }

  void _checkForWinner() {
    // Check if only one player remains
    final activePlayers = _getActivePlayers();
    if (activePlayers.length == 1) {
      final winner = activePlayers[0];
      if (winner == 0) {
        _endHand(winnerSeat: 0);
      } else {
        _endHand(winnerSeat: winner);
      }
    } else {
      _moveToNextPlayer();
    }
  }

  void _moveToNextPlayer() {
    final totalPlayers = _getTotalPlayers();

    // Find next active player who needs to act
    for (int i = 1; i <= totalPlayers; i++) {
      int nextSeat = (_currentActorIndex + i) % totalPlayers;

      if (nextSeat == 0) {
        // Player's turn
        if (!_playerHasFolded && _playerChips > 0) {
          if (!_playerHasActed || _playerBet < _currentBet) {
            setState(() {
              _currentActorIndex = 0;
              _isPlayerTurn = true;
            });
            return;
          }
        }
      } else {
        // Bot's turn
        final bot = _bots[nextSeat - 1];
        if (bot.isActive && !bot.isAllIn) {
          if (!bot.hasActed || bot.currentBet < _currentBet) {
            setState(() {
              _currentActorIndex = nextSeat;
              _isPlayerTurn = false;
            });
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) _botTurn(nextSeat - 1);
            });
            return;
          }
        }
      }
    }

    // If we get here, betting round is complete
    _checkBettingRoundComplete();
  }

  void _botTurn(int botIndex) {
    if (botIndex < 0 || botIndex >= _bots.length) return;

    final bot = _bots[botIndex];
    if (bot.hasFolded || bot.isAllIn) {
      _moveToNextPlayer();
      return;
    }

    setState(() {
      _isPlayerTurn = false;
      bot.lastAction = null; // Clear previous action while thinking
    });

    // Simulate bot thinking - harder bots think faster
    final thinkTime = _difficulty == 'Easy'
        ? 1200
        : _difficulty == 'Medium'
            ? 800
            : 500;

    Future.delayed(Duration(milliseconds: thinkTime), () {
      if (!mounted) return;

      final random = Random();
      final callAmount = _currentBet - bot.currentBet;
      final canCheck = callAmount <= 0;

      // AI decision based on difficulty
      int foldThreshold;
      int callThreshold;
      int raiseMultiplierMax;

      switch (_difficulty) {
        case 'Easy':
          foldThreshold = 20;
          callThreshold = 85;
          raiseMultiplierMax = 2;
          break;
        case 'Hard':
          foldThreshold = 5;
          callThreshold = 45;
          raiseMultiplierMax = 5;
          break;
        default: // Medium
          foldThreshold = 10;
          callThreshold = 60;
          raiseMultiplierMax = 3;
      }

      final decision = random.nextInt(100);

      setState(() {
        bot.hasActed = true;

        if (decision < foldThreshold && !canCheck) {
          // Fold
          bot.lastAction = 'FOLD';
          bot.hasFolded = true;
          _checkForWinner();
        } else if (decision < callThreshold || canCheck) {
          // Check/Call
          if (callAmount > 0) {
            int actualCall = callAmount;
            if (actualCall > bot.chips) {
              actualCall = bot.chips;
              bot.lastAction = 'ALL-IN';
            } else {
              bot.lastAction = 'CALL';
            }
            bot.chips -= actualCall;
            bot.currentBet += actualCall;
            _pot += actualCall;
          } else {
            bot.lastAction = 'CHECK';
          }
          _bbHasOption = false;
          _moveToNextPlayer();
        } else {
          // Raise
          int minRaise = _currentBet + _lastRaiseAmount;
          int raiseMultiplier = random.nextInt(raiseMultiplierMax) + 1;
          int totalBet = minRaise + (_bigBlind * raiseMultiplier);
          if (totalBet > bot.chips + bot.currentBet) {
            totalBet = bot.chips + bot.currentBet;
          }
          int addAmount = totalBet - bot.currentBet;
          int raiseBy = totalBet - _currentBet;

          bot.chips -= addAmount;
          bot.currentBet = totalBet;
          _pot += addAmount;
          if (raiseBy >= _lastRaiseAmount) {
            _lastRaiseAmount = raiseBy;
          }
          _currentBet = totalBet;
          _bbHasOption = false;

          // Reset all other players' acted flags
          _playerHasActed = false;
          for (var otherBot in _bots) {
            if (otherBot.id != bot.id && otherBot.isActive && !otherBot.isAllIn) {
              otherBot.hasActed = false;
            }
          }

          if (bot.chips == 0) {
            bot.lastAction = 'ALL-IN';
          } else {
            bot.lastAction = 'RAISE';
          }

          _moveToNextPlayer();
        }
      });
    });
  }

  void _checkBettingRoundComplete() {
    // Check if all active players are all-in or have matched the bet
    final activePlayers = _getActivePlayers();

    if (activePlayers.length <= 1) {
      // Only one player left, they win
      if (activePlayers.isNotEmpty) {
        _endHand(winnerSeat: activePlayers[0]);
      }
      return;
    }

    // Check if everyone is all-in or has matched
    bool allMatched = true;
    int playersCanAct = 0;

    for (int seat in activePlayers) {
      if (seat == 0) {
        if (_playerChips > 0) playersCanAct++;
        if (_playerBet < _currentBet && _playerChips > 0) {
          allMatched = false;
        }
        if (!_playerHasActed && _playerChips > 0) {
          allMatched = false;
        }
      } else {
        final bot = _bots[seat - 1];
        if (bot.chips > 0) playersCanAct++;
        if (bot.currentBet < _currentBet && bot.chips > 0) {
          allMatched = false;
        }
        if (!bot.hasActed && bot.chips > 0) {
          allMatched = false;
        }
      }
    }

    // If everyone is all-in (no one can act), go to showdown
    if (playersCanAct == 0) {
      _dealToShowdown();
      return;
    }

    if (allMatched) {
      // Special case: preflop BB option
      if (_gamePhase == 'preflop' && _bbHasOption) {
        _bbHasOption = false;
        // Find BB and give them option
        final totalPlayers = _getTotalPlayers();
        int bbSeat = totalPlayers == 2 ? (_dealerPosition + 1) % totalPlayers : (_dealerPosition + 2) % totalPlayers;

        if (bbSeat == 0 && !_playerHasFolded && _playerChips > 0) {
          setState(() {
            _currentActorIndex = 0;
            _isPlayerTurn = true;
            _playerHasActed = false;
          });
          return;
        } else if (bbSeat > 0 && _bots[bbSeat - 1].isActive && _bots[bbSeat - 1].chips > 0) {
          _bots[bbSeat - 1].hasActed = false;
          _currentActorIndex = bbSeat;
          _isPlayerTurn = false;
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _botTurn(bbSeat - 1);
          });
          return;
        }
      }

      // Advance to next phase
      _advancePhase();
    }
  }

  void _dealToShowdown() {
    setState(() {
      // Deal remaining community cards based on current phase
      switch (_gamePhase) {
        case 'preflop':
          // Burn + flop
          _deck.removeLast();
          _communityCards = [
            _deck.removeLast(),
            _deck.removeLast(),
            _deck.removeLast(),
          ];
          // Burn + turn
          _deck.removeLast();
          _communityCards.add(_deck.removeLast());
          // Burn + river
          _deck.removeLast();
          _communityCards.add(_deck.removeLast());
          break;
        case 'flop':
          // Burn + turn
          _deck.removeLast();
          _communityCards.add(_deck.removeLast());
          // Burn + river
          _deck.removeLast();
          _communityCards.add(_deck.removeLast());
          break;
        case 'turn':
          // Burn + river
          _deck.removeLast();
          _communityCards.add(_deck.removeLast());
          break;
      }
      _showBotCards = true;
      _gamePhase = 'showdown';
    });

    // Short delay then go to showdown
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showdown();
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
      _showBotCards = true;
      _gamePhase = 'showdown';

      // Evaluate all active hands
      final activePlayers = _getActivePlayers();
      Map<int, _EvaluatedHand> hands = {};

      for (int seat in activePlayers) {
        if (seat == 0) {
          hands[0] = _evaluateBestHand(_playerCards, _communityCards);
        } else {
          final bot = _bots[seat - 1];
          hands[seat] = _evaluateBestHand(bot.cards, _communityCards);
        }
      }

      // Find best hand(s)
      int? bestSeat;
      _EvaluatedHand? bestHand;
      List<int> winners = [];

      for (var entry in hands.entries) {
        if (bestHand == null || entry.value.compareTo(bestHand) > 0) {
          bestHand = entry.value;
          bestSeat = entry.key;
          winners = [entry.key];
        } else if (entry.value.compareTo(bestHand) == 0) {
          winners.add(entry.key);
        }
      }

      if (winners.length == 1) {
        final winner = winners[0];
        if (winner == 0) {
          _winnerDescription = 'You win with ${bestHand!.description}!';
        } else {
          _winnerDescription = '${_bots[winner - 1].name} wins with ${bestHand!.description}';
        }
      } else {
        _winnerDescription = 'Split pot! ${winners.length} players tie with ${bestHand!.description}';
      }

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          if (winners.length == 1) {
            _endHand(winnerSeat: winners[0]);
          } else {
            _splitPot(winners);
          }
        }
      });
    });
  }

  void _splitPot(List<int> winners) {
    setState(() {
      final share = _pot ~/ winners.length;
      final oddChips = _pot % winners.length;

      for (int i = 0; i < winners.length; i++) {
        int seat = winners[i];
        int amount = share + (i == 0 ? oddChips : 0); // First winner gets odd chips

        if (seat == 0) {
          _playerChips += amount;
        } else {
          _bots[seat - 1].chips += amount;
        }
      }
      _pot = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_winnerDescription),
        backgroundColor: Colors.orange.shade800,
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkGameOver();
      }
    });
  }

  void _endHand({required int winnerSeat}) {
    setState(() {
      if (winnerSeat == 0) {
        _playerChips += _pot;
      } else {
        _bots[winnerSeat - 1].chips += _pot;
      }
      _pot = 0;
    });

    // Show result and start new hand
    String message;
    if (winnerSeat == 0) {
      message = 'You win!';
    } else {
      message = '${_bots[winnerSeat - 1].name} wins!';
    }
    if (_winnerDescription.isNotEmpty) {
      message = _winnerDescription;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: winnerSeat == 0 ? Colors.green.shade800 : Colors.red.shade800,
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkGameOver();
      }
    });
  }

  void _checkGameOver() {
    // Remove bots with no chips
    final activeBots = _bots.where((b) => b.chips > 0).toList();

    if (_playerChips <= 0) {
      _showGameOver(false);
    } else if (activeBots.isEmpty) {
      _showGameOver(true);
    } else {
      _startNewHand();
    }
  }

  void _showGameOver(bool playerWon) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          playerWon ? '🏆 YOU WIN!' : '💀 GAME OVER',
          style: TextStyle(
            color: playerWon ? Colors.green : Colors.red,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          playerWon ? 'Congratulations! You\'ve eliminated all opponents!' : 'You\'ve run out of chips.',
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Exit'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _playerChips = 50000;
                _dealerPosition = 0;
                _bots.clear();
                _initializeBots();
              });
              _startNewHand();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
            ),
            child: const Text('Play Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupScreen() {
    // Difficulty labels for display
    final difficultyLabels = {
      'Easy': 'BEGINNER',
      'Medium': 'INTERMEDIATE',
      'Hard': 'EXPERT',
    };

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

                const Spacer(flex: 1),

                // Opponents display
                Text(
                  '$_numberOfBots',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _numberOfBots == 1 ? 'OPPONENT' : 'OPPONENTS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 24),

                // Difficulty display
                Text(
                  difficultyLabels[_difficulty] ?? _difficulty.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'DIFFICULTY',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 3,
                  ),
                ),

                const SizedBox(height: 48),

                // Opponents Slider
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
                    value: _numberOfBots.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    onChanged: (value) {
                      setState(() => _numberOfBots = value.round());
                    },
                  ),
                ),

                // Min/Max labels for opponents
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '5',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Difficulty selection
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['Easy', 'Medium', 'Hard'].map((diff) {
                    final isSelected = _difficulty == diff;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _difficulty = diff);
                      },
                      child: Container(
                        width: 80,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            diff,
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF0A0A0A) : Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const Spacer(flex: 2),

                // Play button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _gameStarted = true;
                    });
                    _startNewHand();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
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

  @override
  Widget build(BuildContext context) {
    // Show setup screen until user taps Play
    if (!_gameStarted) {
      return _buildSetupScreen();
    }

    return MobileWrapper(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              _buildTopBar(),

              // Players row
              _buildPlayersRow(),

              const Spacer(flex: 2),

              // Community cards with pot
              _buildCommunityCardsWithPot(),

              const Spacer(flex: 3),

              // Action area
              _buildActionArea(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          ),
          const Spacer(),
          // Online/AI indicator
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, color: Color(0xFF22C55E), size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersRow() {
    // Build list with only bots (opponents) - player is shown at bottom
    final allParticipants = <_Participant>[
      ...List.generate(
          _bots.length,
          (i) => _Participant(
                name: _bots[i].name,
                chips: _bots[i].chips,
                currentBet: _bots[i].currentBet,
                hasFolded: _bots[i].hasFolded,
                isCurrentTurn: _currentActorIndex == i + 1 && _gamePhase != 'showdown',
                isPlayer: false,
                isDealer: _dealerPosition == i + 1,
              )),
    ];

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: allParticipants.map((p) => _buildParticipantAvatar(p)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantAvatar(_Participant p) {
    // Avatar emoji based on name
    String getAvatar(String name) {
      if (name == 'You') return '👤';
      final avatars = ['🤖', '🦊', '🐸', '🦁', '🐼'];
      final index = int.tryParse(name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      return avatars[(index - 1) % avatars.length];
    }

    Color? borderColor;
    if (p.isCurrentTurn) {
      borderColor = const Color(0xFFD4AF37);
    }

    return Container(
      width: 72,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.hasFolded ? Colors.grey.shade800 : Colors.white.withValues(alpha: 0.1),
                  border: borderColor != null ? Border.all(color: borderColor, width: 3) : null,
                ),
                child: Center(
                  child: Text(
                    getAvatar(p.name),
                    style: TextStyle(
                      fontSize: 24,
                      color: p.hasFolded ? Colors.grey : null,
                    ),
                  ),
                ),
              ),
              // Dealer badge
              if (p.isDealer)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('D',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
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
            p.name,
            style: TextStyle(
              color: p.hasFolded ? Colors.grey : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          // Chips on one line
          Text(
            p.currentBet > 0 ? '${_formatChips(p.chips)} (${_formatChips(p.currentBet)})' : _formatChips(p.chips),
            style: TextStyle(
              color: p.hasFolded ? Colors.grey : Colors.yellow.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityCardsWithPot() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: i < _communityCards.length ? _buildMinimalCard(_communityCards[i]) : _buildEmptyCardSlot(),
              ),
            const SizedBox(width: 16),
            // Pot amount
            Text(
              _pot.toString(),
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

  Widget _buildMinimalCard(PlayingCard card) {
    const width = 56.0;
    const height = 78.0;
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

  Widget _buildActionArea() {
    // If player folded or game is in showdown
    if (_playerHasFolded || _gamePhase == 'showdown') {
      return _buildWaitMessage();
    }

    // If player is all-in
    if (_playerChips == 0) {
      return _buildWaitMessage(message: 'All In');
    }

    // If it's player's turn, show action buttons
    if (_isPlayerTurn) {
      return _buildPlayerActionArea();
    }

    // Waiting for bots
    return _buildPlayerAreaWithCards();
  }

  Widget _buildWaitMessage({String? message}) {
    String displayMessage = message ?? (_playerHasFolded ? 'You folded' : 'Hand complete');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                displayMessage,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Player's cards
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
              _buildPlayerAvatar(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerActionArea() {
    final callAmount = _currentBet - _playerBet;
    final canCheck = callAmount <= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Action buttons row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _playerAction(canCheck ? 'check' : 'call'),
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
                  onTap: () {
                    final minRaise = _currentBet + _lastRaiseAmount;
                    _showRaiseSlider(minRaise);
                  },
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
              // Swipeable cards with fold animation
              GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(() {
                    _dragOffset += details.delta.dy;
                    // Clamp to only allow upward drag
                    if (_dragOffset > 0) _dragOffset = 0;
                  });
                },
                onVerticalDragEnd: (details) {
                  // If swiped up enough (past threshold), trigger fold
                  if (_dragOffset < -80) {
                    _animateFold();
                  }
                  // Reset drag offset
                  setState(() => _dragOffset = 0);
                },
                child: _isFolding
                    ? SlideTransition(
                        position: _foldSlideAnimation,
                        child: FadeTransition(
                          opacity: _foldOpacityAnimation,
                          child: _buildPlayerCards(),
                        ),
                      )
                    : Transform.translate(
                        offset: Offset(0, _dragOffset * 0.5),
                        child: Opacity(
                          opacity: (1.0 + _dragOffset / 200).clamp(0.3, 1.0),
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
                              _buildPlayerCards(),
                            ],
                          ),
                        ),
                      ),
              ),
              const Spacer(),
              _buildPlayerAvatar(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCards() {
    return Row(
      children: [
        if (_playerCards.isNotEmpty) _buildMinimalCard(_playerCards[0]),
        const SizedBox(width: 8),
        if (_playerCards.length > 1) _buildMinimalCard(_playerCards[1]),
      ],
    );
  }

  Widget _buildPlayerAreaWithCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Waiting indicator
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
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Bot thinking...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildPlayerCards(),
              const Spacer(),
              _buildPlayerAvatar(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerAvatar() {
    final isDealer = _dealerPosition == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: _isPlayerTurn ? const Color(0xFFD4AF37) : const Color(0xFF3B82F6),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Text('👤', style: TextStyle(fontSize: 24)),
              ),
            ),
            // Dealer badge
            if (isDealer)
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('D',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'You',
          style: TextStyle(
            color: const Color(0xFF3B82F6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          _formatChips(_playerChips),
          style: TextStyle(
            color: Colors.yellow.shade600,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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

  void _showRaiseSlider(int minRaise) {
    int raiseAmount = minRaise;
    final maxRaise = _playerChips + _playerBet;

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
                'Raise to: ${_formatChips(raiseAmount)}',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Min: ${_formatChips(minRaise)} | Max: ${_formatChips(maxRaise)}',
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
                _playerAction('raise', amount: raiseAmount);
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

  Widget _buildCard(PlayingCard card, {bool faceDown = false, bool isLarge = false, bool isSmall = false}) {
    final isRed = card.suit == '♥' || card.suit == '♦';
    double width = isLarge
        ? 56.0
        : isSmall
            ? 32.0
            : 42.0;
    double height = isLarge
        ? 80.0
        : isSmall
            ? 46.0
            : 60.0;

    if (faceDown) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2A2A3E),
              const Color(0xFF1A1A2E),
            ],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
              color: isRed ? Colors.red.shade700 : Colors.black87,
              fontSize: isLarge
                  ? 18
                  : isSmall
                      ? 11
                      : 14,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          Text(
            card.suit,
            style: TextStyle(
              color: isRed ? Colors.red.shade700 : Colors.black87,
              fontSize: isLarge
                  ? 16
                  : isSmall
                      ? 10
                      : 12,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCardSlot() {
    return Container(
      width: 42,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
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

// Helper class for participant display
class _Participant {
  final String name;
  final int chips;
  final int currentBet;
  final bool hasFolded;
  final bool isCurrentTurn;
  final bool isPlayer;
  final bool isDealer;

  _Participant({
    required this.name,
    required this.chips,
    required this.currentBet,
    required this.hasFolded,
    required this.isCurrentTurn,
    required this.isPlayer,
    required this.isDealer,
  });
}

class PlayingCard {
  final String rank;
  final String suit;

  PlayingCard({required this.rank, required this.suit});

  @override
  String toString() => '$rank$suit';
}

// ============================================================================
// HAND EVALUATION (inline for single-player mode)
// ============================================================================

enum _HandRank {
  highCard,
  onePair,
  twoPair,
  threeOfAKind,
  straight,
  flush,
  fullHouse,
  fourOfAKind,
  straightFlush,
  royalFlush,
}

class _EvaluatedHand {
  final _HandRank rank;
  final List<int> tiebreakers;
  final String description;

  _EvaluatedHand({
    required this.rank,
    required this.tiebreakers,
    required this.description,
  });

  int compareTo(_EvaluatedHand other) {
    if (rank.index != other.rank.index) {
      return rank.index - other.rank.index;
    }
    for (int i = 0; i < tiebreakers.length && i < other.tiebreakers.length; i++) {
      if (tiebreakers[i] != other.tiebreakers[i]) {
        return tiebreakers[i] - other.tiebreakers[i];
      }
    }
    return 0;
  }
}

_EvaluatedHand _evaluateBestHand(List<PlayingCard> holeCards, List<PlayingCard> communityCards) {
  final allCards = [...holeCards, ...communityCards];

  // Generate all 5-card combinations from 7 cards
  final combinations = <List<PlayingCard>>[];
  _getCombinations(allCards, 5, 0, [], combinations);

  _EvaluatedHand? bestHand;
  for (final combo in combinations) {
    final hand = _evaluateFiveCards(combo);
    if (bestHand == null || hand.compareTo(bestHand) > 0) {
      bestHand = hand;
    }
  }

  return bestHand!;
}

void _getCombinations(
  List<PlayingCard> cards,
  int k,
  int start,
  List<PlayingCard> current,
  List<List<PlayingCard>> result,
) {
  if (current.length == k) {
    result.add(List.from(current));
    return;
  }
  for (int i = start; i < cards.length; i++) {
    current.add(cards[i]);
    _getCombinations(cards, k, i + 1, current, result);
    current.removeLast();
  }
}

int _getRankValue(String rank) {
  switch (rank) {
    case 'A':
      return 14;
    case 'K':
      return 13;
    case 'Q':
      return 12;
    case 'J':
      return 11;
    case '10':
      return 10;
    case '9':
      return 9;
    case '8':
      return 8;
    case '7':
      return 7;
    case '6':
      return 6;
    case '5':
      return 5;
    case '4':
      return 4;
    case '3':
      return 3;
    case '2':
      return 2;
    default:
      return 0;
  }
}

_EvaluatedHand _evaluateFiveCards(List<PlayingCard> cards) {
  final ranks = cards.map((c) => _getRankValue(c.rank)).toList()..sort((a, b) => b - a);
  final suits = cards.map((c) => c.suit).toList();

  final isFlush = suits.toSet().length == 1;
  final isStraight = _isStraight(ranks);
  final isLowStraight = _isLowStraight(ranks);

  final rankCounts = <int, int>{};
  for (final r in ranks) {
    rankCounts[r] = (rankCounts[r] ?? 0) + 1;
  }
  final counts = rankCounts.values.toList()..sort((a, b) => b - a);

  // Royal Flush
  if (isFlush && isStraight && ranks[0] == 14 && ranks[1] == 13) {
    return _EvaluatedHand(
      rank: _HandRank.royalFlush,
      tiebreakers: [14],
      description: 'Royal Flush',
    );
  }

  // Straight Flush
  if (isFlush && (isStraight || isLowStraight)) {
    final highCard = isLowStraight ? 5 : ranks[0];
    return _EvaluatedHand(
      rank: _HandRank.straightFlush,
      tiebreakers: [highCard],
      description: 'Straight Flush, ${_rankName(highCard)} high',
    );
  }

  // Four of a Kind
  if (counts[0] == 4) {
    final quadRank = rankCounts.entries.firstWhere((e) => e.value == 4).key;
    final kicker = rankCounts.entries.firstWhere((e) => e.value == 1).key;
    return _EvaluatedHand(
      rank: _HandRank.fourOfAKind,
      tiebreakers: [quadRank, kicker],
      description: 'Four of a Kind, ${_rankName(quadRank)}s',
    );
  }

  // Full House
  if (counts[0] == 3 && counts[1] == 2) {
    final tripRank = rankCounts.entries.firstWhere((e) => e.value == 3).key;
    final pairRank = rankCounts.entries.firstWhere((e) => e.value == 2).key;
    return _EvaluatedHand(
      rank: _HandRank.fullHouse,
      tiebreakers: [tripRank, pairRank],
      description: 'Full House, ${_rankName(tripRank)}s full of ${_rankName(pairRank)}s',
    );
  }

  // Flush
  if (isFlush) {
    return _EvaluatedHand(
      rank: _HandRank.flush,
      tiebreakers: ranks,
      description: 'Flush, ${_rankName(ranks[0])} high',
    );
  }

  // Straight
  if (isStraight || isLowStraight) {
    final highCard = isLowStraight ? 5 : ranks[0];
    return _EvaluatedHand(
      rank: _HandRank.straight,
      tiebreakers: [highCard],
      description: 'Straight, ${_rankName(highCard)} high',
    );
  }

  // Three of a Kind
  if (counts[0] == 3) {
    final tripRank = rankCounts.entries.firstWhere((e) => e.value == 3).key;
    final kickers = rankCounts.entries.where((e) => e.value == 1).map((e) => e.key).toList()..sort((a, b) => b - a);
    return _EvaluatedHand(
      rank: _HandRank.threeOfAKind,
      tiebreakers: [tripRank, ...kickers],
      description: 'Three of a Kind, ${_rankName(tripRank)}s',
    );
  }

  // Two Pair
  if (counts[0] == 2 && counts[1] == 2) {
    final pairs = rankCounts.entries.where((e) => e.value == 2).map((e) => e.key).toList()..sort((a, b) => b - a);
    final kicker = rankCounts.entries.firstWhere((e) => e.value == 1).key;
    return _EvaluatedHand(
      rank: _HandRank.twoPair,
      tiebreakers: [...pairs, kicker],
      description: 'Two Pair, ${_rankName(pairs[0])}s and ${_rankName(pairs[1])}s',
    );
  }

  // One Pair
  if (counts[0] == 2) {
    final pairRank = rankCounts.entries.firstWhere((e) => e.value == 2).key;
    final kickers = rankCounts.entries.where((e) => e.value == 1).map((e) => e.key).toList()..sort((a, b) => b - a);
    return _EvaluatedHand(
      rank: _HandRank.onePair,
      tiebreakers: [pairRank, ...kickers],
      description: 'Pair of ${_rankName(pairRank)}s',
    );
  }

  // High Card
  return _EvaluatedHand(
    rank: _HandRank.highCard,
    tiebreakers: ranks,
    description: '${_rankName(ranks[0])} high',
  );
}

bool _isStraight(List<int> ranks) {
  for (int i = 0; i < ranks.length - 1; i++) {
    if (ranks[i] - ranks[i + 1] != 1) {
      return false;
    }
  }
  return true;
}

bool _isLowStraight(List<int> ranks) {
  final sorted = List<int>.from(ranks)..sort();
  return sorted[0] == 2 && sorted[1] == 3 && sorted[2] == 4 && sorted[3] == 5 && sorted[4] == 14;
}

String _rankName(int rank) {
  switch (rank) {
    case 14:
      return 'Ace';
    case 13:
      return 'King';
    case 12:
      return 'Queen';
    case 11:
      return 'Jack';
    case 10:
      return 'Ten';
    case 9:
      return 'Nine';
    case 8:
      return 'Eight';
    case 7:
      return 'Seven';
    case 6:
      return 'Six';
    case 5:
      return 'Five';
    case 4:
      return 'Four';
    case 3:
      return 'Three';
    case 2:
      return 'Two';
    default:
      return '$rank';
  }
}
