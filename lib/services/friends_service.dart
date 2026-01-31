import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend.dart';

/// Service for managing friends, friend requests, and game invites
class FriendsService {
  static final FriendsService _instance = FriendsService._internal();
  factory FriendsService() => _instance;
  FriendsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream controllers for real-time updates
  final _friendsController = StreamController<List<Friend>>.broadcast();
  final _friendRequestsController = StreamController<List<FriendRequest>>.broadcast();
  final _gameInvitesController = StreamController<List<GameInvite>>.broadcast();
  final _notificationsController = StreamController<List<AppNotification>>.broadcast();

  Stream<List<Friend>> get friendsStream => _friendsController.stream;
  Stream<List<FriendRequest>> get friendRequestsStream => _friendRequestsController.stream;
  Stream<List<GameInvite>> get gameInvitesStream => _gameInvitesController.stream;
  Stream<List<AppNotification>> get notificationsStream => _notificationsController.stream;

  StreamSubscription? _friendsSubscription;
  StreamSubscription? _requestsSubscription;
  StreamSubscription? _invitesSubscription;
  StreamSubscription? _notificationsSubscription;
  Timer? _heartbeatTimer;

  /// Users are considered offline if their lastOnline is older than this
  static const Duration _onlineTimeout = Duration(minutes: 2);

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Initialize listeners for the current user
  void initialize() {
    if (_currentUserId == null) return;

    // Listen to friends list
    _friendsSubscription =
        _firestore.collection('users').doc(_currentUserId).collection('friends').snapshots().listen((snapshot) async {
      final friends = <Friend>[];
      for (final doc in snapshot.docs) {
        final friendData = await _getUserData(doc.id);
        if (friendData != null) {
          friends.add(friendData);
        }
      }
      _friendsController.add(friends);
    });

    // Listen to friend requests (incoming)
    _requestsSubscription = _firestore
        .collection('friendRequests')
        .where('toUserId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      final requests = snapshot.docs.map((doc) => FriendRequest.fromJson({...doc.data(), 'id': doc.id})).toList();
      _friendRequestsController.add(requests);
    });

    // Listen to game invites
    _invitesSubscription = _firestore
        .collection('gameInvites')
        .where('toUserId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      final invites = snapshot.docs
          .map((doc) => GameInvite.fromJson({...doc.data(), 'id': doc.id}))
          .where((invite) => !invite.isExpired)
          .toList();
      _gameInvitesController.add(invites);
    });

    // Listen to notifications
    _notificationsSubscription = _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      final notifications =
          snapshot.docs.map((doc) => AppNotification.fromJson({...doc.data(), 'id': doc.id})).toList();
      _notificationsController.add(notifications);
    });

    // Set user online status and start heartbeat
    _setOnlineStatus(true);
    _startHeartbeat();
  }

  /// Start heartbeat timer to periodically update lastOnline
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Update lastOnline every 30 seconds to keep user marked as online
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateLastOnline();
    });
  }

  /// Update lastOnline timestamp without changing isOnline flag
  Future<void> _updateLastOnline() async {
    if (_currentUserId == null) return;
    try {
      await _firestore.collection('users').doc(_currentUserId).update({
        'lastOnline': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Handle error silently
    }
  }

  /// Check if a user is truly online based on their lastOnline timestamp
  bool _isUserTrulyOnline(bool isOnlineFlag, DateTime? lastOnline) {
    // If not marked as online, definitely offline
    if (!isOnlineFlag) return false;
    // If no lastOnline timestamp, consider offline (stale data)
    if (lastOnline == null) return false;
    // Check if lastOnline is within the timeout period
    return DateTime.now().difference(lastOnline) < _onlineTimeout;
  }

  /// Clean up listeners
  void dispose() {
    _setOnlineStatus(false);
    _heartbeatTimer?.cancel();
    _friendsSubscription?.cancel();
    _requestsSubscription?.cancel();
    _invitesSubscription?.cancel();
    _notificationsSubscription?.cancel();
  }

  /// Get user data by ID
  Future<Friend?> _getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final isOnlineFlag = data['isOnline'] ?? false;
      final lastOnline = data['lastOnline'] != null ? (data['lastOnline'] as Timestamp).toDate() : null;
      // Use smart online check based on lastOnline timestamp
      final isTrulyOnline = _isUserTrulyOnline(isOnlineFlag, lastOnline);

      return Friend(
        id: userId,
        username: data['username'] ?? 'Unknown',
        avatarUrl: data['avatarUrl'],
        isOnline: isTrulyOnline,
        lastOnline: lastOnline,
        currentGame: data['currentGame'],
        rank: data['rank'] ?? 0,
        chips: data['chips'] ?? 10000,
      );
    } catch (e) {
      return null;
    }
  }

  /// Search for users by username
  Future<List<Friend>> searchUsers(String query) async {
    if (query.isEmpty || _currentUserId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('usernameLower', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('usernameLower', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
          .limit(20)
          .get();

      final results = <Friend>[];
      for (final doc in snapshot.docs) {
        if (doc.id != _currentUserId) {
          final data = doc.data();
          final isOnlineFlag = data['isOnline'] ?? false;
          final lastOnline = data['lastOnline'] != null ? (data['lastOnline'] as Timestamp).toDate() : null;
          // Use smart online check based on lastOnline timestamp
          final isTrulyOnline = _isUserTrulyOnline(isOnlineFlag, lastOnline);

          results.add(Friend(
            id: doc.id,
            username: data['username'] ?? 'Unknown',
            avatarUrl: data['avatarUrl'],
            isOnline: isTrulyOnline,
            lastOnline: lastOnline,
            rank: data['rank'] ?? 0,
            chips: data['chips'] ?? 10000,
          ));
        }
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  /// Send a friend request
  Future<bool> sendFriendRequest(String toUserId) async {
    if (_currentUserId == null) return false;

    try {
      // Check if already friends
      final friendDoc =
          await _firestore.collection('users').doc(_currentUserId).collection('friends').doc(toUserId).get();

      if (friendDoc.exists) {
        return false; // Already friends
      }

      // Check if request already sent
      final existingRequest = await _firestore
          .collection('friendRequests')
          .where('fromUserId', isEqualTo: _currentUserId)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        return false; // Request already pending
      }

      // Get current user's username
      final currentUserDoc = await _firestore.collection('users').doc(_currentUserId).get();
      final currentUsername = currentUserDoc.data()?['username'] ?? 'Unknown';

      // Create friend request
      final requestRef = await _firestore.collection('friendRequests').add({
        'fromUserId': _currentUserId,
        'fromUsername': currentUsername,
        'fromAvatarUrl': currentUserDoc.data()?['avatarUrl'],
        'toUserId': toUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Create notification for recipient
      await _createNotification(
        toUserId,
        NotificationType.friendRequest,
        'Friend Request',
        '$currentUsername wants to be your friend!',
        {'requestId': requestRef.id, 'fromUserId': _currentUserId},
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Accept a friend request
  Future<bool> acceptFriendRequest(String requestId) async {
    if (_currentUserId == null) return false;

    try {
      final requestDoc = await _firestore.collection('friendRequests').doc(requestId).get();

      if (!requestDoc.exists) return false;

      final request = FriendRequest.fromJson({
        ...requestDoc.data()!,
        'id': requestId,
      });

      if (request.toUserId != _currentUserId) return false;

      // Update request status
      await _firestore.collection('friendRequests').doc(requestId).update({
        'status': 'accepted',
      });

      // Add to both users' friends lists
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('friends')
          .doc(request.fromUserId)
          .set({'addedAt': FieldValue.serverTimestamp()});

      await _firestore
          .collection('users')
          .doc(request.fromUserId)
          .collection('friends')
          .doc(_currentUserId)
          .set({'addedAt': FieldValue.serverTimestamp()});

      // Get current user's username
      final currentUserDoc = await _firestore.collection('users').doc(_currentUserId).get();
      final currentUsername = currentUserDoc.data()?['username'] ?? 'Unknown';

      // Notify the sender that request was accepted
      await _createNotification(
        request.fromUserId,
        NotificationType.friendAccepted,
        'Friend Request Accepted',
        '$currentUsername accepted your friend request!',
        {'userId': _currentUserId},
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Decline a friend request
  Future<bool> declineFriendRequest(String requestId) async {
    if (_currentUserId == null) return false;

    try {
      await _firestore.collection('friendRequests').doc(requestId).update({
        'status': 'declined',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove a friend
  Future<bool> removeFriend(String friendId) async {
    if (_currentUserId == null) return false;

    try {
      await _firestore.collection('users').doc(_currentUserId).collection('friends').doc(friendId).delete();

      await _firestore.collection('users').doc(friendId).collection('friends').doc(_currentUserId).delete();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Send a game invite to a friend
  Future<bool> sendGameInvite({
    required String toUserId,
    required String roomCode,
    required String gameType,
    required String stakeName,
  }) async {
    if (_currentUserId == null) return false;

    try {
      // Get current user's username
      final currentUserDoc = await _firestore.collection('users').doc(_currentUserId).get();
      final currentUsername = currentUserDoc.data()?['username'] ?? 'Unknown';

      // Create invite (expires in 5 minutes)
      final inviteRef = await _firestore.collection('gameInvites').add({
        'fromUserId': _currentUserId,
        'fromUsername': currentUsername,
        'toUserId': toUserId,
        'roomCode': roomCode,
        'gameType': gameType,
        'stakeName': stakeName,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
        'status': 'pending',
      });

      // Create notification
      await _createNotification(
        toUserId,
        NotificationType.gameInvite,
        'Game Invite',
        '$currentUsername invited you to a $stakeName game!',
        {
          'inviteId': inviteRef.id,
          'roomCode': roomCode,
          'gameType': gameType,
          'stakeName': stakeName,
        },
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Accept a game invite
  Future<GameInvite?> acceptGameInvite(String inviteId) async {
    if (_currentUserId == null) return null;

    try {
      final inviteDoc = await _firestore.collection('gameInvites').doc(inviteId).get();

      if (!inviteDoc.exists) return null;

      final invite = GameInvite.fromJson({
        ...inviteDoc.data()!,
        'id': inviteId,
      });

      if (invite.isExpired) {
        await _firestore.collection('gameInvites').doc(inviteId).update({
          'status': 'expired',
        });
        return null;
      }

      await _firestore.collection('gameInvites').doc(inviteId).update({
        'status': 'accepted',
      });

      return invite;
    } catch (e) {
      return null;
    }
  }

  /// Decline a game invite
  Future<bool> declineGameInvite(String inviteId) async {
    try {
      await _firestore.collection('gameInvites').doc(inviteId).update({
        'status': 'declined',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get friend's current game (if any)
  Future<String?> getFriendCurrentGame(String friendId) async {
    try {
      final doc = await _firestore.collection('users').doc(friendId).get();
      return doc.data()?['currentGame'];
    } catch (e) {
      return null;
    }
  }

  /// Set current user's game status
  Future<void> setCurrentGame(String? roomCode) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('users').doc(_currentUserId).update({
        'currentGame': roomCode,
      });
    } catch (e) {
      // Handle error silently
    }
  }

  /// Create a notification for a user
  Future<void> _createNotification(
    String userId,
    NotificationType type,
    String title,
    String message,
    Map<String, dynamic>? data,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).collection('notifications').add({
        'type': type.name,
        'title': title,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': data,
      });
    } catch (e) {
      // Handle error silently
    }
  }

  /// Mark notification as read
  Future<void> markNotificationRead(String notificationId) async {
    if (_currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      // Handle error silently
    }
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsRead() async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      // Handle error silently
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('users').doc(_currentUserId).collection('notifications').doc(notificationId).delete();
    } catch (e) {
      // Handle error silently
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await _firestore.collection('users').doc(_currentUserId).collection('notifications').get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      // Handle error silently
    }
  }

  /// Set online status
  Future<void> _setOnlineStatus(bool isOnline) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('users').doc(_currentUserId).update({
        'isOnline': isOnline,
        'lastOnline': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Handle error silently
    }
  }

  /// Get unread notification count
  Future<int> getUnreadNotificationCount() async {
    if (_currentUserId == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get pending friend request count
  Future<int> getPendingFriendRequestCount() async {
    if (_currentUserId == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('friendRequests')
          .where('toUserId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get online friends
  Future<List<Friend>> getOnlineFriends() async {
    if (_currentUserId == null) return [];

    try {
      final friendsSnapshot = await _firestore.collection('users').doc(_currentUserId).collection('friends').get();

      final onlineFriends = <Friend>[];
      for (final doc in friendsSnapshot.docs) {
        final friendData = await _getUserData(doc.id);
        if (friendData != null && friendData.isOnline) {
          onlineFriends.add(friendData);
        }
      }
      return onlineFriends;
    } catch (e) {
      return [];
    }
  }

  /// Check if two users are friends
  Future<bool> areFriends(String userId) async {
    if (_currentUserId == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(_currentUserId).collection('friends').doc(userId).get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Get all friends
  Future<List<Friend>> getAllFriends() async {
    if (_currentUserId == null) return [];

    try {
      final friendsSnapshot = await _firestore.collection('users').doc(_currentUserId).collection('friends').get();

      final friends = <Friend>[];
      for (final doc in friendsSnapshot.docs) {
        final friendData = await _getUserData(doc.id);
        if (friendData != null) {
          friends.add(friendData);
        }
      }
      return friends;
    } catch (e) {
      return [];
    }
  }
}
