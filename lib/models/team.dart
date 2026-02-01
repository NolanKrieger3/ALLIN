import 'dart:ui' show Color;

/// Team member with their rank
class TeamMember {
  final String uid;
  final String displayName;
  final String rank; // 'captain', 'officer', 'member'
  final DateTime joinedAt;
  final int totalWinnings; // Track contributions

  TeamMember({
    required this.uid,
    required this.displayName,
    this.rank = 'member',
    required this.joinedAt,
    this.totalWinnings = 0,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'rank': rank,
        'joinedAt': joinedAt.millisecondsSinceEpoch,
        'totalWinnings': totalWinnings,
      };

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String,
      rank: json['rank'] as String? ?? 'member',
      joinedAt: DateTime.fromMillisecondsSinceEpoch(json['joinedAt'] as int? ?? 0),
      totalWinnings: json['totalWinnings'] as int? ?? 0,
    );
  }

  TeamMember copyWith({
    String? uid,
    String? displayName,
    String? rank,
    DateTime? joinedAt,
    int? totalWinnings,
  }) {
    return TeamMember(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      rank: rank ?? this.rank,
      joinedAt: joinedAt ?? this.joinedAt,
      totalWinnings: totalWinnings ?? this.totalWinnings,
    );
  }

  /// Get rank display icon
  String get rankIcon {
    switch (rank) {
      case 'captain':
        return '👑';
      case 'officer':
        return '⭐';
      default:
        return '';
    }
  }

  /// Get rank display name
  String get rankDisplayName {
    switch (rank) {
      case 'captain':
        return 'Captain';
      case 'officer':
        return 'Officer';
      default:
        return 'Member';
    }
  }
}

/// Chat message in team chat
class TeamChatMessage {
  final String id;
  final String senderUid;
  final String senderName;
  final String message;
  final DateTime timestamp;

  TeamChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderUid': senderUid,
        'senderName': senderName,
        'message': message,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory TeamChatMessage.fromJson(Map<String, dynamic> json) {
    return TeamChatMessage(
      id: json['id'] as String,
      senderUid: json['senderUid'] as String,
      senderName: json['senderName'] as String,
      message: json['message'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int? ?? 0),
    );
  }
}

/// Team invite model
class TeamInvite {
  final String id;
  final String teamId;
  final String teamName;
  final String teamEmblem;
  final String fromUserId;
  final String fromUsername;
  final String toUserId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final TeamInviteStatus status;

  TeamInvite({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.teamEmblem,
    required this.fromUserId,
    required this.fromUsername,
    required this.toUserId,
    required this.createdAt,
    required this.expiresAt,
    this.status = TeamInviteStatus.pending,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'teamId': teamId,
        'teamName': teamName,
        'teamEmblem': teamEmblem,
        'fromUserId': fromUserId,
        'fromUsername': fromUsername,
        'toUserId': toUserId,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'status': status.name,
      };

  factory TeamInvite.fromJson(Map<String, dynamic> json) {
    return TeamInvite(
      id: json['id'] as String,
      teamId: json['teamId'] as String,
      teamName: json['teamName'] as String,
      teamEmblem: json['teamEmblem'] as String? ?? '🃏',
      fromUserId: json['fromUserId'] as String,
      fromUsername: json['fromUsername'] as String,
      toUserId: json['toUserId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      status: TeamInviteStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TeamInviteStatus.pending,
      ),
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

enum TeamInviteStatus {
  pending,
  accepted,
  declined,
  expired,
}

/// Team emblems (index-based for simplicity)
class TeamEmblem {
  static const List<String> emblems = [
    '🃏', // Joker - red
    '♠️', // Spade - purple
    '♥️', // Heart - red
    '♦️', // Diamond - red
    '♣️', // Club - purple
    '🎰', // Slot machine
    '🎲', // Dice
    '🏆', // Trophy
    '👑', // Crown
    '🔥', // Fire
    '⚡', // Lightning
    '🌟', // Star
    '🦁', // Lion
    '🐺', // Wolf
    '🦅', // Eagle
    '🐉', // Dragon
    '💎', // Gem
    '🎯', // Target
    '⚔️', // Swords
    '🛡️', // Shield
  ];

  // Indices that should be red (joker, heart, diamond)
  static const List<int> _redIndices = [0, 2, 3];
  // Indices that should be purple (spade, club)
  static const List<int> _purpleIndices = [1, 4];

  static String getEmblem(int index) {
    if (index < 0 || index >= emblems.length) return emblems[0];
    return emblems[index];
  }

  /// Returns the color for the emblem at the given index
  /// Red for joker, hearts, diamonds; Purple for spades, clubs; null for others
  static Color? getEmblemColor(int index) {
    if (_redIndices.contains(index)) {
      return const Color(0xFFE53935); // Red
    } else if (_purpleIndices.contains(index)) {
      return const Color(0xFF9C27B0); // Purple
    }
    return null; // Default - no color override
  }
}

/// Represents a team
class Team {
  final String id;
  final String name;
  final String description;
  final int emblemIndex;
  final String captainId;
  final List<TeamMember> members;
  final DateTime createdAt;
  final int maxMembers;
  final bool isOpen;

  Team({
    required this.id,
    required this.name,
    this.description = '',
    this.emblemIndex = 0,
    required this.captainId,
    required this.members,
    required this.createdAt,
    this.maxMembers = 50,
    this.isOpen = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'emblemIndex': emblemIndex,
        'captainId': captainId,
        'members': members.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.millisecondsSinceEpoch,
        'maxMembers': maxMembers,
        'isOpen': isOpen,
      };

  factory Team.fromJson(Map<String, dynamic> json, String docId) {
    return Team(
      id: docId,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      emblemIndex: json['emblemIndex'] as int? ?? 0,
      captainId: json['captainId'] as String,
      members: (json['members'] as List<dynamic>?)
              ?.map((m) => TeamMember.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList() ??
          [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int? ?? 0),
      maxMembers: json['maxMembers'] as int? ?? 50,
      isOpen: json['isOpen'] as bool? ?? true,
    );
  }

  Team copyWith({
    String? id,
    String? name,
    String? description,
    int? emblemIndex,
    String? captainId,
    List<TeamMember>? members,
    DateTime? createdAt,
    int? maxMembers,
    bool? isOpen,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      emblemIndex: emblemIndex ?? this.emblemIndex,
      captainId: captainId ?? this.captainId,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
      maxMembers: maxMembers ?? this.maxMembers,
      isOpen: isOpen ?? this.isOpen,
    );
  }

  /// Get the team emblem
  String get emblem => TeamEmblem.getEmblem(emblemIndex);

  /// Check if team is full
  bool get isFull => members.length >= maxMembers;

  /// Get member count
  int get memberCount => members.length;

  /// Get total team winnings
  int get totalWinnings => members.fold(0, (sum, m) => sum + m.totalWinnings);

  /// Check if user is captain
  bool isCaptain(String userId) => captainId == userId;

  /// Check if user is officer or captain
  bool isOfficer(String userId) {
    final member = members.firstWhere((m) => m.uid == userId,
        orElse: () => TeamMember(uid: '', displayName: '', joinedAt: DateTime.now()));
    return member.rank == 'officer' || member.rank == 'captain';
  }

  /// Check if user is member
  bool isMember(String userId) => members.any((m) => m.uid == userId);

  /// Get sorted members (captain first, then officers, then by winnings)
  List<TeamMember> get sortedMembers {
    final sorted = List<TeamMember>.from(members);
    sorted.sort((a, b) {
      // Captain first
      if (a.rank == 'captain') return -1;
      if (b.rank == 'captain') return 1;
      // Officers second
      if (a.rank == 'officer' && b.rank != 'officer') return -1;
      if (b.rank == 'officer' && a.rank != 'officer') return 1;
      // Then by winnings
      return b.totalWinnings.compareTo(a.totalWinnings);
    });
    return sorted;
  }
}
