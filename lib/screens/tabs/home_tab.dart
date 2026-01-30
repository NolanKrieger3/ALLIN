import 'package:flutter/material.dart';
import 'dart:async';
import '../../widgets/animated_buttons.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/friends_widgets.dart';
import '../../models/friend.dart';
import '../../models/team.dart';
import '../../services/friends_service.dart';
import '../../services/team_service.dart';
import '../../services/user_preferences.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../services/game_service.dart';
import '../game_screen.dart';
import '../lobby_screen.dart';
import '../quick_play_screen.dart';
import '../sit_and_go_screen.dart';
import '../tutorial_screen.dart';
import '../multiplayer_game_screen.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback? onNavigateToShop;

  const HomeTab({super.key, this.onNavigateToShop});

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  bool _clubExpanded = false;
  final FriendsService _friendsService = FriendsService();
  final TeamService _teamService = TeamService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  List<Friend> _friends = [];
  int _unreadNotifications = 0;
  int _pendingFriendRequests = 0;
  int _chipBalance = 1000;
  Team? _userTeam;
  StreamSubscription? _friendsSub;
  StreamSubscription? _notificationsSub;
  StreamSubscription? _requestsSub;
  StreamSubscription? _teamSub;
  StreamSubscription? _authSub;

  // Team chat controller
  final TextEditingController _chatController = TextEditingController();

  // Scroll controller for home tab
  final ScrollController _homeScrollController = ScrollController();
  final GlobalKey _teamSectionKey = GlobalKey();

  // Swipeable play card
  final PageController _playCardController = PageController(initialPage: 0);
  int _currentPlayMode = 0;

  @override
  void initState() {
    super.initState();
    _friendsService.initialize();
    _loadFriendsData();
    _loadChipBalance();
    _loadUserTeam();
    _syncUserDataFromFirestore();

    // Listen to auth state changes to reload team when user is confirmed
    _authSub = _authService.authStateChanges.listen((user) {
      if (user != null) {
        if (_userTeam == null) {
          _loadUserTeam();
        }
        // Sync all user data whenever auth state changes (e.g., sign in)
        _syncUserDataFromFirestore();
      }
    });

    _friendsSub = _friendsService.friendsStream.listen((friends) {
      if (mounted) setState(() => _friends = friends);
    });

    _notificationsSub = _friendsService.notificationsStream.listen((notifications) {
      if (mounted) {
        setState(() => _unreadNotifications = notifications.where((n) => !n.isRead).length);
      }
    });

    _requestsSub = _friendsService.friendRequestsStream.listen((requests) {
      if (mounted) setState(() => _pendingFriendRequests = requests.length);
    });
  }

  /// Sync all user data from Firestore - redirect to setup if no username
  Future<void> _syncUserDataFromFirestore() async {
    try {
      final data = await _userService.syncAllUserData();
      final needsSetup = await _userService.needsUsernameSetup();

      if (mounted && needsSetup) {
        // User doesn't have a username set in Firestore, redirect to setup
        Navigator.of(context).pushReplacementNamed('/username-setup');
      } else if (mounted) {
        // Trigger rebuild to show updated data
        _loadChipBalance();
        setState(() {});
      }
    } catch (e) {
      // If sync fails, continue with local data
    }
  }

  Future<void> _loadUserTeam() async {
    try {
      final team = await _teamService.getUserTeam();
      if (mounted) {
        // Always cancel old subscription first
        _teamSub?.cancel();
        _teamSub = null;

        setState(() => _userTeam = team);

        if (team != null) {
          // Watch for team updates, but verify user is still a member
          _teamSub = _teamService.watchTeam(team.id).listen((updatedTeam) {
            if (mounted) {
              // Check if user is still in the team
              final userId = _teamService.currentUserId;
              if (updatedTeam == null || userId == null || !updatedTeam.isMember(userId)) {
                // User is no longer in this team, clear it
                setState(() => _userTeam = null);
                _teamSub?.cancel();
                _teamSub = null;
              } else {
                setState(() => _userTeam = updatedTeam);
              }
            }
          });
        }
      }
    } catch (e) {
      // Silently fail if team loading fails
    }
  }

  void _loadChipBalance() {
    setState(() => _chipBalance = UserPreferences.chips);
  }

  // Public method to refresh chips from other widgets
  void refreshChips() {
    if (mounted) setState(() {});
  }

  void _showCreateTeamDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    int selectedEmblem = 0;
    bool isOpenTeam = true;
    final canAfford = UserPreferences.chips >= TeamService.createTeamCost;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D46A), Color(0xFF00A855)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create Team',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Cost: 1,000,000 chips',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: canAfford
                            ? const Color(0xFF00D46A).withValues(alpha: 0.15)
                            : const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        UserPreferences.formatChips(UserPreferences.chips),
                        style: TextStyle(
                          color: canAfford ? const Color(0xFF00D46A) : const Color(0xFFEF4444),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                // Team Name Field
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  maxLength: 20,
                  cursorColor: const Color(0xFF00D46A),
                  decoration: InputDecoration(
                    hintText: 'Team Name',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    prefixIcon: Icon(Icons.shield_outlined, color: Colors.white.withValues(alpha: 0.4), size: 20),
                    counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF00D46A), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                // Description Field
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  maxLength: 200,
                  maxLines: 2,
                  cursorColor: const Color(0xFF00D46A),
                  decoration: InputDecoration(
                    hintText: 'Description (optional)',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Icon(Icons.notes_rounded, color: Colors.white.withValues(alpha: 0.4), size: 20),
                    ),
                    counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF00D46A), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 24),
                // Emblem Selection
                Text(
                  'Choose Emblem',
                  style:
                      TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: TeamEmblem.emblems.length,
                    itemBuilder: (context, index) => GestureDetector(
                      onTap: () => setDialogState(() => selectedEmblem = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: selectedEmblem == index
                              ? const Color(0xFF00D46A).withValues(alpha: 0.25)
                              : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedEmblem == index
                                ? const Color(0xFF00D46A)
                                : Colors.white.withValues(alpha: 0.12),
                            width: selectedEmblem == index ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            TeamEmblem.emblems[index],
                            style: TextStyle(
                              fontSize: selectedEmblem == index ? 26 : 22,
                              color: TeamEmblem.getEmblemColor(index),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Team Privacy Toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOpenTeam ? Icons.lock_open_rounded : Icons.lock_rounded,
                        color: isOpenTeam ? const Color(0xFF00D46A) : Colors.white.withValues(alpha: 0.5),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOpenTeam ? 'Open Team' : 'Invite Only',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isOpenTeam ? 'Anyone can join' : 'Only invited players can join',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setDialogState(() => isOpenTeam = !isOpenTeam),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 28,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: isOpenTeam ? const Color(0xFF00D46A) : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 200),
                            alignment: isOpenTeam ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: canAfford
                            ? () async {
                                Navigator.pop(context);
                                await _createTeam(nameController.text, descController.text, selectedEmblem, isOpenTeam);
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: canAfford
                                ? const LinearGradient(
                                    colors: [Color(0xFF00D46A), Color(0xFF00A855)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: canAfford ? null : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              canAfford ? 'Create Team' : 'Not Enough Chips',
                              style: TextStyle(
                                color: canAfford ? Colors.black : Colors.white.withValues(alpha: 0.4),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createTeam(String name, String desc, int emblem, bool isOpen) async {
    try {
      await _teamService.createTeam(name: name, description: desc, emblemIndex: emblem, isOpen: isOpen);
      await _loadUserTeam();
      _loadChipBalance();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team created!'), backgroundColor: Color(0xFF00D46A)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showBrowseTeamsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BrowseTeamsSheet(
        teamService: _teamService,
        onJoin: () async {
          await _loadUserTeam();
          _loadChipBalance();
        },
      ),
    );
  }

  Widget _buildTeamChatDropdown() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Messages area with info button in top-left
        Stack(
          children: [
            Container(
              height: 150,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: StreamBuilder<List<TeamChatMessage>>(
                stream: _teamService.watchChatMessages(_userTeam!.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              color: Colors.white.withValues(alpha: 0.15), size: 28),
                          const SizedBox(height: 6),
                          Text(
                            'No messages yet',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }
                  final messages = snapshot.data!;
                  return ListView.builder(
                    reverse: true,
                    itemCount: messages.length > 15 ? 15 : messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[messages.length - 1 - index];
                      final isMe = msg.senderuid == _teamService.currentUserId;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: 8,
                          left: isMe ? 24 : 0,
                          right: isMe ? 0 : 24,
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMe ? 'You' : msg.senderName,
                              style: TextStyle(
                                color: isMe ? const Color(0xFF00D46A) : Colors.white.withValues(alpha: 0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFF00D46A).withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(isMe ? 12 : 4),
                                  topRight: Radius.circular(isMe ? 4 : 12),
                                  bottomLeft: const Radius.circular(12),
                                  bottomRight: const Radius.circular(12),
                                ),
                              ),
                              child: Text(
                                msg.message,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        // Chat input
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: _buildChatInput(),
        ),
      ],
    );
  }

  Widget _buildChatInput() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              cursorColor: const Color(0xFF00D46A),
              decoration: InputDecoration(
                hintText: 'Message your team...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                border: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
              onSubmitted: (text) {
                if (text.trim().isNotEmpty && _userTeam != null) {
                  final message = text.trim();
                  _chatController.clear();
                  // Fire and forget - don't await
                  _teamService.sendChatMessage(_userTeam!.id, message);
                }
              },
            ),
          ),
          AnimatedSendButton(
            onTap: () {
              if (_chatController.text.trim().isNotEmpty && _userTeam != null) {
                final message = _chatController.text.trim();
                _chatController.clear();
                // Fire and forget - don't await
                _teamService.sendChatMessage(_userTeam!.id, message);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showTeamInfoPopup() {
    if (_userTeam == null) return;
    final isCaptain = _userTeam!.isCaptain(_teamService.currentUserId ?? '');

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: 400,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00D46A).withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button and settings for captain
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D46A).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(_userTeam!.emblem, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userTeam!.name,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_userTeam!.memberCount} members',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // Invite friends button (officers and captain)
                    if (_userTeam!.isOfficer(_teamService.currentUserId ?? ''))
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _showInviteFriendsPopup();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D46A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person_add_rounded, color: Color(0xFF00D46A), size: 20),
                        ),
                      ),
                    if (_userTeam!.isOfficer(_teamService.currentUserId ?? '')) const SizedBox(width: 4),
                    if (isCaptain)
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _showTeamSettingsPopup();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.settings_rounded, color: Colors.white.withValues(alpha: 0.5), size: 20),
                        ),
                      ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.5), size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              // Description
              if (_userTeam!.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _userTeam!.description,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                    ),
                  ),
                ),
              // Members list header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Members',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      'Ranked by MMR',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                    ),
                  ],
                ),
              ),
              // Members list
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  itemCount: _userTeam!.sortedMembers.length,
                  itemBuilder: (context, index) {
                    final member = _userTeam!.sortedMembers[index];
                    final isMe = member.odeid == _teamService.currentUserId;
                    final canKick = isCaptain && !isMe;

                    return GestureDetector(
                      onTap: canKick
                          ? () {
                              Navigator.pop(context);
                              _confirmKickMember(member);
                            }
                          : null,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(10),
                          border: canKick ? Border.all(color: Colors.white.withValues(alpha: 0.05)) : null,
                        ),
                        child: Row(
                          children: [
                            // Rank number
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: index < 3
                                    ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: index < 3 ? const Color(0xFFD4AF37) : Colors.white.withValues(alpha: 0.5),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Name
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    member.displayName,
                                    style:
                                        const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  if (member.rankIcon.isNotEmpty) ...[
                                    const SizedBox(width: 5),
                                    Text(member.rankIcon, style: const TextStyle(fontSize: 11)),
                                  ],
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    Text('(You)',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
                                  ],
                                ],
                              ),
                            ),
                            // Rank title
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: member.rank == 'captain'
                                    ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
                                    : member.rank == 'officer'
                                        ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                                        : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                member.rankDisplayName,
                                style: TextStyle(
                                  color: member.rank == 'captain'
                                      ? const Color(0xFFD4AF37)
                                      : member.rank == 'officer'
                                          ? const Color(0xFF3B82F6)
                                          : Colors.white.withValues(alpha: 0.5),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // MMR/Winnings or kick icon
                            if (canKick)
                              Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.2), size: 16)
                            else
                              Text(
                                '${member.totalWinnings}',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Leave/Disband Team button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    if (isCaptain && _userTeam!.memberCount == 1) {
                      _confirmDisbandTeam();
                    } else {
                      _confirmLeaveTeam();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isCaptain && _userTeam!.memberCount == 1
                              ? Icons.delete_outline_rounded
                              : Icons.logout_rounded,
                          color: const Color(0xFFEF4444),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isCaptain && _userTeam!.memberCount == 1 ? 'Disband Team' : 'Leave Team',
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLeaveTeam() async {
    if (_userTeam == null) return;

    // Verify user is still in the team before proceeding
    final userId = _teamService.currentUserId;
    if (userId == null || !_userTeam!.isMember(userId)) {
      // User is no longer in this team, refresh the data
      _teamSub?.cancel();
      _teamSub = null;
      setState(() => _userTeam = null);
      return;
    }

    final isCaptain = _userTeam!.isCaptain(_teamService.currentUserId ?? '');

    // If captain with other members, show transfer leadership prompt
    if (isCaptain && _userTeam!.memberCount > 1) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.8),
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFFFD700), size: 28),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Transfer Leadership',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'As captain, you need to transfer leadership to another member before leaving.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showTeamInfoPopup();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFC000)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.groups_rounded, color: Colors.black, size: 18),
                        SizedBox(width: 8),
                        Text('Manage Team',
                            style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Leave Team',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to leave ${_userTeam!.name}?',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('Cancel',
                              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text('Leave',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _teamService.leaveTeam(_userTeam!.id);
        if (mounted) {
          _teamSub?.cancel();
          _teamSub = null;
          setState(() => _userTeam = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Left team'), backgroundColor: Color(0xFF00D46A)),
          );
        }
      } catch (e) {
        if (mounted) {
          // If user is no longer in team, clear the stale data
          if (e.toString().contains('not in this team')) {
            _teamSub?.cancel();
            _teamSub = null;
            setState(() => _userTeam = null);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You already left this team'), backgroundColor: Color(0xFF00D46A)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
    }
  }

  Future<void> _confirmDisbandTeam() async {
    if (_userTeam == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Disband Team',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to disband ${_userTeam!.name}? This will permanently delete the team.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('Cancel',
                              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text('Disband',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _teamService.disbandTeam(_userTeam!.id);
        if (mounted) {
          setState(() => _userTeam = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Team disbanded'), backgroundColor: Color(0xFF00D46A)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmKickMember(TeamMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_remove_rounded, color: Color(0xFFEF4444), size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Kick Member',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Remove ${member.displayName} from the team?',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('Cancel',
                              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_remove_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text('Kick',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true && _userTeam != null) {
      try {
        await _teamService.kickMember(_userTeam!.id, member.odeid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${member.displayName} has been kicked'), backgroundColor: const Color(0xFF00D46A)),
          );
          // Refresh team data
          _loadUserTeam();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showTeamSettingsPopup() {
    if (_userTeam == null) return;
    final descController = TextEditingController(text: _userTeam!.description);
    int selectedEmblemIndex = _userTeam!.emblemIndex;
    bool isOpenTeam = _userTeam!.isOpen;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: 400,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Team Settings',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.6), size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Emblem selector
                        Text(
                          'Team Emblem',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: TeamEmblem.emblems.length,
                          itemBuilder: (context, index) {
                            final isSelected = index == selectedEmblemIndex;
                            final emblemColor = TeamEmblem.getEmblemColor(index);
                            return GestureDetector(
                              onTap: () => setSheetState(() => selectedEmblemIndex = index),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF00D46A).withValues(alpha: 0.15)
                                      : const Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(10),
                                  border: isSelected ? Border.all(color: const Color(0xFF00D46A), width: 2) : null,
                                ),
                                child: Center(
                                  child: Text(
                                    TeamEmblem.emblems[index],
                                    style: TextStyle(
                                      fontSize: 22,
                                      color: emblemColor,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        // Description
                        Text(
                          'Description',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descController,
                          maxLines: 3,
                          maxLength: 200,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Enter team description...',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Team Privacy Toggle (Captain only)
                        if (_userTeam!.isCaptain(_teamService.currentUserId ?? '')) ...[
                          Text(
                            'Team Privacy',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isOpenTeam ? Icons.lock_open_rounded : Icons.lock_rounded,
                                  color: isOpenTeam ? const Color(0xFF00D46A) : Colors.white.withValues(alpha: 0.5),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isOpenTeam ? 'Open Team' : 'Invite Only',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isOpenTeam ? 'Anyone can join' : 'Only invited players can join',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setSheetState(() => isOpenTeam = !isOpenTeam),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 48,
                                    height: 28,
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: isOpenTeam ? const Color(0xFF00D46A) : Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: AnimatedAlign(
                                      duration: const Duration(milliseconds: 200),
                                      alignment: isOpenTeam ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(11),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
                // Save button (fixed at bottom)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          if (selectedEmblemIndex != _userTeam!.emblemIndex) {
                            await _teamService.updateEmblem(_userTeam!.id, selectedEmblemIndex);
                          }
                          if (descController.text != _userTeam!.description) {
                            await _teamService.updateDescription(_userTeam!.id, descController.text);
                          }
                          if (isOpenTeam != _userTeam!.isOpen) {
                            await _teamService.updateIsOpen(_userTeam!.id, isOpenTeam);
                          }
                          _loadUserTeam();
                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D46A),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInviteFriendsPopup() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
            maxWidth: 400,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00D46A).withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D46A).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add_rounded, color: Color(0xFF00D46A), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invite Friends',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Select friends to invite to your team',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.5), size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Friends list
              Flexible(
                child: FutureBuilder<List<Friend>>(
                  future: _friendsService.getAllFriends(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline_rounded, color: Colors.white.withValues(alpha: 0.2), size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No friends to invite',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add friends first!',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }
                    final friends = snapshot.data!;
                    // Filter out friends already in the team
                    final availableFriends = friends.where((f) => !_userTeam!.isMember(f.id)).toList();

                    if (availableFriends.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                color: Colors.white.withValues(alpha: 0.2), size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'All friends are in your team!',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: availableFriends.length,
                      itemBuilder: (context, index) {
                        final friend = availableFriends[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Center(
                                  child: Text(
                                    friend.username.isNotEmpty ? friend.username[0].toUpperCase() : '?',
                                    style:
                                        const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      friend.username,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: friend.isOnline ? const Color(0xFF00D46A) : Colors.grey,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          friend.isOnline ? 'Online' : 'Offline',
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Invite button
                              GestureDetector(
                                onTap: () async {
                                  try {
                                    await _teamService.sendTeamInvite(_userTeam!.id, friend.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Invite sent to ${friend.username}!'),
                                          backgroundColor: const Color(0xFF00D46A),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00D46A),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Invite',
                                    style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addTestChips() async {
    await _userService.addChips(1000000);
    setState(() {}); // Trigger rebuild to show updated balance
  }

  @override
  void dispose() {
    _friendsSub?.cancel();
    _notificationsSub?.cancel();
    _requestsSub?.cancel();
    _teamSub?.cancel();
    _authSub?.cancel();
    _playCardController.dispose();
    _chatController.dispose();
    _homeScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFriendsData() async {
    final friends = await _friendsService.getAllFriends();
    final unreadCount = await _friendsService.getUnreadNotificationCount();
    final requestCount = await _friendsService.getPendingFriendRequestCount();

    if (mounted) {
      setState(() {
        _friends = friends;
        _unreadNotifications = unreadCount;
        _pendingFriendRequests = requestCount;
      });
    }
  }

  void _showNotificationPanel() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
          child: NotificationPanel(onClose: () => Navigator.of(context).pop()),
        ),
      ),
    );
  }

  void _showAddFriendDialog() {
    showDialog(context: context, builder: (context) => const AddFriendDialog());
  }

  void _showFriendsListDialog() {
    showDialog(context: context, builder: (context) => const FriendsListDialog());
  }

  void _showDevMenu() {
    final parentNavigator = Navigator.of(context);
    final parentScaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 340,
          constraints: const BoxConstraints(maxHeight: 480),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.bug_report, color: Colors.white.withValues(alpha: 0.6), size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Developer Menu',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Current: ${AuthService().currentUser?.email ?? AuthService().currentUser?.uid.substring(0, 8) ?? "Not signed in"}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
              ),
              const SizedBox(height: 16),
              // Scrollable options
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      DevMenuItem(
                        icon: Icons.swap_horiz,
                        color: const Color(0xFFFF9800),
                        title: 'Switch Test Account',
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _showAccountSwitcher();
                        },
                      ),
                      DevMenuItem(
                        icon: Icons.person_add,
                        color: const Color(0xFF9C27B0),
                        title: 'Create Test Account',
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _showCreateTestAccount();
                        },
                      ),
                      DevMenuItem(
                        icon: Icons.add_box,
                        color: const Color(0xFF4CAF50),
                        title: 'Add 1M Chips',
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          await _addTestChips();
                          parentScaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added 1,000,000 chips! Balance: ${UserPreferences.formatChips(UserPreferences.chips)}',
                              ),
                            ),
                          );
                        },
                      ),
                      DevMenuItem(
                        icon: Icons.meeting_room,
                        color: const Color(0xFF2196F3),
                        title: 'Create Test Room',
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          try {
                            final room = await GameService().createRoom(isPrivate: true);
                            if (mounted) {
                              parentNavigator.push(
                                MaterialPageRoute(builder: (_) => MultiplayerGameScreen(roomId: room.id)),
                              );
                            }
                          } catch (e) {
                            if (mounted) parentScaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                      ),
                      DevMenuItem(
                        icon: Icons.person_off,
                        color: const Color(0xFFE91E63),
                        title: 'New Anonymous Session',
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          try {
                            await AuthService().signOut();
                            final cred = await AuthService().signInAnonymously();
                            if (mounted) {
                              final newId = cred.user?.uid.substring(0, 8) ?? '???';
                              parentScaffoldMessenger.showSnackBar(SnackBar(content: Text('New session: $newId...')));
                            }
                          } catch (e) {
                            if (mounted) parentScaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                      ),
                      DevMenuItem(
                        icon: Icons.logout,
                        color: const Color(0xFFFF4444),
                        title: 'Sign Out',
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          try {
                            await AuthService().signOut();
                            if (mounted)
                              parentScaffoldMessenger.showSnackBar(const SnackBar(content: Text('Signed out!')));
                          } catch (e) {
                            if (mounted) parentScaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                      ),
                      DevMenuItem(
                        icon: UserPreferences.hasProPass ? Icons.star : Icons.star_border,
                        color: const Color(0xFFFFD700),
                        title: UserPreferences.hasProPass ? 'Pro Pass: ON' : 'Pro Pass: OFF',
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          await UserPreferences.setProPass(!UserPreferences.hasProPass);
                          if (mounted) {
                            setState(() {});
                            parentScaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  UserPreferences.hasProPass ? 'Pro Pass enabled!' : 'Pro Pass disabled!',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Close button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Close', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccountSwitcher() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Switch Test Account', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Sign in with email:', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 10),
            _buildAccountOption(dialogContext, scaffoldMessenger, 'test1@allin.dev', 'Test123!'),
            _buildAccountOption(dialogContext, scaffoldMessenger, 'test2@allin.dev', 'Test123!'),
            _buildAccountOption(dialogContext, scaffoldMessenger, 'test3@allin.dev', 'Test123!'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel'))],
      ),
    );
  }

  void _showCreateTestAccount() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Create Test Account', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Email',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Password (min 6 chars)',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await AuthService().registerWithEmail(
                  email: emailController.text.trim(),
                  password: passwordController.text,
                );
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Created & signed in as ${emailController.text}')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: Text('Create', style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountOption(
    BuildContext dialogContext,
    ScaffoldMessengerState scaffoldMessenger,
    String email,
    String password,
  ) {
    final isCurrentUser = AuthService().currentUser?.email == email;
    return ListTile(
      title: Text(email, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
      trailing: isCurrentUser ? Icon(Icons.check_circle, color: Colors.white.withValues(alpha: 0.5), size: 18) : null,
      onTap: isCurrentUser
          ? null
          : () async {
              Navigator.pop(dialogContext);
              try {
                await AuthService().signOut();
                await AuthService().signInWithEmail(email: email, password: password);
                if (mounted) {
                  scaffoldMessenger.showSnackBar(SnackBar(content: Text('Signed in as $email')));
                }
              } catch (e) {
                // If sign-in fails, try to create the account first
                try {
                  await AuthService().registerWithEmail(email: email, password: password);
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(SnackBar(content: Text('Created & signed in as $email')));
                  }
                } catch (createError) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(SnackBar(content: Text('Failed: $createError')));
                  }
                }
              }
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        controller: _homeScrollController,
        slivers: [
          // Header - Balance and Notification
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance (clickable to shop)
                  GestureDetector(
                    onTap: () {
                      widget.onNavigateToShop?.call();
                    },
                    child: Text(
                      '\$${UserPreferences.chips.toString().replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]},',
                          )}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  // Friends button
                  GestureDetector(
                    onTap: _showFriendsListDialog,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          Icon(
                            Icons.people_rounded,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 24,
                          ),
                          if (_pendingFriendRequests > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF4444),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Text(
                                  _pendingFriendRequests > 9 ? '9+' : _pendingFriendRequests.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ALL IN Logo
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('♠', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 24)),
                      const SizedBox(width: 8),
                      const Text('♥', style: TextStyle(color: Colors.red, fontSize: 24)),
                      const SizedBox(width: 8),
                      Text('♣', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 24)),
                      const SizedBox(width: 8),
                      Text('♦', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 24)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ALL IN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Swipeable Play Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                children: [
                  SizedBox(
                    height: 140,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = constraints.maxWidth;
                        return PageView.builder(
                          controller: _playCardController,
                          onPageChanged: (index) => setState(() => _currentPlayMode = index),
                          itemCount: 5,
                          itemBuilder: (context, index) {
                            final isLast = index == 4;
                            return Padding(
                              padding: EdgeInsets.only(right: isLast ? 0 : 12),
                              child: _buildPlayModeCardByIndex(index),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Animated dots indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPlayMode == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPlayMode == index ? Colors.white : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),

          // Teams Section
          SliverToBoxAdapter(
            key: _teamSectionKey,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedTapButton(
                    onTap: () {
                      if (_userTeam != null) {
                        final wasExpanded = _clubExpanded;
                        setState(() => _clubExpanded = !_clubExpanded);
                        // Scroll to center team section when expanding
                        if (!wasExpanded) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final context = _teamSectionKey.currentContext;
                            if (context != null) {
                              final renderObject = context.findRenderObject();
                              if (renderObject != null) {
                                // For slivers, we need to use a different approach
                                final scrollableState = Scrollable.of(context);
                                if (scrollableState.context.findRenderObject() != null) {
                                  Scrollable.ensureVisible(
                                    context,
                                    alignment: 0.3, // Show in upper third
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                  );
                                }
                              }
                            }
                          });
                        }
                      } else {
                        setState(() => _clubExpanded = !_clubExpanded);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _userTeam != null
                            ? const Color(0xFF00D46A).withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.03),
                        borderRadius: _clubExpanded
                            ? const BorderRadius.vertical(top: Radius.circular(14))
                            : BorderRadius.circular(14),
                        border: Border.all(
                          color: _userTeam != null
                              ? const Color(0xFF00D46A).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (_userTeam != null) ...[
                            GestureDetector(
                              onTap: () {
                                _showTeamInfoPopup();
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00D46A).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF00D46A).withValues(alpha: 0.5),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00D46A).withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        _userTeam!.emblem,
                                        style: TextStyle(
                                          fontSize: 20,
                                          color: TeamEmblem.getEmblemColor(_userTeam!.emblemIndex),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: -4,
                                    bottom: -4,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A1A1A),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF00D46A),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.info_outline_rounded,
                                        size: 10,
                                        color: Color(0xFF00D46A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Icon(Icons.groups_rounded, color: Colors.white.withValues(alpha: 0.6), size: 24),
                          ],
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userTeam?.name ?? 'Teams',
                                  style:
                                      const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                if (_userTeam != null) ...[
                                  Row(
                                    children: [
                                      Text(
                                        '${_userTeam!.memberCount} members',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF00D46A),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${(_userTeam!.memberCount * 0.3).round()} online',
                                        style: const TextStyle(color: Color(0xFF00D46A), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Text(
                                    'Join or create a team',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            _clubExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: Colors.white.withValues(alpha: 0.3),
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Team dropdown (when user has a team)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: _clubExpanded && _userTeam != null
                        ? Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D46A).withValues(alpha: 0.04),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                              border: Border.all(color: const Color(0xFF00D46A).withValues(alpha: 0.2)),
                            ),
                            child: _buildTeamChatDropdown(),
                          )
                        : const SizedBox.shrink(),
                  ),
                  // No team state dropdown
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: _clubExpanded && _userTeam == null
                        ? Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.02),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.groups_outlined, color: Colors.white.withValues(alpha: 0.3), size: 40),
                                const SizedBox(height: 12),
                                const Text(
                                  'No Team Yet',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Join a team to compete and earn rewards',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _showCreateTeamDialog(),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: Column(
                                          children: [
                                            Text('Create',
                                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                                            Text('1M chips',
                                                style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () => _showBrowseTeamsDialog(),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: const Column(
                                          children: [
                                            Text('Browse', style: TextStyle(color: Colors.white)),
                                            Text('1K to join', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          // Tutorial Button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TutorialScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.school_rounded, color: Colors.white.withValues(alpha: 0.6), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tutorial',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Learn how to play',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3), size: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom spacing
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  Widget _buildPlayModeCardByIndex(int index) {
    switch (index) {
      case 0:
        return _buildPlayModeCard(
          title: 'Play Now',
          subtitle: 'Jump into a game',
          icon: Icons.play_arrow_rounded,
          gradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickPlayScreen())),
        );
      case 1:
        return _buildPlayModeCard(
          title: 'Sit & Go',
          subtitle: 'Starts when full',
          icon: Icons.groups_rounded,
          gradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SitAndGoScreen())),
        );
      case 2:
        return _buildPlayModeCard(
          title: 'Tournaments',
          subtitle: 'Compete for prizes',
          icon: Icons.emoji_events_rounded,
          gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tournaments coming soon!'), backgroundColor: Color(0xFF1A1A2E)),
            );
          },
        );
      case 3:
        return _buildPlayModeCard(
          title: 'Practice',
          subtitle: 'Play vs bots',
          icon: Icons.smart_toy_rounded,
          gradient: const [Color(0xFF22C55E), Color(0xFF16A34A)],
          onTap: () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => const GameScreen(gameMode: 'Practice'))),
        );
      case 4:
      default:
        return _buildPlayModeCard(
          title: 'Private Games',
          subtitle: 'Play with friends',
          icon: UserPreferences.hasProPass ? Icons.vpn_key_rounded : Icons.lock_rounded,
          gradient: UserPreferences.hasProPass
              ? const [Color(0xFF8B5CF6), Color(0xFF7C3AED)]
              : const [Color(0xFF6B7280), Color(0xFF4B5563)],
          isLocked: !UserPreferences.hasProPass,
          onTap: () {
            if (UserPreferences.hasProPass) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Private Games - Coming soon!'), backgroundColor: Color(0xFF8B5CF6)),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Upgrade to Premium to unlock Private Games'), backgroundColor: Color(0xFF1A1A2E)),
              );
            }
          },
        );
    }
  }

  Widget _buildPlayModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return AnimatedTapButton(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLocked ? [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)] : gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: isLocked ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        icon,
                        color: isLocked ? Colors.white.withValues(alpha: 0.4) : Colors.white,
                        size: 32,
                      ),
                      if (isLocked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white.withValues(alpha: 0.6),
                          size: 28,
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isLocked ? Colors.white.withValues(alpha: 0.5) : Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isLocked ? Colors.white.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateRoomDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: Colors.white.withValues(alpha: 0.6), size: 32),
              const SizedBox(height: 16),
              const Text(
                'Create Room',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'A room code will be generated for you',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    navigator.pop();
                    try {
                      final gameService = GameService();
                      final room = await gameService.createRoom(isPrivate: true);
                      navigator.push(MaterialPageRoute(builder: (_) => MultiplayerGameScreen(roomId: room.id)));
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Failed to create room: $e')));
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Create',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinRoomDialog(BuildContext context) {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_rounded, color: Colors.white.withValues(alpha: 0.6), size: 32),
              const SizedBox(height: 16),
              const Text(
                'Join Room',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text('Enter the room code', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
              const SizedBox(height: 20),
              TextField(
                controller: codeController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 6,
                ),
                decoration: InputDecoration(
                  hintText: 'XXXXXX',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.15), letterSpacing: 6),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (codeController.text.length == 6) {
                      final roomCode = codeController.text.toUpperCase();
                      final navigator = Navigator.of(context);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      navigator.pop();
                      try {
                        final gameService = GameService();
                        await gameService.joinRoom(roomCode);
                        navigator.push(MaterialPageRoute(builder: (_) => MultiplayerGameScreen(roomId: roomCode)));
                      } catch (e) {
                        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Failed to join room: $e')));
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Join',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BrowseTeamsSheet extends StatefulWidget {
  final TeamService teamService;
  final Future<void> Function() onJoin;

  const BrowseTeamsSheet({required this.teamService, required this.onJoin});

  @override
  State<BrowseTeamsSheet> createState() => BrowseTeamsSheetState();
}

class BrowseTeamsSheetState extends State<BrowseTeamsSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Team> _teams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() => _isLoading = true);
    try {
      final teams = await widget.teamService.getAllTeams();
      if (mounted) {
        setState(() {
          _teams = teams;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      _loadTeams();
      return;
    }
    setState(() => _isLoading = true);
    try {
      final teams = await widget.teamService.searchTeams(query);
      if (mounted) {
        setState(() {
          _teams = teams;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinTeam(Team team) async {
    try {
      await widget.teamService.joinTeam(team.id);
      if (mounted) {
        Navigator.pop(context);
      }
      await widget.onJoin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined ${team.name}!'), backgroundColor: const Color(0xFF00D46A)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.groups_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Browse Teams',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Join cost: 1,000 chips',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_teams.length} teams',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Search bar
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: 'Search teams...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.35), size: 20),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          // Teams list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D46A)))
                : _teams.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, color: Colors.white.withValues(alpha: 0.3), size: 48),
                            const SizedBox(height: 12),
                            Text('No teams found', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _teams.length,
                        itemBuilder: (ctx, index) {
                          final team = _teams[index];
                          final canJoin = !team.isFull && UserPreferences.chips >= TeamService.joinTeamCost;
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF00D46A).withValues(alpha: 0.2),
                                        const Color(0xFF00D46A).withValues(alpha: 0.05),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(child: Text(team.emblem, style: const TextStyle(fontSize: 26))),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        team.name,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.people_outline_rounded,
                                              color: Colors.white.withValues(alpha: 0.4), size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${team.memberCount}/${team.maxMembers}',
                                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                                          ),
                                          if (team.description.isNotEmpty) ...[
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                team.description,
                                                style:
                                                    TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () {
                                    if (team.isFull) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('This team is full'), backgroundColor: Colors.orange),
                                      );
                                    } else if (UserPreferences.chips < TeamService.joinTeamCost) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Need ${TeamService.joinTeamCost} chips to join (you have ${UserPreferences.chips})'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    } else {
                                      _joinTeam(team);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: canJoin
                                          ? const LinearGradient(
                                              colors: [Color(0xFF00D46A), Color(0xFF00A855)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      color: canJoin ? null : Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      team.isFull ? 'Full' : 'Join',
                                      style: TextStyle(
                                        color: canJoin ? Colors.black : Colors.white.withValues(alpha: 0.4),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
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
    );
  }
}
