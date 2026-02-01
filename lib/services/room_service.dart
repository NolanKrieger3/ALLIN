import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_room.dart';
import 'user_preferences.dart';

/// Service for managing game rooms - creation, joining, leaving, fetching
class RoomService {
  static const String databaseUrl = 'https://allin-d0e2d-default-rtdb.firebaseio.com';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Get current user display name
  /// Priority: 1) Saved username in preferences, 2) Firebase displayName, 3) Email prefix, 4) Consistent random fallback
  String get currentUserName {
    // First check UserPreferences - this is where the app actually stores the username
    final hasSetUsername = UserPreferences.hasSetUsername;
    final savedUsername = UserPreferences.username;

    print('🔍 USERNAME CHECK: hasSetUsername=$hasSetUsername, savedUsername=$savedUsername');

    // Check if we have a valid saved username (either flag is set OR username doesn't look random)
    // Random names follow pattern: AdjectiveNoun## (e.g., "LuckyShark42")
    final looksLikeSavedUsername =
        savedUsername.isNotEmpty && !RegExp(r'^[A-Z][a-z]+[A-Z][a-z]+\d{1,2}$').hasMatch(savedUsername);

    if (hasSetUsername || looksLikeSavedUsername) {
      print('✅ Using saved username: $savedUsername');
      return savedUsername;
    }

    // Fall back to Firebase Auth info
    final user = _auth.currentUser;
    if (user != null) {
      print('🔍 Firebase user: displayName=${user.displayName}, email=${user.email}, uid=${user.uid}');

      if (user.displayName != null && user.displayName!.isNotEmpty) {
        print('✅ Using Firebase displayName: ${user.displayName}');
        return user.displayName!;
      }
      if (user.email != null && user.email!.isNotEmpty) {
        final emailPrefix = user.email!.split('@').first;
        print('✅ Using email prefix: $emailPrefix');
        return emailPrefix;
      }
    }

    // Final fallback - use UserPreferences which now caches the random name
    print('⚠️ Using UserPreferences fallback: $savedUsername');
    return savedUsername;
  }

  /// Get auth token for authenticated requests
  Future<String?> getAuthToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  /// Generate a unique room ID
  String generateRoomId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Generate a 4-digit PIN for private rooms
  String generateRoomPin() {
    final random = Random();
    return List.generate(4, (_) => random.nextInt(10).toString()).join();
  }

  // ============================================================================
  // ROOM CRUD
  // ============================================================================

  /// Create a private game room with a 4-digit PIN
  Future<Map<String, String>> createPrivateRoom({
    int bigBlind = 100,
    int startingChips = 10000,
    int maxPlayers = 8,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in to create a room');

    final token = await getAuthToken();
    final roomPin = generateRoomPin();
    final roomId = 'PRIV_$roomPin'; // Use PIN as part of room ID for easy lookup

    final room = GameRoom(
      id: roomId,
      hostId: userId,
      players: [
        GamePlayer(
          uid: userId,
          displayName: currentUserName,
          chips: startingChips,
          lastActiveAt: DateTime.now(),
        )
      ],
      bigBlind: bigBlind,
      smallBlind: bigBlind ~/ 2,
      createdAt: DateTime.now(),
      isPrivate: true,
      gameType: 'private',
      maxPlayers: maxPlayers,
    );

    final response = await http.put(
      Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode(room.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create room: ${response.body}');
    }

    return {'roomId': roomId, 'roomPin': roomPin};
  }

  /// Join a private room by PIN
  Future<String> joinPrivateRoom(String pin, {int startingChips = 10000}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in to join a room');

    final roomId = 'PRIV_$pin';
    final token = await getAuthToken();

    // Check if room exists
    final response = await http.get(Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'));

    if (response.statusCode != 200) {
      throw Exception('Failed to find room');
    }

    final roomData = jsonDecode(response.body);
    if (roomData == null) {
      throw Exception('Room not found. Check the PIN and try again.');
    }

    final room = GameRoom.fromJson(roomData, roomId);

    // Check if room is full
    if (room.players.length >= room.maxPlayers) {
      throw Exception('Room is full');
    }

    // Check if game already started
    if (room.status != 'waiting') {
      throw Exception('Game has already started');
    }

    // Check if already in room
    if (room.players.any((p) => p.uid == userId)) {
      return roomId; // Already in room, just return
    }

    // Add player to room
    final newPlayer = GamePlayer(
      uid: userId,
      displayName: currentUserName,
      chips: startingChips,
      lastActiveAt: DateTime.now(),
    );

    final updatedPlayers = [...room.players, newPlayer];

    await http.patch(
      Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({'players': updatedPlayers.map((p) => p.toJson()).toList()}),
    );

    return roomId;
  }

  /// Create a new game room
  Future<GameRoom> createRoom({
    int bigBlind = 100,
    int startingChips = 1000,
    bool isPrivate = false,
    String gameType = 'cash',
    int maxPlayers = 6,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in to create a room');

    final token = await getAuthToken();
    final roomId = generateRoomId();

    final room = GameRoom(
      id: roomId,
      hostId: userId,
      players: [
        GamePlayer(
          uid: userId,
          displayName: currentUserName,
          chips: startingChips,
          lastActiveAt: DateTime.now(),
        )
      ],
      bigBlind: bigBlind,
      smallBlind: bigBlind ~/ 2,
      createdAt: DateTime.now(),
      isPrivate: isPrivate,
      gameType: gameType,
      maxPlayers: maxPlayers,
    );

    final response = await http.put(
      Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode(room.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create room: ${response.body}');
    }

    return room;
  }

  /// Create a Sit & Go tournament room
  Future<GameRoom> createSitAndGoRoom({int startingChips = 10000, int bigBlind = 100}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in to create a room');

    final token = await getAuthToken();
    final roomId = generateRoomId();

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
      Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode(room.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create room: ${response.body}');
    }

    return room;
  }

  /// Join an existing room
  Future<void> joinRoom(String roomId, {int? startingChips}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in to join a room');

    final token = await getAuthToken();

    print('JOIN ATTEMPT: userId=$userId, name=$currentUserName, roomId=$roomId');

    final response = await http.get(Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'));

    if (response.statusCode != 200 || response.body == 'null') {
      throw Exception('Room not found');
    }

    final roomData = jsonDecode(response.body) as Map<String, dynamic>;
    final room = GameRoom.fromJson(roomData, roomId);

    print('ROOM PLAYERS: ${room.players.map((p) => "${p.displayName} (${p.uid})").join(", ")}');

    if (room.isFull) throw Exception('Room is full');

    bool isJoinable;
    if (room.gameType == 'quickplay') {
      isJoinable = room.status == 'waiting' || room.status == 'playing';
    } else {
      isJoinable = room.status == 'waiting' || (room.status == 'playing' && room.phase == 'waiting_for_players');
    }
    if (!isJoinable) throw Exception('Game already in progress');

    // Check if player is already in the room
    final existingPlayerIndex = room.players.indexWhere((p) => p.uid == userId);
    if (existingPlayerIndex != -1) {
      print('ALREADY IN ROOM: User $userId is already a player');

      // If room is in 'waiting' status, reset player's stale state (hasFolded, hasActed, etc.)
      if (room.status == 'waiting') {
        final existingPlayer = room.players[existingPlayerIndex];
        final resetPlayer = existingPlayer.copyWith(
          hasFolded: false,
          hasActed: false,
          currentBet: 0,
          totalContributed: 0,
          cards: [],
          lastAction: null,
          lastActiveAt: DateTime.now(),
        );

        final updatedPlayers = List<GamePlayer>.from(room.players);
        updatedPlayers[existingPlayerIndex] = resetPlayer;

        await http.patch(
          Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'),
          body: jsonEncode({'players': updatedPlayers.map((p) => p.toJson()).toList()}),
        );
        print('✅ Reset stale player state for user $userId in waiting room');
      }
      return;
    }

    final chips = startingChips ?? room.players.first.chips;
    final isJoiningMidGame = room.status == 'playing' && room.phase != 'waiting_for_players';

    final newPlayer = GamePlayer(
      uid: userId,
      displayName: currentUserName,
      chips: chips,
      isReady: true,
      hasFolded: isJoiningMidGame,
      lastActiveAt: DateTime.now(),
    );

    final updatedPlayers = [...room.players, newPlayer];

    await http.patch(
      Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({'players': updatedPlayers.map((p) => p.toJson()).toList()}),
    );

    print('✅ Successfully joined room $roomId with ${updatedPlayers.length} players');
  }

  /// Leave a room
  Future<void> leaveRoom(String roomId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final token = await getAuthToken();

    final response = await http.get(Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'));

    if (response.statusCode != 200 || response.body == 'null') return;

    final roomData = jsonDecode(response.body) as Map<String, dynamic>;
    final room = GameRoom.fromJson(roomData, roomId);
    final updatedPlayers = room.players.where((p) => p.uid != userId).toList();

    if (updatedPlayers.isEmpty) {
      await http.delete(Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'));
    } else {
      final newHostId = room.hostId == userId ? updatedPlayers.first.uid : room.hostId;

      await http.patch(
        Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'),
        body: jsonEncode({'players': updatedPlayers.map((p) => p.toJson()).toList(), 'hostId': newHostId}),
      );
    }
  }

  /// Toggle ready status
  Future<void> toggleReady(String roomId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final token = await getAuthToken();

    final response = await http.get(Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'));

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
      Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({'players': updatedPlayers.map((p) => p.toJson()).toList()}),
    );
  }

  // ============================================================================
  // FETCHING & STREAMS
  // ============================================================================

  /// Listen to a specific room (polling-based)
  Stream<GameRoom?> watchRoom(String roomId) {
    return Stream.periodic(const Duration(milliseconds: 500)).asyncMap((_) => fetchRoom(roomId));
  }

  /// Fetch a single room
  Future<GameRoom?> fetchRoom(String roomId) async {
    final token = await getAuthToken();

    final response = await http.get(Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'));

    if (response.statusCode != 200 || response.body == 'null') {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return GameRoom.fromJson(data, roomId);
  }

  /// Get available rooms stream
  Stream<List<GameRoom>> getAvailableRooms() {
    return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) => fetchAvailableRooms('cash'));
  }

  /// Get available Sit & Go tournaments stream
  Stream<List<GameRoom>> getAvailableSitAndGoRooms() {
    return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) => fetchAvailableRooms('sitandgo'));
  }

  /// Immediately fetch available cash game rooms
  Future<List<GameRoom>> fetchAvailableCashRooms() async {
    return fetchAvailableRooms('cash');
  }

  /// Immediately fetch available Sit & Go rooms
  Future<List<GameRoom>> fetchAvailableSitAndGoRoomsNow() async {
    return fetchAvailableRooms('sitandgo');
  }

  Future<List<GameRoom>> fetchAvailableRooms(String gameType) async {
    final token = await getAuthToken();
    final userId = currentUserId;

    final response = await http.get(
      Uri.parse('$databaseUrl/game_rooms.json?auth=$token&orderBy="status"&equalTo="waiting"'),
    );

    if (response.statusCode != 200 || response.body == 'null') {
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final allRooms =
        data.entries.map((e) => GameRoom.fromJson(Map<String, dynamic>.from(e.value as Map), e.key)).toList();

    return allRooms
        .where(
          (room) =>
              !room.isFull && room.gameType == gameType && !room.isPrivate && !room.players.any((p) => p.uid == userId),
        )
        .toList();
  }

  /// Fetch joinable rooms by blind level
  Future<List<GameRoom>> fetchJoinableRoomsByBlind(int bigBlind, {String gameType = 'cash', int? maxPlayers}) async {
    await cleanupStaleRooms();

    final token = await getAuthToken();
    final userId = currentUserId;

    final response = await http.get(
      Uri.parse('$databaseUrl/game_rooms.json?auth=$token'),
    );

    print('🔍 FETCHING JOINABLE ROOMS for bigBlind=$bigBlind, gameType=$gameType');

    if (response.statusCode != 200 || response.body == 'null') {
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final allRooms =
        data.entries.map((e) => GameRoom.fromJson(Map<String, dynamic>.from(e.value as Map), e.key)).toList();

    print('🔍 Total rooms in database: ${allRooms.length}');

    final joinableRooms = allRooms.where((room) {
      final isCorrectBlind = room.bigBlind == bigBlind;
      final isCorrectGameType = room.gameType == gameType;
      final isNotFull = !room.isFull;
      final isNotPrivate = !room.isPrivate;
      final userNotInRoom = !room.players.any((p) => p.uid == userId);

      bool isJoinable;
      if (gameType.startsWith('sitandgo')) {
        isJoinable = room.status == 'waiting';
      } else {
        isJoinable = room.status == 'waiting' || room.status == 'playing';
      }

      bool hasSpace;
      if (gameType.startsWith('sitandgo')) {
        hasSpace = room.players.length < (maxPlayers ?? room.maxPlayers);
      } else {
        hasSpace = room.players.length < 6;
      }

      // Debug log for each room
      if (!isCorrectBlind && room.gameType == gameType) {
        print('❌ Room ${room.id}: wrong blind (${room.bigBlind} != $bigBlind)');
      }

      return isCorrectBlind &&
          isCorrectGameType &&
          isNotFull &&
          isNotPrivate &&
          userNotInRoom &&
          isJoinable &&
          hasSpace;
    }).toList();

    print('✅ Found ${joinableRooms.length} joinable rooms for blind=$bigBlind, gameType=$gameType');

    // Sort by fullest first, then oldest
    joinableRooms.sort((a, b) {
      final playerCompare = b.players.length.compareTo(a.players.length);
      if (playerCompare != 0) return playerCompare;
      return a.createdAt.compareTo(b.createdAt);
    });

    return joinableRooms;
  }

  /// Check if all rooms for a given blind/gameType are full
  Future<bool> areAllRoomsFull(int bigBlind, String gameType) async {
    final token = await getAuthToken();
    final response = await http.get(
      Uri.parse('$databaseUrl/game_rooms.json?auth=$token'),
    );

    if (response.statusCode != 200 || response.body == 'null') {
      return true;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final allRooms =
        data.entries.map((e) => GameRoom.fromJson(Map<String, dynamic>.from(e.value as Map), e.key)).toList();

    final matchingRooms = allRooms.where((room) {
      return room.bigBlind == bigBlind &&
          room.gameType == gameType &&
          !room.isPrivate &&
          (room.status == 'waiting' || room.status == 'playing');
    }).toList();

    if (matchingRooms.isEmpty) return true;
    return matchingRooms.every((room) => room.players.length >= 6);
  }

  // ============================================================================
  // HEARTBEAT & CLEANUP
  // ============================================================================

  /// Send heartbeat to keep player active in room
  Future<void> sendHeartbeat(String roomId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final token = await getAuthToken();

    final response = await http.get(Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'));
    if (response.statusCode != 200 || response.body == 'null') return;

    final roomData = jsonDecode(response.body) as Map<String, dynamic>;
    final room = GameRoom.fromJson(roomData, roomId);

    final myIndex = room.players.indexWhere((p) => p.uid == userId);
    if (myIndex == -1) return;

    await http.patch(
      Uri.parse('$databaseUrl/game_rooms/$roomId/players/$myIndex.json?auth=$token'),
      body: jsonEncode({'lastActiveAt': DateTime.now().toIso8601String()}),
    );
  }

  /// Remove inactive players from a room
  Future<void> removeInactivePlayers(String roomId) async {
    final userId = currentUserId;
    final token = await getAuthToken();

    final response = await http.get(Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'));
    if (response.statusCode != 200 || response.body == 'null') return;

    final roomData = jsonDecode(response.body) as Map<String, dynamic>;
    final room = GameRoom.fromJson(roomData, roomId);

    if (room.hostId != userId) return;
    if (room.status != 'waiting') return;

    final now = DateTime.now();
    final activePlayers = room.players.where((p) {
      if (p.lastActiveAt == null) {
        return now.difference(room.createdAt).inSeconds < 45;
      }
      return now.difference(p.lastActiveAt!).inSeconds < 45;
    }).toList();

    if (activePlayers.length < room.players.length) {
      if (activePlayers.isEmpty) {
        await http.delete(Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'));
      } else {
        final newHostId = activePlayers.any((p) => p.uid == room.hostId) ? room.hostId : activePlayers.first.uid;

        await http.patch(
          Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'),
          body: jsonEncode({
            'players': activePlayers.map((p) => p.toJson()).toList(),
            'hostId': newHostId,
          }),
        );
      }
    }
  }

  /// Clean up stale rooms
  Future<void> cleanupStaleRooms() async {
    final token = await getAuthToken();
    if (token == null) return;

    try {
      final response = await http.get(Uri.parse('$databaseUrl/game_rooms.json?auth=$token'));

      if (response.statusCode != 200 || response.body == 'null') return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final now = DateTime.now();

      for (final entry in data.entries) {
        final roomId = entry.key;
        final roomData = Map<String, dynamic>.from(entry.value as Map);
        final room = GameRoom.fromJson(roomData, roomId);

        bool shouldDelete = false;
        String reason = '';

        // Delete empty rooms
        if (room.players.isEmpty) {
          shouldDelete = true;
          reason = 'empty';
        }
        // Delete finished rooms
        else if (room.status == 'finished') {
          shouldDelete = true;
          reason = 'finished';
        }
        // Delete waiting rooms older than 5 minutes (stale lobbies)
        else if (room.status == 'waiting') {
          final waitTime = now.difference(room.createdAt).inMinutes;
          if (waitTime >= 5) {
            shouldDelete = true;
            reason = 'stale lobby (${waitTime}min)';
          }
        }
        // Delete playing/in_progress rooms older than 30 minutes (stale games)
        else if (room.status == 'in_progress' || room.status == 'playing') {
          final gameTime = now.difference(room.createdAt).inMinutes;
          if (gameTime > 30) {
            shouldDelete = true;
            reason = 'stale game (${gameTime}min)';
          }
        }

        if (shouldDelete) {
          print('🗑️ Deleting room $roomId: $reason');
          await http.delete(Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'));
        }
      }
    } catch (e) {
      print('⚠️ Cleanup error: $e');
    }
  }

  /// Delete ALL game rooms (for debugging/testing)
  Future<void> deleteAllRooms() async {
    final token = await getAuthToken();
    if (token == null) return;

    try {
      await http.delete(Uri.parse('$databaseUrl/game_rooms.json?auth=$token'));
      print('🗑️ Deleted ALL game rooms');
    } catch (e) {
      print('⚠️ Delete all rooms error: $e');
    }
  }
}
