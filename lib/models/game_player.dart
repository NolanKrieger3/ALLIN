import 'playing_card.dart';

// Sentinel value to distinguish between "not provided" and "explicitly null"
const _sentinel = Object();

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

  /// Check if player is all-in (has chips but all committed)
  bool get isAllIn => chips == 0 && !hasFolded;

  /// Check if player can act (not folded and has chips)
  bool get canAct => !hasFolded && chips > 0;

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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GamePlayer && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}
