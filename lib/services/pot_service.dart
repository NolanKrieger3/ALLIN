import '../models/game_room.dart';
import 'hand_evaluator.dart';

/// Service for pot calculations, side pots, and chip distribution
class PotService {
  /// Calculate side pots when players are all-in for different amounts
  /// Returns a list of (pot amount, eligible player uids) pairs
  static List<({int amount, List<String> eligibleUids})> calculateSidePots(List<GamePlayer> players) {
    // Get all players who contributed (not folded or contributed to pot)
    final contributors = players.where((p) => p.totalContributed > 0 || !p.hasFolded).toList();
    if (contributors.isEmpty) return [];

    // Get unique contribution amounts sorted (using totalContributed for the whole hand)
    final contributionAmounts = contributors.map((p) => p.totalContributed).toSet().toList()..sort();

    final sidePots = <({int amount, List<String> eligibleUids})>[];
    var previousLevel = 0;

    for (final level in contributionAmounts) {
      if (level <= previousLevel) continue;

      // Calculate how much goes into this pot level
      final levelContribution = level - previousLevel;

      // Find all players who contributed at least this amount
      final eligiblePlayers = contributors.where((p) => p.totalContributed >= level && !p.hasFolded).toList();
      final allContributors = contributors.where((p) => p.totalContributed >= level).toList();

      if (eligiblePlayers.isNotEmpty) {
        final potAmount = levelContribution * allContributors.length;
        sidePots.add((amount: potAmount, eligibleUids: eligiblePlayers.map((p) => p.uid).toList()));
      }

      previousLevel = level;
    }

    return sidePots;
  }

  /// Distribute pot(s) to winners, handling side pots correctly
  static List<GamePlayer> distributePots(
    List<GamePlayer> players,
    List<PlayingCard> communityCards,
    int totalPot,
  ) {
    final finalPlayers = List<GamePlayer>.from(players);
    final activePlayers = players.where((p) => !p.hasFolded).toList();

    if (activePlayers.length == 1) {
      // Only one player left - they win everything
      final winnerIdx = finalPlayers.indexWhere((p) => p.uid == activePlayers.first.uid);
      if (winnerIdx != -1) {
        finalPlayers[winnerIdx] = finalPlayers[winnerIdx].copyWith(
          chips: finalPlayers[winnerIdx].chips + totalPot,
        );
      }
      return finalPlayers;
    }

    // Calculate side pots
    final sidePots = calculateSidePots(players);

    if (sidePots.isEmpty) {
      // No side pots - simple distribution
      final winnerIndices = HandEvaluator.determineWinners(activePlayers, communityCards);
      if (winnerIndices.isEmpty) return finalPlayers;

      final sharePerWinner = totalPot ~/ winnerIndices.length;
      for (final winnerIdx in winnerIndices) {
        final winnerId = activePlayers[winnerIdx].uid;
        final playerIdx = finalPlayers.indexWhere((p) => p.uid == winnerId);
        if (playerIdx != -1) {
          finalPlayers[playerIdx] = finalPlayers[playerIdx].copyWith(
            chips: finalPlayers[playerIdx].chips + sharePerWinner,
          );
        }
      }
      return finalPlayers;
    }

    // Distribute each side pot
    for (final pot in sidePots) {
      final eligibleForThisPot = finalPlayers.where((p) => pot.eligibleUids.contains(p.uid)).toList();
      if (eligibleForThisPot.isEmpty) continue;

      final winnerIndices = HandEvaluator.determineWinners(eligibleForThisPot, communityCards);
      if (winnerIndices.isEmpty) continue;

      final winAmount = pot.amount ~/ winnerIndices.length;
      for (final winnerIdx in winnerIndices) {
        final winnerId = eligibleForThisPot[winnerIdx].uid;
        final playerIdx = finalPlayers.indexWhere((p) => p.uid == winnerId);
        if (playerIdx != -1) {
          finalPlayers[playerIdx] = finalPlayers[playerIdx].copyWith(
            chips: finalPlayers[playerIdx].chips + winAmount,
          );
        }
      }
    }

    return finalPlayers;
  }
}
