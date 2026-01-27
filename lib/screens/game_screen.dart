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

class _GameScreenState extends State<GameScreen> {
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

  @override
  void initState() {
    super.initState();
    // Show settings dialog after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showGameSettingsDialog();
    });
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
                        color: isSelected
                            ? const Color(0xFFD4AF37)
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFD4AF37)
                              : Colors.white.withValues(alpha: 0.2),
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
                          color: isSelected
                              ? diffColor.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? diffColor
                                : Colors.white.withValues(alpha: 0.2),
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
    _bots = List.generate(_numberOfBots, (index) => Bot(
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
    final thinkTime = _difficulty == 'Easy' ? 1200 : _difficulty == 'Medium' ? 800 : 500;
    
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
        int bbSeat = totalPlayers == 2 
            ? (_dealerPosition + 1) % totalPlayers 
            : (_dealerPosition + 2) % totalPlayers;
        
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
          playerWon
              ? 'Congratulations! You\'ve eliminated all opponents!'
              : 'You\'ve run out of chips.',
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

  @override
  Widget build(BuildContext context) {
    // Show loading state while waiting for game settings
    if (!_gameStarted) {
      return MobileWrapper(
        child: Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.3),
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
    
    return MobileWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              _buildTopBar(),
              
              // Game table
              _buildGameTable(),
              
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white54,
              size: 20,
            ),
          ),
          const Spacer(),
          // Pot display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatChips(_pot),
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          // Player chips
          Text(
            _formatChips(_playerChips),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameTable() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            // Bots area
            Expanded(
              flex: 3,
              child: _buildBotsArea(),
            ),
            
            // Community cards
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _buildCommunityCards(),
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBotsArea() {
    if (_bots.isEmpty) return const SizedBox();
    
    final activeBots = _bots.where((b) => b.chips > 0 || !b.hasFolded).toList();
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: activeBots.map((bot) => _buildBotWidget(bot)).toList(),
        );
      },
    );
  }

  Widget _buildBotWidget(Bot bot) {
    final isCurrentTurn = _currentActorIndex == bot.id + 1 && !_isPlayerTurn;
    final isDealer = _dealerPosition == bot.id + 1;
    
    return Opacity(
      opacity: bot.hasFolded ? 0.3 : 1.0,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrentTurn 
              ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentTurn
                ? const Color(0xFFD4AF37).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (bot.cards.isNotEmpty) ...[
                  _buildMiniCard(bot.cards[0], faceDown: !_showBotCards),
                  const SizedBox(width: 2),
                  _buildMiniCard(bot.cards[1], faceDown: !_showBotCards),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // Name + Dealer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDealer)
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4AF37),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'D',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Text(
                  'B${bot.id + 1}',
                  style: TextStyle(
                    color: bot.hasFolded ? Colors.red.shade300 : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            // Chips
            Text(
              _formatChips(bot.chips),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 9,
              ),
            ),
            // Action indicator
            if (bot.lastAction != null && !bot.hasFolded)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _buildMiniAction(bot.lastAction!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCard(PlayingCard card, {bool faceDown = false}) {
    if (faceDown) {
      return Container(
        width: 24,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
      );
    }
    
    final isRed = card.suit == '♥' || card.suit == '♦';
    return Container(
      width: 24,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            card.rank,
            style: TextStyle(
              color: isRed ? Colors.red.shade700 : Colors.black,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          Text(
            card.suit,
            style: TextStyle(
              color: isRed ? Colors.red.shade700 : Colors.black,
              fontSize: 8,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAction(String action) {
    Color color;
    switch (action) {
      case 'FOLD': color = Colors.red; break;
      case 'CHECK': color = Colors.blue; break;
      case 'CALL': color = Colors.green; break;
      case 'RAISE': color = Colors.orange; break;
      case 'ALL-IN': color = Colors.purple; break;
      default: color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        action,
        style: TextStyle(
          color: color,
          fontSize: 7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildOpponentArea() {
    return _buildBotsArea();
  }

  Widget _buildActionIndicator(String action) {
    return _buildMiniAction(action);
  }

  Widget _buildCommunityCards() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 5; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          if (i < _communityCards.length)
            _buildCard(_communityCards[i])
          else
            _buildEmptyCardSlot(),
        ],
      ],
    );
  }

  Widget _buildPlayerArea() {
    final isDealer = _dealerPosition == 0;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player cards with dealer badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isDealer)
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD4AF37),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'D',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              Opacity(
                opacity: _playerHasFolded ? 0.3 : 1.0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_playerCards.isNotEmpty) ...[
                      _buildCard(_playerCards[0], isLarge: true),
                      const SizedBox(width: 8),
                      _buildCard(_playerCards[1], isLarge: true),
                    ],
                  ],
                ),
              ),
              if (_playerHasFolded)
                Container(
                  margin: const EdgeInsets.only(left: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'FOLD',
                    style: TextStyle(
                      color: Colors.red.shade300,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Action buttons or status
          if (_playerChips == 0 && _gamePhase != 'showdown' && !_playerHasFolded)
            Text(
              'ALL IN',
              style: TextStyle(
                color: const Color(0xFFD4AF37),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            )
          else if (_isPlayerTurn && _gamePhase != 'showdown' && !_playerHasFolded)
            _buildActionButtons()
          else if (!_isPlayerTurn && _gamePhase != 'showdown' && !_playerHasFolded)
            Text(
              '• • •',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 20,
                letterSpacing: 4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final callAmount = _currentBet - _playerBet;
    final canCheck = callAmount <= 0;
    final minRaise = _currentBet + _lastRaiseAmount;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionBtn('Fold', Colors.red.shade400, () => _playerAction('fold')),
        const SizedBox(width: 8),
        if (canCheck)
          _buildActionBtn('Check', Colors.white, () => _playerAction('check'))
        else
          _buildActionBtn('Call ${_formatChips(callAmount)}', Colors.green, () => _playerAction('call')),
        const SizedBox(width: 8),
        _buildActionBtn('Raise', Colors.orange, () => _showRaiseSlider(minRaise)),
        const SizedBox(width: 8),
        _buildActionBtn('All In', const Color(0xFFD4AF37), () => _playerAction('allin')),
      ],
    );
  }

  Widget _buildActionBtn(String label, Color color, VoidCallback onTap) {
    final isWhite = color == Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isWhite ? Colors.white : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: isWhite ? null : Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isWhite ? Colors.black : color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
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
    double width = isLarge ? 56.0 : isSmall ? 32.0 : 42.0;
    double height = isLarge ? 80.0 : isSmall ? 46.0 : 60.0;
    
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
              fontSize: isLarge ? 18 : isSmall ? 11 : 14,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          Text(
            card.suit,
            style: TextStyle(
              color: isRed ? Colors.red.shade700 : Colors.black87,
              fontSize: isLarge ? 16 : isSmall ? 10 : 12,
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
    case 'A': return 14;
    case 'K': return 13;
    case 'Q': return 12;
    case 'J': return 11;
    case '10': return 10;
    case '9': return 9;
    case '8': return 8;
    case '7': return 7;
    case '6': return 6;
    case '5': return 5;
    case '4': return 4;
    case '3': return 3;
    case '2': return 2;
    default: return 0;
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
    case 14: return 'Ace';
    case 13: return 'King';
    case 12: return 'Queen';
    case 11: return 'Jack';
    case 10: return 'Ten';
    case 9: return 'Nine';
    case 8: return 'Eight';
    case 7: return 'Seven';
    case 6: return 'Six';
    case 5: return 'Five';
    case 4: return 'Four';
    case 3: return 'Three';
    case 2: return 'Two';
    default: return '$rank';
  }
}
