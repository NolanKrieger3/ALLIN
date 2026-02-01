import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_room.dart';
import 'room_service.dart';

/// Service for handling game flow - starting games, dealing cards, new hands
class GameFlowService {
  final RoomService _roomService = RoomService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<String?> _getAuthToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  /// Create and shuffle a standard 52-card deck
  List<String> _createShuffledDeck() {
    final ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
    final suits = ['♠', '♥', '♦', '♣'];
    final deck = <String>[];

    for (final suit in suits) {
      for (final rank in ranks) {
        deck.add('$rank|$suit');
      }
    }

    deck.shuffle(Random());
    return deck;
  }

  /// Start a game in the specified room
  Future<void> startGame(String roomId) async {
    final token = await _getAuthToken();
    final room = await _roomService.fetchRoom(roomId);
    if (room == null) return;

    // CRITICAL: Guard against starting a game that's already in progress
    // This prevents race conditions where startGame is called multiple times
    if (room.status == 'in_progress' && room.phase != 'waiting_for_players') {
      print('⚠️ Game already in progress, skipping startGame');
      return;
    }

    final deck = _createShuffledDeck();
    final numPlayers = room.players.length;

    final updatedPlayers = room.players.asMap().entries.map((entry) {
      final player = entry.value;

      final card1Str = deck.removeLast().split('|');
      final card2Str = deck.removeLast().split('|');
      final cards = [
        PlayingCard(rank: card1Str[0], suit: card1Str[1]),
        PlayingCard(rank: card2Str[0], suit: card2Str[1]),
      ];

      return player.copyWith(
        cards: cards,
        hasFolded: false,
        hasActed: false,
        currentBet: 0,
        totalContributed: 0,
        lastAction: null,
      );
    }).toList();

    final dealerIndex = Random().nextInt(numPlayers);

    final isHeadsUp = numPlayers == 2;
    final sbIndex = isHeadsUp ? dealerIndex : (dealerIndex + 1) % numPlayers;
    final bbIndex = isHeadsUp ? (dealerIndex + 1) % numPlayers : (dealerIndex + 2) % numPlayers;

    final smallBlind = room.smallBlind;
    final bigBlind = room.bigBlind;

    var sbPlayer = updatedPlayers[sbIndex];
    final sbAmount = sbPlayer.chips >= smallBlind ? smallBlind : sbPlayer.chips;
    updatedPlayers[sbIndex] = sbPlayer.copyWith(
      chips: sbPlayer.chips - sbAmount,
      currentBet: sbAmount,
      totalContributed: sbAmount,
    );

    var bbPlayer = updatedPlayers[bbIndex];
    final bbAmount = bbPlayer.chips >= bigBlind ? bigBlind : bbPlayer.chips;
    updatedPlayers[bbIndex] = bbPlayer.copyWith(
      chips: bbPlayer.chips - bbAmount,
      currentBet: bbAmount,
      totalContributed: bbAmount,
    );

    final pot = sbAmount + bbAmount;
    int firstToAct;
    if (isHeadsUp) {
      firstToAct = dealerIndex;
    } else {
      firstToAct = (dealerIndex + 3) % numPlayers;
    }

    await http.patch(
      Uri.parse('${RoomService.databaseUrl}/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({
        'status': 'in_progress',
        'phase': 'preflop',
        'players': updatedPlayers.map((p) => p.toJson()).toList(),
        'deck': deck,
        'communityCards': [],
        'pot': pot,
        'currentBet': bigBlind,
        'dealerIndex': dealerIndex,
        'currentTurnPlayerId': updatedPlayers[firstToAct].uid,
        'turnStartTime': DateTime.now().millisecondsSinceEpoch,
        'lastRaiseAmount': bigBlind,
        'smallBlindIndex': sbIndex,
        'bigBlindIndex': bbIndex,
        'bbHasOption': true,
      }),
    );
  }

  /// Start a new hand after showdown
  Future<void> newHand(String roomId) async {
    final token = await _getAuthToken();
    final room = await _roomService.fetchRoom(roomId);
    if (room == null) return;

    // CRITICAL: Only start new hand from showdown phase
    // This prevents race conditions where newHand is called multiple times
    if (room.phase != 'showdown' && room.status != 'finished') {
      print('⚠️ Game not in showdown, skipping newHand (current phase: ${room.phase})');
      return;
    }

    // Remove eliminated players
    var players = room.players.where((p) => p.chips > 0).toList();
    if (players.length < 2) {
      await http.patch(
        Uri.parse('${RoomService.databaseUrl}/game_rooms/$roomId.json?auth=$token'),
        body: jsonEncode({
          'status': 'finished',
          'phase': 'showdown',
        }),
      );
      return;
    }

    final deck = _createShuffledDeck();
    final numPlayers = players.length;
    final newDealerIndex = (room.dealerIndex + 1) % numPlayers;
    final isHeadsUp = numPlayers == 2;
    final sbIndex = isHeadsUp ? newDealerIndex : (newDealerIndex + 1) % numPlayers;
    final bbIndex = isHeadsUp ? (newDealerIndex + 1) % numPlayers : (newDealerIndex + 2) % numPlayers;

    var sbPlayer = players[sbIndex];
    final smallBlindAmount = sbPlayer.chips >= room.smallBlind ? room.smallBlind : sbPlayer.chips;
    players[sbIndex] = sbPlayer.copyWith(
      chips: sbPlayer.chips - smallBlindAmount,
      currentBet: smallBlindAmount,
      totalContributed: smallBlindAmount,
    );

    var bbPlayer = players[bbIndex];
    final bigBlindAmount = bbPlayer.chips >= room.bigBlind ? room.bigBlind : bbPlayer.chips;
    players[bbIndex] = bbPlayer.copyWith(
      chips: bbPlayer.chips - bigBlindAmount,
      currentBet: bigBlindAmount,
      totalContributed: bigBlindAmount,
    );

    var pot = smallBlindAmount + bigBlindAmount;

    // Reset players and deal new cards
    final updatedPlayers = players.asMap().entries.map((entry) {
      final i = entry.key;
      final player = entry.value;

      final card1Str = deck.removeLast().split('|');
      final card2Str = deck.removeLast().split('|');
      final newCards = [
        PlayingCard(rank: card1Str[0], suit: card1Str[1]),
        PlayingCard(rank: card2Str[0], suit: card2Str[1]),
      ];

      var resetPlayer = player.copyWith(
        hasFolded: false,
        hasActed: false,
        cards: [], // Clear cards first to prevent flash of old cards
        lastAction: null,
      );

      if (i != sbIndex && i != bbIndex) {
        resetPlayer = resetPlayer.copyWith(
          currentBet: 0,
          totalContributed: 0,
        );
      }

      return resetPlayer.copyWith(cards: newCards);
    }).toList();

    int firstToAct;
    if (isHeadsUp) {
      firstToAct = newDealerIndex;
    } else {
      firstToAct = (newDealerIndex + 3) % numPlayers;
    }

    await http.patch(
      Uri.parse('${RoomService.databaseUrl}/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({
        'status': 'in_progress',
        'phase': 'preflop',
        'players': updatedPlayers.map((p) => p.toJson()).toList(),
        'deck': deck,
        'communityCards': [],
        'pot': pot,
        'currentBet': room.bigBlind,
        'dealerIndex': newDealerIndex,
        'currentTurnPlayerId': updatedPlayers[firstToAct].uid,
        'turnStartTime': DateTime.now().millisecondsSinceEpoch,
        'lastRaiseAmount': room.bigBlind,
        'smallBlindIndex': sbIndex,
        'bigBlindIndex': bbIndex,
        'winnerId': null,
        'winnerIds': null,
        'winningHandName': null,
        'bbHasOption': true,
      }),
    );
  }

  /// Handle auto-fold for timed out players
  Future<void> handleTurnTimeout(String roomId) async {
    final token = await _getAuthToken();
    final room = await _roomService.fetchRoom(roomId);
    if (room == null || room.status != 'in_progress') return;

    final currentPlayerId = room.currentTurnPlayerId;
    if (currentPlayerId == null) return;

    final playerIndex = room.players.indexWhere((p) => p.uid == currentPlayerId);
    if (playerIndex == -1) return;

    final player = room.players[playerIndex];
    final updatedPlayers = List<GamePlayer>.from(room.players);
    updatedPlayers[playerIndex] = player.copyWith(hasFolded: true, hasActed: true, lastAction: 'FOLD');

    final activePlayers = updatedPlayers.where((p) => !p.hasFolded).toList();

    if (activePlayers.length == 1) {
      final winner = activePlayers.first;
      final winnerIdx = updatedPlayers.indexWhere((p) => p.uid == winner.uid);
      updatedPlayers[winnerIdx] = winner.copyWith(chips: winner.chips + room.pot);

      await http.patch(
        Uri.parse('${RoomService.databaseUrl}/game_rooms/$roomId.json?auth=$token'),
        body: jsonEncode({
          'players': updatedPlayers.map((p) => p.toJson()).toList(),
          'pot': 0,
          'status': 'finished',
          'phase': 'showdown',
          'winnerId': winner.uid,
        }),
      );
      return;
    }

    var nextPlayerIndex = (playerIndex + 1) % updatedPlayers.length;
    int loopCount = 0;
    while (updatedPlayers[nextPlayerIndex].hasFolded && loopCount < updatedPlayers.length) {
      nextPlayerIndex = (nextPlayerIndex + 1) % updatedPlayers.length;
      loopCount++;
    }

    await http.patch(
      Uri.parse('${RoomService.databaseUrl}/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({
        'players': updatedPlayers.map((p) => p.toJson()).toList(),
        'currentTurnPlayerId': updatedPlayers[nextPlayerIndex].uid,
        'turnStartTime': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// Update turn start time
  Future<void> updateTurnStartTime(String roomId) async {
    final token = await _getAuthToken();
    await http.patch(
      Uri.parse('${RoomService.databaseUrl}/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({
        'turnStartTime': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// Update game status
  Future<void> updateGameStatus(String roomId, String status) async {
    final token = await _getAuthToken();
    await http.patch(
      Uri.parse('${RoomService.databaseUrl}/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({'status': status}),
    );
  }

  /// Update tournament state
  Future<void> updateTournamentState(
    String roomId, {
    required int currentBlindLevel,
    required int smallBlind,
    required int bigBlind,
    required DateTime lastBlindIncreaseTime,
  }) async {
    final token = await _getAuthToken();
    await http.patch(
      Uri.parse('${RoomService.databaseUrl}/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({
        'currentBlindLevel': currentBlindLevel,
        'smallBlind': smallBlind,
        'bigBlind': bigBlind,
        'lastBlindIncreaseTime': lastBlindIncreaseTime.millisecondsSinceEpoch,
      }),
    );
  }
}
