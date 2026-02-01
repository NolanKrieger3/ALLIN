import 'dart:async';
import '../models/game_room.dart';
import 'room_service.dart';
import 'game_action_service.dart';
import 'game_flow_service.dart';
import 'bot_service.dart';

// Re-export GamePhase for backward compatibility
export 'game_action_service.dart' show GamePhase;

/// Service for managing multiplayer poker games via Firebase Realtime Database REST API
/// This is a facade that delegates to specialized services for better code organization
class GameService {
  final RoomService _roomService = RoomService();
  final GameActionService _actionService = GameActionService();
  final GameFlowService _flowService = GameFlowService();
  final BotService _botService = BotService();

  /// Get current user ID
  String? get currentUserId => _roomService.currentUserId;

  /// Get current user display name
  String get currentUserName => _roomService.currentUserName;

  // ============================================================================
  // ROOM MANAGEMENT (delegated to RoomService)
  // ============================================================================

  /// Create a new game room
  Future<GameRoom> createRoom({
    int bigBlind = 100,
    int startingChips = 1000,
    bool isPrivate = false,
    String gameType = 'cash',
    int maxPlayers = 2,
  }) =>
      _roomService.createRoom(
        bigBlind: bigBlind,
        startingChips: startingChips,
        isPrivate: isPrivate,
        gameType: gameType,
        maxPlayers: maxPlayers,
      );

  /// Create a Sit & Go tournament room
  Future<GameRoom> createSitAndGoRoom({int startingChips = 10000, int bigBlind = 100}) =>
      _roomService.createSitAndGoRoom(startingChips: startingChips, bigBlind: bigBlind);

  /// Join an existing room
  Future<void> joinRoom(String roomId, {int? startingChips}) =>
      _roomService.joinRoom(roomId, startingChips: startingChips);

  /// Leave a room
  Future<void> leaveRoom(String roomId) => _roomService.leaveRoom(roomId);

  /// Toggle ready status
  Future<void> toggleReady(String roomId) => _roomService.toggleReady(roomId);

  /// Send heartbeat to show player is active
  Future<void> sendHeartbeat(String roomId) => _roomService.sendHeartbeat(roomId);

  /// Remove inactive players from room
  Future<void> removeInactivePlayers(String roomId) => _roomService.removeInactivePlayers(roomId);

  /// Watch a room for real-time updates
  Stream<GameRoom?> watchRoom(String roomId) => _roomService.watchRoom(roomId);

  /// Fetch a room by ID
  Future<GameRoom?> fetchRoom(String roomId) => _roomService.fetchRoom(roomId);

  /// Fetch all available cash game rooms
  Future<List<GameRoom>> fetchAvailableCashRooms() => _roomService.fetchAvailableCashRooms();

  /// Fetch all available Sit & Go rooms
  Future<List<GameRoom>> fetchAvailableSitAndGoRooms() => _roomService.fetchAvailableSitAndGoRoomsNow();

  /// Fetch joinable rooms by blind level
  Future<List<GameRoom>> fetchJoinableRoomsByBlind(
    int bigBlind, {
    String gameType = 'cash',
    int? maxPlayers,
  }) =>
      _roomService.fetchJoinableRoomsByBlind(bigBlind, gameType: gameType, maxPlayers: maxPlayers);

  /// Check if all rooms for a given blind level are full
  Future<bool> areAllRoomsFull(int bigBlind, String gameType) => _roomService.areAllRoomsFull(bigBlind, gameType);

  /// Cleanup stale/abandoned rooms
  Future<void> cleanupStaleRooms() => _roomService.cleanupStaleRooms();

  /// Delete all game rooms (admin function)
  Future<void> deleteAllRooms() => _roomService.deleteAllRooms();

  // ============================================================================
  // GAME FLOW (delegated to GameFlowService)
  // ============================================================================

  /// Start a game in the specified room
  Future<void> startGame(String roomId, {bool skipReadyCheck = false}) async {
    if (!skipReadyCheck) {
      final room = await _roomService.fetchRoom(roomId);
      if (room == null) throw Exception('Room not found');
      if (!room.players.every((p) => p.isReady || _botService.isBot(p.uid))) {
        throw Exception('Not all players are ready');
      }
    }
    await _flowService.startGame(roomId);
  }

  /// Start game for solo play (with bots)
  Future<void> startGameSolo(String roomId) async {
    final room = await _roomService.fetchRoom(roomId);
    if (room == null) throw Exception('Room not found');

    // Add bots to fill the room if needed
    await _botService.fillRoomWithBots(roomId);

    // Start the game
    await _flowService.startGame(roomId);
  }

  /// Start game from waiting phase (when enough players have joined)
  Future<void> startGameFromWaiting(String roomId) async {
    final room = await _roomService.fetchRoom(roomId);
    if (room == null) throw Exception('Room not found');
    if (room.status != 'waiting' && room.phase != 'waiting_for_players') {
      throw Exception('Game not in waiting state');
    }
    await _flowService.startGame(roomId);
  }

  /// Start a new hand after showdown
  Future<void> newHand(String roomId) => _flowService.newHand(roomId);

  /// Handle turn timeout (auto-fold)
  Future<void> handleTurnTimeout(String roomId) => _flowService.handleTurnTimeout(roomId);

  /// Update turn start time
  Future<void> updateTurnStartTime(String roomId) => _flowService.updateTurnStartTime(roomId);

  /// Update game status
  Future<void> updateGameStatus(String roomId, String status) => _flowService.updateGameStatus(roomId, status);

  /// Update tournament blind state
  Future<void> updateTournamentState(
    String roomId, {
    required int currentBlindLevel,
    required int smallBlind,
    required int bigBlind,
    required DateTime lastBlindIncreaseTime,
  }) =>
      _flowService.updateTournamentState(
        roomId,
        currentBlindLevel: currentBlindLevel,
        smallBlind: smallBlind,
        bigBlind: bigBlind,
        lastBlindIncreaseTime: lastBlindIncreaseTime,
      );

  // ============================================================================
  // PLAYER ACTIONS (delegated to GameActionService)
  // ============================================================================

  /// Player action (fold, check, call, raise, allin)
  Future<void> playerAction(String roomId, String action, {int? raiseAmount}) =>
      _actionService.playerAction(roomId, action, raiseAmount: raiseAmount);

  /// Bot action (for host controlling bots)
  Future<void> botAction(String roomId, String botId, String action, {int? raiseAmount}) =>
      _actionService.botAction(roomId, botId, action, raiseAmount: raiseAmount);

  // ============================================================================
  // BOT MANAGEMENT (delegated to BotService)
  // ============================================================================

  /// Check if a player ID belongs to a bot
  bool isBot(String playerId) => _botService.isBot(playerId);

  /// Add bots to fill a room
  Future<void> fillRoomWithBots(String roomId) => _botService.fillRoomWithBots(roomId);

  /// Add a specific number of bots to a room
  Future<void> addBotsToRoom(String roomId, int numberOfBots) => _botService.addBotsToRoom(roomId, numberOfBots);
}
