import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_room.dart';
import 'user_preferences.dart';
import 'hand_evaluator.dart';

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
  Future<GameRoom> createRoom({int bigBlind = 100, int startingChips = 1000, bool isPrivate = false}) async {
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
  Future<void> joinRoom(String roomId, {int startingChips = 1000}) async {
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

    final newPlayer = GamePlayer(uid: userId, displayName: currentUserName, chips: startingChips);
    print('ADDING PLAYER: ${newPlayer.displayName} (${newPlayer.uid})');

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
  Future<List<GameRoom>> fetchJoinableRoomsByBlind(int bigBlind) async {
    // Clean up stale rooms first
    await cleanupStaleRooms();
    
    final token = await _getAuthToken();
    final userId = currentUserId;

    // Fetch ALL rooms (we'll filter locally since Firebase REST has limited query support)
    final response = await http.get(
      Uri.parse('$_databaseUrl/game_rooms.json?auth=$token'),
    );

    print('🔍 Fetching joinable rooms for bigBlind: $bigBlind');

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
    // - Not full
    // - Not private
    // - User not already in room
    // - Either waiting OR playing with phase='waiting_for_players'
    // - Has exactly 1 player (to join them)
    final joinableRooms = allRooms.where((room) {
      final isCorrectBlind = room.bigBlind == bigBlind;
      final isNotFull = !room.isFull;
      final isNotPrivate = !room.isPrivate;
      final userNotInRoom = !room.players.any((p) => p.uid == userId);
      final isJoinable = room.status == 'waiting' || (room.status == 'playing' && room.phase == 'waiting_for_players');
      final needsPlayer = room.players.length == 1; // Only join rooms that have exactly 1 player waiting

      print(
          '🔍 Room ${room.id}: blind=${room.bigBlind}, status=${room.status}, players=${room.players.length}, needsPlayer=$needsPlayer, userNotInRoom=$userNotInRoom');

      return isCorrectBlind && isNotFull && isNotPrivate && userNotInRoom && isJoinable && needsPlayer;
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
  Future<void> startGame(String roomId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final token = await _getAuthToken();
    final room = await _fetchRoom(roomId);
    if (room == null) return;

    if (room.hostId != userId) throw Exception('Only host can start the game');
    if (!room.canStart) throw Exception('Not all players are ready');

    // Create and shuffle deck
    final deck = _createShuffledDeck();

    // Deal cards to players
    final updatedPlayers = room.players.map((p) {
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
        lastAction: null, // Clear action indicator for new hand
      );
    }).toList();

    final numPlayers = updatedPlayers.length;
    final isHeadsUp = numPlayers == 2;

    // Blind positions differ in heads-up vs multi-way
    // Heads-up: Dealer posts SB, other player posts BB
    // Multi-way: Player after dealer posts SB, next posts BB
    int sbIndex;
    int bbIndex;
    int firstToAct;

    if (isHeadsUp) {
      // Heads-up: Dealer = SB, other = BB
      sbIndex = room.dealerIndex;
      bbIndex = (room.dealerIndex + 1) % numPlayers;
      // Preflop: SB/Dealer acts first in heads-up
      firstToAct = sbIndex;
    } else {
      // Multi-way: SB is left of dealer, BB is left of SB
      sbIndex = (room.dealerIndex + 1) % numPlayers;
      bbIndex = (room.dealerIndex + 2) % numPlayers;
      // Preflop: Player left of BB acts first (UTG)
      firstToAct = (bbIndex + 1) % numPlayers;
    }

    // Post blinds (handle case where player doesn't have enough chips)
    final sbAmount = min(room.smallBlind, updatedPlayers[sbIndex].chips);
    final bbAmount = min(room.bigBlind, updatedPlayers[bbIndex].chips);

    updatedPlayers[sbIndex] = updatedPlayers[sbIndex].copyWith(
      chips: updatedPlayers[sbIndex].chips - sbAmount,
      currentBet: sbAmount,
    );
    updatedPlayers[bbIndex] = updatedPlayers[bbIndex].copyWith(
      chips: updatedPlayers[bbIndex].chips - bbAmount,
      currentBet: bbAmount,
    );

    await http.patch(
      Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({
        'status': 'playing',
        'phase': 'preflop',
        'players': updatedPlayers.map((p) => p.toJson()).toList(),
        'deck': deck,
        'pot': sbAmount + bbAmount,
        'currentBet': bbAmount,
        'minRaise': room.bigBlind, // Minimum raise is BB preflop
        'currentTurnPlayerId': updatedPlayers[firstToAct].uid,
        'communityCards': [],
        'lastRaiseAmount': room.bigBlind,
        'bbHasOption': true, // Big blind gets option to raise preflop
      }),
    );
  }

  /// Start the game immediately (skip waiting room, works with 1+ players)
  Future<void> startGameSolo(String roomId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final token = await _getAuthToken();
    final room = await _fetchRoom(roomId);
    if (room == null) return;

    if (room.hostId != userId) throw Exception('Only host can start the game');

    // Create and shuffle deck
    final deck = _createShuffledDeck();

    // Deal cards to players
    final updatedPlayers = room.players.map((p) {
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

    // Handle solo player case
    if (numPlayers == 1) {
      // Solo mode - no blinds needed, just show the game table
      await http.patch(
        Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
        body: jsonEncode({
          'status': 'playing',
          'phase': 'waiting_for_players', // Special phase for solo
          'players': updatedPlayers.map((p) => p.toJson()).toList(),
          'deck': deck,
          'pot': 0,
          'currentBet': 0,
          'minRaise': room.bigBlind,
          'currentTurnPlayerId': updatedPlayers[0].uid,
          'communityCards': [],
          'lastRaiseAmount': room.bigBlind,
          'bbHasOption': false,
        }),
      );
      return;
    }

    final isHeadsUp = numPlayers == 2;

    int sbIndex;
    int bbIndex;
    int firstToAct;

    if (isHeadsUp) {
      sbIndex = room.dealerIndex;
      bbIndex = (room.dealerIndex + 1) % numPlayers;
      firstToAct = sbIndex;
    } else {
      sbIndex = (room.dealerIndex + 1) % numPlayers;
      bbIndex = (room.dealerIndex + 2) % numPlayers;
      firstToAct = (bbIndex + 1) % numPlayers;
    }

    final sbAmount = min(room.smallBlind, updatedPlayers[sbIndex].chips);
    final bbAmount = min(room.bigBlind, updatedPlayers[bbIndex].chips);

    updatedPlayers[sbIndex] = updatedPlayers[sbIndex].copyWith(
      chips: updatedPlayers[sbIndex].chips - sbAmount,
      currentBet: sbAmount,
    );
    updatedPlayers[bbIndex] = updatedPlayers[bbIndex].copyWith(
      chips: updatedPlayers[bbIndex].chips - bbAmount,
      currentBet: bbAmount,
    );

    await http.patch(
      Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({
        'status': 'playing',
        'phase': 'preflop',
        'players': updatedPlayers.map((p) => p.toJson()).toList(),
        'deck': deck,
        'pot': sbAmount + bbAmount,
        'currentBet': bbAmount,
        'minRaise': room.bigBlind,
        'currentTurnPlayerId': updatedPlayers[firstToAct].uid,
        'communityCards': [],
        'lastRaiseAmount': room.bigBlind,
        'bbHasOption': true,
      }),
    );
  }

  /// Start the game from waiting_for_players phase (when 2nd player joins)
  Future<void> startGameFromWaiting(String roomId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final token = await _getAuthToken();
    final room = await _fetchRoom(roomId);
    if (room == null) return;

    if (room.hostId != userId) throw Exception('Only host can start the game');
    if (room.players.length < 2) throw Exception('Need at least 2 players');

    // Create and shuffle a new deck
    final deck = _createShuffledDeck();

    // Deal fresh cards to all players
    final updatedPlayers = room.players.map((p) {
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

    int sbIndex;
    int bbIndex;
    int firstToAct;

    if (isHeadsUp) {
      sbIndex = room.dealerIndex;
      bbIndex = (room.dealerIndex + 1) % numPlayers;
      firstToAct = sbIndex;
    } else {
      sbIndex = (room.dealerIndex + 1) % numPlayers;
      bbIndex = (room.dealerIndex + 2) % numPlayers;
      firstToAct = (bbIndex + 1) % numPlayers;
    }

    final sbAmount = min(room.smallBlind, updatedPlayers[sbIndex].chips);
    final bbAmount = min(room.bigBlind, updatedPlayers[bbIndex].chips);

    updatedPlayers[sbIndex] = updatedPlayers[sbIndex].copyWith(
      chips: updatedPlayers[sbIndex].chips - sbAmount,
      currentBet: sbAmount,
    );
    updatedPlayers[bbIndex] = updatedPlayers[bbIndex].copyWith(
      chips: updatedPlayers[bbIndex].chips - bbAmount,
      currentBet: bbAmount,
    );

    await http.patch(
      Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({
        'status': 'playing',
        'phase': 'preflop',
        'players': updatedPlayers.map((p) => p.toJson()).toList(),
        'deck': deck,
        'pot': sbAmount + bbAmount,
        'currentBet': bbAmount,
        'minRaise': room.bigBlind,
        'currentTurnPlayerId': updatedPlayers[firstToAct].uid,
        'communityCards': [],
        'lastRaiseAmount': room.bigBlind,
        'bbHasOption': true,
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
          lastAction: 'ALL-IN',
        );

        // If this all-in is a raise, update current bet and reset hasActed
        if (newTotalBet > currentBet) {
          final raiseBy = newTotalBet - currentBet;
          if (raiseBy >= lastRaiseAmount) {
            lastRaiseAmount = raiseBy;
            // Reset hasActed for all other players since there's a raise
            updatedPlayers = updatedPlayers.map((p) {
              if (p.uid != userId && !p.hasFolded) {
                return p.copyWith(hasActed: false);
              }
              return p;
            }).toList();
          }
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

    // Track if BB option was used (any raise or BB checked/called)
    var bbOptionUsed = !room.bbHasOption; // Already used if false

    // If action is check/call and player is BB preflop with option, it's used
    if (room.phase == 'preflop' && room.bbHasOption) {
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
    // Special case: preflop BB option - BB gets to act even if all bets are equal
    final allPlayersActed = playersWhoCanAct.every((p) => p.hasActed);
    final allBetsEqual = playersWhoCanAct.every((p) => p.currentBet == currentBet);
    final bettingComplete = allPlayersActed && allBetsEqual && bbOptionUsed;

    if (bettingComplete) {
      // Move to next phase
      await _advancePhase(roomId, room, updatedPlayers, pot, lastRaiseAmount);
    } else {
      await http.patch(
        Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
        body: jsonEncode({
          'players': updatedPlayers.map((p) => p.toJson()).toList(),
          'pot': pot,
          'currentBet': currentBet,
          'lastRaiseAmount': lastRaiseAmount,
          'currentTurnPlayerId': updatedPlayers[nextPlayerIndex].uid,
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

    // Deal remaining community cards based on current phase
    switch (room.phase) {
      case 'preflop':
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
      case 'flop':
        // Deal turn and river
        deck.removeLast(); // Burn
        final turnCard2 = deck.removeLast().split('|');
        communityCards.add(PlayingCard(rank: turnCard2[0], suit: turnCard2[1]));
        deck.removeLast(); // Burn
        final riverCard2 = deck.removeLast().split('|');
        communityCards.add(PlayingCard(rank: riverCard2[0], suit: riverCard2[1]));
        break;
      case 'turn':
        // Deal river only
        deck.removeLast(); // Burn
        final riverCard3 = deck.removeLast().split('|');
        communityCards.add(PlayingCard(rank: riverCard3[0], suit: riverCard3[1]));
        break;
      case 'river':
        // Already at river, just go to showdown
        break;
    }

    // Determine winner(s)
    final activePlayers = players.where((p) => !p.hasFolded).toList();
    final winnerIndices = HandEvaluator.determineWinners(activePlayers, communityCards);

    if (winnerIndices.isEmpty) {
      winnerIndices.add(0);
    }

    final firstWinner = activePlayers[winnerIndices.first];
    final winningHand = HandEvaluator.evaluateBestHand(firstWinner.cards, communityCards);

    // Split pot among winners
    final potPerWinner = pot ~/ winnerIndices.length;
    final remainder = pot % winnerIndices.length;

    final finalPlayers = List<GamePlayer>.from(players);
    final winnerUids = <String>[];

    for (var i = 0; i < winnerIndices.length; i++) {
      final winner = activePlayers[winnerIndices[i]];
      final winnerIdx = finalPlayers.indexWhere((p) => p.uid == winner.uid);
      if (winnerIdx != -1) {
        final winAmount = potPerWinner + (i == 0 ? remainder : 0);
        finalPlayers[winnerIdx] = finalPlayers[winnerIdx].copyWith(chips: finalPlayers[winnerIdx].chips + winAmount);
        winnerUids.add(winner.uid);
      }
    }

    await http.patch(
      Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({
        'players': finalPlayers.map((p) => p.toJson()).toList(),
        'communityCards': communityCards.map((c) => c.toJson()).toList(),
        'deck': deck,
        'phase': 'showdown',
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

    if (room.phase == 'preflop') {
      if (isHeadsUp) {
        // Heads-up: Dealer (who is SB) acts first preflop
        return room.dealerIndex;
      } else {
        // Multi-way: UTG (player after BB) acts first
        // Dealer -> SB -> BB -> UTG
        return (room.dealerIndex + 3) % numPlayers;
      }
    } else {
      // Post-flop: First active player after dealer
      var firstToAct = (room.dealerIndex + 1) % numPlayers;
      int loopCount = 0;
      while (players[firstToAct].hasFolded && loopCount < numPlayers) {
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
    int lastRaiseAmount,
  ) async {
    final token = await _getAuthToken();
    final deck = List<String>.from(room.deck);
    final communityCards = List<PlayingCard>.from(room.communityCards);
    String nextPhase;

    // Reset current bets, hasActed, and lastAction for new betting round
    var updatedPlayers = players.map((p) => p.copyWith(currentBet: 0, hasActed: false, lastAction: null)).toList();

    switch (room.phase) {
      case 'preflop':
        // Burn one card, then deal flop (3 cards)
        deck.removeLast(); // Burn card
        for (var i = 0; i < 3; i++) {
          final card = deck.removeLast().split('|');
          communityCards.add(PlayingCard(rank: card[0], suit: card[1]));
        }
        nextPhase = 'flop';
        break;
      case 'flop':
        // Burn one card, then deal turn (1 card)
        deck.removeLast(); // Burn card
        final card = deck.removeLast().split('|');
        communityCards.add(PlayingCard(rank: card[0], suit: card[1]));
        nextPhase = 'turn';
        break;
      case 'turn':
        // Burn one card, then deal river (1 card)
        deck.removeLast(); // Burn card
        final cardStr = deck.removeLast().split('|');
        communityCards.add(PlayingCard(rank: cardStr[0], suit: cardStr[1]));
        nextPhase = 'river';
        break;
      case 'river':
        // Showdown - determine winner using proper hand evaluation
        nextPhase = 'showdown';
        final activePlayers = updatedPlayers.where((p) => !p.hasFolded).toList();

        // Evaluate hands and determine winners
        final winnerIndices = HandEvaluator.determineWinners(activePlayers, communityCards);

        // If no valid hands (shouldn't happen), fall back to first active player
        if (winnerIndices.isEmpty) {
          winnerIndices.add(0);
        }

        // Get winning hand description for display
        final firstWinner = activePlayers[winnerIndices.first];
        final winningHand = HandEvaluator.evaluateBestHand(firstWinner.cards, communityCards);

        // Split pot among winners
        final potPerWinner = pot ~/ winnerIndices.length;
        final remainder = pot % winnerIndices.length;

        final finalPlayers = List<GamePlayer>.from(updatedPlayers);
        final winnerUids = <String>[];

        for (var i = 0; i < winnerIndices.length; i++) {
          final winner = activePlayers[winnerIndices[i]];
          final winnerIdx = finalPlayers.indexWhere((p) => p.uid == winner.uid);
          if (winnerIdx != -1) {
            // First winner gets any remainder chips
            final winAmount = potPerWinner + (i == 0 ? remainder : 0);
            finalPlayers[winnerIdx] = finalPlayers[winnerIdx].copyWith(
              chips: finalPlayers[winnerIdx].chips + winAmount,
            );
            winnerUids.add(winner.uid);
          }
        }

        await http.patch(
          Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
          body: jsonEncode({
            'players': finalPlayers.map((p) => p.toJson()).toList(),
            'communityCards': communityCards.map((c) => c.toJson()).toList(),
            'deck': deck,
            'phase': nextPhase,
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
      default:
        nextPhase = room.phase;
    }

    // Find first active player to act in new betting round
    final firstToActIdx = _getFirstToActIndex(room.copyWith(phase: nextPhase), updatedPlayers);

    await http.patch(
      Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({
        'players': updatedPlayers.map((p) => p.toJson()).toList(),
        'communityCards': communityCards.map((c) => c.toJson()).toList(),
        'deck': deck,
        'phase': nextPhase,
        'pot': pot,
        'currentBet': 0,
        'lastRaiseAmount': room.bigBlind, // Reset min raise to big blind
        'currentTurnPlayerId': updatedPlayers[firstToActIdx].uid,
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
    final resetPlayers =
        activePlayers.map((p) => p.copyWith(cards: [], hasFolded: false, currentBet: 0, isReady: true)).toList();

    // Move dealer button
    final newDealerIndex = (room.dealerIndex + 1) % resetPlayers.length;

    await http.patch(
      Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({
        'players': resetPlayers.map((p) => p.toJson()).toList(),
        'status': 'waiting',
        'phase': 'preflop',
        'pot': 0,
        'currentBet': 0,
        'dealerIndex': newDealerIndex,
        'communityCards': [],
        'deck': [],
        'currentTurnPlayerId': null,
        'winnerId': null,
        'bbHasOption': true, // Reset BB option for new hand
        'lastRaiseAmount': 0,
      }),
    );
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

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
