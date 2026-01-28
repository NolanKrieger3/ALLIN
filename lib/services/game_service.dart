import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_room.dart';
import 'user_preferences.dart';
import 'hand_evaluator.dart';

/// Game phases for Texas Hold'em
enum GamePhase {
  preflop,
  flop,
  turn,
  river,
  showdown,
  waitingForPlayers;

  /// Convert from string (for Firebase compatibility)
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

  /// Convert to string (for Firebase compatibility)
  String toDbString() {
    switch (this) {
      case GamePhase.waitingForPlayers:
        return 'waiting_for_players';
      default:
        return name;
    }
  }
}

/// Service for managing multiplayer poker games via Firebase Realtime Database REST API
class GameService {
  static const String _databaseUrl = 'https://allin-d0e2d-default-rtdb.firebaseio.com';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Get current user display name - prioritize Firebase auth info for multiplayer
  String get currentUserName {
    final user = _auth.currentUser;
    if (user != null) {
      // Use Firebase display name if set
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        return user.displayName!;
      }
      // Use email prefix for email accounts
      if (user.email != null && user.email!.isNotEmpty) {
        return user.email!.split('@').first;
      }
      // For anonymous users, use a unique ID-based name
      return 'Player${user.uid.substring(0, 4).toUpperCase()}';
    }
    // Fallback to local preferences
    return UserPreferences.username;
  }

  /// Get auth token for authenticated requests
  Future<String?> _getAuthToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  // ============================================================================
  // ROOM MANAGEMENT
  // ============================================================================

  /// Create a new game room
  Future<GameRoom> createRoom(
      {int bigBlind = 100, int startingChips = 1000, bool isPrivate = false, String gameType = 'cash'}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in to create a room');

    final token = await _getAuthToken();

    // Generate a unique room ID
    final roomId = _generateRoomId();

    final room = GameRoom(
      id: roomId,
      hostId: userId,
      players: [GamePlayer(uid: userId, displayName: currentUserName, chips: startingChips)],
      bigBlind: bigBlind,
      smallBlind: bigBlind ~/ 2,
      createdAt: DateTime.now(),
      isPrivate: isPrivate,
      gameType: gameType,
    );

    final response = await http.put(
      Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode(room.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create room: ${response.body}');
    }

    return room;
  }

  /// Join an existing room
  /// If [startingChips] is not provided, it will match the host's starting chips
  Future<void> joinRoom(String roomId, {int? startingChips}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in to join a room');

    final token = await _getAuthToken();

    // Debug: Print join attempt info
    print('JOIN ATTEMPT: userId=$userId, name=$currentUserName, roomId=$roomId');

    // Get current room data
    final response = await http.get(Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'));

    if (response.statusCode != 200 || response.body == 'null') {
      throw Exception('Room not found');
    }

    final roomData = jsonDecode(response.body) as Map<String, dynamic>;
    final room = GameRoom.fromJson(roomData, roomId);

    // Debug: Print current players
    print('ROOM PLAYERS: ${room.players.map((p) => "${p.displayName} (${p.uid})").join(", ")}');

    if (room.isFull) throw Exception('Room is full');
    // Allow joining rooms that are 'waiting' OR 'playing' with 'waiting_for_players' phase
    final isJoinable = room.status == 'waiting' || (room.status == 'playing' && room.phase == 'waiting_for_players');
    if (!isJoinable) throw Exception('Game already in progress');
    if (room.players.any((p) => p.uid == userId)) {
      print('ALREADY IN ROOM: User $userId is already a player');
      return; // Already in room
    }

    // Use provided chips or match the host's chips
    final chips = startingChips ?? room.players.first.chips;

    // Auto-ready the player so game can start immediately when matched
    final newPlayer = GamePlayer(uid: userId, displayName: currentUserName, chips: chips, isReady: true);
    print('ADDING PLAYER: ${newPlayer.displayName} (${newPlayer.uid}) with $chips chips - auto-ready');

    final updatedPlayers = [...room.players, newPlayer];

    await http.patch(
      Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({'players': updatedPlayers.map((p) => p.toJson()).toList()}),
    );

    print('✅ Successfully joined room $roomId with ${updatedPlayers.length} players');
  }

  /// Leave a room
  Future<void> leaveRoom(String roomId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final token = await _getAuthToken();

    final response = await http.get(Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'));

    if (response.statusCode != 200 || response.body == 'null') return;

    final roomData = jsonDecode(response.body) as Map<String, dynamic>;
    final room = GameRoom.fromJson(roomData, roomId);
    final updatedPlayers = room.players.where((p) => p.uid != userId).toList();

    if (updatedPlayers.isEmpty) {
      // Delete room if no players left
      await http.delete(Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'));
    } else {
      final newHostId = room.hostId == userId ? updatedPlayers.first.uid : room.hostId;

      await http.patch(
        Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
        body: jsonEncode({'players': updatedPlayers.map((p) => p.toJson()).toList(), 'hostId': newHostId}),
      );
    }
  }

  /// Toggle ready status
  Future<void> toggleReady(String roomId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final token = await _getAuthToken();

    final response = await http.get(Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'));

    if (response.statusCode != 200 || response.body == 'null') return;

    final roomData = jsonDecode(response.body) as Map<String, dynamic>;
    final room = GameRoom.fromJson(roomData, roomId);

    final updatedPlayers = room.players.map((p) {
      if (p.uid == userId) {
        return p.copyWith(isReady: !p.isReady);
      }
      return p;
    }).toList();

    await http.patch(
      Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({'players': updatedPlayers.map((p) => p.toJson()).toList()}),
    );
  }

  /// Get available rooms to join (polling-based)
  Stream<List<GameRoom>> getAvailableRooms() {
    return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) => _fetchAvailableRooms('cash'));
  }

  /// Get available Sit & Go tournaments to join
  Stream<List<GameRoom>> getAvailableSitAndGoRooms() {
    return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) => _fetchAvailableRooms('sitandgo'));
  }

  /// Immediately fetch available cash game rooms (no stream delay)
  Future<List<GameRoom>> fetchAvailableCashRooms() async {
    return _fetchAvailableRooms('cash');
  }

  /// Clean up stale rooms (rooms with 1 player waiting too long, or finished games)
  Future<void> cleanupStaleRooms() async {
    final token = await _getAuthToken();
    if (token == null) return;

    try {
      final response = await http.get(Uri.parse('$_databaseUrl/game_rooms.json?auth=$token'));

      if (response.statusCode != 200 || response.body == 'null') return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final now = DateTime.now();

      for (final entry in data.entries) {
        final roomId = entry.key;
        final roomData = Map<String, dynamic>.from(entry.value as Map);
        final room = GameRoom.fromJson(roomData, roomId);

        bool shouldDelete = false;
        String reason = '';

        // Delete if no players
        if (room.players.isEmpty) {
          shouldDelete = true;
          reason = 'empty room';
        }
        // Delete if finished for more than 2 minutes
        else if (room.status == 'finished') {
          shouldDelete = true;
          reason = 'game finished';
        }
        // Delete if 1 player waiting for more than 5 minutes
        else if (room.players.length == 1 && room.status == 'waiting') {
          final age = now.difference(room.createdAt);
          if (age.inMinutes >= 5) {
            shouldDelete = true;
            reason = 'stale (${age.inMinutes} min old with 1 player)';
          }
        }

        if (shouldDelete) {
          print('🧹 Deleting room $roomId: $reason');
          await http.delete(Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'));
        }
      }
    } catch (e) {
      print('⚠️ Cleanup error: $e');
    }
  }

  /// Fetch joinable cash game rooms by blind level (includes rooms waiting for players)
  Future<List<GameRoom>> fetchJoinableRoomsByBlind(int bigBlind, {String gameType = 'cash'}) async {
    // Clean up stale rooms first
    await cleanupStaleRooms();

    final token = await _getAuthToken();
    final userId = currentUserId;

    // Fetch ALL rooms (we'll filter locally since Firebase REST has limited query support)
    final response = await http.get(
      Uri.parse('$_databaseUrl/game_rooms.json?auth=$token'),
    );

    print('🔍 Fetching joinable rooms for bigBlind: $bigBlind, gameType: $gameType');

    if (response.statusCode != 200 || response.body == 'null') {
      print('🔍 No rooms found or error');
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    print('🔍 Total rooms in database: ${data.length}');

    final allRooms =
        data.entries.map((e) => GameRoom.fromJson(Map<String, dynamic>.from(e.value as Map), e.key)).toList();

    // Filter for joinable rooms:
    // - Same blind level
    // - Same game type
    // - Not full
    // - Not private
    // - User not already in room
    // - Either waiting OR playing with phase='waiting_for_players'
    // - Has exactly 1 player (to join them)
    final joinableRooms = allRooms.where((room) {
      final isCorrectBlind = room.bigBlind == bigBlind;
      final isCorrectGameType = room.gameType == gameType;
      final isNotFull = !room.isFull;
      final isNotPrivate = !room.isPrivate;
      final userNotInRoom = !room.players.any((p) => p.uid == userId);
      final isJoinable = room.status == 'waiting' || (room.status == 'playing' && room.phase == 'waiting_for_players');
      final needsPlayer = room.players.length == 1; // Only join rooms that have exactly 1 player waiting

      print(
          '🔍 Room ${room.id}: blind=${room.bigBlind}, gameType=${room.gameType}, status=${room.status}, players=${room.players.length}, needsPlayer=$needsPlayer, userNotInRoom=$userNotInRoom');

      return isCorrectBlind &&
          isCorrectGameType &&
          isNotFull &&
          isNotPrivate &&
          userNotInRoom &&
          isJoinable &&
          needsPlayer;
    }).toList();

    // Sort by most recently created (newest first) - these are more likely to have active players
    joinableRooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    print('🔍 Joinable rooms for blind $bigBlind: ${joinableRooms.length}');
    if (joinableRooms.isNotEmpty) {
      print('🎯 Best room to join: ${joinableRooms.first.id} (created ${joinableRooms.first.createdAt})');
    }
    return joinableRooms;
  }

  /// Immediately fetch available Sit & Go rooms (no stream delay)
  Future<List<GameRoom>> fetchAvailableSitAndGoRooms() async {
    return _fetchAvailableRooms('sitandgo');
  }

  Future<List<GameRoom>> _fetchAvailableRooms(String gameType) async {
    final token = await _getAuthToken();
    final userId = currentUserId;

    final response = await http.get(
      Uri.parse('$_databaseUrl/game_rooms.json?auth=$token&orderBy="status"&equalTo="waiting"'),
    );

    print('🔍 Fetching rooms for gameType: $gameType');
    print('🔍 Response status: ${response.statusCode}');
    print('🔍 Response body: ${response.body}');

    if (response.statusCode != 200 || response.body == 'null') {
      print('🔍 No rooms found or error');
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    print('🔍 Total rooms in database: ${data.length}');

    final allRooms =
        data.entries.map((e) => GameRoom.fromJson(Map<String, dynamic>.from(e.value as Map), e.key)).toList();

    for (final room in allRooms) {
      print(
        '🔍 Room ${room.id}: gameType=${room.gameType}, isPrivate=${room.isPrivate}, players=${room.players.length}, isFull=${room.isFull}',
      );
      for (final player in room.players) {
        print('   - Player: ${player.uid} (current user: $userId, match: ${player.uid == userId})');
      }
    }

    final filteredRooms = allRooms
        .where(
          (room) =>
              !room.isFull && room.gameType == gameType && !room.isPrivate && !room.players.any((p) => p.uid == userId),
        )
        .toList();

    print('🔍 Filtered rooms available to join: ${filteredRooms.length}');
    return filteredRooms;
  }

  /// Create a Sit & Go tournament room
  Future<GameRoom> createSitAndGoRoom({int startingChips = 10000, int bigBlind = 100}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in to create a room');

    final token = await _getAuthToken();
    final roomId = _generateRoomId();

    final room = GameRoom(
      id: roomId,
      hostId: userId,
      players: [GamePlayer(uid: userId, displayName: currentUserName, chips: startingChips)],
      maxPlayers: 6,
      bigBlind: bigBlind,
      smallBlind: bigBlind ~/ 2,
      createdAt: DateTime.now(),
      gameType: 'sitandgo',
    );

    final response = await http.put(
      Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode(room.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create room: ${response.body}');
    }

    return room;
  }

  /// Listen to a specific room (polling-based for Windows compatibility)
  Stream<GameRoom?> watchRoom(String roomId) {
    return Stream.periodic(const Duration(milliseconds: 500)).asyncMap((_) => _fetchRoom(roomId));
  }

  Future<GameRoom?> _fetchRoom(String roomId) async {
    final token = await _getAuthToken();

    final response = await http.get(Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'));

    if (response.statusCode != 200 || response.body == 'null') {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return GameRoom.fromJson(data, roomId);
  }

  // ============================================================================
  // GAME ACTIONS
  // ============================================================================

  /// Start the game (host only)
  /// Set [skipReadyCheck] to true for auto-matched games where players are auto-ready
  Future<void> startGame(String roomId, {bool skipReadyCheck = false}) async {
    final userId = currentUserId;
    if (userId == null) return;

    final room = await _fetchRoom(roomId);
    if (room == null) return;

    if (room.hostId != userId) throw Exception('Only host can start the game');
    if (room.players.length < 2) throw Exception('Need at least 2 players to start');
    if (!skipReadyCheck && !room.canStart) throw Exception('Not all players are ready');

    await _startGameInternal(roomId, room);
  }

  /// Start the game immediately (skip waiting room, works with 1+ players)
  Future<void> startGameSolo(String roomId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final room = await _fetchRoom(roomId);
    if (room == null) return;

    if (room.hostId != userId) throw Exception('Only host can start the game');

    // Handle solo player case
    if (room.players.length == 1) {
      await _startSoloWaiting(roomId, room);
      return;
    }

    await _startGameInternal(roomId, room);
  }

  /// Start the game from waiting_for_players phase (when 2nd player joins)
  Future<void> startGameFromWaiting(String roomId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final room = await _fetchRoom(roomId);
    if (room == null) return;

    if (room.hostId != userId) throw Exception('Only host can start the game');
    if (room.players.length < 2) throw Exception('Need at least 2 players');

    await _startGameInternal(roomId, room);
  }

  /// Internal helper to start a game - shared logic for all start methods
  Future<void> _startGameInternal(String roomId, GameRoom room) async {
    final token = await _getAuthToken();

    // Create and shuffle deck
    final deck = _createShuffledDeck();

    // Deal cards to players
    var updatedPlayers = room.players.map((p) {
      final card1 = deck.removeLast();
      final card2 = deck.removeLast();
      return p.copyWith(
        cards: [
          PlayingCard(rank: card1.split('|')[0], suit: card1.split('|')[1]),
          PlayingCard(rank: card2.split('|')[0], suit: card2.split('|')[1]),
        ],
        currentBet: 0,
        hasFolded: false,
        hasActed: false,
        lastAction: null,
      );
    }).toList();

    final numPlayers = updatedPlayers.length;
    final isHeadsUp = numPlayers == 2;

    // Calculate blind positions
    // Heads-up: Dealer posts SB, other player posts BB
    // Multi-way: Player after dealer posts SB, next posts BB
    final sbIndex = isHeadsUp ? room.dealerIndex : (room.dealerIndex + 1) % numPlayers;
    final bbIndex = isHeadsUp ? (room.dealerIndex + 1) % numPlayers : (room.dealerIndex + 2) % numPlayers;

    // First to act: Heads-up = SB, Multi-way = UTG (left of BB)
    var firstToAct = isHeadsUp ? sbIndex : (bbIndex + 1) % numPlayers;

    // Post blinds (handle case where player doesn't have enough chips)
    final sbAmount = min(room.smallBlind, updatedPlayers[sbIndex].chips);
    final bbAmount = min(room.bigBlind, updatedPlayers[bbIndex].chips);

    updatedPlayers[sbIndex] = updatedPlayers[sbIndex].copyWith(
      chips: updatedPlayers[sbIndex].chips - sbAmount,
      currentBet: sbAmount,
      totalContributed: sbAmount,
    );
    updatedPlayers[bbIndex] = updatedPlayers[bbIndex].copyWith(
      chips: updatedPlayers[bbIndex].chips - bbAmount,
      currentBet: bbAmount,
      totalContributed: bbAmount,
    );

    // Skip all-in players for first to act
    int loopCount = 0;
    while (updatedPlayers[firstToAct].chips == 0 && loopCount < numPlayers) {
      firstToAct = (firstToAct + 1) % numPlayers;
      loopCount++;
    }

    // BB only has option if they have chips remaining
    final bbHasChips = updatedPlayers[bbIndex].chips > 0;

    // If BB is all-in for less than full BB, adjust lastRaiseAmount
    // In this case, the "raise amount" is only what BB actually posted
    final effectiveLastRaise = bbAmount < room.bigBlind ? bbAmount : room.bigBlind;

    await http.patch(
      Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({
        'status': 'playing',
        'phase': GamePhase.preflop.toDbString(),
        'players': updatedPlayers.map((p) => p.toJson()).toList(),
        'deck': deck,
        'pot': sbAmount + bbAmount,
        'currentBet': bbAmount,
        'currentTurnPlayerId': updatedPlayers[firstToAct].uid,
        'turnStartTime': DateTime.now().millisecondsSinceEpoch,
        'communityCards': [],
        'lastRaiseAmount': effectiveLastRaise,
        'bbHasOption': bbHasChips,
      }),
    );
  }

  /// Helper for solo waiting mode
  /// Note: We don't deal cards or create a deck here since they'll be
  /// re-dealt when a 2nd player joins and _startGameInternal is called
  Future<void> _startSoloWaiting(String roomId, GameRoom room) async {
    final token = await _getAuthToken();

    await http.patch(
      Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({
        'status': 'playing',
        'phase': GamePhase.waitingForPlayers.toDbString(),
        'pot': 0,
        'currentBet': 0,
        'currentTurnPlayerId': room.players[0].uid,
        'communityCards': [],
        'lastRaiseAmount': room.bigBlind,
        'bbHasOption': false,
      }),
    );
  }

  /// Player action (fold, check, call, raise, allin)
  Future<void> playerAction(String roomId, String action, {int? raiseAmount}) async {
    final userId = currentUserId;
    if (userId == null) return;

    final token = await _getAuthToken();
    final room = await _fetchRoom(roomId);
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

    // Mark that this player has acted this round
    updatedPlayers[playerIndex] = player.copyWith(hasActed: true);

    String lastActionLabel = action.toUpperCase(); // Default to action name

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
        // If player doesn't have enough, they go all-in for what they have
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
        // raiseAmount is the TOTAL bet amount they want to make
        final totalBet = raiseAmount ?? (currentBet + lastRaiseAmount);
        final raiseBy = totalBet - currentBet;

        // Minimum raise must be at least the size of the last raise (or BB if first raise)
        if (raiseBy < lastRaiseAmount && totalBet < player.chips + player.currentBet) {
          throw Exception('Raise must be at least $lastRaiseAmount');
        }

        final addAmount = totalBet - player.currentBet;
        if (addAmount > player.chips) {
          throw Exception('Not enough chips');
        }

        // Check if this is an all-in raise
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

        // Reset hasActed for all other players since there's a raise
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

        // If this all-in is a raise, update current bet
        // Only reset hasActed (reopen betting) if it's a FULL raise (>= lastRaiseAmount)
        // A short all-in does NOT reopen betting for players who already acted
        if (newTotalBet > currentBet) {
          final raiseBy = newTotalBet - currentBet;
          final isFullRaise = raiseBy >= lastRaiseAmount;

          if (isFullRaise) {
            lastRaiseAmount = raiseBy;
            // Full raise - reset hasActed for all other players
            updatedPlayers = updatedPlayers.map((p) {
              if (p.uid != userId && !p.hasFolded) {
                return p.copyWith(hasActed: false);
              }
              return p;
            }).toList();
          }
          // Note: Short all-in still updates currentBet, but doesn't reopen action
          currentBet = newTotalBet;
        }
        break;
    }

    // Mark current player as having acted
    final currentPlayerIdx = updatedPlayers.indexWhere((p) => p.uid == userId);
    if (currentPlayerIdx != -1) {
      updatedPlayers[currentPlayerIdx] = updatedPlayers[currentPlayerIdx].copyWith(hasActed: true);
    }

    // Check if hand is over (only one player left)
    final activePlayers = updatedPlayers.where((p) => !p.hasFolded).toList();
    if (activePlayers.length == 1) {
      // Award pot to winner
      final winnerIndex = updatedPlayers.indexWhere((p) => !p.hasFolded);
      updatedPlayers[winnerIndex] = updatedPlayers[winnerIndex].copyWith(
        chips: updatedPlayers[winnerIndex].chips + pot,
      );

      await http.patch(
        Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
        body: jsonEncode({
          'players': updatedPlayers.map((p) => p.toJson()).toList(),
          'pot': 0,
          'status': 'finished',
          'winnerId': updatedPlayers[winnerIndex].uid,
        }),
      );
      return;
    }

    // Find next player who can act (not folded and has chips)
    var nextPlayerIndex = (playerIndex + 1) % updatedPlayers.length;
    int loopCount = 0;
    while ((updatedPlayers[nextPlayerIndex].hasFolded || updatedPlayers[nextPlayerIndex].chips == 0) &&
        loopCount < updatedPlayers.length) {
      nextPlayerIndex = (nextPlayerIndex + 1) % updatedPlayers.length;
      loopCount++;
    }

    // Track if BB option was used (only relevant preflop)
    // Post-flop streets don't have BB option, so it's always "used"
    final currentPhase = GamePhase.fromString(room.phase);
    var bbOptionUsed = true; // Default to true for post-flop streets

    // BB option only applies preflop
    if (currentPhase == GamePhase.preflop) {
      bbOptionUsed = !room.bbHasOption; // Already used if bbHasOption is false

      if (room.bbHasOption) {
        final numPlayers = updatedPlayers.length;
        final isHeadsUp = numPlayers == 2;
        final bbIndex = isHeadsUp ? (room.dealerIndex + 1) % numPlayers : (room.dealerIndex + 2) % numPlayers;

        if (updatedPlayers[playerIndex].uid == updatedPlayers[bbIndex].uid) {
          // BB is acting - any action uses the option
          bbOptionUsed = true;
        } else if (action == 'raise' || action == 'allin') {
          // Any raise means BB option becomes a normal call/fold/raise decision
          bbOptionUsed = true;
        }
      }
    }

    // Check if all remaining players are all-in (no more betting possible)
    final playersWhoCanAct = updatedPlayers.where((p) => !p.hasFolded && p.chips > 0).toList();
    final allPlayersAllIn = playersWhoCanAct.isEmpty || playersWhoCanAct.length <= 1;

    if (allPlayersAllIn) {
      // Deal out remaining community cards and go to showdown
      await _dealToShowdown(roomId, room, updatedPlayers, pot);
      return;
    }

    // Check if betting round is complete:
    // All active players with chips must have acted AND matched the current bet
    // BB option only matters on preflop - on flop/turn/river, betting completes when all have acted and bets match
    final allPlayersActed = playersWhoCanAct.every((p) => p.hasActed);
    final allBetsEqual = playersWhoCanAct.every((p) => p.currentBet == currentBet);

    // BB option only applies preflop
    final isPreflop = currentPhase == GamePhase.preflop;
    final bettingComplete = allPlayersActed && allBetsEqual && (isPreflop ? bbOptionUsed : true);

    print(
        '🎯 BETTING CHECK: phase=$currentPhase, allActed=$allPlayersActed, betsEqual=$allBetsEqual, bbOptionUsed=$bbOptionUsed, complete=$bettingComplete');
    print(
        '   Players: ${playersWhoCanAct.map((p) => '${p.displayName}(acted=${p.hasActed}, bet=${p.currentBet})').join(', ')}');

    if (bettingComplete) {
      print('✅ Advancing to next phase from ${room.phase}');
      // Move to next phase
      await _advancePhase(roomId, room, updatedPlayers, pot);
    } else {
      await http.patch(
        Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
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

  /// Deal remaining community cards and go directly to showdown (all-in scenario)
  Future<void> _dealToShowdown(String roomId, GameRoom room, List<GamePlayer> players, int pot) async {
    final token = await _getAuthToken();
    final deck = List<String>.from(room.deck);
    final communityCards = List<PlayingCard>.from(room.communityCards);
    final currentPhase = GamePhase.fromString(room.phase);

    // Deal remaining community cards based on current phase
    switch (currentPhase) {
      case GamePhase.preflop:
        // Deal flop (burn + 3), turn (burn + 1), river (burn + 1)
        deck.removeLast(); // Burn
        for (var i = 0; i < 3; i++) {
          final card = deck.removeLast().split('|');
          communityCards.add(PlayingCard(rank: card[0], suit: card[1]));
        }
        deck.removeLast(); // Burn
        final turnCard = deck.removeLast().split('|');
        communityCards.add(PlayingCard(rank: turnCard[0], suit: turnCard[1]));
        deck.removeLast(); // Burn
        final riverCard = deck.removeLast().split('|');
        communityCards.add(PlayingCard(rank: riverCard[0], suit: riverCard[1]));
        break;
      case GamePhase.flop:
        // Deal turn and river
        deck.removeLast(); // Burn
        final turnCard2 = deck.removeLast().split('|');
        communityCards.add(PlayingCard(rank: turnCard2[0], suit: turnCard2[1]));
        deck.removeLast(); // Burn
        final riverCard2 = deck.removeLast().split('|');
        communityCards.add(PlayingCard(rank: riverCard2[0], suit: riverCard2[1]));
        break;
      case GamePhase.turn:
        // Deal river only
        deck.removeLast(); // Burn
        final riverCard3 = deck.removeLast().split('|');
        communityCards.add(PlayingCard(rank: riverCard3[0], suit: riverCard3[1]));
        break;
      case GamePhase.river:
      case GamePhase.showdown:
      case GamePhase.waitingForPlayers:
        // Already at river or beyond, just go to showdown
        break;
    }

    // Determine winner(s) and distribute pot (handles side pots)
    final activePlayers = players.where((p) => !p.hasFolded).toList();
    final finalPlayers = _distributePots(players, communityCards, pot);

    // Get winning hand info for display
    final winnerIndices = HandEvaluator.determineWinners(activePlayers, communityCards);
    if (winnerIndices.isEmpty) {
      winnerIndices.add(0);
    }
    final firstWinner = activePlayers[winnerIndices.first];
    final winningHand = HandEvaluator.evaluateBestHand(firstWinner.cards, communityCards);
    final winnerUids = winnerIndices.map((i) => activePlayers[i].uid).toList();

    await http.patch(
      Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
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
      }),
    );
  }

  /// Get the first player to act based on game phase
  /// Heads-up: Preflop - dealer acts first; Postflop - non-dealer acts first
  /// Multi-way: Preflop - UTG (left of BB); Postflop - first active after dealer
  int _getFirstToActIndex(GameRoom room, List<GamePlayer> players) {
    final numPlayers = players.length;
    final isHeadsUp = numPlayers == 2;
    final currentPhase = GamePhase.fromString(room.phase);

    if (currentPhase == GamePhase.preflop) {
      int firstToAct;
      if (isHeadsUp) {
        // Heads-up: Dealer (who is SB) acts first preflop
        firstToAct = room.dealerIndex;
      } else {
        // Multi-way: UTG (player after BB) acts first
        // Dealer -> SB -> BB -> UTG
        firstToAct = (room.dealerIndex + 3) % numPlayers;
      }
      // Skip folded and all-in players
      int loopCount = 0;
      while ((players[firstToAct].hasFolded || players[firstToAct].chips == 0) && loopCount < numPlayers) {
        firstToAct = (firstToAct + 1) % numPlayers;
        loopCount++;
      }
      return firstToAct;
    } else {
      // Post-flop: First active player after dealer (skip folded and all-in players)
      var firstToAct = (room.dealerIndex + 1) % numPlayers;
      int loopCount = 0;
      while ((players[firstToAct].hasFolded || players[firstToAct].chips == 0) && loopCount < numPlayers) {
        firstToAct = (firstToAct + 1) % numPlayers;
        loopCount++;
      }
      return firstToAct;
    }
  }

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

    // Reset current bets, hasActed, and lastAction for new betting round
    var updatedPlayers = players.map((p) => p.copyWith(currentBet: 0, hasActed: false, lastAction: null)).toList();

    switch (currentPhase) {
      case GamePhase.preflop:
        // Burn one card, then deal flop (3 cards)
        deck.removeLast(); // Burn card
        for (var i = 0; i < 3; i++) {
          final card = deck.removeLast().split('|');
          communityCards.add(PlayingCard(rank: card[0], suit: card[1]));
        }
        nextPhase = GamePhase.flop;
        break;
      case GamePhase.flop:
        // Burn one card, then deal turn (1 card)
        deck.removeLast(); // Burn card
        final card = deck.removeLast().split('|');
        communityCards.add(PlayingCard(rank: card[0], suit: card[1]));
        nextPhase = GamePhase.turn;
        break;
      case GamePhase.turn:
        // Burn one card, then deal river (1 card)
        deck.removeLast(); // Burn card
        final cardStr = deck.removeLast().split('|');
        communityCards.add(PlayingCard(rank: cardStr[0], suit: cardStr[1]));
        nextPhase = GamePhase.river;
        break;
      case GamePhase.river:
        // Showdown - determine winner using proper hand evaluation
        nextPhase = GamePhase.showdown;
        final activePlayers = updatedPlayers.where((p) => !p.hasFolded).toList();

        // Distribute pot (handles side pots)
        final finalPlayers = _distributePots(updatedPlayers, communityCards, pot);

        // Get winning hand info for display
        final winnerIndices = HandEvaluator.determineWinners(activePlayers, communityCards);
        if (winnerIndices.isEmpty) {
          winnerIndices.add(0);
        }
        final firstWinner = activePlayers[winnerIndices.first];
        final winningHand = HandEvaluator.evaluateBestHand(firstWinner.cards, communityCards);
        final winnerUids = winnerIndices.map((i) => activePlayers[i].uid).toList();

        await http.patch(
          Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
          body: jsonEncode({
            'players': finalPlayers.map((p) => p.toJson()).toList(),
            'communityCards': communityCards.map((c) => c.toJson()).toList(),
            'deck': deck,
            'phase': nextPhase.toDbString(),
            'pot': 0,
            'currentBet': 0,
            'lastRaiseAmount': 0,
            'status': 'finished',
            'winnerId': winnerUids.first, // Primary winner for backward compat
            'winnerIds': winnerUids, // All winners for split pots
            'winningHandName': winningHand.description,
          }),
        );
        return;
      case GamePhase.showdown:
      case GamePhase.waitingForPlayers:
        nextPhase = currentPhase;
    }

    // Find first active player to act in new betting round
    final firstToActIdx = _getFirstToActIndex(room.copyWith(phase: nextPhase.toDbString()), updatedPlayers);

    await http.patch(
      Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({
        'players': updatedPlayers.map((p) => p.toJson()).toList(),
        'communityCards': communityCards.map((c) => c.toJson()).toList(),
        'deck': deck,
        'phase': nextPhase.toDbString(),
        'pot': pot,
        'currentBet': 0,
        'lastRaiseAmount': room.bigBlind, // Reset min raise to big blind
        'currentTurnPlayerId': updatedPlayers[firstToActIdx].uid,
        'turnStartTime': DateTime.now().millisecondsSinceEpoch,
        'bbHasOption': false, // BB option only applies preflop, reset for new streets
      }),
    );
  }

  /// Start a new hand
  Future<void> newHand(String roomId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final token = await _getAuthToken();
    final room = await _fetchRoom(roomId);
    if (room == null) return;

    if (room.hostId != userId) throw Exception('Only host can start new hand');

    // Remove players with no chips
    final activePlayers = room.players.where((p) => p.chips > 0).toList();
    if (activePlayers.length < 2) {
      throw Exception('Need at least 2 players with chips');
    }

    // Reset player states and make them ready
    final resetPlayers = activePlayers
        .map((p) => p.copyWith(
            cards: [],
            hasFolded: false,
            currentBet: 0,
            totalContributed: 0,
            isReady: true,
            hasActed: false,
            lastAction: null))
        .toList();

    // Move dealer button
    final newDealerIndex = (room.dealerIndex + 1) % resetPlayers.length;

    await http.patch(
      Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({
        'players': resetPlayers.map((p) => p.toJson()).toList(),
        'status': 'waiting',
        'phase': GamePhase.preflop.toDbString(),
        'pot': 0,
        'currentBet': 0,
        'dealerIndex': newDealerIndex,
        'communityCards': [],
        'deck': [],
        'currentTurnPlayerId': null,
        'winnerId': null,
        'winnerIds': null,
        'winningHandName': null,
        'bbHasOption': true, // Reset BB option for new hand
        'lastRaiseAmount': 0,
      }),
    );
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  /// Calculate side pots when players are all-in for different amounts
  /// Returns a list of (pot amount, eligible player uids) pairs
  List<({int amount, List<String> eligibleUids})> _calculateSidePots(List<GamePlayer> players) {
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
  List<GamePlayer> _distributePots(
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
    final sidePots = _calculateSidePots(players);

    if (sidePots.isEmpty) {
      // No side pots - simple distribution
      final winnerIndices = HandEvaluator.determineWinners(activePlayers, communityCards);
      if (winnerIndices.isEmpty) return finalPlayers;

      final potPerWinner = totalPot ~/ winnerIndices.length;
      final remainder = totalPot % winnerIndices.length;

      for (var i = 0; i < winnerIndices.length; i++) {
        final winner = activePlayers[winnerIndices[i]];
        final winnerIdx = finalPlayers.indexWhere((p) => p.uid == winner.uid);
        if (winnerIdx != -1) {
          final winAmount = potPerWinner + (i == 0 ? remainder : 0);
          finalPlayers[winnerIdx] = finalPlayers[winnerIdx].copyWith(
            chips: finalPlayers[winnerIdx].chips + winAmount,
          );
        }
      }
      return finalPlayers;
    }

    // Distribute each side pot separately
    for (final sidePot in sidePots) {
      // Find eligible active players for this pot
      final eligiblePlayers = activePlayers.where((p) => sidePot.eligibleUids.contains(p.uid)).toList();

      if (eligiblePlayers.isEmpty) continue;

      // Determine winners among eligible players
      final winnerIndices = HandEvaluator.determineWinners(eligiblePlayers, communityCards);
      if (winnerIndices.isEmpty) continue;

      final potPerWinner = sidePot.amount ~/ winnerIndices.length;
      final remainder = sidePot.amount % winnerIndices.length;

      // Get winner UIDs and sort by position (for odd chip distribution)
      // In standard poker, odd chip goes to first winner left of dealer
      // For simplicity, we give to first winner in the list (could enhance with dealer position)
      for (var i = 0; i < winnerIndices.length; i++) {
        final winner = eligiblePlayers[winnerIndices[i]];
        final winnerIdx = finalPlayers.indexWhere((p) => p.uid == winner.uid);
        if (winnerIdx != -1) {
          // First winner gets the odd chip(s)
          final winAmount = potPerWinner + (i == 0 ? remainder : 0);
          finalPlayers[winnerIdx] = finalPlayers[winnerIdx].copyWith(
            chips: finalPlayers[winnerIdx].chips + winAmount,
          );
        }
      }
    }

    return finalPlayers;
  }

  String _generateRoomId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  List<String> _createShuffledDeck() {
    final deck = <String>[];
    for (var suit in ['♠', '♥', '♣', '♦']) {
      for (var rank in ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K']) {
        deck.add('$rank|$suit');
      }
    }
    deck.shuffle(Random());
    return deck;
  }
}
