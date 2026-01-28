import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/mobile_wrapper.dart';

// Playing card class
class TutorialCard {
  final String rank;
  final String suit;

  TutorialCard({required this.rank, required this.suit});

  String get display => '$rank$suit';

  bool get isRed => suit == '♥' || suit == '♦';

  int get rankValue {
    switch (rank) {
      case 'A':
        return 14;
      case 'K':
        return 13;
      case 'Q':
        return 12;
      case 'J':
        return 11;
      default:
        return int.tryParse(rank) ?? 0;
    }
  }
}

// Tutorial lesson structure
class TutorialLesson {
  final String title;
  final List<TutorialCard> playerCards;
  final List<TutorialCard> bot1Cards;
  final List<TutorialCard> bot2Cards;
  final List<TutorialCard> communityCards;
  final List<TutorialStep> steps;

  TutorialLesson({
    required this.title,
    required this.playerCards,
    required this.bot1Cards,
    required this.bot2Cards,
    required this.communityCards,
    required this.steps,
  });
}

class TutorialStep {
  final String phase; // 'preflop', 'flop', 'turn', 'river', 'showdown'
  final String lionMessage;
  final String? requiredAction; // 'fold', 'check', 'call', 'raise', 'allin', null (just info)
  final int? raiseAmount;
  final bool highlightCards;
  final bool highlightPot;
  final bool highlightActions;
  final String? botAction; // What bots do this step

  TutorialStep({
    required this.phase,
    required this.lionMessage,
    this.requiredAction,
    this.raiseAmount,
    this.highlightCards = false,
    this.highlightPot = false,
    this.highlightActions = false,
    this.botAction,
  });
}

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> with TickerProviderStateMixin {
  int _currentLessonIndex = 0;
  int _currentStepIndex = 0;
  bool _showLionBubble = true;
  bool _waitingForAction = false;
  bool _lessonComplete = false;

  // Game state
  String _gamePhase = 'preflop';
  int _pot = 150; // Starting with blinds posted
  int _playerChips = 10000;
  int _bot1Chips = 10000;
  int _bot2Chips = 10000;
  int _currentBet = 100;
  int _playerBet = 0;
  List<TutorialCard> _visibleCommunityCards = [];

  String _bot1Action = '';
  String _bot2Action = '';
  bool _showPlayerCards = true;
  bool _showBot1Cards = false;
  bool _showBot2Cards = false;

  late AnimationController _bubbleController;
  late Animation<double> _bubbleAnimation;

  // Tutorial lessons
  final List<TutorialLesson> _lessons = [
    // Lesson 1: Basic Introduction - Strong Hand
    TutorialLesson(
      title: 'Lesson 1: Your First Hand',
      playerCards: [
        TutorialCard(rank: 'A', suit: '♠'),
        TutorialCard(rank: 'A', suit: '♥'),
      ],
      bot1Cards: [
        TutorialCard(rank: 'K', suit: '♣'),
        TutorialCard(rank: 'Q', suit: '♣'),
      ],
      bot2Cards: [
        TutorialCard(rank: '7', suit: '♦'),
        TutorialCard(rank: '2', suit: '♠'),
      ],
      communityCards: [
        TutorialCard(rank: 'A', suit: '♣'),
        TutorialCard(rank: '8', suit: '♦'),
        TutorialCard(rank: '3', suit: '♠'),
        TutorialCard(rank: '5', suit: '♥'),
        TutorialCard(rank: 'J', suit: '♣'),
      ],
      steps: [
        TutorialStep(
          phase: 'preflop',
          lionMessage:
              "Welcome to Texas Hold'em! 🎉\n\nI'm Leo the Lion, and I'll teach you how to play poker!\n\nYou've been dealt two cards - these are YOUR hole cards. Only you can see them!",
          highlightCards: true,
        ),
        TutorialStep(
          phase: 'preflop',
          lionMessage:
              "Wow! You have Pocket Aces (A♠ A♥)! 🔥\n\nThis is the BEST starting hand in poker! Two Aces give you a powerful pair before any community cards are dealt.",
          highlightCards: true,
        ),
        TutorialStep(
          phase: 'preflop',
          lionMessage:
              "See the pot in the middle? That's 150 chips from the blinds.\n\nThe current bet is 100 (the big blind). You need to at least CALL this amount to stay in the hand.",
          highlightPot: true,
        ),
        TutorialStep(
          phase: 'preflop',
          lionMessage:
              "With such a strong hand, let's RAISE! 💪\n\nRaising puts pressure on opponents and builds the pot when you have great cards.\n\nTap the RAISE button!",
          requiredAction: 'raise',
          raiseAmount: 300,
          highlightActions: true,
        ),
        TutorialStep(
          phase: 'preflop',
          lionMessage:
              "Great raise! Bot 1 calls your raise, but Bot 2 folds.\n\nWhen someone folds, they give up their cards and any chance to win this hand.",
          botAction: 'bot1_call_bot2_fold',
        ),
        TutorialStep(
          phase: 'flop',
          lionMessage:
              "Now comes THE FLOP! 🃏\n\nThree community cards are dealt face-up. Everyone can use these cards with their hole cards to make the best 5-card hand.",
          highlightCards: true,
        ),
        TutorialStep(
          phase: 'flop',
          lionMessage:
              "AMAZING! The flop has an Ace! ♣️\n\nYou now have THREE ACES (Three of a Kind)! This is an incredibly strong hand!\n\nLet's bet to build the pot. Tap CHECK first (we're first to act).",
          requiredAction: 'check',
          highlightCards: true,
        ),
        TutorialStep(
          phase: 'flop',
          lionMessage:
              "Bot 1 bets 200 chips. Now you can CALL, RAISE, or FOLD.\n\nWith three Aces, we should definitely RAISE!\n\nTap RAISE!",
          requiredAction: 'raise',
          raiseAmount: 600,
          botAction: 'bot1_bet',
          highlightActions: true,
        ),
        TutorialStep(
          phase: 'flop',
          lionMessage: "Bot 1 calls your raise. The pot is growing! 💰",
          botAction: 'bot1_call',
        ),
        TutorialStep(
          phase: 'turn',
          lionMessage:
              "THE TURN - the fourth community card!\n\nOne more card to come after this. Your Three Aces are still very strong!",
          highlightCards: true,
        ),
        TutorialStep(
          phase: 'turn',
          lionMessage: "Let's keep building the pot.\n\nTap BET to put pressure on your opponent!",
          requiredAction: 'raise',
          raiseAmount: 500,
          highlightActions: true,
        ),
        TutorialStep(
          phase: 'turn',
          lionMessage: "Bot 1 calls again! They might have something, but probably can't beat your trips!",
          botAction: 'bot1_call',
        ),
        TutorialStep(
          phase: 'river',
          lionMessage:
              "THE RIVER - the final community card! 🌊\n\nThis is it! After this, we go to showdown if anyone calls.",
          highlightCards: true,
        ),
        TutorialStep(
          phase: 'river',
          lionMessage:
              "Time for a big bet! You have an incredible hand.\n\nLet's go ALL-IN and try to win their whole stack! 🚀\n\nTap ALL-IN!",
          requiredAction: 'allin',
          highlightActions: true,
        ),
        TutorialStep(
          phase: 'river',
          lionMessage: "Bot 1 calls the all-in! Time for SHOWDOWN! 🎯",
          botAction: 'bot1_call',
        ),
        TutorialStep(
          phase: 'showdown',
          lionMessage:
              "SHOWDOWN! All cards are revealed!\n\nBot 1 had K♣ Q♣ - they made a pair of Kings.\n\nBut YOU have THREE ACES! You WIN! 🏆🎉",
          highlightCards: true,
        ),
      ],
    ),

    // Lesson 2: When to Fold
    TutorialLesson(
      title: 'Lesson 2: Knowing When to Fold',
      playerCards: [
        TutorialCard(rank: '7', suit: '♦'),
        TutorialCard(rank: '2', suit: '♣'),
      ],
      bot1Cards: [
        TutorialCard(rank: 'A', suit: '♠'),
        TutorialCard(rank: 'K', suit: '♠'),
      ],
      bot2Cards: [
        TutorialCard(rank: 'Q', suit: '♥'),
        TutorialCard(rank: 'Q', suit: '♦'),
      ],
      communityCards: [
        TutorialCard(rank: 'A', suit: '♥'),
        TutorialCard(rank: 'K', suit: '♦'),
        TutorialCard(rank: '9', suit: '♠'),
        TutorialCard(rank: '4', suit: '♣'),
        TutorialCard(rank: 'A', suit: '♣'),
      ],
      steps: [
        TutorialStep(
          phase: 'preflop',
          lionMessage:
              "Not every hand is a winner! 😅\n\nLook at your cards: 7♦ 2♣\n\nThis is called 'Seven-Deuce' - it's actually the WORST starting hand in poker!",
          highlightCards: true,
        ),
        TutorialStep(
          phase: 'preflop',
          lionMessage:
              "Your cards don't connect (not suited, not close in rank).\n\nSmart players FOLD weak hands like this to save chips for better opportunities.\n\nTap FOLD!",
          requiredAction: 'fold',
          highlightActions: true,
        ),
        TutorialStep(
          phase: 'preflop',
          lionMessage: "Great decision! 👍\n\nBy folding, you saved your chips. Let's watch what happens...",
        ),
        TutorialStep(
          phase: 'showdown',
          lionMessage:
              "Bot 1 won with Two Pair (Aces and Kings)!\n\nIf you had stayed in, you would have lost a lot of chips. Folding weak hands is a KEY skill in poker! 🧠",
          highlightCards: true,
        ),
      ],
    ),

    // Lesson 3: Position and Betting
    TutorialLesson(
      title: 'Lesson 3: Reading the Board',
      playerCards: [
        TutorialCard(rank: 'K', suit: '♥'),
        TutorialCard(rank: 'Q', suit: '♥'),
      ],
      bot1Cards: [
        TutorialCard(rank: '10', suit: '♠'),
        TutorialCard(rank: '9', suit: '♠'),
      ],
      bot2Cards: [
        TutorialCard(rank: '5', suit: '♣'),
        TutorialCard(rank: '5', suit: '♦'),
      ],
      communityCards: [
        TutorialCard(rank: 'J', suit: '♥'),
        TutorialCard(rank: '10', suit: '♥'),
        TutorialCard(rank: '4', suit: '♠'),
        TutorialCard(rank: 'A', suit: '♥'),
        TutorialCard(rank: '2', suit: '♣'),
      ],
      steps: [
        TutorialStep(
          phase: 'preflop',
          lionMessage:
              "Let's learn about DRAWS! 🎨\n\nYou have K♥ Q♥ - two hearts! This is called a 'suited' hand and it's pretty good!",
          highlightCards: true,
        ),
        TutorialStep(
          phase: 'preflop',
          lionMessage: "Suited hands can make FLUSHES (5 cards of the same suit).\n\nLet's see the flop! Tap CALL.",
          requiredAction: 'call',
          highlightActions: true,
        ),
        TutorialStep(
          phase: 'preflop',
          lionMessage: "Both bots call. On to the flop!",
          botAction: 'both_call',
        ),
        TutorialStep(
          phase: 'flop',
          lionMessage:
              "WOW! Look at this flop! J♥ 10♥ 4♠\n\nYou have a FLUSH DRAW (4 hearts, need 1 more) AND a STRAIGHT DRAW (K-Q-J-10, need an Ace or 9)!",
          highlightCards: true,
        ),
        TutorialStep(
          phase: 'flop',
          lionMessage:
              "This is called a 'MONSTER DRAW'! 🐉\n\nYou have many cards that can help you. Let's see another card. Tap CHECK.",
          requiredAction: 'check',
          highlightActions: true,
        ),
        TutorialStep(
          phase: 'flop',
          lionMessage: "Everyone checks. Free card!",
          botAction: 'both_check',
        ),
        TutorialStep(
          phase: 'turn',
          lionMessage:
              "THE TURN: A♥ !!! 🎉\n\nYOU HIT YOUR FLUSH! K♥ Q♥ J♥ 10♥ A♥ - that's a ROYAL FLUSH, the BEST hand possible!",
          highlightCards: true,
        ),
        TutorialStep(
          phase: 'turn',
          lionMessage:
              "When you have the NUTS (best possible hand), you want to extract maximum value!\n\nLet's bet small to keep them in. Tap BET!",
          requiredAction: 'raise',
          raiseAmount: 200,
          highlightActions: true,
        ),
        TutorialStep(
          phase: 'turn',
          lionMessage: "Both bots call your small bet. Perfect! 😈",
          botAction: 'both_call',
        ),
        TutorialStep(
          phase: 'river',
          lionMessage:
              "The river doesn't matter - you already have the unbeatable hand!\n\nTime to get paid. Tap ALL-IN! 💰",
          requiredAction: 'allin',
          highlightActions: true,
        ),
        TutorialStep(
          phase: 'river',
          lionMessage: "Bot 1 folds but Bot 2 calls with their pocket 5s!",
          botAction: 'bot1_fold_bot2_call',
        ),
        TutorialStep(
          phase: 'showdown',
          lionMessage:
              "ROYAL FLUSH! 👑\n\nThe rarest and most powerful hand in poker! You played that perfectly - building the pot when you had a draw, then going for value when you hit!\n\nCongratulations, you've completed the tutorial! 🎓",
          highlightCards: true,
        ),
      ],
    ),
  ];

  TutorialLesson get _currentLesson => _lessons[_currentLessonIndex];
  TutorialStep get _currentStep => _currentLesson.steps[_currentStepIndex];

  @override
  void initState() {
    super.initState();
    _bubbleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bubbleAnimation = CurvedAnimation(
      parent: _bubbleController,
      curve: Curves.easeOutBack,
    );
    _bubbleController.forward();
    _initializeLesson();
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    super.dispose();
  }

  void _initializeLesson() {
    setState(() {
      _currentStepIndex = 0;
      _gamePhase = 'preflop';
      _pot = 150;
      _playerChips = 10000;
      _bot1Chips = 10000;
      _bot2Chips = 10000;
      _currentBet = 100;
      _playerBet = 0;
      _visibleCommunityCards = [];
      _bot1Action = '';
      _bot2Action = '';
      _showPlayerCards = true;
      _showBot1Cards = false;
      _showBot2Cards = false;
      _waitingForAction = false;
      _lessonComplete = false;
      _showLionBubble = true;
    });
    _processCurrentStep();
  }

  void _processCurrentStep() {
    final step = _currentStep;

    setState(() {
      _gamePhase = step.phase;

      // Show community cards based on phase
      if (step.phase == 'flop' && _visibleCommunityCards.length < 3) {
        _visibleCommunityCards = _currentLesson.communityCards.take(3).toList();
      } else if (step.phase == 'turn' && _visibleCommunityCards.length < 4) {
        _visibleCommunityCards = _currentLesson.communityCards.take(4).toList();
      } else if (step.phase == 'river' && _visibleCommunityCards.length < 5) {
        _visibleCommunityCards = _currentLesson.communityCards.take(5).toList();
      } else if (step.phase == 'showdown') {
        _visibleCommunityCards = _currentLesson.communityCards;
        _showBot1Cards = true;
        _showBot2Cards = true;
      }

      // Process bot actions
      if (step.botAction != null) {
        _processBotAction(step.botAction!);
      }

      // Check if action is required
      _waitingForAction = step.requiredAction != null;
    });

    // Animate lion bubble
    _bubbleController.reset();
    _bubbleController.forward();
  }

  void _processBotAction(String action) {
    switch (action) {
      case 'bot1_call_bot2_fold':
        _bot1Action = 'CALL';
        _bot2Action = 'FOLD';
        _bot1Chips -= 300;
        _pot += 300;
        break;
      case 'bot1_bet':
        _bot1Action = 'BET 200';
        _bot1Chips -= 200;
        _pot += 200;
        _currentBet = 200;
        break;
      case 'bot1_call':
        _bot1Action = 'CALL';
        // Chips already adjusted in player action
        break;
      case 'both_call':
        _bot1Action = 'CALL';
        _bot2Action = 'CALL';
        _bot1Chips -= 100;
        _bot2Chips -= 100;
        _pot += 200;
        break;
      case 'both_check':
        _bot1Action = 'CHECK';
        _bot2Action = 'CHECK';
        break;
      case 'bot1_fold_bot2_call':
        _bot1Action = 'FOLD';
        _bot2Action = 'CALL';
        break;
    }
  }

  void _handlePlayerAction(String action) {
    if (!_waitingForAction) return;

    final step = _currentStep;
    if (step.requiredAction != action) {
      // Wrong action - show hint
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Try tapping ${step.requiredAction?.toUpperCase() ?? 'the correct button'}!'),
          backgroundColor: const Color(0xFFD4AF37),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Correct action!
    setState(() {
      _waitingForAction = false;

      switch (action) {
        case 'fold':
          // Player folds
          break;
        case 'check':
          // Player checks
          break;
        case 'call':
          final callAmount = _currentBet - _playerBet;
          _playerChips -= callAmount;
          _playerBet = _currentBet;
          _pot += callAmount;
          break;
        case 'raise':
          final raiseAmount = step.raiseAmount ?? 300;
          _playerChips -= raiseAmount;
          _playerBet += raiseAmount;
          _pot += raiseAmount;
          _currentBet = _playerBet;
          break;
        case 'allin':
          _pot += _playerChips;
          _playerChips = 0;
          break;
      }
    });

    // Move to next step
    _nextStep();
  }

  void _nextStep() {
    if (_currentStepIndex < _currentLesson.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      _processCurrentStep();
    } else {
      // Lesson complete
      setState(() {
        _lessonComplete = true;
      });
    }
  }

  void _nextLesson() {
    if (_currentLessonIndex < _lessons.length - 1) {
      setState(() {
        _currentLessonIndex++;
      });
      _initializeLesson();
    } else {
      // Tutorial complete!
      _showTutorialComplete();
    }
  }

  void _showTutorialComplete() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFF00D46A).withValues(alpha: 0.5)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎓', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Tutorial Complete!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You\'ve learned the basics of Texas Hold\'em!\n\nNow go practice in Quick Play!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D46A),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: SafeArea(
          child: Stack(
            children: [
              // Main game area
              Column(
                children: [
                  _buildHeader(),
                  _buildGameTable(),
                  _buildPlayerArea(),
                ],
              ),

              // Lion with speech bubble
              if (_showLionBubble) _buildLionGuide(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
          const SizedBox(width: 12),
          // Lesson progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentLesson.title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: List.generate(_lessons.length, (index) {
                  return Container(
                    width: 20,
                    height: 3,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color:
                          index <= _currentLessonIndex ? const Color(0xFF00D46A) : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ],
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
              '$_pot',
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          // Step counter
          Text(
            '${_currentStepIndex + 1}/${_currentLesson.steps.length}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameTable() {
    return Expanded(
      child: Column(
        children: [
          // Bots row at top (matching game_screen style)
          _buildBotsRow(),

          // Spacer to push community cards to center
          const Spacer(flex: 2),

          // Community cards with pot inline
          _buildCommunityCardsWithPot(),

          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildBotsRow() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBotAvatar('B1', _bot1Chips, _bot1Action, _showBot1Cards ? _currentLesson.bot1Cards : null),
            const SizedBox(width: 16),
            _buildBotAvatar('B2', _bot2Chips, _bot2Action, _showBot2Cards ? _currentLesson.bot2Cards : null),
          ],
        ),
      ),
    );
  }

  Widget _buildBotAvatar(String name, int chips, String action, List<TutorialCard>? cards) {
    final hasFolded = action.contains('FOLD');
    final isCurrentTurn = false; // Tutorial doesn't track bot turns visually

    return Container(
      width: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasFolded ? Colors.grey.shade800 : Colors.white.withValues(alpha: 0.1),
                ),
                child: Center(
                  child: Text(
                    name == 'B1' ? '🤖' : '🦊',
                    style: TextStyle(
                      fontSize: 20,
                      color: hasFolded ? Colors.grey : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
              color: hasFolded ? Colors.grey : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _formatChips(chips),
            style: TextStyle(
              color: hasFolded ? Colors.grey : Colors.yellow.shade600,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (action.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: hasFolded ? Colors.red.withValues(alpha: 0.3) : const Color(0xFF00D46A).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                action,
                style: TextStyle(
                  color: hasFolded ? Colors.red.shade300 : const Color(0xFF00D46A),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommunityCardsWithPot() {
    return Column(
      children: [
        // Community cards
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < 5; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              i < _visibleCommunityCards.length
                  ? _buildMinimalCard(_visibleCommunityCards[i], highlight: _currentStep.highlightCards)
                  : _buildEmptyCardSlot(),
            ],
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

  Widget _buildMinimalCard(TutorialCard card, {bool highlight = false, bool isLarge = false}) {
    final width = isLarge ? 70.0 : 56.0;
    final height = isLarge ? 98.0 : 78.0;
    final isRed = card.isRed;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: highlight ? Border.all(color: const Color(0xFFD4AF37), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: highlight ? const Color(0xFFD4AF37).withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.3),
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
              fontSize: isLarge ? 24 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            card.suit,
            style: TextStyle(
              color: isRed ? Colors.red.shade700 : Colors.black,
              fontSize: isLarge ? 26 : 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCardSlot() {
    return Container(
      width: 56,
      height: 78,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
    );
  }

  Widget _buildMiniCard(TutorialCard card) {
    final isRed = card.isRed;
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

  Widget _buildMiniCardBack() {
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

  String _formatChips(int chips) {
    if (chips >= 1000000) {
      return '${(chips / 1000000).toStringAsFixed(1)}M';
    } else if (chips >= 1000) {
      return '${(chips / 1000).toStringAsFixed(1)}K';
    }
    return chips.toString();
  }

  Widget _buildBotSeat(String name, int chips, List<TutorialCard>? cards, String action) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cards
          Row(
            mainAxisSize: MainAxisSize.min,
            children: cards != null
                ? cards
                    .map((c) =>
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: _buildCard(c, small: true)))
                    .toList()
                : [_buildCardBack(small: true), _buildCardBack(small: true)],
          ),
          const SizedBox(height: 6),
          // Name
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
          Text('$chips', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
          if (action.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: action.contains('FOLD')
                    ? Colors.red.withValues(alpha: 0.6)
                    : const Color(0xFF00D46A).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Text(action, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          // Action buttons row
          if (!_lessonComplete) _buildActionButtonsRow(),
          const SizedBox(height: 16),
          // Player cards and avatar row
          Row(
            children: [
              // Player cards (larger, swipe-to-fold style)
              Expanded(
                child: Row(
                  children: _showPlayerCards
                      ? _currentLesson.playerCards
                          .map((c) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildMinimalCard(c, highlight: _currentStep.highlightCards, isLarge: true),
                              ))
                          .toList()
                      : [_buildCardBack(), const SizedBox(width: 8), _buildCardBack()],
                ),
              ),
              const SizedBox(width: 12),
              // Player avatar on right
              _buildPlayerAvatar(),
            ],
          ),
          const SizedBox(height: 16),
          // Lesson complete buttons
          if (_lessonComplete) _buildLessonCompleteButtons(),
        ],
      ),
    );
  }

  Widget _buildPlayerAvatar() {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(color: const Color(0xFF3B82F6), width: 2),
          ),
          child: const Center(
            child: Text('👤', style: TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(height: 4),
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

  Widget _buildActionButtonsRow() {
    final step = _currentStep;
    final isActionStep = step.requiredAction != null;

    if (!isActionStep) {
      // Just a "Continue" button for info steps
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D46A),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text('Continue', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      );
    }

    // Action buttons - match game_screen layout (two buttons side by side)
    final canCheck = _currentBet <= _playerBet;
    final isCallRequired = step.requiredAction == 'call' || step.requiredAction == 'check';
    final isRaiseRequired = step.requiredAction == 'raise' || step.requiredAction == 'allin';
    final isFoldRequired = step.requiredAction == 'fold';

    return Row(
      children: [
        // Check/Call button
        Expanded(
          child: GestureDetector(
            onTap: () => _handlePlayerAction(canCheck ? 'check' : 'call'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isCallRequired ? const Color(0xFF00D46A) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCallRequired ? const Color(0xFF00D46A) : Colors.white.withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                child: Text(
                  canCheck ? 'Check' : 'Call',
                  style: TextStyle(
                    color: isCallRequired ? Colors.white : Colors.white,
                    fontSize: 16,
                    fontWeight: isCallRequired ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Raise button
        Expanded(
          child: GestureDetector(
            onTap: () => _handlePlayerAction(step.requiredAction == 'allin' ? 'allin' : 'raise'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isRaiseRequired ? const Color(0xFFD4AF37) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isRaiseRequired ? const Color(0xFFD4AF37) : Colors.white.withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                child: Text(
                  step.requiredAction == 'allin' ? 'All In' : 'Raise',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: isRaiseRequired ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn(String label, Color color, bool isRequired) {
    final isWhite = color == Colors.white;
    return GestureDetector(
      onTap: () {
        final action = label.toLowerCase().replaceAll(' ', '');
        if (action == 'check' || action == 'call') {
          _handlePlayerAction(_currentBet <= _playerBet ? 'check' : 'call');
        } else {
          _handlePlayerAction(action);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isRequired
              ? color
              : isWhite
                  ? Colors.white
                  : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: isRequired
              ? Border.all(color: Colors.white, width: 1.5)
              : isWhite
                  ? null
                  : Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: isRequired ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isRequired
                    ? Colors.white
                    : isWhite
                        ? Colors.black
                        : color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialActionButton(String label, Color color, bool isRequired, {bool fullWidth = false}) {
    return GestureDetector(
      onTap: () {
        final action = label.toLowerCase().replaceAll('-', '');
        if (action == 'check' || action == 'call') {
          _handlePlayerAction(_currentBet <= _playerBet ? 'check' : 'call');
        } else {
          _handlePlayerAction(action);
        }
      },
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: fullWidth ? 20 : 16, vertical: 12),
        decoration: BoxDecoration(
          color: isRequired ? color : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
          border: isRequired ? null : Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isRequired ? Colors.white : color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSeat() {
    return Column(
      children: [
        // Player cards
        Row(
          mainAxisSize: MainAxisSize.min,
          children: _showPlayerCards
              ? _currentLesson.playerCards
                  .map((c) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _buildCard(c, highlight: _currentStep.highlightCards),
                      ))
                  .toList()
              : [_buildCardBack(), _buildCardBack()],
        ),
        const SizedBox(height: 8),
        // Player info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('YOU', style: TextStyle(color: Color(0xFF00D46A), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              const Text('🪙', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text('$_playerChips',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(TutorialCard card, {bool small = false, bool highlight = false}) {
    final isRed = card.isRed;
    double width = small ? 32.0 : 56.0;
    double height = small ? 46.0 : 80.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: highlight ? Border.all(color: const Color(0xFFD4AF37), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: highlight ? const Color(0xFFD4AF37).withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.2),
            blurRadius: highlight ? 8 : 4,
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
              fontSize: small ? 11 : 18,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          Text(
            card.suit,
            style: TextStyle(
              color: isRed ? Colors.red.shade700 : Colors.black87,
              fontSize: small ? 10 : 16,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack({bool small = false}) {
    double width = small ? 32.0 : 56.0;
    double height = small ? 46.0 : 80.0;

    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A3E), Color(0xFF1A1A2E)],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
    );
  }

  Widget _buildActionButtons() {
    final step = _currentStep;
    final isActionStep = step.requiredAction != null;

    if (!isActionStep && !_lessonComplete) {
      // Just a "Continue" button for info steps
      return Container(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D46A),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    // Action buttons
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildActionButton('FOLD', Colors.red, step.requiredAction == 'fold'),
              const SizedBox(width: 8),
              _buildActionButton(
                _currentBet <= _playerBet ? 'CHECK' : 'CALL',
                Colors.blue,
                step.requiredAction == 'check' || step.requiredAction == 'call',
              ),
              const SizedBox(width: 8),
              _buildActionButton('RAISE', const Color(0xFF00D46A), step.requiredAction == 'raise'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _buildActionButton('ALL-IN', const Color(0xFFD4AF37), step.requiredAction == 'allin'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, bool isRequired) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          final action = label.toLowerCase().replaceAll('-', '');
          if (action == 'check' || action == 'call') {
            _handlePlayerAction(_currentBet <= _playerBet ? 'check' : 'call');
          } else {
            _handlePlayerAction(action);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isRequired ? color : color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: isRequired ? Border.all(color: Colors.white, width: 2) : null,
            boxShadow:
                isRequired ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2)] : null,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isRequired ? Colors.white : Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isRequired) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLessonCompleteButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _initializeLesson,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: const Text('Replay'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _nextLesson,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D46A),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Text(
              _currentLessonIndex < _lessons.length - 1 ? 'Next Lesson' : 'Finish Tutorial',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLionGuide() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: _waitingForAction || _lessonComplete ? 220 : 180,
      child: ScaleTransition(
        scale: _bubbleAnimation,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Lion avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(child: Text('🦁', style: TextStyle(fontSize: 32))),
            ),
            const SizedBox(width: 8),
            // Speech bubble
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Leo the Lion',
                          style: TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_currentStep.requiredAction != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D46A).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Your turn!',
                              style: TextStyle(
                                color: Color(0xFF00D46A),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currentStep.lionMessage,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
