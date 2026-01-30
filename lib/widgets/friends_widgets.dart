import 'package:flutter/material.dart';
import 'dart:async';
import '../models/friend.dart';
import '../services/friends_service.dart';

/// Notification Panel Widget
class NotificationPanel extends StatefulWidget {
  final VoidCallback onClose;

  const NotificationPanel({super.key, required this.onClose});

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel> {
  final FriendsService _friendsService = FriendsService();
  List<AppNotification> _notifications = [];
  List<FriendRequest> _friendRequests = [];
  List<GameInvite> _gameInvites = [];
  StreamSubscription? _notificationsSub;
  StreamSubscription? _requestsSub;
  StreamSubscription? _invitesSub;
  int _selectedTab = 0; // 0: All, 1: Friend Requests, 2: Game Invites

  @override
  void initState() {
    super.initState();
    _notificationsSub = _friendsService.notificationsStream.listen((notifications) {
      if (mounted) setState(() => _notifications = notifications);
    });
    _requestsSub = _friendsService.friendRequestsStream.listen((requests) {
      if (mounted) setState(() => _friendRequests = requests);
    });
    _invitesSub = _friendsService.gameInvitesStream.listen((invites) {
      if (mounted) setState(() => _gameInvites = invites);
    });
  }

  @override
  void dispose() {
    _notificationsSub?.cancel();
    _requestsSub?.cancel();
    _invitesSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    if (_notifications.any((n) => !n.isRead))
                      TextButton(
                        onPressed: () => _friendsService.markAllNotificationsRead(),
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(color: Color(0xFFD4AF37)),
                        ),
                      ),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close, color: Colors.white54),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildTab(0, 'All', _notifications.where((n) => !n.isRead).length),
                const SizedBox(width: 8),
                _buildTab(1, 'Friends', _friendRequests.length),
                const SizedBox(width: 8),
                _buildTab(2, 'Invites', _gameInvites.length),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Content
          Flexible(
            child: _selectedTab == 0
                ? _buildAllNotifications()
                : _selectedTab == 1
                    ? _buildFriendRequests()
                    : _buildGameInvites(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, int count) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5)) : null,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFD4AF37) : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAllNotifications() {
    if (_notifications.isEmpty) {
      return _buildEmptyState('No notifications', Icons.notifications_off_outlined);
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationItem(notification);
      },
    );
  }

  Widget _buildNotificationItem(AppNotification notification) {
    IconData icon;
    Color iconColor;

    switch (notification.type) {
      case NotificationType.friendRequest:
        icon = Icons.person_add;
        iconColor = const Color(0xFF2196F3);
        break;
      case NotificationType.friendAccepted:
        icon = Icons.people;
        iconColor = const Color(0xFF4CAF50);
        break;
      case NotificationType.gameInvite:
        icon = Icons.sports_esports;
        iconColor = const Color(0xFFFF9800);
        break;
      case NotificationType.challengeReceived:
        icon = Icons.flash_on;
        iconColor = const Color(0xFFE91E63);
        break;
      case NotificationType.giftReceived:
        icon = Icons.card_giftcard;
        iconColor = const Color(0xFF9C27B0);
        break;
      case NotificationType.rankUp:
        icon = Icons.trending_up;
        iconColor = const Color(0xFFD4AF37);
        break;
      case NotificationType.general:
        icon = Icons.info;
        iconColor = Colors.white54;
        break;
    }

    return GestureDetector(
      onTap: () {
        if (!notification.isRead) {
          _friendsService.markNotificationRead(notification.id);
        }
        _handleNotificationTap(notification);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: notification.isRead ? null : Border.all(color: iconColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.message,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(notification.createdAt),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _friendsService.deleteNotification(notification.id),
              icon: Icon(
                Icons.close,
                color: Colors.white.withValues(alpha: 0.3),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendRequests() {
    if (_friendRequests.isEmpty) {
      return _buildEmptyState('No friend requests', Icons.person_add_disabled);
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _friendRequests.length,
      itemBuilder: (context, index) {
        final request = _friendRequests[index];
        return _buildFriendRequestItem(request);
      },
    );
  }

  Widget _buildFriendRequestItem(FriendRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                request.fromUsername.isNotEmpty ? request.fromUsername[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.fromUsername,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Wants to be your friend',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  await _friendsService.acceptFriendRequest(request.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('You are now friends with ${request.fromUsername}!'),
                        backgroundColor: const Color(0xFF4CAF50),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _friendsService.declineFriendRequest(request.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Decline',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameInvites() {
    if (_gameInvites.isEmpty) {
      return _buildEmptyState('No game invites', Icons.sports_esports_outlined);
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _gameInvites.length,
      itemBuilder: (context, index) {
        final invite = _gameInvites[index];
        return _buildGameInviteItem(invite);
      },
    );
  }

  Widget _buildGameInviteItem(GameInvite invite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.sports_esports, color: Color(0xFFFF9800), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${invite.fromUsername} invited you',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${invite.stakeName} ${invite.gameType}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Room: ${invite.roomCode}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final acceptedInvite = await _friendsService.acceptGameInvite(invite.id);
                    if (acceptedInvite != null && mounted) {
                      widget.onClose();
                      // Navigate to the game - caller should handle this
                      Navigator.of(context).pop(acceptedInvite);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'Join Game',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _friendsService.declineGameInvite(invite.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Decline',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNotificationTap(AppNotification notification) {
    switch (notification.type) {
      case NotificationType.friendRequest:
        setState(() => _selectedTab = 1);
        break;
      case NotificationType.gameInvite:
        setState(() => _selectedTab = 2);
        break;
      default:
        break;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.month}/${dateTime.day}';
  }
}

/// Add Friend Dialog
class AddFriendDialog extends StatefulWidget {
  const AddFriendDialog({super.key});

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  final FriendsService _friendsService = FriendsService();
  final TextEditingController _searchController = TextEditingController();
  List<Friend> _searchResults = [];
  bool _isSearching = false;
  final Set<String> _pendingRequests = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    final results = await _friendsService.searchUsers(query);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: 380,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Friend',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _search(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by username...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Results
            Flexible(
              child: _isSearching
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                      ),
                    )
                  : _searchResults.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Text(
                              _searchController.text.isEmpty ? 'Enter a username to search' : 'No players found',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            final isPending = _pendingRequests.contains(user.id);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        user.username[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.username,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: user.isOnline ? const Color(0xFF4CAF50) : Colors.grey,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              user.isOnline ? 'Online' : 'Offline',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.5),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: isPending
                                        ? null
                                        : () async {
                                            setState(() => _pendingRequests.add(user.id));
                                            final success = await _friendsService.sendFriendRequest(user.id);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    success
                                                        ? 'Friend request sent to ${user.username}!'
                                                        : 'Could not send request',
                                                  ),
                                                  backgroundColor:
                                                      success ? const Color(0xFF4CAF50) : const Color(0xFFFF4444),
                                                ),
                                              );
                                            }
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color:
                                            isPending ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF2196F3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isPending ? 'Sent' : 'Add',
                                        style: TextStyle(
                                          color: isPending ? Colors.white54 : Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Friends List Dialog (for viewing all friends and inviting to games)
class FriendsListDialog extends StatefulWidget {
  final String? roomCode;
  final String? gameType;
  final String? stakeName;

  const FriendsListDialog({
    super.key,
    this.roomCode,
    this.gameType,
    this.stakeName,
  });

  @override
  State<FriendsListDialog> createState() => _FriendsListDialogState();
}

class _FriendsListDialogState extends State<FriendsListDialog> {
  final FriendsService _friendsService = FriendsService();
  List<Friend> _friends = [];
  bool _isLoading = true;
  final Set<String> _invitedFriends = {};

  bool get _isInviteMode => widget.roomCode != null;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final friends = await _friendsService.getAllFriends();
    if (mounted) {
      setState(() {
        _friends = friends;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: 380,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isInviteMode ? 'Invite Friends' : 'Friends',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
                ],
              ),
            ),

            // Friends list
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                      ),
                    )
                  : _friends.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline, color: Colors.white.withValues(alpha: 0.3), size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  'No friends yet',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    showDialog(
                                      context: context,
                                      builder: (context) => const AddFriendDialog(),
                                    );
                                  },
                                  child: const Text(
                                    'Add Friends',
                                    style: TextStyle(color: Color(0xFFD4AF37)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: _friends.length,
                          itemBuilder: (context, index) {
                            final friend = _friends[index];
                            return _buildFriendItem(friend);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendItem(Friend friend) {
    final isInvited = _invitedFriends.contains(friend.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    friend.username[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (friend.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  friend.isOnline ? (friend.currentGame != null ? 'In Game' : 'Online') : 'Offline',
                  style: TextStyle(
                    color: friend.isOnline ? const Color(0xFF4CAF50) : Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_isInviteMode) ...[
            GestureDetector(
              onTap: isInvited || !friend.isOnline
                  ? null
                  : () async {
                      setState(() => _invitedFriends.add(friend.id));
                      await _friendsService.sendGameInvite(
                        toUserId: friend.id,
                        roomCode: widget.roomCode!,
                        gameType: widget.gameType ?? 'Cash Game',
                        stakeName: widget.stakeName ?? 'Bronze',
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Invite sent to ${friend.username}!'),
                            backgroundColor: const Color(0xFF4CAF50),
                          ),
                        );
                      }
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isInvited
                      ? Colors.white.withValues(alpha: 0.1)
                      : friend.isOnline
                          ? const Color(0xFF4CAF50)
                          : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isInvited ? 'Invited' : 'Invite',
                  style: TextStyle(
                    color: isInvited || !friend.isOnline ? Colors.white54 : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ] else ...[
            if (friend.currentGame != null && friend.isOnline)
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop(friend.currentGame);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Spectate',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white.withValues(alpha: 0.5)),
              color: const Color(0xFF2A2A2A),
              onSelected: (value) async {
                switch (value) {
                  case 'remove':
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1A1A1A),
                        title: const Text('Remove Friend', style: TextStyle(color: Colors.white)),
                        content: Text(
                          'Are you sure you want to remove ${friend.username} from your friends?',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Remove', style: TextStyle(color: Color(0xFFFF4444))),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _friendsService.removeFriend(friend.id);
                      _loadFriends();
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove, color: Color(0xFFFF4444), size: 20),
                      SizedBox(width: 8),
                      Text('Remove Friend', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
