import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_room.dart';
import 'hand_evaluator.dart';
import 'pot_service.dart';
import 'room_service.dart';

/// Game phases for Texas Hold'em
enum GamePhase {
  preflop,
  flop,
  turn,
  river,
  showdown,
  waitingForPlayers;

  static GamePhase fromString(String? value) {
    switch (value) {
      case 'preflop':
        return GamePhase.preflop;
      case 'flop':
        return GamePhase.flop;
      case 'turn':
        return GamePhase.turn;
      case 'river':
        return GamePhase.river;
      case 'showdown':
        return GamePhase.showdown;
      case 'waiting_for_players':
        return GamePhase.waitingForPlayers;
      default:
        return GamePhase.preflop;
    }
  }

  String toDbString() {
    switch (this) {
      case GamePhase.waitingForPlayers:
        return 'waiting_for_players';
      default:
        return name;
    }
  }
}

/// Service for handling player and bot actions in poker games
class GameActionService {
  final RoomService _roomService = RoomService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<String?> _getAuthToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  /// Check if a player is a bot
  bool isBot(String playerId) {
    return playerId.startsWith('bot_');
  }

  /// Player action (fold, check, call, raise, allin)
  Future<void> playerAction(String roomId, String action, {int? raiseAmount}) async {
    final userId = currentUserId;
    if (userId == null) return;

    final room = await _roomService.fetchRoom(roomId);
    if (room == null) return;

    if (room.currentTurnPlayerId != userId) {
      throw Exception('Not your turn');
    }

    final playerIndex = room.players.indexWhere((p) => p.uid == userId);
    if (playerIndex == -1) return;

    final player = room.players[playerIndex];
    var updatedPlayers = List<GamePlayer>.from(room.players);
    var pot = room.pot;
    var currentBet = room.currentBet;
    var lastRaiseAmount = room.lastRaiseAmount;

    updatedPlayers[playerIndex] = player.copyWith(hasActed: true);

    String lastActionLabel = action.toUpperCase();

    switch (action) {
      case 'fold':
        updatedPlayers[playerIndex] = updatedPlayers[playerIndex].copyWith(hasFolded: true, lastAction: 'FOLD');
        break;

      case 'check':
        if (currentBet > player.currentBet) {
          throw Exception('Cannot check - must call or raise');
        }
        updatedPlayers[playerIndex] = updatedPlayers[playerIndex].copyWith(lastAction: 'CHECK');
        break;

      case 'call':
        var callAmount = currentBet - player.currentBet;
        if (callAmount > player.chips) {
          callAmount = player.chips;
          lastActionLabel = 'ALL-IN';
        } else {
          lastActionLabel = 'CALL';
        }
        updatedPlayers[playerIndex] = updatedPlayers[playerIndex].copyWith(
          chips: player.chips - callAmount,
          currentBet: player.currentBet + callAmount,
          totalContributed: player.totalContributed + callAmount,
          lastAction: lastActionLabel,
        );
        pot += callAmount;
        break;

      case 'raise':
        final totalBet = raiseAmount ?? (currentBet + lastRaiseAmount);
        final raiseBy = totalBet - currentBet;

        if (raiseBy < lastRaiseAmount && totalBet < player.chips + player.currentBet) {
          throw Exception('Raise must be at least $lastRaiseAmount');
        }

        final addAmount = totalBet - player.currentBet;
        if (addAmount > player.chips) {
          throw Exception('Not enough chips');
        }

        if (addAmount == player.chips) {
          lastActionLabel = 'ALL-IN';
        } else {
          lastActionLabel = 'RAISE';
        }

        updatedPlayers[playerIndex] = updatedPlayers[playerIndex].copyWith(
          chips: player.chips - addAmount,
          currentBet: totalBet,
          totalContributed: player.totalContributed + addAmount,
          lastAction: lastActionLabel,
        );
        pot += addAmount;
        lastRaiseAmount = raiseBy;
        currentBet = totalBet;

        updatedPlayers = updatedPlayers.map((p) {
          if (p.uid != userId && !p.hasFolded) {
            return p.copyWith(hasActed: false);
          }
          return p;
        }).toList();
        break;

      case 'allin':
        final allInAmount = player.chips;
        final newTotalBet = player.currentBet + allInAmount;

        pot += allInAmount;
        updatedPlayers[playerIndex] = updatedPlayers[playerIndex].copyWith(
          currentBet: newTotalBet,
          chips: 0,
          totalContributed: player.totalContributed + allInAmount,
          lastAction: 'ALL-IN',
        );

        if (newTotalBet > currentBet) {
          final raiseBy = newTotalBet - currentBet;
          final isFullRaise = raiseBy >= lastRaiseAmount;

          // Update lastRaiseAmount only for full raises
          if (isFullRaise) {
            lastRaiseAmount = raiseBy;
          }

          // ALWAYS reset hasActed for other players when all-in increases the bet
          // They need a chance to respond (call/fold/raise) regardless of raise size
          print('🎲 ALL-IN RAISE: resetting hasActed for opponents (currentBet $currentBet -> $newTotalBet)');
          updatedPlayers = updatedPlayers.map((p) {
            if (p.uid != userId && !p.hasFolded && p.chips > 0) {
              print('   Resetting hasActed for ${p.displayName} (chips: ${p.chips})');
              return p.copyWith(hasActed: false);
            }
            return p;
          }).toList();

          currentBet = newTotalBet;
        }

        print('🎲 ALL-IN: player bet=$newTotalBet, currentBet=$currentBet, chips=0');
        break;
    }

    final currentPlayerIdx = updatedPlayers.indexWhere((p) => p.uid == userId);
    if (currentPlayerIdx != -1) {
      updatedPlayers[currentPlayerIdx] = updatedPlayers[currentPlayerIdx].copyWith(hasActed: true);
    }

    await _processPostAction(
      roomId: roomId,
      room: room,
      updatedPlayers: updatedPlayers,
      pot: pot,
      currentBet: currentBet,
      lastRaiseAmount: lastRaiseAmount,
      playerIndex: playerIndex,
      action: action,
    );
  }

  /// Bot action - executes an action on behalf of a bot player
  Future<void> botAction(String roomId, String botId, String action, {int? raiseAmount}) async {
    final userId = currentUserId;
    if (userId == null) return;

    final room = await _roomService.fetchRoom(roomId);
    if (room == null) return;

    if (room.hostId != userId) {
      throw Exception('Only the host can control bots');
    }

    if (room.currentTurnPlayerId != botId) {
      throw Exception('Not this bot\'s turn');
    }

    if (!isBot(botId)) {
      throw Exception('Not a bot player');
    }

    final playerIndex = room.players.indexWhere((p) => p.uid == botId);
    if (playerIndex == -1) return;

    final player = room.players[playerIndex];
    var updatedPlayers = List<GamePlayer>.from(room.players);
    var pot = room.pot;
    var currentBet = room.currentBet;
    var lastRaiseAmount = room.lastRaiseAmount;

    updatedPlayers[playerIndex] = player.copyWith(hasActed: true);

    String lastActionLabel = action.toUpperCase();

    switch (action) {
      case 'fold':
        updatedPlayers[playerIndex] = updatedPlayers[playerIndex].copyWith(hasFolded: true, lastAction: 'FOLD');
        break;

      case 'check':
        if (currentBet > player.currentBet) {
          var callAmount = currentBet - player.currentBet;
          if (callAmount > player.chips) {
            callAmount = player.chips;
            lastActionLabel = 'ALL-IN';
          } else {
            lastActionLabel = 'CALL';
          }
          updatedPlayers[playerIndex] = updatedPlayers[playerIndex].copyWith(
            chips: player.chips - callAmount,
            currentBet: player.currentBet + callAmount,
            totalContributed: player.totalContributed + callAmount,
            lastAction: lastActionLabel,
          );
          pot += callAmount;
        } else {
          updatedPlayers[playerIndex] = updatedPlayers[playerIndex].copyWith(lastAction: 'CHECK');
        }
        break;

      case 'call':
        var callAmount = currentBet - player.currentBet;
        if (callAmount > player.chips) {
          callAmount = player.chips;
          lastActionLabel = 'ALL-IN';
        } else {
          lastActionLabel = 'CALL';
        }
        updatedPlayers[playerIndex] = updatedPlayers[playerIndex].copyWith(
          chips: player.chips - callAmount,
          currentBet: player.currentBet + callAmount,
          totalContributed: player.totalContributed + callAmount,
          lastAction: lastActionLabel,
        );
        pot += callAmount;
        break;

      case 'raise':
        final totalBet = raiseAmount ?? (currentBet + lastRaiseAmount);
        final raiseBy = totalBet - currentBet;
        final addAmount = totalBet - player.currentBet;

        if (addAmount > player.chips) {
          final allInAmount = player.chips;
          final newTotalBet = player.currentBet + allInAmount;
          pot += allInAmount;
          updatedPlayers[playerIndex] = updatedPlayers[playerIndex].copyWith(
            currentBet: newTotalBet,
            chips: 0,
            totalContributed: player.totalContributed + allInAmount,
            lastAction: 'ALL-IN',
          );
          if (newTotalBet > currentBet) {
            final raiseBy = newTotalBet - currentBet;
            final isFullRaise = raiseBy >= lastRaiseAmount;

            if (isFullRaise) {
              lastRaiseAmount = raiseBy;
              // Reset hasActed for all other players since this is a full raise
              updatedPlayers = updatedPlayers.map((p) {
                if (p.uid != botId && !p.hasFolded) {
                  return p.copyWith(hasActed: false);
                }
                return p;
              }).toList();
            }
            currentBet = newTotalBet;
          }
        } else {
          if (addAmount == player.chips) {
            lastActionLabel = 'ALL-IN';
          } else {
            lastActionLabel = 'RAISE';
          }
          updatedPlayers[playerIndex] = updatedPlayers[playerIndex].copyWith(
            chips: player.chips - addAmount,
            currentBet: totalBet,
            totalContributed: player.totalContributed + addAmount,
            lastAction: lastActionLabel,
          );
          pot += addAmount;
          lastRaiseAmount = raiseBy > 0 ? raiseBy : lastRaiseAmount;
          currentBet = totalBet;

          updatedPlayers = updatedPlayers.map((p) {
            if (p.uid != botId && !p.hasFolded) {
              return p.copyWith(hasActed: false);
            }
            return p;
          }).toList();
        }
        break;
    }

    await _processPostAction(
      roomId: roomId,
      room: room,
      updatedPlayers: updatedPlayers,
      pot: pot,
      currentBet: currentBet,
      lastRaiseAmount: lastRaiseAmount,
      playerIndex: playerIndex,
      action: action,
      actorId: botId,
    );
  }

  /// Process the state after an action (check for winners, advance phase, etc.)
  Future<void> _processPostAction({
    required String roomId,
    required GameRoom room,
    required List<GamePlayer> updatedPlayers,
    required int pot,
    required int currentBet,
    required int lastRaiseAmount,
    required int playerIndex,
    required String action,
    String? actorId,
  }) async {
    final token = await _getAuthToken();

    // Check if hand is over (only one player left)
    final activePlayers = updatedPlayers.where((p) => !p.hasFolded).toList();
    if (activePlayers.length == 1) {
      final winnerIndex = updatedPlayers.indexWhere((p) => !p.hasFolded);
      updatedPlayers[winnerIndex] = updatedPlayers[winnerIndex].copyWith(
        chips: updatedPlayers[winnerIndex].chips + pot,
      );

      await http.patch(
        Uri.parse('${RoomService.databaseUrl}/game_rooms/$roomId.json?auth=$token'),
        body: jsonEncode({
          'players': updatedPlayers.map((p) => p.toJson()).toList(),
          'pot': 0,
          'status': 'finished',
          'phase': 'showdown',
          'winnerId': updatedPlayers[winnerIndex].uid,
        }),
      );
      return;
    }

    // Find next player
    var nextPlayerIndex = (playerIndex + 1) % updatedPlayers.length;
    int loopCount = 0;
    while ((updatedPlayers[nextPlayerIndex].hasFolded || updatedPlayers[nextPlayerIndex].chips == 0) &&
        loopCount < updatedPlayers.length) {
      nextPlayerIndex = (nextPlayerIndex + 1) % updatedPlayers.length;
      loopCount++;
    }

    // Check BB option
    final currentPhase = GamePhase.fromString(room.phase);
    var bbOptionUsed = true;

    if (currentPhase == GamePhase.preflop) {
      bbOptionUsed = !room.bbHasOption;
      if (room.bbHasOption) {
        final numPlayers = updatedPlayers.length;
        final isHeadsUp = numPlayers == 2;
        final bbIndex = isHeadsUp ? (room.dealerIndex + 1) % numPlayers : (room.dealerIndex + 2) % numPlayers;

        if (updatedPlayers[playerIndex].uid == updatedPlayers[bbIndex].uid) {
          bbOptionUsed = true;
        } else if (action == 'raise' || action == 'allin') {
          bbOptionUsed = true;
        }
      }
    }

    // Players who can still make betting decisions (not folded, have chips)
    final playersWhoCanAct = updatedPlayers.where((p) => !p.hasFolded && p.chips > 0).toList();

    // Check if we should deal to showdown (run out the board)
    // This happens ONLY when:
    // 1. All active players have acted in this round, AND
    // 2. Either everyone is all-in, OR only one player has chips and all bets are matched
    //
    // Key poker rule: A player going all-in does NOT skip other players' turns.
    // Other players must still get a chance to call/fold/raise.

    // First, check if any player still needs to respond to the current bet
    // A player needs to respond if:
    // - They haven't acted yet in this round, OR
    // - Their current bet is less than the table's current bet
    final playersNeedingToRespond = playersWhoCanAct.where((p) => !p.hasActed || p.currentBet < currentBet).toList();

    print(
        '🔍 All-in check: playersWhoCanAct=${playersWhoCanAct.length}, needingToRespond=${playersNeedingToRespond.length}');
    print(
        '   Players needing to respond: ${playersNeedingToRespond.map((p) => '${p.displayName}(acted:${p.hasActed}, bet:${p.currentBet})').join(', ')}');

    // Only consider all-in showdown if NO players need to respond
    if (playersNeedingToRespond.isEmpty && activePlayers.length >= 2) {
      // Now check if we should run out the board:
      // - No one can bet anymore (0 or 1 players have chips)
      if (playersWhoCanAct.length <= 1) {
        print('📢 All players all-in or called - dealing to showdown');
        await _dealToShowdown(roomId, room, updatedPlayers, pot);
        return;
      }
    }

    // Check if betting round is complete
    final allPlayersActed = playersWhoCanAct.every((p) => p.hasActed);
    final allBetsEqual = playersWhoCanAct.every((p) => p.currentBet == currentBet);
    final isPreflop = currentPhase == GamePhase.preflop;
    final bettingComplete = allPlayersActed && allBetsEqual && (isPreflop ? bbOptionUsed : true);

    print('🔍 Betting check: acted=$allPlayersActed, equal=$allBetsEqual, complete=$bettingComplete');
    print(
        '   Players who can act: ${playersWhoCanAct.map((p) => '${p.displayName}(acted:${p.hasActed}, bet:${p.currentBet})').join(', ')}');
    print('   Current bet: $currentBet');

    if (bettingComplete) {
      await Future.delayed(const Duration(milliseconds: 1500));
      await _advancePhase(roomId, room, updatedPlayers, pot);
    } else {
      await http.patch(
        Uri.parse('${RoomService.databaseUrl}/game_rooms/$roomId.json?auth=$token'),
        body: jsonEncode({
          'players': updatedPlayers.map((p) => p.toJson()).toList(),
          'pot': pot,
          'currentBet': currentBet,
          'lastRaiseAmount': lastRaiseAmount,
          'currentTurnPlayerId': updatedPlayers[nextPlayerIndex].uid,
          'turnStartTime': DateTime.now().millisecondsSinceEpoch,
          'bbHasOption': !bbOptionUsed,
        }),
      );
    }
  }

  /// Deal remaining cards and go to showdown with animations
  /// Cards are dealt one phase at a time with delays for visual effect
  Future<void> _dealToShowdown(String roomId, GameRoom room, List<GamePlayer> players, int pot) async {
    final token = await _getAuthToken();
    var deck = List<String>.from(room.deck);
    var communityCards = List<PlayingCard>.from(room.communityCards);
    var currentPhase = GamePhase.fromString(room.phase);

    // Safety check: ensure deck has enough cards
    if (deck.length < 8 && currentPhase == GamePhase.preflop) {
      print('⚠️ Deck too small (${deck.length} cards), cannot deal to showdown');
      return;
    }

    // Reset player states for runout (no betting, just dealing)
    var updatedPlayers = players
        .map((p) => p.copyWith(
              currentBet: 0,
              hasActed: true,
              lastAction: p.chips == 0 && !p.hasFolded ? 'ALL-IN' : p.lastAction,
            ))
        .toList();

    // Deal cards phase by phase with delays for animation
    // Phase 1: Deal flop if needed
    if (currentPhase == GamePhase.preflop && deck.length >= 4) {
      deck.removeLast(); // burn
      for (var i = 0; i < 3; i++) {
        final card = deck.removeLast().split('|');
        communityCards.add(PlayingCard(rank: card[0], suit: card[1]));
      }

      // Update to flop phase
      await http.patch(
        Uri.parse('${RoomService.databaseUrl}/game_rooms/$roomId.json?auth=$token'),
        body: jsonEncode({
          'communityCards': communityCards.map((c) => c.toJson()).toList(),
          'deck': deck,
          'phase': GamePhase.flop.toDbString(),
          'players': updatedPlayers.map((p) => p.toJson()).toList(),
          'isAllInRunout': true,
        }),
      );

      // Wait for animation
      await Future.delayed(const Duration(milliseconds: 1500));
      currentPhase = GamePhase.flop;
    }

    // Phase 2: Deal turn if needed
    if (currentPhase == GamePhase.flop && deck.length >= 2) {
      deck.removeLast(); // burn
      final turnCard = deck.removeLast().split('|');
      communityCards.add(PlayingCard(rank: turnCard[0], suit: turnCard[1]));

      // Update to turn phase
      await http.patch(
        Uri.parse('${RoomService.databaseUrl}/game_rooms/$roomId.json?auth=$token'),
        body: jsonEncode({
          'communityCards': communityCards.map((c) => c.toJson()).toList(),
          'deck': deck,
          'phase': GamePhase.turn.toDbString(),
          'isAllInRunout': true,
        }),
      );

      // Wait for animation
      await Future.delayed(const Duration(milliseconds: 1500));
      currentPhase = GamePhase.turn;
    }

    // Phase 3: Deal river if needed
    if (currentPhase == GamePhase.turn && deck.length >= 2) {
      deck.removeLast(); // burn
      final riverCard = deck.removeLast().split('|');
      communityCards.add(PlayingCard(rank: riverCard[0], suit: riverCard[1]));

      // Update to river phase
      await http.patch(
        Uri.parse('${RoomService.databaseUrl}/game_rooms/$roomId.json?auth=$token'),
        body: jsonEncode({
          'communityCards': communityCards.map((c) => c.toJson()).toList(),
          'deck': deck,
          'phase': GamePhase.river.toDbString(),
          'isAllInRunout': true,
        }),
      );

      // Wait for animation
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    // Final phase: Showdown with winner determination
    final activePlayers = players.where((p) => !p.hasFolded).toList();
    final finalPlayers = PotService.distributePots(players, communityCards, pot);

    final winnerIndices = HandEvaluator.determineWinners(activePlayers, communityCards);
    if (winnerIndices.isEmpty) winnerIndices.add(0);
    final firstWinner = activePlayers[winnerIndices.first];
    final winningHand = HandEvaluator.evaluateBestHand(firstWinner.cards, communityCards);
    final winnerUids = winnerIndices.map((i) => activePlayers[i].uid).toList();

    await http.patch(
      Uri.parse('${RoomService.databaseUrl}/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({
        'players': finalPlayers.map((p) => p.toJson()).toList(),
        'communityCards': communityCards.map((c) => c.toJson()).toList(),
        'deck': deck,
        'phase': GamePhase.showdown.toDbString(),
        'pot': 0,
        'currentBet': 0,
        'lastRaiseAmount': 0,
        'status': 'finished',
        'winnerId': winnerUids.first,
        'winnerIds': winnerUids,
        'winningHandName': winningHand.description,
        'isAllInRunout': false,
      }),
    );
  }

  /// Advance to next betting phase
  Future<void> _advancePhase(
    String roomId,
    GameRoom room,
    List<GamePlayer> players,
    int pot,
  ) async {
    final token = await _getAuthToken();
    final deck = List<String>.from(room.deck);
    final communityCards = List<PlayingCard>.from(room.communityCards);
    final currentPhase = GamePhase.fromString(room.phase);
    GamePhase nextPhase;

    var updatedPlayers = players.map((p) => p.copyWith(currentBet: 0, hasActed: false, lastAction: null)).toList();

    try {
      switch (currentPhase) {
        case GamePhase.preflop:
          // Need 1 burn + 3 flop cards = 4 cards minimum
          if (deck.length < 4) {
            print('⚠️ Not enough cards in deck for flop (${deck.length} remaining)');
            return;
          }
          deck.removeLast(); // burn
          for (var i = 0; i < 3; i++) {
            final card = deck.removeLast().split('|');
            communityCards.add(PlayingCard(rank: card[0], suit: card[1]));
          }
          nextPhase = GamePhase.flop;
          break;
        case GamePhase.flop:
          // Need 1 burn + 1 turn card = 2 cards minimum
          if (deck.length < 2) {
            print('⚠️ Not enough cards in deck for turn (${deck.length} remaining)');
            return;
          }
          deck.removeLast(); // burn
          final card = deck.removeLast().split('|');
          communityCards.add(PlayingCard(rank: card[0], suit: card[1]));
          nextPhase = GamePhase.turn;
          break;
        case GamePhase.turn:
          // Need 1 burn + 1 river card = 2 cards minimum
          if (deck.length < 2) {
            print('⚠️ Not enough cards in deck for river (${deck.length} remaining)');
            return;
          }
          deck.removeLast(); // burn
          final cardStr = deck.removeLast().split('|');
          communityCards.add(PlayingCard(rank: cardStr[0], suit: cardStr[1]));
          nextPhase = GamePhase.river;
          break;
        case GamePhase.river:
          nextPhase = GamePhase.showdown;
          final activePlayers = updatedPlayers.where((p) => !p.hasFolded).toList();
          final finalPlayers = PotService.distributePots(updatedPlayers, communityCards, pot);

          final winnerIndices = HandEvaluator.determineWinners(activePlayers, communityCards);
          if (winnerIndices.isEmpty) winnerIndices.add(0);
          final firstWinner = activePlayers[winnerIndices.first];
          final winningHand = HandEvaluator.evaluateBestHand(firstWinner.cards, communityCards);
          final winnerUids = winnerIndices.map((i) => activePlayers[i].uid).toList();

          await http.patch(
            Uri.parse('${RoomService.databaseUrl}/game_rooms/$roomId.json?auth=$token'),
            body: jsonEncode({
              'players': finalPlayers.map((p) => p.toJson()).toList(),
              'communityCards': communityCards.map((c) => c.toJson()).toList(),
              'deck': deck,
              'phase': nextPhase.toDbString(),
              'pot': 0,
              'currentBet': 0,
              'lastRaiseAmount': 0,
              'status': 'finished',
              'winnerId': winnerUids.first,
              'winnerIds': winnerUids,
              'winningHandName': winningHand.description,
            }),
          );
          return;
        default:
          nextPhase = currentPhase;
      }
    } catch (e) {
      print('❌ Error advancing phase: $e');
      return;
    }

    final firstToActIdx = _getFirstToActIndex(room.copyWith(phase: nextPhase.toDbString()), updatedPlayers);

    await http.patch(
      Uri.parse('${RoomService.databaseUrl}/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({
        'players': updatedPlayers.map((p) => p.toJson()).toList(),
        'communityCards': communityCards.map((c) => c.toJson()).toList(),
        'deck': deck,
        'phase': nextPhase.toDbString(),
        'pot': pot,
        'currentBet': 0,
        'lastRaiseAmount': room.bigBlind,
        'currentTurnPlayerId': updatedPlayers[firstToActIdx].uid,
        'turnStartTime': DateTime.now().millisecondsSinceEpoch,
        'bbHasOption': false,
      }),
    );
  }

  int _getFirstToActIndex(GameRoom room, List<GamePlayer> players) {
    final numPlayers = players.length;
    final isHeadsUp = numPlayers == 2;
    final currentPhase = GamePhase.fromString(room.phase);

    if (currentPhase == GamePhase.preflop) {
      int firstToAct;
      if (isHeadsUp) {
        firstToAct = room.dealerIndex;
      } else {
        firstToAct = (room.dealerIndex + 3) % numPlayers;
      }
      int loopCount = 0;
      while ((players[firstToAct].hasFolded || players[firstToAct].chips == 0) && loopCount < numPlayers) {
        firstToAct = (firstToAct + 1) % numPlayers;
        loopCount++;
      }
      return firstToAct;
    } else {
      var firstToAct = (room.dealerIndex + 1) % numPlayers;
      int loopCount = 0;
      while ((players[firstToAct].hasFolded || players[firstToAct].chips == 0) && loopCount < numPlayers) {
        firstToAct = (firstToAct + 1) % numPlayers;
        loopCount++;
      }
      return firstToAct;
    }
  }
}
