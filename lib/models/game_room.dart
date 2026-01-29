/// Represents a playing card
class PlayingCard {
  final String rank;
  final String suit;

  PlayingCard({required this.rank, required this.suit});

  Map<String, dynamic> toJson() => {'rank': rank, 'suit': suit};

  factory PlayingCard.fromJson(Map<String, dynamic> json) {
    return PlayingCard(
      rank: json['rank'] as String,
      suit: json['suit'] as String,
    );
  }

  @override
  String toString() => '$rank$suit';
}

/// Represents a player in the game
class GamePlayer {
  final String uid;
  final String displayName;
  final int chips;
  final List<PlayingCard> cards;
  final bool hasFolded;
  final int currentBet;
  final int totalContributed; // Cumulative contribution to pot this hand (for side pots)
  final bool isReady;
  final bool hasActed; // Track if player has acted in current betting round
  final String? lastAction; // Track last action for UI indicator (CALL, CHECK, FOLD, RAISE, ALL-IN)
  final DateTime? lastActiveAt; // Heartbeat timestamp for detecting disconnected players

  GamePlayer({
    required this.uid,
    required this.displayName,
    required this.chips,
    this.cards = const [],
    this.hasFolded = false,
    this.currentBet = 0,
    this.totalContributed = 0,
    this.isReady = false,
    this.hasActed = false,
    this.lastAction,
    this.lastActiveAt,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'chips': chips,
        'cards': cards.map((c) => c.toJson()).toList(),
        'hasFolded': hasFolded,
        'currentBet': currentBet,
        'totalContributed': totalContributed,
        'isReady': isReady,
        'hasActed': hasActed,
        'lastAction': lastAction,
        'lastActiveAt': lastActiveAt?.toIso8601String(),
      };

  factory GamePlayer.fromJson(Map<String, dynamic> json) {
    return GamePlayer(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String,
      chips: json['chips'] as int,
      cards:
          (json['cards'] as List<dynamic>?)?.map((c) => PlayingCard.fromJson(c as Map<String, dynamic>)).toList() ?? [],
      hasFolded: json['hasFolded'] as bool? ?? false,
      currentBet: json['currentBet'] as int? ?? 0,
      totalContributed: json['totalContributed'] as int? ?? 0,
      isReady: json['isReady'] as bool? ?? false,
      hasActed: json['hasActed'] as bool? ?? false,
      lastAction: json['lastAction'] as String?,
      lastActiveAt: json['lastActiveAt'] != null ? DateTime.tryParse(json['lastActiveAt'] as String) : null,
    );
  }

  /// Check if player is considered inactive (no heartbeat for 30+ seconds)
  bool get isInactive {
    if (lastActiveAt == null) return true; // No heartbeat ever = inactive
    return DateTime.now().difference(lastActiveAt!).inSeconds > 30;
  }

  GamePlayer copyWith({
    String? uid,
    String? displayName,
    int? chips,
    List<PlayingCard>? cards,
    bool? hasFolded,
    int? currentBet,
    int? totalContributed,
    bool? isReady,
    bool? hasActed,
    Object? lastAction = _sentinel,
    Object? lastActiveAt = _sentinel,
  }) {
    return GamePlayer(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      chips: chips ?? this.chips,
      cards: cards ?? this.cards,
      hasFolded: hasFolded ?? this.hasFolded,
      currentBet: currentBet ?? this.currentBet,
      totalContributed: totalContributed ?? this.totalContributed,
      isReady: isReady ?? this.isReady,
      hasActed: hasActed ?? this.hasActed,
      lastAction: lastAction == _sentinel ? this.lastAction : lastAction as String?,
      lastActiveAt: lastActiveAt == _sentinel ? this.lastActiveAt : lastActiveAt as DateTime?,
    );
  }
}

// Sentinel value to distinguish between "not provided" and "explicitly null"
const _sentinel = Object();

/// Represents a game room
class GameRoom {
  final String id;
  final String hostId;
  final List<GamePlayer> players;
  final int maxPlayers;
  final int bigBlind;
  final int smallBlind;
  final String status; // waiting, playing, finished
  final String phase; // preflop, flop, turn, river, showdown
  final int pot;
  final int currentBet;
  final String? currentTurnPlayerId;
  final int dealerIndex;
  final List<PlayingCard> communityCards;
  final List<String> deck; // Stored as strings, decoded when needed
  final DateTime createdAt;
  final String? winnerId;
  final String gameType; // cash, sitandgo, private
  final int lastRaiseAmount; // Track minimum raise amount
  final bool isPrivate; // Whether this is a private room with room code sharing
  final bool bbHasOption; // Big blind's option to raise preflop if no raises
  final String? winningHandName; // Description of the winning hand at showdown
  final int? turnStartTime; // Timestamp when current turn started (for turn timer)
  final int turnTimeLimit; // Seconds allowed per turn (default 30)

  GameRoom({
    required this.id,
    required this.hostId,
    required this.players,
    this.maxPlayers = 2,
    this.bigBlind = 100,
    this.smallBlind = 50,
    this.status = 'waiting',
    this.phase = 'preflop',
    this.pot = 0,
    this.currentBet = 0,
    this.currentTurnPlayerId,
    this.dealerIndex = 0,
    this.communityCards = const [],
    this.deck = const [],
    required this.createdAt,
    this.winnerId,
    this.isPrivate = false,
    this.gameType = 'cash',
    this.lastRaiseAmount = 0,
    this.bbHasOption = true,
    this.winningHandName,
    this.turnStartTime,
    this.turnTimeLimit = 30,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hostId': hostId,
        'players': players.map((p) => p.toJson()).toList(),
        'maxPlayers': maxPlayers,
        'bigBlind': bigBlind,
        'smallBlind': smallBlind,
        'status': status,
        'phase': phase,
        'pot': pot,
        'currentBet': currentBet,
        'currentTurnPlayerId': currentTurnPlayerId,
        'dealerIndex': dealerIndex,
        'communityCards': communityCards.map((c) => c.toJson()).toList(),
        'deck': deck,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'winnerId': winnerId,
        'gameType': gameType,
        'lastRaiseAmount': lastRaiseAmount,
        'isPrivate': isPrivate,
        'bbHasOption': bbHasOption,
        'winningHandName': winningHandName,
        'turnStartTime': turnStartTime,
        'turnTimeLimit': turnTimeLimit,
      };

  factory GameRoom.fromJson(Map<String, dynamic> json, String docId) {
    return GameRoom(
      id: docId,
      hostId: json['hostId'] as String,
      players: (json['players'] as List<dynamic>)
          .map((p) => GamePlayer.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      maxPlayers: json['maxPlayers'] as int? ?? 2,
      bigBlind: json['bigBlind'] as int? ?? 100,
      smallBlind: json['smallBlind'] as int? ?? 50,
      status: json['status'] as String? ?? 'waiting',
      phase: json['phase'] as String? ?? 'preflop',
      pot: json['pot'] as int? ?? 0,
      currentBet: json['currentBet'] as int? ?? 0,
      currentTurnPlayerId: json['currentTurnPlayerId'] as String?,
      dealerIndex: json['dealerIndex'] as int? ?? 0,
      communityCards: (json['communityCards'] as List<dynamic>?)
              ?.map((c) => PlayingCard.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList() ??
          [],
      deck: (json['deck'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int? ?? 0),
      winnerId: json['winnerId'] as String?,
      gameType: json['gameType'] as String? ?? 'cash',
      lastRaiseAmount: json['lastRaiseAmount'] as int? ?? 0,
      isPrivate: json['isPrivate'] as bool? ?? false,
      bbHasOption: json['bbHasOption'] as bool? ?? true,
      winningHandName: json['winningHandName'] as String?,
      turnStartTime: json['turnStartTime'] as int?,
      turnTimeLimit: json['turnTimeLimit'] as int? ?? 30,
    );
  }

  GameRoom copyWith({
    String? id,
    String? hostId,
    List<GamePlayer>? players,
    int? maxPlayers,
    int? bigBlind,
    int? smallBlind,
    String? status,
    String? phase,
    int? pot,
    int? currentBet,
    String? currentTurnPlayerId,
    int? dealerIndex,
    List<PlayingCard>? communityCards,
    List<String>? deck,
    DateTime? createdAt,
    String? winnerId,
    String? gameType,
    int? lastRaiseAmount,
    bool? isPrivate,
    bool? bbHasOption,
    String? winningHandName,
    int? turnStartTime,
    int? turnTimeLimit,
  }) {
    return GameRoom(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      players: players ?? this.players,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      bigBlind: bigBlind ?? this.bigBlind,
      smallBlind: smallBlind ?? this.smallBlind,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      pot: pot ?? this.pot,
      currentBet: currentBet ?? this.currentBet,
      currentTurnPlayerId: currentTurnPlayerId ?? this.currentTurnPlayerId,
      dealerIndex: dealerIndex ?? this.dealerIndex,
      communityCards: communityCards ?? this.communityCards,
      deck: deck ?? this.deck,
      createdAt: createdAt ?? this.createdAt,
      winnerId: winnerId ?? this.winnerId,
      gameType: gameType ?? this.gameType,
      lastRaiseAmount: lastRaiseAmount ?? this.lastRaiseAmount,
      isPrivate: isPrivate ?? this.isPrivate,
      bbHasOption: bbHasOption ?? this.bbHasOption,
      winningHandName: winningHandName ?? this.winningHandName,
      turnStartTime: turnStartTime ?? this.turnStartTime,
      turnTimeLimit: turnTimeLimit ?? this.turnTimeLimit,
    );
  }

  bool get isFull => players.length >= maxPlayers;

  /// Game can start when there are 2+ players and all non-host players are ready
  bool get canStart {
    if (players.length < 2) return false;
    // All players except the host must be ready (host is always considered ready)
    return players.where((p) => p.uid != hostId).every((p) => p.isReady);
  }

  bool get isSitAndGo => gameType == 'sitandgo';
}
