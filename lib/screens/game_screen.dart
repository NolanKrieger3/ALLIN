import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/mobile_wrapper.dart';
import '../services/user_preferences.dart';

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

  // Blind level settings
  int _selectedBlindIndex = 0;
  static const List<Map<String, dynamic>> _blindLevels = [
    {'name': 'Micro', 'bigBlind': 100, 'minBuyIn': 5000, 'maxBuyIn': 10000},
    {'name': 'Low', 'bigBlind': 500, 'minBuyIn': 25000, 'maxBuyIn': 50000},
    {'name': 'Medium', 'bigBlind': 1000, 'minBuyIn': 50000, 'maxBuyIn': 100000},
    {'name': 'High', 'bigBlind': 5000, 'minBuyIn': 250000, 'maxBuyIn': 500000},
    {'name': 'VIP', 'bigBlind': 10000, 'minBuyIn': 500000, 'maxBuyIn': 1000000},
  ];
  int _buyInAmount = 5000; // Selected buy-in amount

  // Bot cards visibility is determined by _gamePhase == 'showdown'

  // Game state
  int _pot = 0;
  int _playerChips = 0; // Table chips (from buy-in)
  int _playerBet = 0; // Player's current bet this round
  int _currentBet = 0; // The current bet to match
  int _lastRaiseAmount = 0; // For minimum raise calculation
  int _bigBlind = 100; // Now dynamic based on selected blind level
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
  String _winnerDescription = '';

  // Showdown animation
  bool _showdownAnimationComplete = false;
  int? _winningSeat;
  Map<int, _EvaluatedHand> _showdownHands = {};

  // Fold animation
  late AnimationController _foldAnimationController;
  late Animation<Offset> _foldSlideAnimation;
  late Animation<double> _foldOpacityAnimation;
  bool _isFolding = false;
  double _dragOffset = 0.0;
  List<PlayingCard> _foldedCards = []; // Store cards when folded to show ghost outline

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

  void _initializeBots() {
    // Bots get the same buy-in amount as the player for fair play
    final botChips = _buyInAmount > 0 ? _buyInAmount : _blindLevels[_selectedBlindIndex]['minBuyIn'] as int;
    _bots = List.generate(
        _numberOfBots,
        (index) => Bot(
              id: index,
              name: 'Bot ${index + 1}',
              chips: botChips,
            ));
  }

  int _getTotalPlayers() => 1 + _bots.length; // Player + bots

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
      _foldedCards = []; // Clear folded cards for new hand

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
        _currentBet = bb; // Current bet is the big blind amount
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
      _winnerDescription = '';
      _showdownAnimationComplete = false;
      _winningSeat = null;
      _showdownHands = {};
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
          _foldedCards = List.from(_playerCards); // Save cards before folding
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
            if (bot.isActive && !bot.isAllIn && bot.chips > 0) {
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

          // Update current bet if this all-in is higher
          if (newTotalBet > _currentBet) {
            int raiseBy = newTotalBet - _currentBet;
            if (raiseBy >= _lastRaiseAmount) {
              _lastRaiseAmount = raiseBy;
            }
            _currentBet = newTotalBet;
            _bbHasOption = false;
          }

          // ALWAYS reset acted flags for all active bots when player goes all-in
          // This gives them the chance to call or fold
          for (var bot in _bots) {
            if (bot.isActive && !bot.isAllIn && bot.chips > 0 && bot.currentBet < _currentBet) {
              bot.hasActed = false;
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
        if (!_playerHasFolded) {
          // Player needs to act if:
          // 1. They haven't acted yet AND have chips, OR
          // 2. They haven't matched the current bet AND have chips
          bool needsToAct = (!_playerHasActed && _playerChips > 0) || (_playerBet < _currentBet && _playerChips > 0);
          if (needsToAct) {
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
          // Bot needs to act if:
          // 1. They haven't acted yet AND have chips, OR
          // 2. They haven't matched the current bet AND have chips
          bool needsToAct = (!bot.hasActed && bot.chips > 0) || (bot.currentBet < _currentBet && bot.chips > 0);
          if (needsToAct) {
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

    // Simulate bot thinking - variable timing for realism
    final random = Random();
    final baseTime = _difficulty == 'Easy'
        ? 1500
        : _difficulty == 'Medium'
            ? 1200
            : 900;
    final thinkTime = baseTime + random.nextInt(1000); // Add 0-1s variation

    Future.delayed(Duration(milliseconds: thinkTime), () {
      if (!mounted) return;

      final random = Random();
      final callAmount = _currentBet - bot.currentBet;
      final canCheck = callAmount <= 0;

      // AI decision based on difficulty (with more realistic fold/raise behavior)
      int foldThreshold;
      int callThreshold;
      int raiseMultiplierMax;

      switch (_difficulty) {
        case 'Easy':
          foldThreshold = 35; // Folds more often
          callThreshold = 80;
          raiseMultiplierMax = 3;
          break;
        case 'Hard':
          foldThreshold = 15; // Still folds sometimes
          callThreshold = 50; // Raises more
          raiseMultiplierMax = 6;
          break;
        default: // Medium
          foldThreshold = 25;
          callThreshold = 65;
          raiseMultiplierMax = 4;
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

          // Reset all other players' acted flags since there's a new bet to respond to
          // Only reset if this was a meaningful raise (not just a call that happens to be the max)
          if (raiseBy > 0) {
            if (!_playerHasFolded && _playerChips > 0) {
              _playerHasActed = false;
            }
            for (var otherBot in _bots) {
              if (otherBot.id != bot.id && otherBot.isActive && !otherBot.isAllIn && otherBot.chips > 0) {
                otherBot.hasActed = false;
              }
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
        // Player can act if they have chips
        if (_playerChips > 0) playersCanAct++;

        // Player needs to act if:
        // 1. They haven't matched the current bet AND have chips to do so
        // 2. OR they haven't acted at all this round AND have chips
        if (_playerChips > 0) {
          if (_playerBet < _currentBet) {
            allMatched = false;
          } else if (!_playerHasActed) {
            allMatched = false;
          }
        }
      } else {
        final bot = _bots[seat - 1];
        // Bot can act if they have chips
        if (bot.chips > 0) playersCanAct++;

        // Bot needs to act if:
        // 1. They haven't matched the current bet AND have chips to do so
        // 2. OR they haven't acted at all this round AND have chips
        if (bot.chips > 0) {
          if (bot.currentBet < _currentBet) {
            allMatched = false;
          } else if (!bot.hasActed) {
            allMatched = false;
          }
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
      _gamePhase = 'showdown';
      _showdownAnimationComplete = false;

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

      // Store hands for UI display
      _showdownHands = hands;

      // Find best hand(s)
      _EvaluatedHand? bestHand;
      List<int> winners = [];

      for (var entry in hands.entries) {
        if (bestHand == null || entry.value.compareTo(bestHand) > 0) {
          bestHand = entry.value;
          winners = [entry.key];
        } else if (entry.value.compareTo(bestHand) == 0) {
          winners.add(entry.key);
        }
      }

      // Set winner for animation (first winner if split pot)
      _winningSeat = winners.isNotEmpty ? winners[0] : null;

      if (winners.length == 1) {
        final winner = winners[0];
        if (winner == 0) {
          _winnerDescription = 'You win with ${_getShortHandName(bestHand!.rank)}';
        } else {
          _winnerDescription = '${_bots[winner - 1].name} wins with ${_getShortHandName(bestHand!.rank)}';
        }
      } else {
        _winnerDescription = 'Split pot! ${winners.length} players tie with ${_getShortHandName(bestHand!.rank)}';
      }

      // Start animation delay - show all hands for 1 second before highlighting winner
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() => _showdownAnimationComplete = true);
        }
      });

      // End hand after 3 seconds total
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

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkGameOver();
      }
    });
  }

  void _checkGameOver() {
    // Remove bots with no chips
    _bots = _bots.where((b) => b.chips > 0).toList();

    // If player runs out of chips, show buy-back dialog
    if (_playerChips <= 0) {
      _showBuyBackDialog();
      return; // Don't continue until player decides
    }

    // If all bots are eliminated, add new ones to keep the game going
    if (_bots.isEmpty) {
      setState(() {
        _initializeBots(); // Re-add bots with fresh chips
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You eliminated all bots! New opponents joining...'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    }

    // Continue to next hand
    _startNewHand();
  }

  void _showBuyBackDialog() {
    final userBalance = UserPreferences.chips;
    final minBuyIn = _blindLevels[_selectedBlindIndex]['minBuyIn'] as int;
    final maxBuyIn = _blindLevels[_selectedBlindIndex]['maxBuyIn'] as int;
    final canBuyBack = userBalance >= minBuyIn;
    int selectedBuyIn = minBuyIn.clamp(minBuyIn, userBalance.clamp(minBuyIn, maxBuyIn));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Column(
            children: [
              Text('💀', style: TextStyle(fontSize: 48)),
              SizedBox(height: 8),
              Text(
                'YOU BUSTED!',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // User balance display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('💰', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(
                      'Balance: ${_formatChipsLong(userBalance)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (canBuyBack) ...[
                Text(
                  'Buy back in?',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                // Buy-in slider
                Text(
                  _formatChipsLong(selectedBuyIn),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFD4AF37),
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                    thumbColor: const Color(0xFFD4AF37),
                    overlayColor: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: selectedBuyIn.toDouble(),
                    min: minBuyIn.toDouble(),
                    max: userBalance.clamp(minBuyIn, maxBuyIn).toDouble(),
                    onChanged: (value) {
                      setDialogState(() => selectedBuyIn = value.toInt());
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatChipsLong(minBuyIn),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                    ),
                    Text(
                      _formatChipsLong(userBalance.clamp(minBuyIn, maxBuyIn)),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                    ),
                  ],
                ),
              ] else ...[
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
                const SizedBox(height: 8),
                Text(
                  'Not enough chips!\nNeed at least ${_formatChipsLong(minBuyIn)} to continue.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            // Exit button
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Exit game
              },
              child: const Text('Exit', style: TextStyle(color: Colors.white54)),
            ),
            // Shop button (if can't afford)
            if (!canBuyBack)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Exit game
                  // Navigate to shop - this will be handled by home screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                ),
                child: const Text('Go to Shop', style: TextStyle(color: Colors.white)),
              ),
            // Buy back button (if can afford)
            if (canBuyBack)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _processBuyBack(selectedBuyIn);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                ),
                child: const Text('Buy In', style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _processBuyBack(int amount) async {
    // Deduct from user balance and wait for it to persist
    final newBalance = UserPreferences.chips - amount;
    await UserPreferences.setChips(newBalance);

    setState(() {
      _playerChips = amount;
    });

    // If all bots are eliminated, add new ones
    if (_bots.isEmpty) {
      _initializeBots();
    }

    // Continue game
    _startNewHand();
  }

  void _showCashOutDialog() {
    final profit = _playerChips - _buyInAmount;
    final profitColor = profit >= 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final profitSign = profit >= 0 ? '+' : '';

    // Check if player has money in the pot (mid-round)
    final bool hasPotContribution = _playerBet > 0 || (_gamePhase != 'preflop' && _gamePhase != 'showdown' && _pot > 0);
    final int potLoss = _playerBet; // What they'd forfeit by leaving now

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cash Out',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_money, color: Color(0xFFD4AF37), size: 48),
            const SizedBox(height: 16),
            Text(
              _formatChipsLong(_playerChips),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$profitSign${_formatChipsLong(profit)} from buy-in',
              style: TextStyle(
                color: profitColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your chips will be added to your balance.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            // Warning if leaving mid-round
            if (hasPotContribution) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        potLoss > 0
                            ? 'You\'ll forfeit ${_formatChipsLong(potLoss)} in the pot!'
                            : 'Hand in progress - pot will be forfeited!',
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Playing', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              // Capture navigator before async gap
              final navigator = Navigator.of(context);

              // Add chips to user balance
              final newBalance = UserPreferences.chips + _playerChips;
              await UserPreferences.setChips(newBalance);

              navigator.pop(); // Close dialog
              navigator.pop(); // Exit game
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
            ),
            child: const Text('Cash Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

  Widget _buildSetupScreen() {
    final userBalance = UserPreferences.chips;
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
                  'PRACTICE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Play against AI bots',
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
                              ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: isLocked ? 0.02 : 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected ? Border.all(color: const Color(0xFFD4AF37), width: 2) : null,
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
                      activeTrackColor: const Color(0xFFD4AF37),
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                      thumbColor: const Color(0xFFD4AF37),
                      overlayColor: const Color(0xFFD4AF37).withValues(alpha: 0.2),
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

                // Opponents and Difficulty in a row
                Row(
                  children: [
                    // Opponents
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'OPPONENTS',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _AnimatedPressButton(
                                onTap: _numberOfBots > 1 ? () => setState(() => _numberOfBots--) : null,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.remove,
                                      color: _numberOfBots > 1 ? Colors.white : Colors.white24, size: 20),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '$_numberOfBots',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 16),
                              _AnimatedPressButton(
                                onTap: _numberOfBots < 7 ? () => setState(() => _numberOfBots++) : null,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.add,
                                      color: _numberOfBots < 7 ? Colors.white : Colors.white24, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Difficulty
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'DIFFICULTY',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: ['Easy', 'Medium', 'Hard'].map((diff) {
                                final isSelected = _difficulty == diff;
                                final label = diff == 'Easy'
                                    ? '😊'
                                    : diff == 'Medium'
                                        ? '😐'
                                        : '😈';
                                return _AnimatedPressButton(
                                  onTap: () => setState(() => _difficulty = diff),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      label,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Play button
                _AnimatedPressButton(
                  onTap: canAfford
                      ? () async {
                          // Deduct buy-in from user balance
                          await UserPreferences.setChips(userBalance - _buyInAmount);

                          setState(() {
                            _gameStarted = true;
                            _playerChips = _buyInAmount;
                            _bigBlind = selectedLevel['bigBlind'] as int;
                          });
                          _startNewHand();
                        }
                      : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: canAfford ? const Color(0xFFD4AF37) : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        canAfford ? 'PLAY' : 'NOT ENOUGH CHIPS',
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

                const SizedBox(height: 32),
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
          _AnimatedPressButton(
            onTap: () {
              // If game is in progress and player has chips, show cash out dialog
              if (_gameStarted && _playerChips > 0) {
                _showCashOutDialog();
              } else {
                Navigator.pop(context);
              }
            },
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
    final isShowdown = _gamePhase == 'showdown';
    final totalBots = _bots.length;
    // Always include player in row when we have multiple bots
    final includePlayerInRow = totalBots > 5;
    const maxVisible = 5;

    // Build all participants - include player when more than 5 bots
    final allParticipants = <_Participant>[];

    // Player is at seat index 0
    if (includePlayerInRow) {
      allParticipants.add(_Participant(
        name: 'You',
        chips: _playerChips,
        currentBet: _playerBet,
        hasFolded: _playerHasFolded,
        isCurrentTurn: _currentActorIndex == 0 && _gamePhase != 'showdown',
        isPlayer: true,
        isDealer: _dealerPosition == 0,
        cards: _playerCards,
        seatIndex: 0,
      ));
    }

    // Add all bots (seat indices 1+)
    allParticipants.addAll(List.generate(
        _bots.length,
        (i) => _Participant(
              name: _bots[i].name,
              chips: _bots[i].chips,
              currentBet: _bots[i].currentBet,
              hasFolded: _bots[i].hasFolded,
              isCurrentTurn: _currentActorIndex == i + 1 && _gamePhase != 'showdown',
              isPlayer: false,
              isDealer: _dealerPosition == i + 1,
              cards: _bots[i].cards,
              seatIndex: i + 1,
            )));

    final totalParticipants = allParticipants.length;
    // Enable centering and sliding only when there are more participants than visible slots
    // This prevents duplicate keys and only shows the carousel when needed (6+ bots)
    final shouldCenterOnActive = totalParticipants > maxVisible;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: isShowdown ? 170 : 110,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use Stack-based sliding animation for centering on active player
          if (shouldCenterOnActive) {
            // Find current actor index in allParticipants list
            int activeIndex;
            if (includePlayerInRow) {
              activeIndex = _currentActorIndex;
            } else {
              activeIndex = _currentActorIndex > 0 ? _currentActorIndex - 1 : 0;
            }

            // Clamp activeIndex to valid range
            if (activeIndex < 0) activeIndex = 0;
            if (activeIndex >= totalParticipants) activeIndex = totalParticipants - 1;

            const centerSlot = maxVisible ~/ 2; // = 2 (middle of 5 slots)
            final availableWidth = constraints.maxWidth;
            const avatarWidth = 72.0;
            const avatarMargin = 4.0;
            const slotWidth = avatarWidth + avatarMargin;
            final rowWidth = maxVisible * slotWidth;
            final rowStartX = (availableWidth - rowWidth) / 2;

            // Build visible slots with circular wrapping
            // E.g., if activeIndex=0 and total=7, show: 5, 6, 0, 1, 2
            final visibleIndices = <int>[];
            for (int slot = 0; slot < maxVisible; slot++) {
              final offset = slot - centerSlot; // -2, -1, 0, 1, 2
              final idx = (activeIndex + offset + totalParticipants) % totalParticipants;
              visibleIndices.add(idx);
            }

            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (int slot = 0; slot < visibleIndices.length; slot++)
                  Builder(
                    key: ValueKey(allParticipants[visibleIndices[slot]].seatIndex),
                    builder: (context) {
                      final participantIndex = visibleIndices[slot];
                      final participant = allParticipants[participantIndex];

                      // Calculate x position for this slot
                      final xPos = rowStartX + (slot * slotWidth);

                      return AnimatedPositioned(
                        key: ValueKey('pos_${participant.seatIndex}'),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        left: xPos,
                        top: 0,
                        bottom: 0,
                        child: _buildParticipantAvatar(participant),
                      );
                    },
                  ),
              ],
            );
          }

          // Default behavior for smaller games - simple row
          final availableWidth = constraints.maxWidth;
          const avatarWidth = 68.0;
          final totalWidth = allParticipants.length * (avatarWidth + 4);
          final startX = (availableWidth - totalWidth) / 2;

          return Stack(
            children: [
              for (int i = 0; i < allParticipants.length; i++)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  left: startX + (i * (avatarWidth + 4)),
                  top: 0,
                  bottom: 0,
                  child: _buildParticipantAvatar(allParticipants[i]),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildParticipantAvatar(_Participant p) {
    final isShowdown = _gamePhase == 'showdown';
    final isWinner = _winningSeat == p.seatIndex;
    final isLoser = isShowdown && _showdownAnimationComplete && !isWinner && !p.hasFolded;
    final participantHand = _showdownHands[p.seatIndex];

    // Avatar emoji based on name - use user's selected avatar for "You"
    String getAvatar(String name) {
      if (name == 'You') return UserPreferences.avatar;
      final avatars = ['🤖', '🦊', '🐸', '🦁', '🐼', '🐮', '🐧'];
      final index = int.tryParse(name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      return avatars[(index - 1) % avatars.length];
    }

    // Border color: primary color if winner at showdown, white if their turn
    Color? borderColor;
    if (isShowdown && _showdownAnimationComplete && isWinner) {
      borderColor = const Color(0xFF6366F1); // Primary color for winner
    } else if (p.isCurrentTurn) {
      borderColor = Colors.white.withValues(alpha: 0.9);
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isLoser ? 0.5 : 1.0,
      child: Container(
        width: 68,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Winner glow ring
                if (isShowdown && _showdownAnimationComplete && isWinner)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                          blurRadius: 12,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.hasFolded ? Colors.grey.shade800 : Colors.white.withValues(alpha: 0.1),
                    border: borderColor != null ? Border.all(color: borderColor, width: 3) : null,
                    boxShadow: p.hasFolded
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      getAvatar(p.name),
                      style: TextStyle(
                        fontSize: 20,
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
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('D',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                    ),
                  ),
                // Winner badge
                if (isShowdown && _showdownAnimationComplete && isWinner)
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('WIN',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Name
            Text(
              p.name,
              style: TextStyle(
                color: p.hasFolded ? Colors.grey : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            // Chips amount
            Text(
              _formatChips(p.chips),
              style: TextStyle(
                color: p.hasFolded ? Colors.grey : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            // Current bet on separate line
            if (p.currentBet > 0)
              Text(
                '(${_formatChips(p.currentBet)})',
                style: TextStyle(
                  color: p.hasFolded ? Colors.grey.withValues(alpha: 0.6) : Colors.orange.shade400,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            // Show hole cards during showdown
            if (isShowdown && !p.hasFolded && p.cards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMiniCard(
                      p.cards[0],
                      isHighlighted: _showdownAnimationComplete &&
                          isWinner &&
                          participantHand != null &&
                          participantHand.isCardInWinningHand(p.cards[0]),
                      isDimmed: isLoser,
                    ),
                    const SizedBox(width: 2),
                    if (p.cards.length > 1)
                      _buildMiniCard(
                        p.cards[1],
                        isHighlighted: _showdownAnimationComplete &&
                            isWinner &&
                            participantHand != null &&
                            participantHand.isCardInWinningHand(p.cards[1]),
                        isDimmed: isLoser,
                      ),
                  ],
                ),
              ),
            // Show hand name during showdown
            if (isShowdown && _showdownAnimationComplete && !p.hasFolded && participantHand != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _getShortHandName(participantHand.rank),
                  style: TextStyle(
                    color: isWinner ? const Color(0xFFFFD700) : Colors.white.withValues(alpha: 0.7),
                    fontSize: 9,
                    fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build a mini card for showdown display
  Widget _buildMiniCard(PlayingCard card, {bool isHighlighted = false, bool isDimmed = false}) {
    const width = 28.0;
    const height = 38.0;
    final isRed = card.suit == '♥' || card.suit == '♦';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDimmed ? Colors.grey.shade300 : Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          if (isHighlighted) ...[
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.8),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ] else
            BoxShadow(
              color: Colors.black.withValues(alpha: isDimmed ? 0.1 : 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
        border: isHighlighted ? Border.all(color: const Color(0xFFFFD700), width: 1.5) : null,
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isDimmed ? 0.5 : 1.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.rank,
              style: TextStyle(
                color: isDimmed ? Colors.grey : (isRed ? Colors.red.shade700 : Colors.black),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              card.suit,
              style: TextStyle(
                color: isDimmed ? Colors.grey : (isRed ? Colors.red.shade700 : Colors.black),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get short hand name for display
  String _getShortHandName(_HandRank rank) {
    switch (rank) {
      case _HandRank.royalFlush:
        return 'Royal Flush';
      case _HandRank.straightFlush:
        return 'Str. Flush';
      case _HandRank.fourOfAKind:
        return 'Quads';
      case _HandRank.fullHouse:
        return 'Full House';
      case _HandRank.flush:
        return 'Flush';
      case _HandRank.straight:
        return 'Straight';
      case _HandRank.threeOfAKind:
        return 'Trips';
      case _HandRank.twoPair:
        return 'Two Pair';
      case _HandRank.onePair:
        return 'Pair';
      case _HandRank.highCard:
        return 'High Card';
    }
  }

  Widget _buildCommunityCardsWithPot() {
    final isShowdown = _gamePhase == 'showdown' && _showdownAnimationComplete;
    final winnerHand = _winningSeat != null ? _showdownHands[_winningSeat] : null;

    return Column(
      children: [
        // Winner text that fades in during showdown
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: isShowdown && _winnerDescription.isNotEmpty ? 1.0 : 0.0,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _winnerDescription,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 5; i++)
                () {
                  if (i >= _communityCards.length) {
                    return _buildEmptyCardSlot();
                  }
                  final card = _communityCards[i];
                  final isHighlighted = isShowdown && winnerHand != null && winnerHand.isCardInWinningHand(card);
                  final isDimmed = isShowdown && winnerHand != null && !winnerHand.isCardInWinningHand(card);
                  return _buildMinimalCard(card, isHighlighted: isHighlighted, isDimmed: isDimmed);
                }(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Pot amount below cards
        Text(
          _pot.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMinimalCard(PlayingCard card,
      {bool isLarge = false, bool isHighlighted = false, bool isDimmed = false}) {
    final width = isLarge ? 70.0 : 58.0;
    final height = isLarge ? 98.0 : 82.0;
    final isRed = card.suit == '♥' || card.suit == '♦';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDimmed ? Colors.grey.shade300 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          if (isHighlighted) ...[
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.8),
              blurRadius: 12,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ] else
            BoxShadow(
              color: Colors.black.withValues(alpha: isDimmed ? 0.1 : 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
        border: isHighlighted ? Border.all(color: const Color(0xFFFFD700), width: 2) : null,
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isDimmed ? 0.5 : 1.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.rank,
              style: TextStyle(
                color: isDimmed ? Colors.grey : (isRed ? Colors.red.shade700 : Colors.black),
                fontSize: isLarge ? 24 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              card.suit,
              style: TextStyle(
                color: isDimmed ? Colors.grey : (isRed ? Colors.red.shade700 : Colors.black),
                fontSize: isLarge ? 26 : 26,
              ),
            ),
          ],
        ),
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
    final isShowdown = _gamePhase == 'showdown';
    final isPlayerWinner = _winningSeat == 0;
    final isPlayerLoser = isShowdown && _showdownAnimationComplete && !isPlayerWinner && !_playerHasFolded;
    final playerHand = _showdownHands[0];

    // During showdown, show simple status (winner text is shown above cards now)
    if (isShowdown) {
      displayMessage = isPlayerWinner ? 'You win!' : 'Showdown';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isShowdown && _showdownAnimationComplete && isPlayerWinner
                  ? const Color(0xFFFFD700).withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isShowdown && _showdownAnimationComplete && isPlayerWinner
                    ? const Color(0xFFFFD700).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: Center(
              child: Text(
                displayMessage,
                style: TextStyle(
                  color: isShowdown && _showdownAnimationComplete && isPlayerWinner
                      ? const Color(0xFFFFD700)
                      : Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                  fontWeight: isPlayerWinner ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isPlayerLoser ? 0.5 : 1.0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Player's cards - always show face up during showdown (dimmed if folded or lost)
                if (isShowdown && _playerCards.isNotEmpty)
                  SizedBox(
                    width: 165, // 90 * 2 - 15 overlap
                    height: 126,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildLargeCard(
                          _playerCards[0],
                          isHighlighted: _showdownAnimationComplete &&
                              isPlayerWinner &&
                              !_playerHasFolded &&
                              playerHand != null &&
                              playerHand.isCardInWinningHand(_playerCards[0]),
                          isDimmed: isPlayerLoser || _playerHasFolded,
                        ),
                        Positioned(
                          left: 75, // 90 - 15 overlap
                          child: _buildLargeCard(
                            _playerCards.length > 1 ? _playerCards[1] : _playerCards[0],
                            isHighlighted: _showdownAnimationComplete &&
                                isPlayerWinner &&
                                !_playerHasFolded &&
                                playerHand != null &&
                                _playerCards.length > 1 &&
                                playerHand.isCardInWinningHand(_playerCards[1]),
                            isDimmed: isPlayerLoser || _playerHasFolded,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_playerHasFolded && _foldedCards.isNotEmpty)
                  // Show ghost outline of folded cards
                  SizedBox(
                    width: _foldedCards.length > 1 ? 165 : 90, // 90 * 2 - 15 overlap
                    height: 126,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildLargeCard(_foldedCards[0], isGhost: true),
                        if (_foldedCards.length > 1)
                          Positioned(
                            left: 75, // 90 - 15 overlap
                            child: _buildLargeCard(_foldedCards[1], isGhost: true),
                          ),
                      ],
                    ),
                  )
                else
                  _buildPlayerCardsLarge(),
                const Spacer(),
                _buildPlayerAvatarLarge(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerActionArea() {
    final callAmount = _currentBet - _playerBet;
    final canCheck = callAmount <= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          // Action buttons row
          Row(
            children: [
              Expanded(
                child: _AnimatedGameButton(
                  onTap: () => _playerAction(canCheck ? 'check' : 'call'),
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
              const SizedBox(width: 12),
              Expanded(
                child: _AnimatedGameButton(
                  onTap: () {
                    final minRaise = _currentBet + _lastRaiseAmount;
                    _showRaiseSlider(minRaise);
                  },
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
            ],
          ),
          const SizedBox(height: 16),
          // Cards area with swipe to fold (no text)
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
                          child: _buildPlayerCardsLarge(),
                        ),
                      )
                    : Transform.translate(
                        offset: Offset(0, _dragOffset * 0.5),
                        child: Opacity(
                          opacity: (1.0 + _dragOffset / 200).clamp(0.3, 1.0),
                          child: _buildPlayerCardsLarge(),
                        ),
                      ),
              ),
              const Spacer(),
              _buildPlayerAvatarLarge(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCardsLarge({bool isDimmed = false}) {
    // Use SizedBox with Stack for proper overlap without overflow
    const cardWidth = 90.0;
    const overlap = 15.0;
    final totalWidth = _playerCards.length > 1 ? (cardWidth * 2 - overlap) : cardWidth;

    return SizedBox(
      width: totalWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_playerCards.isNotEmpty) _buildLargeCard(_playerCards[0], isDimmed: isDimmed),
          if (_playerCards.length > 1)
            Positioned(
              left: cardWidth - overlap,
              child: _buildLargeCard(_playerCards[1], isDimmed: isDimmed),
            ),
        ],
      ),
    );
  }

  Widget _buildLargeCard(PlayingCard card, {bool isHighlighted = false, bool isDimmed = false, bool isGhost = false}) {
    const width = 90.0;
    const height = 126.0;
    final isRed = card.suit == '♥' || card.suit == '♦';

    // Ghost card style for folded cards
    if (isGhost) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.rank,
              style: TextStyle(
                color: (isRed ? Colors.red.shade300 : Colors.white).withValues(alpha: 0.4),
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              card.suit,
              style: TextStyle(
                color: (isRed ? Colors.red.shade300 : Colors.white).withValues(alpha: 0.4),
                fontSize: 34,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDimmed ? Colors.grey.shade300 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (isHighlighted) ...[
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.8),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ] else
            BoxShadow(
              color: Colors.black.withValues(alpha: isDimmed ? 0.1 : 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
        border: isHighlighted ? Border.all(color: const Color(0xFFFFD700), width: 2) : null,
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isDimmed ? 0.5 : 1.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.rank,
              style: TextStyle(
                color: isDimmed ? Colors.grey : (isRed ? Colors.red.shade700 : Colors.black),
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              card.suit,
              style: TextStyle(
                color: isDimmed ? Colors.grey : (isRed ? Colors.red.shade700 : Colors.black),
                fontSize: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerAreaWithCards() {
    final callAmount = _currentBet - _playerBet;
    final canCheck = callAmount <= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          // Disabled action buttons (grayed out while bot thinks)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Center(
                    child: Text(
                      canCheck ? 'Check' : 'Call ${_formatChips(callAmount)}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Raise',
                      style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.4), fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildPlayerCardsLarge(),
              const Spacer(),
              _buildPlayerAvatarLarge(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerAvatarLarge() {
    final isDealer = _dealerPosition == 0;
    final isMyTurn = _isPlayerTurn && _gamePhase != 'showdown';

    return Container(
      width: 100,
      height: 126, // Match the large card height
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMyTurn ? const Color(0xFFD4AF37) : Colors.white.withValues(alpha: 0.1),
          width: isMyTurn ? 2 : 1,
        ),
        boxShadow: isMyTurn
            ? [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar circle
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isMyTurn ? const Color(0xFFD4AF37) : Colors.white.withValues(alpha: 0.1),
                  border: Border.all(
                    color: isMyTurn ? const Color(0xFFD4AF37) : Colors.white.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    UserPreferences.avatar,
                    style: TextStyle(
                      fontSize: 24,
                      color: isMyTurn ? Colors.black : null,
                    ),
                  ),
                ),
              ),
              // Dealer badge
              if (isDealer)
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0A0A0A),
                        width: 2,
                      ),
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
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Player label
          Text(
            'YOU',
            style: TextStyle(
              color: isMyTurn ? const Color(0xFFD4AF37) : Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          // Chips amount
          Text(
            _formatChips(_playerChips),
            style: TextStyle(
              color: Colors.yellow.shade500,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          // Current bet if any
          if (_playerBet > 0)
            Text(
              '(${_formatChips(_playerBet)})',
              style: TextStyle(
                color: Colors.orange.shade400,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  void _showRaiseSlider(int minRaise) {
    int raiseAmount = minRaise;
    final maxRaise = _playerChips + _playerBet;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Amount display
                  Text(
                    _formatChips(raiseAmount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RAISE TO',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withValues(alpha: 0.1),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                    ),
                    child: Slider(
                      value: raiseAmount.toDouble().clamp(minRaise.toDouble(), maxRaise.toDouble()),
                      min: minRaise.toDouble(),
                      max: maxRaise.toDouble(),
                      onChanged: (value) {
                        setDialogState(() => raiseAmount = value.toInt());
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
                          _formatChips(minRaise),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatChips(maxRaise),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Quick bet buttons
                  Row(
                    children: [
                      _buildQuickBetButton('½ Pot', () {
                        setDialogState(() {
                          raiseAmount = ((_pot / 2) + _currentBet).toInt().clamp(minRaise, maxRaise);
                        });
                      }),
                      const SizedBox(width: 8),
                      _buildQuickBetButton('Pot', () {
                        setDialogState(() {
                          raiseAmount = (_pot + _currentBet).clamp(minRaise, maxRaise);
                        });
                      }),
                      const SizedBox(width: 8),
                      _buildQuickBetButton('All In', () {
                        setDialogState(() {
                          raiseAmount = maxRaise;
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _AnimatedPressButton(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AnimatedPressButton(
                          onTap: () {
                            Navigator.pop(context);
                            _playerAction('raise', amount: raiseAmount);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'Raise',
                                style: TextStyle(
                                  color: Color(0xFF0A0A0A),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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
        ),
      ),
    );
  }

  Widget _buildQuickBetButton(String label, VoidCallback onTap) {
    return Expanded(
      child: _AnimatedPressButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCardSlot() {
    return Container(
      width: 58,
      height: 82,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
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

class _ActionButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = widget.color == Colors.white;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isWhite ? Colors.white : widget.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: isWhite ? null : Border.all(color: widget.color.withValues(alpha: 0.3)),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: isWhite ? Colors.black : widget.color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated button widget with scale animation on press
class _AnimatedGameButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry? padding;

  const _AnimatedGameButton({
    required this.child,
    required this.onTap,
    this.decoration,
    this.padding,
  });

  @override
  State<_AnimatedGameButton> createState() => _AnimatedGameButtonState();
}

class _AnimatedGameButtonState extends State<_AnimatedGameButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: child,
          ),
        ),
        child: Container(
          padding: widget.padding,
          decoration: widget.decoration,
          child: widget.child,
        ),
      ),
    );
  }
}

// Generic animated press button for setup screen and dialogs
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

class _AnimatedPressButtonState extends State<_AnimatedPressButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: isEnabled ? (_) => _controller.forward() : null,
      onTapUp: isEnabled
          ? (_) {
              _controller.reverse();
              widget.onTap!();
            }
          : null,
      onTapCancel: isEnabled ? () => _controller.reverse() : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: isEnabled ? _opacityAnimation.value : 0.5,
            child: child,
          ),
        ),
        child: widget.child,
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
  final List<PlayingCard> cards;
  final int seatIndex;

  _Participant({
    required this.name,
    required this.chips,
    required this.currentBet,
    required this.hasFolded,
    required this.isCurrentTurn,
    required this.isPlayer,
    required this.isDealer,
    this.cards = const [],
    this.seatIndex = 0,
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
  final List<PlayingCard> winningCards;

  _EvaluatedHand({
    required this.rank,
    required this.tiebreakers,
    required this.description,
    this.winningCards = const [],
  });

  /// Check if a card is part of the winning hand
  bool isCardInWinningHand(PlayingCard card) {
    return winningCards.any((c) => c.rank == card.rank && c.suit == card.suit);
  }

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
  List<PlayingCard>? bestCombo;
  for (final combo in combinations) {
    final hand = _evaluateFiveCards(combo);
    if (bestHand == null || hand.compareTo(bestHand) > 0) {
      bestHand = hand;
      bestCombo = combo;
    }
  }

  // Return hand with the winning cards included
  return _EvaluatedHand(
    rank: bestHand!.rank,
    tiebreakers: bestHand.tiebreakers,
    description: bestHand.description,
    winningCards: bestCombo ?? [],
  );
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
