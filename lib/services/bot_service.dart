import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_room.dart';

/// Service for managing bot players in poker games
class BotService {
  static const String _databaseUrl = 'https://allin-d0e2d-default-rtdb.firebaseio.com';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Bot names for variety
  static const botNames = [
    'RoboBluff',
    'ChipBot',
    'AceAI',
    'PokerDroid',
    'CardShark',
    'BetBot',
    'FoldMaster',
    'AllInAI',
    'RiverBot',
    'FlopKing',
    'TurnPro',
    'BlindRaider'
  ];

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Get auth token for authenticated requests
  Future<String?> _getAuthToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  /// Check if a player is a bot
  bool isBot(String playerId) {
    return playerId.startsWith('bot_');
  }

  /// Fill a room with bot players for testing
  /// Adds bots until the room is full
  Future<void> fillRoomWithBots(String roomId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in');

    final token = await _getAuthToken();

    // Get current room data
    final response = await http.get(Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'));
    if (response.statusCode != 200 || response.body == 'null') {
      throw Exception('Room not found');
    }

    final roomData = jsonDecode(response.body) as Map<String, dynamic>;
    final room = GameRoom.fromJson(roomData, roomId);

    // Only host can add bots
    if (room.hostId != userId) {
      throw Exception('Only the host can add bots');
    }

    final random = Random();
    final existingCount = room.players.length;
    final botsNeeded = room.maxPlayers - existingCount;

    if (botsNeeded <= 0) return; // Room already full

    // Get starting chips from first player (should be the host)
    final startingChips = room.players.isNotEmpty ? room.players.first.chips : 1500;

    // Create bot players
    final newPlayers = <GamePlayer>[...room.players];
    final usedNames = room.players.map((p) => p.displayName).toSet();

    for (int i = 0; i < botsNeeded; i++) {
      // Pick a unique bot name
      String botName;
      int attempts = 0;
      do {
        botName = botNames[random.nextInt(botNames.length)];
        if (usedNames.contains(botName)) {
          botName = '$botName${random.nextInt(99) + 1}';
        }
        attempts++;
      } while (usedNames.contains(botName) && attempts < 20);

      usedNames.add(botName);

      // Generate a unique bot ID
      final botId = 'bot_${DateTime.now().millisecondsSinceEpoch}_$i';

      newPlayers.add(GamePlayer(
        uid: botId,
        displayName: botName,
        chips: startingChips,
        isReady: true,
        lastActiveAt: DateTime.now(),
      ));
    }

    // Update room with bots
    await http.patch(
      Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({'players': newPlayers.map((p) => p.toJson()).toList()}),
    );

    print('🤖 Added $botsNeeded bots to room $roomId');
  }

  /// Add a specific number of bots to a room
  Future<void> addBotsToRoom(String roomId, int count) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in');

    final token = await _getAuthToken();

    // Get current room data
    final response = await http.get(Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'));
    if (response.statusCode != 200 || response.body == 'null') {
      throw Exception('Room not found');
    }

    final roomData = jsonDecode(response.body) as Map<String, dynamic>;
    final room = GameRoom.fromJson(roomData, roomId);

    // Only host can add bots
    if (room.hostId != userId) {
      throw Exception('Only the host can add bots');
    }

    final random = Random();
    final existingCount = room.players.length;
    final maxBotsToAdd = room.maxPlayers - existingCount;
    final botsToAdd = count.clamp(0, maxBotsToAdd);

    if (botsToAdd <= 0) return; // Room already full

    // Get starting chips from first player (should be the host)
    final startingChips = room.players.isNotEmpty ? room.players.first.chips : 1500;

    // Create bot players
    final newPlayers = <GamePlayer>[...room.players];
    final usedNames = room.players.map((p) => p.displayName).toSet();

    for (int i = 0; i < botsToAdd; i++) {
      // Pick a unique bot name
      String botName;
      int attempts = 0;
      do {
        botName = botNames[random.nextInt(botNames.length)];
        if (usedNames.contains(botName)) {
          botName = '$botName${random.nextInt(99) + 1}';
        }
        attempts++;
      } while (usedNames.contains(botName) && attempts < 20);

      usedNames.add(botName);

      // Generate a unique bot ID
      final botId = 'bot_${DateTime.now().millisecondsSinceEpoch}_$i';

      newPlayers.add(GamePlayer(
        uid: botId,
        displayName: botName,
        chips: startingChips,
        isReady: true,
        lastActiveAt: DateTime.now(),
      ));
    }

    // Update room with bots
    await http.patch(
      Uri.parse('$_databaseUrl/game_rooms/$roomId.json?auth=$token'),
      body: jsonEncode({'players': newPlayers.map((p) => p.toJson()).toList()}),
    );

    print('🤖 Added $botsToAdd bots to room $roomId');
  }
}
