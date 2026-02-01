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
  /// Priority: 1) Saved username in preferences, 2) Firebase displayName, 3) Email prefix, 4) Random fallback
  String get currentUserName {
    // First check UserPreferences - this is where the app actually stores the username
    if (UserPreferences.hasSetUsername) {
      final savedUsername = UserPreferences.username;
      if (savedUsername.isNotEmpty) {
        return savedUsername;
      }
    }

    // Fall back to Firebase Auth info
    final user = _auth.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        return user.displayName!;
      }
      if (user.email != null && user.email!.isNotEmpty) {
        return user.email!.split('@').first;
      }
      return 'Player${user.uid.substring(0, 4).toUpperCase()}';
    }

    // Final fallback - generate random name
    return UserPreferences.username;
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

  // ============================================================================
  // ROOM CRUD
  // ============================================================================

  /// Create a new game room
  Future<GameRoom> createRoom({
    int bigBlind = 100,
    int startingChips = 1000,
    bool isPrivate = false,
    String gameType = 'cash',
    int maxPlayers = 2,
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
    if (room.players.any((p) => p.uid == userId)) {
      print('ALREADY IN ROOM: User $userId is already a player');
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

      return isCorrectBlind &&
          isCorrectGameType &&
          isNotFull &&
          isNotPrivate &&
          userNotInRoom &&
          isJoinable &&
          hasSpace;
    }).toList();

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

        if (room.players.isEmpty) {
          shouldDelete = true;
        } else if (room.status == 'finished') {
          shouldDelete = true;
        } else if (room.status == 'waiting' && room.players.length == 1) {
          final waitTime = now.difference(room.createdAt).inSeconds;
          if (waitTime > 30) {
            shouldDelete = true;
          }
        }

        if (shouldDelete) {
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
