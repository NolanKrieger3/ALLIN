import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/game_room.dart';
import '../models/game_player.dart';
import 'auth_service.dart';
import 'room_service.dart';

/// Dedicated service for Sit & Go tournament matchmaking
/// Unlike Quick Play, Sit & Go waits for a lobby to fill before starting
class SitAndGoService {
  static final SitAndGoService _instance = SitAndGoService._internal();
  factory SitAndGoService() => _instance;
  SitAndGoService._internal();

  final AuthService _authService = AuthService();

  static const String databaseUrl = 'https://allin-d0e2d-default-rtdb.firebaseio.com';
  static const Map<String, String> _jsonHeaders = {'Content-Type': 'application/json'};

  String? get currentUserId => _authService.currentUser?.uid;
  String get currentUserName => _authService.currentUser?.displayName ?? 'Player';

  Future<String?> getAuthToken() async {
    return await _authService.currentUser?.getIdToken();
  }

  String _generateRoomId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (index) => chars[(DateTime.now().microsecondsSinceEpoch + index) % chars.length]).join();
  }

  /// Join a Sit & Go tournament at the specified buy-in level
  /// Returns the room ID to navigate to the waiting screen
  Future<String> joinSitAndGo({
    required int buyIn,
    required int startingChips,
    int maxPlayers = 6,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in to join Sit & Go');

    print('🎰 SitAndGo: Starting join for buyIn=$buyIn, chips=$startingChips, maxPlayers=$maxPlayers');

    // Step 1: Leave any rooms we're currently in
    await _leaveAllRooms();

    // Step 2: Find existing Sit & Go rooms at this buy-in level
    final availableRooms = await _fetchAvailableSitAndGoRooms(buyIn, maxPlayers);

    // Step 3: Join existing room or create new one
    if (availableRooms.isNotEmpty) {
      // Sort by most players first (fill lobbies faster)
      availableRooms.sort((a, b) => b.players.length.compareTo(a.players.length));

      // Try to join the fullest room
      for (final room in availableRooms) {
        try {
          await _joinRoom(room.id, startingChips);
          print('🎰 SitAndGo: Joined existing room ${room.id} (${room.players.length + 1}/$maxPlayers)');
          return room.id;
        } catch (e) {
          print('⚠️ SitAndGo: Failed to join ${room.id}: $e');
          // Room might have filled, try next one
          continue;
        }
      }
    }

    // No available rooms or all failed, create new one
    final roomId = await _createSitAndGoRoom(buyIn, startingChips, maxPlayers);
    print('🎰 SitAndGo: Created new room $roomId');
    return roomId;
  }

  /// Leave all rooms the user is currently in
  Future<void> _leaveAllRooms() async {
    final userId = currentUserId;
    if (userId == null) return;

    final token = await getAuthToken();
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$databaseUrl/game_rooms.json?auth=$token'),
      );

      if (response.statusCode != 200 || response.body == 'null') return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      for (final entry in data.entries) {
        final roomId = entry.key;
        final roomData = Map<String, dynamic>.from(entry.value as Map);
        final room = GameRoom.fromJson(roomData, roomId);

        if (room.players.any((p) => p.uid == userId)) {
          print('🚪 SitAndGo: Leaving room $roomId');
          await _leaveRoom(roomId);
        }
      }
    } catch (e) {
      print('⚠️ SitAndGo: Error leaving rooms: $e');
    }
  }

  /// Fetch available Sit & Go rooms at the specified buy-in
  Future<List<GameRoom>> _fetchAvailableSitAndGoRooms(int buyIn, int maxPlayers) async {
    final userId = currentUserId;
    final token = await getAuthToken();

    final response = await http.get(
      Uri.parse('$databaseUrl/game_rooms.json?auth=$token'),
    );

    if (response.statusCode != 200 || response.body == 'null') {
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final allRooms =
        data.entries.map((e) => GameRoom.fromJson(Map<String, dynamic>.from(e.value as Map), e.key)).toList();

    // Filter for Sit & Go rooms at this buy-in that we can join
    final availableRooms = allRooms.where((room) {
      final isSitAndGo = room.gameType.contains('sitandgo');
      final isCorrectBuyIn = room.bigBlind == buyIn;
      final isWaiting = room.status == RoomStatus.waiting;
      final hasSpace = room.players.length < maxPlayers;
      final notInRoom = !room.players.any((p) => p.uid == userId);
      final notPrivate = !room.isPrivate;

      return isSitAndGo && isCorrectBuyIn && isWaiting && hasSpace && notInRoom && notPrivate;
    }).toList();

    print('🎰 SitAndGo: Found ${availableRooms.length} joinable rooms for buyIn=$buyIn');
    for (final room in availableRooms) {
      print('   Room ${room.id}: ${room.players.length}/$maxPlayers players');
    }

    return availableRooms;
  }

  /// Create a new Sit & Go room
  Future<String> _createSitAndGoRoom(int buyIn, int startingChips, int maxPlayers) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in');

    final token = await getAuthToken();
    final roomId = _generateRoomId();

    final room = GameRoom(
      id: roomId,
      hostId: userId,
      players: [
        GamePlayer(
          uid: userId,
          displayName: currentUserName,
          chips: startingChips,
          lastActiveAt: DateTime.now(),
          isReady: true,
        )
      ],
      maxPlayers: maxPlayers,
      bigBlind: buyIn,
      smallBlind: buyIn ~/ 2,
      createdAt: DateTime.now(),
      gameType: 'sitandgo',
    );

    final response = await http.put(
      Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'),
      headers: _jsonHeaders,
      body: jsonEncode({
        ...room.toJson(),
        'lastActivityAt': DateTime.now().millisecondsSinceEpoch,
        'defaultChips': startingChips,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create Sit & Go room: ${response.body}');
    }

    return roomId;
  }

  /// Join an existing room with retry logic to handle race conditions
  Future<void> _joinRoom(String roomId, int startingChips) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in');

    final token = await getAuthToken();

    // Retry up to 5 times to handle race conditions where multiple players
    // try to join simultaneously and overwrite each other's updates
    const maxRetries = 5;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      // Get current room data (fresh read on each attempt)
      final response = await http.get(
        Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'),
      );

      if (response.statusCode != 200 || response.body == 'null') {
        throw Exception('Room not found');
      }

      final roomData = jsonDecode(response.body) as Map<String, dynamic>;
      final room = GameRoom.fromJson(roomData, roomId);

      // Check if room is still joinable
      if (room.status != RoomStatus.waiting) {
        throw Exception('Room is no longer waiting');
      }

      final maxPlayers = room.maxPlayers;
      if (room.players.length >= maxPlayers) {
        throw Exception('Room is full');
      }

      // Check if we're already in the room (might have joined on a previous attempt)
      if (room.players.any((p) => p.uid == userId)) {
        print('✅ SitAndGo: Already in room $roomId');
        return; // Success - we're already in
      }

      // Record player count before patch for validation
      final expectedPlayerCount = room.players.length + 1;

      // Add player to room
      final updatedPlayers = [
        ...room.players,
        GamePlayer(
          uid: userId,
          displayName: currentUserName,
          chips: startingChips,
          lastActiveAt: DateTime.now(),
          isReady: true,
        ),
      ];

      final patchResponse = await http.patch(
        Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'players': updatedPlayers.map((p) => p.toJson()).toList(),
          'lastActivityAt': DateTime.now().millisecondsSinceEpoch,
        }),
      );

      if (patchResponse.statusCode != 200) {
        throw Exception('Failed to join room');
      }

      // Verify the join was successful by re-reading the room
      await Future.delayed(const Duration(milliseconds: 100));
      final verifyResponse = await http.get(
        Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'),
      );

      if (verifyResponse.statusCode == 200 && verifyResponse.body != 'null') {
        final verifyData = jsonDecode(verifyResponse.body) as Map<String, dynamic>;
        final verifyRoom = GameRoom.fromJson(verifyData, roomId);

        if (verifyRoom.players.any((p) => p.uid == userId)) {
          print('✅ SitAndGo: Successfully joined room $roomId (${verifyRoom.players.length} players)');
          return; // Success!
        }

        // We're not in the room - our update was overwritten by another player
        print('⚠️ SitAndGo: Join attempt $attempt failed (race condition), retrying...');
        await Future.delayed(Duration(milliseconds: 50 + (attempt * 100)));
        continue;
      }
    }

    throw Exception('Failed to join room after $maxRetries attempts');
  }

  /// Leave a room
  Future<void> _leaveRoom(String roomId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final token = await getAuthToken();

    final response = await http.get(
      Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'),
    );

    if (response.statusCode != 200 || response.body == 'null') return;

    final roomData = jsonDecode(response.body) as Map<String, dynamic>;
    final room = GameRoom.fromJson(roomData, roomId);
    final updatedPlayers = room.players.where((p) => p.uid != userId).toList();

    if (updatedPlayers.isEmpty) {
      // Delete empty room
      await http.delete(Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'));
    } else {
      // Update room with remaining players
      final newHostId = room.hostId == userId ? updatedPlayers.first.uid : room.hostId;
      await http.patch(
        Uri.parse('$databaseUrl/game_rooms/$roomId.json?auth=$token'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'players': updatedPlayers.map((p) => p.toJson()).toList(),
          'hostId': newHostId,
          'lastActivityAt': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    }
  }
}
