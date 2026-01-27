/// Friend model for the friends system
class Friend {
  final String id;
  final String username;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastOnline;
  final String? currentGame; // Room code if in a game
  final int rank;
  final int chips;

  Friend({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.isOnline = false,
    this.lastOnline,
    this.currentGame,
    this.rank = 0,
    this.chips = 0,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
      lastOnline: json['lastOnline'] != null 
          ? DateTime.parse(json['lastOnline'] as String) 
          : null,
      currentGame: json['currentGame'] as String?,
      rank: json['rank'] as int? ?? 0,
      chips: json['chips'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatarUrl': avatarUrl,
      'isOnline': isOnline,
      'lastOnline': lastOnline?.toIso8601String(),
      'currentGame': currentGame,
      'rank': rank,
      'chips': chips,
    };
  }
}

/// Friend request model
class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromUsername;
  final String? fromAvatarUrl;
  final String toUserId;
  final DateTime createdAt;
  final FriendRequestStatus status;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    this.fromAvatarUrl,
    required this.toUserId,
    required this.createdAt,
    this.status = FriendRequestStatus.pending,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as String,
      fromUserId: json['fromUserId'] as String,
      fromUsername: json['fromUsername'] as String,
      fromAvatarUrl: json['fromAvatarUrl'] as String?,
      toUserId: json['toUserId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => FriendRequestStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'fromAvatarUrl': fromAvatarUrl,
      'toUserId': toUserId,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
    };
  }
}

enum FriendRequestStatus {
  pending,
  accepted,
  declined,
}

/// Game invite model
class GameInvite {
  final String id;
  final String fromUserId;
  final String fromUsername;
  final String roomCode;
  final String gameType; // 'headsUp', 'sitAndGo', etc.
  final String stakeName;
  final DateTime createdAt;
  final DateTime expiresAt;
  final GameInviteStatus status;

  GameInvite({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.roomCode,
    required this.gameType,
    required this.stakeName,
    required this.createdAt,
    required this.expiresAt,
    this.status = GameInviteStatus.pending,
  });

  factory GameInvite.fromJson(Map<String, dynamic> json) {
    return GameInvite(
      id: json['id'] as String,
      fromUserId: json['fromUserId'] as String,
      fromUsername: json['fromUsername'] as String,
      roomCode: json['roomCode'] as String,
      gameType: json['gameType'] as String,
      stakeName: json['stakeName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      status: GameInviteStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => GameInviteStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'roomCode': roomCode,
      'gameType': gameType,
      'stakeName': stakeName,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'status': status.name,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

enum GameInviteStatus {
  pending,
  accepted,
  declined,
  expired,
}

/// Notification model for the notification panel
class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.general,
      ),
      title: json['title'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'data': data,
    };
  }
}

enum NotificationType {
  friendRequest,
  friendAccepted,
  gameInvite,
  challengeReceived,
  giftReceived,
  rankUp,
  general,
}
