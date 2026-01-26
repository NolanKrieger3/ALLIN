import '../models/game_room.dart';

/// Hand rankings from lowest to highest
enum HandRank {
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

/// Represents an evaluated poker hand
class EvaluatedHand {
  final HandRank rank;
  final List<int> tiebreakers; // For comparing hands of same rank
  final String description;
  
  EvaluatedHand({
    required this.rank,
    required this.tiebreakers,
    required this.description,
  });
  
  /// Compare two hands. Returns positive if this hand wins, negative if other wins, 0 if tie
  int compareTo(EvaluatedHand other) {
    // First compare by hand rank
    if (rank.index != other.rank.index) {
      return rank.index - other.rank.index;
    }
    
    // Same rank - compare tiebreakers
    for (int i = 0; i < tiebreakers.length && i < other.tiebreakers.length; i++) {
      if (tiebreakers[i] != other.tiebreakers[i]) {
        return tiebreakers[i] - other.tiebreakers[i];
      }
    }
    
    return 0; // Exact tie
  }
}

/// Evaluates poker hands according to Texas Hold'em rules
class HandEvaluator {
  /// Card rank values (Ace can be 1 or 14)
  static int getRankValue(String rank) {
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
  
  /// Get the best 5-card hand from 7 cards (2 hole + 5 community)
  static EvaluatedHand evaluateBestHand(List<PlayingCard> holeCards, List<PlayingCard> communityCards) {
    final allCards = [...holeCards, ...communityCards];
    
    // Generate all 5-card combinations from 7 cards (21 combinations)
    final combinations = _getCombinations(allCards, 5);
    
    EvaluatedHand? bestHand;
    for (final combo in combinations) {
      final hand = _evaluateFiveCards(combo);
      if (bestHand == null || hand.compareTo(bestHand) > 0) {
        bestHand = hand;
      }
    }
    
    return bestHand!;
  }
  
  /// Generate all combinations of size k from a list
  static List<List<PlayingCard>> _getCombinations(List<PlayingCard> cards, int k) {
    final result = <List<PlayingCard>>[];
    _combinationsHelper(cards, k, 0, [], result);
    return result;
  }
  
  static void _combinationsHelper(
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
      _combinationsHelper(cards, k, i + 1, current, result);
      current.removeLast();
    }
  }
  
  /// Evaluate exactly 5 cards
  static EvaluatedHand _evaluateFiveCards(List<PlayingCard> cards) {
    final ranks = cards.map((c) => getRankValue(c.rank)).toList()..sort((a, b) => b - a);
    final suits = cards.map((c) => c.suit).toList();
    
    // Check for flush
    final isFlush = suits.toSet().length == 1;
    
    // Check for straight
    final isStraight = _isStraight(ranks);
    final isLowStraight = _isLowStraight(ranks); // A-2-3-4-5
    
    // Count ranks for pairs, trips, quads
    final rankCounts = <int, int>{};
    for (final r in ranks) {
      rankCounts[r] = (rankCounts[r] ?? 0) + 1;
    }
    
    final counts = rankCounts.values.toList()..sort((a, b) => b - a);
    
    // Royal Flush: A-K-Q-J-10 of same suit
    if (isFlush && isStraight && ranks[0] == 14 && ranks[1] == 13) {
      return EvaluatedHand(
        rank: HandRank.royalFlush,
        tiebreakers: [14],
        description: 'Royal Flush',
      );
    }
    
    // Straight Flush
    if (isFlush && (isStraight || isLowStraight)) {
      final highCard = isLowStraight ? 5 : ranks[0];
      return EvaluatedHand(
        rank: HandRank.straightFlush,
        tiebreakers: [highCard],
        description: 'Straight Flush, ${_rankName(highCard)} high',
      );
    }
    
    // Four of a Kind
    if (counts[0] == 4) {
      final quadRank = rankCounts.entries.firstWhere((e) => e.value == 4).key;
      final kicker = rankCounts.entries.firstWhere((e) => e.value == 1).key;
      return EvaluatedHand(
        rank: HandRank.fourOfAKind,
        tiebreakers: [quadRank, kicker],
        description: 'Four of a Kind, ${_rankName(quadRank)}s',
      );
    }
    
    // Full House
    if (counts[0] == 3 && counts[1] == 2) {
      final tripRank = rankCounts.entries.firstWhere((e) => e.value == 3).key;
      final pairRank = rankCounts.entries.firstWhere((e) => e.value == 2).key;
      return EvaluatedHand(
        rank: HandRank.fullHouse,
        tiebreakers: [tripRank, pairRank],
        description: 'Full House, ${_rankName(tripRank)}s full of ${_rankName(pairRank)}s',
      );
    }
    
    // Flush
    if (isFlush) {
      return EvaluatedHand(
        rank: HandRank.flush,
        tiebreakers: ranks,
        description: 'Flush, ${_rankName(ranks[0])} high',
      );
    }
    
    // Straight
    if (isStraight || isLowStraight) {
      final highCard = isLowStraight ? 5 : ranks[0];
      return EvaluatedHand(
        rank: HandRank.straight,
        tiebreakers: [highCard],
        description: 'Straight, ${_rankName(highCard)} high',
      );
    }
    
    // Three of a Kind
    if (counts[0] == 3) {
      final tripRank = rankCounts.entries.firstWhere((e) => e.value == 3).key;
      final kickers = rankCounts.entries.where((e) => e.value == 1).map((e) => e.key).toList()..sort((a, b) => b - a);
      return EvaluatedHand(
        rank: HandRank.threeOfAKind,
        tiebreakers: [tripRank, ...kickers],
        description: 'Three of a Kind, ${_rankName(tripRank)}s',
      );
    }
    
    // Two Pair
    if (counts[0] == 2 && counts[1] == 2) {
      final pairs = rankCounts.entries.where((e) => e.value == 2).map((e) => e.key).toList()..sort((a, b) => b - a);
      final kicker = rankCounts.entries.firstWhere((e) => e.value == 1).key;
      return EvaluatedHand(
        rank: HandRank.twoPair,
        tiebreakers: [...pairs, kicker],
        description: 'Two Pair, ${_rankName(pairs[0])}s and ${_rankName(pairs[1])}s',
      );
    }
    
    // One Pair
    if (counts[0] == 2) {
      final pairRank = rankCounts.entries.firstWhere((e) => e.value == 2).key;
      final kickers = rankCounts.entries.where((e) => e.value == 1).map((e) => e.key).toList()..sort((a, b) => b - a);
      return EvaluatedHand(
        rank: HandRank.onePair,
        tiebreakers: [pairRank, ...kickers],
        description: 'Pair of ${_rankName(pairRank)}s',
      );
    }
    
    // High Card
    return EvaluatedHand(
      rank: HandRank.highCard,
      tiebreakers: ranks,
      description: '${_rankName(ranks[0])} high',
    );
  }
  
  /// Check if ranks form a straight (assumes sorted descending)
  static bool _isStraight(List<int> ranks) {
    for (int i = 0; i < ranks.length - 1; i++) {
      if (ranks[i] - ranks[i + 1] != 1) {
        return false;
      }
    }
    return true;
  }
  
  /// Check for A-2-3-4-5 straight (wheel)
  static bool _isLowStraight(List<int> ranks) {
    final sorted = List<int>.from(ranks)..sort();
    return sorted[0] == 2 && sorted[1] == 3 && sorted[2] == 4 && sorted[3] == 5 && sorted[4] == 14;
  }
  
  /// Convert rank value to name
  static String _rankName(int rank) {
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
  
  /// Determine winner(s) from a list of players
  /// Returns list of winner indices (multiple if tie/split pot)
  static List<int> determineWinners(
    List<GamePlayer> players,
    List<PlayingCard> communityCards,
  ) {
    final activePlayers = <int, EvaluatedHand>{};
    
    for (int i = 0; i < players.length; i++) {
      if (!players[i].hasFolded && players[i].cards.isNotEmpty) {
        activePlayers[i] = evaluateBestHand(players[i].cards, communityCards);
      }
    }
    
    if (activePlayers.isEmpty) return [];
    
    // Find the best hand
    EvaluatedHand? bestHand;
    for (final hand in activePlayers.values) {
      if (bestHand == null || hand.compareTo(bestHand) > 0) {
        bestHand = hand;
      }
    }
    
    // Find all players with the best hand (for split pots)
    final winners = <int>[];
    for (final entry in activePlayers.entries) {
      if (entry.value.compareTo(bestHand!) == 0) {
        winners.add(entry.key);
      }
    }
    
    return winners;
  }
}
