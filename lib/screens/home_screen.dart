import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import '../widgets/mobile_wrapper.dart';
import '../widgets/friends_widgets.dart';
import '../models/friend.dart';
import '../models/team.dart';
import '../services/friends_service.dart';
import '../services/team_service.dart';
import '../services/user_preferences.dart';
import '../services/user_service.dart';
import 'game_screen.dart';
import 'lobby_screen.dart';
import 'quick_play_screen.dart';
import 'sit_and_go_screen.dart';
import 'tutorial_screen.dart';
import 'multiplayer_game_screen.dart';
import '../services/game_service.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1;
  // Keys to force rebuild when needed
  final GlobalKey<_HomeTabState> _homeTabKey = GlobalKey<_HomeTabState>();
  final GlobalKey<_ShopTabState> _shopTabKey = GlobalKey<_ShopTabState>();

  void _refreshAllBalances() {
    _homeTabKey.currentState?.refreshChips();
    _shopTabKey.currentState?.refreshBalance();
  }

  @override
  Widget build(BuildContext context) {
    return MobileWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _ShopTab(key: _shopTabKey),
            _HomeTab(key: _homeTabKey),
            _ProfileTab(onChipsChanged: _refreshAllBalances),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(color: Color(0xFF0A0A0A)),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, Icons.storefront_outlined, Icons.storefront),
            _buildNavItem(1, Icons.home_outlined, Icons.home_rounded),
            _buildNavItem(2, Icons.person_outline_rounded, Icons.person_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon) {
    final isActive = _currentIndex == index;
    return _AnimatedTapButton(
      onTap: () => setState(() => _currentIndex = index),
      scaleDown: 0.9,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Icon(
          isActive ? activeIcon : icon,
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.35),
          size: 24,
        ),
      ),
    );
  }
}

// ============================================================================
// ANIMATED TAP BUTTON - Reusable animated button with scale effect
// ============================================================================

class _AnimatedTapButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  const _AnimatedTapButton({
    required this.child,
    this.onTap,
    this.scaleDown = 0.95,
  });

  @override
  State<_AnimatedTapButton> createState() => _AnimatedTapButtonState();
}

class _AnimatedTapButtonState extends State<_AnimatedTapButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleDown : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}

class _AnimatedSendButton extends StatefulWidget {
  final VoidCallback? onTap;

  const _AnimatedSendButton({this.onTap});

  @override
  State<_AnimatedSendButton> createState() => _AnimatedSendButtonState();
}

class _AnimatedSendButtonState extends State<_AnimatedSendButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF00D46A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.arrow_upward_rounded, color: Colors.black, size: 18),
        ),
      ),
    );
  }
}

// ============================================================================
// HOME TAB - Main Play Screen
// ============================================================================

class _HomeTab extends StatefulWidget {
  const _HomeTab({super.key});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
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
      builder: (context) => _BrowseTeamsSheet(
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
          _AnimatedSendButton(
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
                      _DevMenuItem(
                        icon: Icons.swap_horiz,
                        color: const Color(0xFFFF9800),
                        title: 'Switch Test Account',
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _showAccountSwitcher();
                        },
                      ),
                      _DevMenuItem(
                        icon: Icons.person_add,
                        color: const Color(0xFF9C27B0),
                        title: 'Create Test Account',
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _showCreateTestAccount();
                        },
                      ),
                      _DevMenuItem(
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
                      _DevMenuItem(
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
                      _DevMenuItem(
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
                      _DevMenuItem(
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
                      _DevMenuItem(
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
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance (clickable to shop)
                  GestureDetector(
                    onTap: () {
                      final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                      homeState?.setState(() => homeState._currentIndex = 0);
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
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('♠', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 24)),
                      const SizedBox(width: 8),
                      Text('♥', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 24)),
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
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
              child: Column(
                children: [
                  SizedBox(
                    height: 160,
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
                  const SizedBox(height: 16),
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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AnimatedTapButton(
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
                        borderRadius: _clubExpanded && _userTeam != null
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
                                Text(
                                  _userTeam != null ? '${_userTeam!.memberCount} members' : 'Join or create a team',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _userTeam != null
                                ? (_clubExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded)
                                : Icons.chevron_right_rounded,
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
                  // No team state
                  if (_clubExpanded && _userTeam == null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(12),
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
                                      Text('Create', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                                      Text('1M chips',
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
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
                    ),
                  ],
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
    return _AnimatedTapButton(
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

// ============================================================================
// SHOP TAB - Minimalist Design
// ============================================================================

class _ShopTab extends StatefulWidget {
  const _ShopTab({super.key});

  @override
  State<_ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<_ShopTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedCategory = 0;

  final List<Map<String, dynamic>> _categories = [
    {'icon': '✨', 'name': 'Featured'},
    {'icon': '💎', 'name': 'Currency'},
    {'icon': '🎨', 'name': 'Cosmetics'},
    {'icon': '📦', 'name': 'Chests'},
  ];

  void refreshBalance() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedCategory = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Minimal Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Shop',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    _BalanceChip(
                        emoji: '🪙',
                        amount: UserPreferences.formatChips(UserPreferences.chips),
                        color: Colors.white.withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    _BalanceChip(
                        emoji: '💎',
                        amount: UserPreferences.gems.toString(),
                        color: Colors.white.withValues(alpha: 0.6)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Minimal Category Tabs
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(2),
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.4),
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: _categories.map((cat) => Tab(child: Text(cat['name']))).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildFeaturedTab(), _buildCurrencyTab(), _buildCosmeticsTab(), _buildChestsTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Daily Bonus - Minimalist
          _AnimatedTapButton(
            onTap: () => _showDailySpinDialog(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.refresh_rounded, color: Color(0xFF22C55E), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Spin',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Free chips & gems',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(8)),
                    child: const Text(
                      'Claim',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Mini Games Row - Simplified
          Row(
            children: [
              Expanded(
                child: _AnimatedTapButton(
                  onTap: () => _showGemWheelDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.donut_large_rounded, color: Colors.white.withValues(alpha: 0.7), size: 24),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Gem Wheel',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.diamond_outlined, color: Colors.white.withValues(alpha: 0.5), size: 14),
                            const SizedBox(width: 4),
                            Text('50', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnimatedTapButton(
                  onTap: () => _showLuckyHandDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFD4AF37).withValues(alpha: 0.15),
                          const Color(0xFFD4AF37).withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.style_rounded, color: Color(0xFFD4AF37), size: 24),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Lucky Hand',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          UserPreferences.todaysLuckyHand.name,
                          style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 11, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Hot Deals section label
          Text(
            'Deals',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),

          // Starter Pack - Simplified
          _HotDealCard(
            title: 'Starter Pack',
            subtitle: 'Perfect for new players',
            icon: Icons.rocket_launch_rounded,
            items: ['10,000 Chips', '50 Gems', 'Gold Card Back'],
            price: '\$2.99',
            originalPrice: '\$5.99',
            gradient: [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)],
          ),
          const SizedBox(height: 10),

          // VIP Bundle
          _HotDealCard(
            title: 'VIP Bundle',
            subtitle: 'Best value pack',
            icon: Icons.workspace_premium_rounded,
            items: ['100,000 Chips', '500 Gems', 'Royal Set'],
            price: '\$19.99',
            originalPrice: '\$49.99',
            gradient: [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)],
            isBest: true,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildCurrencyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chips Section
          Text(
            'Chips',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CurrencyCard(
                  emoji: '🪙',
                  amount: '10K',
                  price: '\$0.99',
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CurrencyCard(
                  emoji: '🪙',
                  amount: '50K',
                  price: '\$4.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+5K',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CurrencyCard(
                  emoji: '🪙',
                  amount: '150K',
                  price: '\$9.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+25K',
                  isBest: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CurrencyCard(
                  emoji: '🪙',
                  amount: '500K',
                  price: '\$19.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+100K',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CurrencyCard(
                  emoji: '🪙',
                  amount: '1.5M',
                  price: '\$49.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+350K',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CurrencyCard(
                  emoji: '🪙',
                  amount: '5M',
                  price: '\$99.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+1.5M',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Gems Section
          Text(
            'Gems',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CurrencyCard(
                  emoji: '💎',
                  amount: '100',
                  price: '\$0.99',
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CurrencyCard(
                  emoji: '💎',
                  amount: '500',
                  price: '\$4.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+50',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CurrencyCard(
                  emoji: '💎',
                  amount: '1,200',
                  price: '\$9.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+200',
                  isBest: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CurrencyCard(
                  emoji: '💎',
                  amount: '2,500',
                  price: '\$19.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+500',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CurrencyCard(
                  emoji: '💎',
                  amount: '6,500',
                  price: '\$49.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+1500',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CurrencyCard(
                  emoji: '💎',
                  amount: '14K',
                  price: '\$99.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+4000',
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildCosmeticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          // Card Backs Category
          _CosmeticCategoryDropdown(
            emoji: '🎴',
            title: 'Card Backs',
            commonItems: [
              _CosmeticItemData(emoji: '🎴', name: 'Classic', price: 'Equipped', isOwned: true),
              _CosmeticItemData(emoji: '🟤', name: 'Wood', price: '100'),
              _CosmeticItemData(emoji: '🔘', name: 'Simple', price: '150'),
            ],
            rareItems: [
              _CosmeticItemData(emoji: '🌟', name: 'Gold', price: '500'),
              _CosmeticItemData(emoji: '🔵', name: 'Ocean', price: '500'),
              _CosmeticItemData(emoji: '🟢', name: 'Forest', price: '600'),
            ],
            epicItems: [
              _CosmeticItemData(emoji: '💎', name: 'Diamond', price: '1,000'),
              _CosmeticItemData(emoji: '🔥', name: 'Fire', price: '1,200'),
              _CosmeticItemData(emoji: '❄️', name: 'Ice', price: '1,200'),
            ],
            legendaryItems: [
              _CosmeticItemData(emoji: '👑', name: 'Royal', price: '2,500'),
              _CosmeticItemData(emoji: '🌈', name: 'Prismatic', price: '3,000'),
              _CosmeticItemData(emoji: '⚡', name: 'Thunder', price: '3,500'),
            ],
          ),
          SizedBox(height: 12),

          // Table Themes Category
          _CosmeticCategoryDropdown(
            emoji: '🎨',
            title: 'Table Themes',
            commonItems: [
              _CosmeticItemData(emoji: '🟢', name: 'Classic', price: 'Equipped', isOwned: true),
              _CosmeticItemData(emoji: '🟤', name: 'Brown', price: '100'),
              _CosmeticItemData(emoji: '⚫', name: 'Dark', price: '150'),
            ],
            rareItems: [
              _CosmeticItemData(emoji: '🔵', name: 'Royal Blue', price: '500'),
              _CosmeticItemData(emoji: '🟣', name: 'Velvet', price: '750'),
              _CosmeticItemData(emoji: '🔴', name: 'Vegas', price: '750'),
            ],
            epicItems: [
              _CosmeticItemData(emoji: '⬛', name: 'Midnight', price: '1,000'),
              _CosmeticItemData(emoji: '🌊', name: 'Ocean', price: '1,200'),
              _CosmeticItemData(emoji: '🌸', name: 'Sakura', price: '1,200'),
            ],
            legendaryItems: [
              _CosmeticItemData(emoji: '✨', name: 'Galaxy', price: '2,500'),
              _CosmeticItemData(emoji: '🌋', name: 'Volcanic', price: '3,000'),
              _CosmeticItemData(emoji: '💫', name: 'Nebula', price: '3,500'),
            ],
          ),
          SizedBox(height: 12),

          // Avatars Category
          _CosmeticCategoryDropdown(
            emoji: '👤',
            title: 'Avatars',
            commonItems: [
              _CosmeticItemData(emoji: '👤', name: 'Default', price: 'Equipped', isOwned: true),
              _CosmeticItemData(emoji: '😊', name: 'Smiley', price: '100'),
              _CosmeticItemData(emoji: '😐', name: 'Neutral', price: '100'),
            ],
            rareItems: [
              _CosmeticItemData(emoji: '🤠', name: 'Cowboy', price: '300'),
              _CosmeticItemData(emoji: '🎩', name: 'Fancy', price: '500'),
              _CosmeticItemData(emoji: '🧢', name: 'Cool Guy', price: '400'),
            ],
            epicItems: [
              _CosmeticItemData(emoji: '👸', name: 'Royalty', price: '750'),
              _CosmeticItemData(emoji: '🤖', name: 'Robot', price: '800'),
              _CosmeticItemData(emoji: '🦊', name: 'Fox', price: '850'),
            ],
            legendaryItems: [
              _CosmeticItemData(emoji: '👽', name: 'Alien', price: '2,000'),
              _CosmeticItemData(emoji: '🐉', name: 'Dragon', price: '2,500'),
              _CosmeticItemData(emoji: '👻', name: 'Phantom', price: '3,000'),
            ],
          ),
          SizedBox(height: 12),

          // Emotes Category
          _CosmeticCategoryDropdown(
            emoji: '😎',
            title: 'Emotes',
            commonItems: [
              _CosmeticItemData(emoji: '👍', name: 'GG', price: 'Free', isOwned: true),
              _CosmeticItemData(emoji: '👋', name: 'Wave', price: '50'),
              _CosmeticItemData(emoji: '👏', name: 'Clap', price: '75'),
            ],
            rareItems: [
              _CosmeticItemData(emoji: '😎', name: 'Cool', price: '200'),
              _CosmeticItemData(emoji: '🤣', name: 'LOL', price: '200'),
              _CosmeticItemData(emoji: '😱', name: 'Shock', price: '300'),
            ],
            epicItems: [
              _CosmeticItemData(emoji: '🎉', name: 'Party', price: '500'),
              _CosmeticItemData(emoji: '🃏', name: 'Bluff', price: '600'),
              _CosmeticItemData(emoji: '💪', name: 'Flex', price: '550'),
            ],
            legendaryItems: [
              _CosmeticItemData(emoji: '🔥', name: 'On Fire', price: '1,500'),
              _CosmeticItemData(emoji: '💎', name: 'Rich', price: '2,000'),
              _CosmeticItemData(emoji: '👑', name: 'King', price: '2,500'),
            ],
          ),
          SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildChestsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Chests contain random rewards including chips, cosmetics, and rare items!',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Chests Grid
          _ModernChestCard(
            name: 'Bronze Chest',
            emoji: '🧰',
            price: 50,
            rewards: ['500-2K Chips', 'Common Emote', 'Card Back'],
            gradient: [const Color(0xFF8D6E63), const Color(0xFF5D4037)],
            rarity: 'Common',
          ),
          const SizedBox(height: 14),
          _ModernChestCard(
            name: 'Silver Chest',
            emoji: '🪨',
            price: 150,
            rewards: ['2K-10K Chips', 'Rare Emote', 'Table Theme'],
            gradient: [const Color(0xFF90A4AE), const Color(0xFF607D8B)],
            rarity: 'Rare',
          ),
          const SizedBox(height: 14),
          _ModernChestCard(
            name: 'Gold Chest',
            emoji: '👑',
            price: 500,
            rewards: ['10K-50K Chips', 'Epic Items', 'Dealer Skin'],
            gradient: [const Color(0xFFFFD54F), const Color(0xFFFF8F00)],
            rarity: 'Epic',
            isBest: true,
          ),
          const SizedBox(height: 14),
          _ModernChestCard(
            name: 'Diamond Chest',
            emoji: '💎',
            price: 1000,
            rewards: ['50K-200K Chips', 'Legendary Items', 'Exclusive Set'],
            gradient: [const Color(0xFF00BCD4), const Color(0xFF0097A7)],
            rarity: 'Legendary',
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  void _showDailySpinDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const _DailySpinDialog()).then((_) => refreshBalance());
  }

  void _showGemWheelDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const _GemWheelDialog()).then((_) => refreshBalance());
  }

  void _showLuckyHandDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const _LuckyHandDialog()).then((_) => refreshBalance());
  }
}

// Balance chip widget for header
class _BalanceChip extends StatelessWidget {
  final String emoji;
  final String amount;
  final Color color;

  const _BalanceChip({required this.emoji, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            amount,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// Dev menu item widget
class _DevMenuItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  const _DevMenuItem({required this.icon, required this.color, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 18),
          ],
        ),
      ),
    );
  }
}

// Section label widget
class _SectionLabel extends StatelessWidget {
  final String emoji;
  final String title;

  const _SectionLabel({required this.emoji, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 1,
      ),
    );
  }
}

// Currency card widget - Minimalist
class _CurrencyCard extends StatelessWidget {
  final String emoji;
  final String amount;
  final String price;
  final Color color;
  final String? bonus;
  final bool isBest;

  const _CurrencyCard({
    required this.emoji,
    required this.amount,
    required this.price,
    required this.color,
    this.bonus,
    this.isBest = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isBest ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          if (isBest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'BEST',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 8, fontWeight: FontWeight.w600),
              ),
            )
          else if (bonus != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                bonus!,
                style: const TextStyle(color: Color(0xFF22C55E), fontSize: 8, fontWeight: FontWeight.w600),
              ),
            )
          else
            const SizedBox(height: 16),
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            amount,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              price,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// Cosmetic item widget
class _CosmeticItem extends StatelessWidget {
  final String emoji;
  final String name;
  final String price;
  final bool isOwned;

  const _CosmeticItem({required this.emoji, required this.name, required this.price, this.isOwned = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isOwned ? null : () => _showPurchaseDialog(context),
      child: Container(
        width: 90,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOwned ? const Color(0xFF4CAF50).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 6),
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (isOwned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  price,
                  style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 9, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💎', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      price,
                      style: const TextStyle(color: Color(0xFF9C27B0), fontSize: 11, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💎', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    price,
                    style: const TextStyle(color: Color(0xFF9C27B0), fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Purchased $name!'), backgroundColor: const Color(0xFF4CAF50)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9C27B0),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Buy',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
  }
}

// Cosmetic item data for the dropdown system
class _CosmeticItemData {
  final String emoji;
  final String name;
  final String price;
  final bool isOwned;

  const _CosmeticItemData({required this.emoji, required this.name, required this.price, this.isOwned = false});
}

// Cosmetic category dropdown with rarity sub-dropdowns
class _CosmeticCategoryDropdown extends StatefulWidget {
  final String emoji;
  final String title;
  final List<_CosmeticItemData> commonItems;
  final List<_CosmeticItemData> rareItems;
  final List<_CosmeticItemData> epicItems;
  final List<_CosmeticItemData> legendaryItems;

  const _CosmeticCategoryDropdown({
    required this.emoji,
    required this.title,
    required this.commonItems,
    required this.rareItems,
    required this.epicItems,
    required this.legendaryItems,
  });

  @override
  State<_CosmeticCategoryDropdown> createState() => _CosmeticCategoryDropdownState();
}

class _CosmeticCategoryDropdownState extends State<_CosmeticCategoryDropdown> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // Main category header
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(widget.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          ),

          // Rarity sub-dropdowns
          if (_isExpanded) ...[
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            _RaritySubDropdown(rarity: 'Common', color: const Color(0xFF9E9E9E), items: widget.commonItems),
            _RaritySubDropdown(rarity: 'Rare', color: const Color(0xFF2196F3), items: widget.rareItems),
            _RaritySubDropdown(rarity: 'Epic', color: const Color(0xFF9C27B0), items: widget.epicItems),
            _RaritySubDropdown(rarity: 'Legendary', color: const Color(0xFFD4AF37), items: widget.legendaryItems),
          ],
        ],
      ),
    );
  }
}

// Rarity sub-dropdown widget
class _RaritySubDropdown extends StatefulWidget {
  final String rarity;
  final Color color;
  final List<_CosmeticItemData> items;

  const _RaritySubDropdown({required this.rarity, required this.color, required this.items});

  @override
  State<_RaritySubDropdown> createState() => _RaritySubDropdownState();
}

class _RaritySubDropdownState extends State<_RaritySubDropdown> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Rarity header
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.08)),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.rarity,
                    style: TextStyle(color: widget.color, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${widget.items.length} items',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down, color: Colors.white.withValues(alpha: 0.4), size: 20),
                ),
              ],
            ),
          ),
        ),

        // Items grid
        if (_isExpanded)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.black.withValues(alpha: 0.2),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.items
                  .map(
                    (item) => _CosmeticGridItem(
                      emoji: item.emoji,
                      name: item.name,
                      price: item.price,
                      isOwned: item.isOwned,
                      rarityColor: widget.color,
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

// Cosmetic grid item for rarity dropdowns
class _CosmeticGridItem extends StatelessWidget {
  final String emoji;
  final String name;
  final String price;
  final bool isOwned;
  final Color rarityColor;

  const _CosmeticGridItem({
    required this.emoji,
    required this.name,
    required this.price,
    required this.isOwned,
    required this.rarityColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isOwned ? null : () => _showPurchaseDialog(context),
      child: Container(
        width: 85,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOwned ? const Color(0xFF4CAF50).withValues(alpha: 0.5) : rarityColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (isOwned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  price,
                  style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 8, fontWeight: FontWeight.w700),
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💎', style: TextStyle(fontSize: 9)),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      price,
                      style: TextStyle(color: rarityColor, fontSize: 10, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: rarityColor.withValues(alpha: 0.4)),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 48)),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💎', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    price,
                    style: TextStyle(color: rarityColor, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Purchased $name!'), backgroundColor: const Color(0xFF4CAF50)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: rarityColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Buy',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
  }
}

// Hot deal card widget
class _HotDealCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> items;
  final String price;
  final String originalPrice;
  final List<Color> gradient;
  final bool isBest;

  const _HotDealCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    required this.price,
    required this.originalPrice,
    required this.gradient,
    this.isBest = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    if (isBest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'BEST',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: items
                      .map(
                        (item) =>
                            Text(item, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                originalPrice,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 11,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  price,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Modern chest card widget - Simplified
class _ModernChestCard extends StatelessWidget {
  final String name;
  final String emoji;
  final int price;
  final List<String> rewards;
  final List<Color> gradient;
  final String rarity;
  final bool isBest;

  const _ModernChestCard({
    required this.name,
    required this.emoji,
    required this.price,
    required this.rewards,
    required this.gradient,
    required this.rarity,
    this.isBest = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showChestDialog(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [gradient[0].withValues(alpha: 0.3), gradient[1].withValues(alpha: 0.15)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: isBest ? 0.15 : 0.08), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          rarity,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: rewards
                        .map(
                          (reward) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              reward,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text('💎', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    price.toString(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                name,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  rarity,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Possible Rewards', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
              const SizedBox(height: 8),
              ...rewards.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white.withValues(alpha: 0.5), size: 14),
                      const SizedBox(width: 6),
                      Text(r, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opened $name!'), backgroundColor: Colors.white.withValues(alpha: 0.2)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        'Open for $price',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PROFILE TAB
// ============================================================================

class _ProfileTab extends StatefulWidget {
  final VoidCallback? onChipsChanged;

  const _ProfileTab({super.key, this.onChipsChanged});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool _achievementsExpanded = false;
  bool _statisticsExpanded = false;
  bool _referralExpanded = false;
  final FriendsService _friendsService = FriendsService();
  List<Friend> _friends = [];
  StreamSubscription? _friendsSub;
  StreamSubscription? _authSub;
  String _displayUsername = '';

  @override
  void initState() {
    super.initState();
    _displayUsername = UserPreferences.username;
    _loadFriends();
    _friendsSub = _friendsService.friendsStream.listen((friends) {
      if (mounted) setState(() => _friends = friends);
    });
    // Listen for auth state changes to refresh username
    _authSub = AuthService().authStateChanges.listen((user) async {
      if (user != null && mounted) {
        // Sync data from Firestore when user changes
        await UserService().syncAllUserData();
        if (mounted) {
          setState(() {
            _displayUsername = UserPreferences.username;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _friendsSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final friends = await _friendsService.getAllFriends();
    if (mounted) setState(() => _friends = friends);
  }

  void _showAddFriendDialog() {
    showDialog(context: context, builder: (context) => const AddFriendDialog());
  }

  void _showFriendsListDialog() {
    showDialog(context: context, builder: (context) => const FriendsListDialog());
  }

  void _showDevMenu(BuildContext context) {
    final parentScaffoldMessenger = ScaffoldMessenger.of(context);
    final parentNavigator = Navigator.of(context);

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
                      _DevMenuItem(
                        icon: Icons.swap_horiz,
                        color: const Color(0xFFFF9800),
                        title: 'Sign In (Username)',
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _showUsernameSignIn(context);
                        },
                      ),
                      _DevMenuItem(
                        icon: Icons.email,
                        color: const Color(0xFF9C27B0),
                        title: 'Sign In (Email - Dev)',
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _showAccountSwitcher(context);
                        },
                      ),
                      _DevMenuItem(
                        icon: Icons.person_add,
                        color: const Color(0xFF673AB7),
                        title: 'Create Test Account (Email)',
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _showCreateTestAccount(context);
                        },
                      ),
                      _DevMenuItem(
                        icon: Icons.add_box,
                        color: const Color(0xFF4CAF50),
                        title: 'Add 1M Chips',
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          await UserService().addChips(1000000);
                          widget.onChipsChanged?.call();
                          parentScaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added 1,000,000 chips! Balance: ${UserPreferences.formatChips(UserPreferences.chips)}',
                              ),
                            ),
                          );
                        },
                      ),
                      _DevMenuItem(
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
                      _DevMenuItem(
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
                      _DevMenuItem(
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

  void _showAccountSwitcher(BuildContext context) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Switch Test Account',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sign in with email:', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
            const SizedBox(height: 10),
            _buildAccountOption(dialogContext, scaffoldMessenger, 'test1@allin.dev', 'Test123!'),
            _buildAccountOption(dialogContext, scaffoldMessenger, 'test2@allin.dev', 'Test123!'),
            _buildAccountOption(dialogContext, scaffoldMessenger, 'test3@allin.dev', 'Test123!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
        ],
      ),
    );
  }

  void _showCreateTestAccount(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Create Test Account',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Email',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Password (min 6 chars)',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
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
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showUsernameSignIn(BuildContext context) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Sign In with Username',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sign into an existing account',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: usernameController,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Username',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                prefixIcon: Icon(Icons.person, color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                prefixIcon: Icon(Icons.lock, color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final username = usernameController.text.trim();
              final password = passwordController.text;
              if (username.isEmpty || password.isEmpty) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Please enter username and password')),
                );
                return;
              }
              try {
                // Sign out first
                await AuthService().signOut();
                // Sign in with username/password
                await AuthService().signInWithUsername(username: username, password: password);
                // Cache the credentials for auto-login
                await UserPreferences.setUsername(username);
                await UserPreferences.setCachedPassword(password);
                await UserPreferences.setCachedUid(AuthService().currentUser!.uid);
                // Sync user data
                await UserService().syncAllUserData();
                if (mounted) {
                  setState(() => _displayUsername = username);
                  scaffoldMessenger.showSnackBar(SnackBar(content: Text('Signed in as $username')));
                }
              } catch (e) {
                if (mounted) {
                  String errorMsg = 'Sign in failed';
                  final errorStr = e.toString().toLowerCase();
                  if (errorStr.contains('user-not-found') ||
                      errorStr.contains('wrong-password') ||
                      errorStr.contains('invalid-credential')) {
                    errorMsg = 'Invalid username or password';
                  }
                  scaffoldMessenger.showSnackBar(SnackBar(content: Text(errorMsg)));
                }
              }
            },
            child: const Text('Sign In'),
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
      title: Text(email, style: const TextStyle(color: Colors.white)),
      trailing: isCurrentUser ? const Icon(Icons.check_circle, color: Color(0xFF4CAF50)) : null,
      onTap: isCurrentUser
          ? null
          : () async {
              Navigator.pop(dialogContext);
              try {
                await AuthService().signOut();
                await AuthService().signInWithEmail(email: email, password: password);
                // Sync user data after switching
                await UserService().syncAllUserData();
                if (mounted) {
                  setState(() => _displayUsername = UserPreferences.username);
                  scaffoldMessenger.showSnackBar(SnackBar(content: Text('Signed in as $email')));
                }
              } catch (e) {
                // If sign-in fails, try to create the account first
                try {
                  await AuthService().registerWithEmail(email: email, password: password);
                  await UserService().syncAllUserData();
                  if (mounted) {
                    setState(() => _displayUsername = UserPreferences.username);
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
        slivers: [
          // Profile Header - Minimalist
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Profile',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      // Dev Button
                      GestureDetector(
                        onTap: () => _showDevMenu(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Icon(Icons.bug_report, color: Colors.white.withValues(alpha: 0.4), size: 18),
                          ),
                        ),
                      ),
                      // Settings Button
                      GestureDetector(
                        onTap: () => _showSettings(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.settings_outlined, color: Colors.white.withValues(alpha: 0.5), size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Profile Card - Minimalist
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(child: Text('👤', style: TextStyle(fontSize: 26))),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _displayUsername,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.military_tech, color: Colors.white.withValues(alpha: 0.4), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Unranked',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Ranked Season Card - Minimalist
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(child: Text('🏅', style: TextStyle(fontSize: 18))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Season 1',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '28 days remaining',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Bronze III',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '0 / 100 RP',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Rank tiers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _RankTier(name: 'Bronze', color: Colors.white.withValues(alpha: 0.5), isActive: true),
                        _RankTier(name: 'Silver', color: Colors.white.withValues(alpha: 0.3), isActive: false),
                        _RankTier(name: 'Gold', color: Colors.white.withValues(alpha: 0.3), isActive: false),
                        _RankTier(name: 'Platinum', color: Colors.white.withValues(alpha: 0.3), isActive: false),
                        _RankTier(name: 'Diamond', color: Colors.white.withValues(alpha: 0.3), isActive: false),
                        _RankTier(name: 'Champion', color: Colors.white.withValues(alpha: 0.3), isActive: false),
                        _RankTier(name: 'Legend', color: Colors.white.withValues(alpha: 0.3), isActive: false),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress bar
                    Stack(
                      children: [
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Container(
                          height: 4,
                          width: 0, // 0% progress
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Win ranked games to earn RP and climb',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Statistics Dropdown
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _statisticsExpanded = !_statisticsExpanded),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(child: Text('📊', style: TextStyle(fontSize: 18))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Statistics',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '0 games played',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: _statisticsExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white.withValues(alpha: 0.4),
                              size: 22,
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

          // Statistics Content (Expandable)
          if (_statisticsExpanded)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: _StatCard(value: '0', label: 'Games'),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: _StatCard(value: '0', label: 'Wins'),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: _StatCard(value: '0%', label: 'Win Rate'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: _StatCard(value: '0', label: 'Best Streak'),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: _StatCard(value: '0', label: 'Earnings'),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: _StatCard(value: 'Lv.1', label: 'Level'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: _StatCard(value: '-', label: 'Rank'),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: _StatCard(value: '1,000', label: 'ELO'),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: _StatCard(value: '0', label: 'Trophies'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: _StatCard(value: '0', label: 'Duels Won'),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: _StatCard(value: '0', label: 'Tournaments'),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: _StatCard(value: '0', label: 'Hands'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Profit/Loss Graph
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Chip Balance History',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '7 Days',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Simple line graph representation
                          SizedBox(
                            height: 80,
                            child: CustomPaint(size: const Size(double.infinity, 80), painter: _ChipGraphPainter()),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Mon', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 9)),
                              Text('Tue', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 9)),
                              Text('Wed', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 9)),
                              Text('Thu', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 9)),
                              Text('Fri', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 9)),
                              Text('Sat', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 9)),
                              Text('Sun', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 9)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Achievements Dropdown - Minimalist
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _achievementsExpanded = !_achievementsExpanded),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(child: Text('🏆', style: TextStyle(fontSize: 18))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Achievements',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '0 / 100 Unlocked',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: _achievementsExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white.withValues(alpha: 0.4),
                              size: 22,
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

          // Achievement Grid (Expandable)
          if (_achievementsExpanded)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _AchievementCard.fromIndex(index),
                  childCount: 100,
                ),
              ),
            ),

          // Season Pass - Minimalist
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Season Pass',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'FREE',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text('🏆', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Text(
                                  'Tier 1',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '0 / 1000 XP',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: 0.0,
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.3)),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Tier rewards preview
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _TierReward(emoji: '🪙', label: 'Tier 1', isFree: true),
                            _TierReward(emoji: '💎', label: 'Tier 2', isFree: true),
                            _TierReward(emoji: '🎴', label: 'Tier 3', isFree: false),
                            _TierReward(emoji: '✨', label: 'Tier 4', isFree: false),
                            _TierReward(emoji: '👑', label: 'Tier 5', isFree: false),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Premium Pass Button
                        GestureDetector(
                          onTap: () => _showPremiumPassDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(child: Text('👑', style: TextStyle(fontSize: 14))),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Premium Pass',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.9),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Unlock exclusive rewards & 2x XP',
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('💎', style: TextStyle(fontSize: 11)),
                                      const SizedBox(width: 3),
                                      Text(
                                        '500',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Referral Section - Minimalist
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _referralExpanded = !_referralExpanded),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(child: Text('🎁', style: TextStyle(fontSize: 18))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Invite Friends',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Earn rewards for referrals',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: _referralExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white.withValues(alpha: 0.4),
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_referralExpanded) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Your Referral Code',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '0 invited',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'ALLIN-ABC123',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () {},
                                  child: Icon(Icons.copy, color: Colors.white.withValues(alpha: 0.4), size: 18),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Rewards per friend',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  const Text('🪙', style: TextStyle(fontSize: 24)),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '5,000',
                                    style: TextStyle(
                                      color: Color(0xFFD4AF37),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Chips',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                                  ),
                                ],
                              ),
                              Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.1)),
                              Column(
                                children: [
                                  const Text('💎', style: TextStyle(fontSize: 24)),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '50',
                                    style: TextStyle(
                                      color: Color(0xFF2196F3),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Gems',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('Share Invite Link'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Spacing
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  void _showChallengeDialog(BuildContext context, String friendName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFC2185B)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(child: Text('⚔️', style: TextStyle(fontSize: 36))),
              ),
              const SizedBox(height: 20),
              Text(
                'Challenge $friendName',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                'Send a heads-up duel challenge!',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
              ),
              const SizedBox(height: 24),
              Text('Select Stakes', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StakeOption(amount: '1,000', isSelected: false),
                  _StakeOption(amount: '5,000', isSelected: true),
                  _StakeOption(amount: '10,000', isSelected: false),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Challenge sent to $friendName!'),
                            backgroundColor: const Color(0xFFE91E63),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Send Challenge',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
  }

  void _showGiftDialog(BuildContext context, String friendName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF388E3C)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(child: Text('🎁', style: TextStyle(fontSize: 36))),
              ),
              const SizedBox(height: 20),
              Text(
                'Gift to $friendName',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _GiftOption(emoji: '🪙', label: 'Chips', amount: '1,000', isSelected: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GiftOption(emoji: '💎', label: 'Gems', amount: '10', isSelected: false),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sent gift to $friendName!'),
                            backgroundColor: const Color(0xFF4CAF50),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Send Gift',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
  }

  void _showPremiumPassDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8, maxWidth: 360),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8860B)]),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(child: Text('👑', style: TextStyle(fontSize: 40))),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Premium Pass',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock exclusive rewards!',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  _PremiumBenefit(icon: '⚡', text: '2x XP on all games'),
                  const SizedBox(height: 10),
                  _PremiumBenefit(icon: '🎴', text: 'Exclusive card backs'),
                  const SizedBox(height: 10),
                  _PremiumBenefit(icon: '🪙', text: 'Bonus chips every tier'),
                  const SizedBox(height: 10),
                  _PremiumBenefit(icon: '👤', text: 'Premium avatar frame'),
                  const SizedBox(height: 10),
                  _PremiumBenefit(icon: '💬', text: 'Exclusive emotes'),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Premium Pass purchased!'), backgroundColor: Color(0xFFD4AF37)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('💎', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          const Text(
                            'Buy for 500 Gems',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Maybe Later', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.5)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SettingsItem(icon: Icons.volume_up, title: 'Sound', hasToggle: true),
              _SettingsItem(icon: Icons.vibration, title: 'Vibration', hasToggle: true),
              _SettingsItem(icon: Icons.notifications, title: 'Notifications', hasToggle: true),
              const Divider(color: Colors.white12, height: 24),
              _SettingsItem(icon: Icons.help_outline, title: 'Help & Support'),
              _SettingsItem(icon: Icons.info_outline, title: 'About'),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// REUSABLE WIDGETS
// ============================================================================

class _BalanceCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final List<Color> gradient;

  const _BalanceCard({required this.emoji, required this.label, required this.value, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(color: gradient[0], fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Icon(Icons.add, color: Colors.white.withValues(alpha: 0.3), size: 16),
        ],
      ),
    );
  }
}

class _QuickPlayCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _QuickPlayCard({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: gradient[0].withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: gradient[0].withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  final String emoji;
  final String amount;
  final String price;
  final bool isBest;

  const _ShopItemCard({required this.emoji, required this.amount, required this.price, this.isBest = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBest ? const Color(0xFFD4AF37).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          if (isBest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: const Color(0xFFD4AF37), borderRadius: BorderRadius.circular(6)),
              child: const Text(
                'BEST',
                style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w800),
              ),
            ),
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Text(
              price,
              style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
        ],
      ),
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  final String name;
  final bool isOnline;

  const _FriendAvatar({required this.name, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  name[0],
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (isOnline)
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
        const SizedBox(height: 6),
        Text(name, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool hasToggle;
  final bool isDestructive;

  const _SettingsItem({required this.icon, required this.title, this.hasToggle = false, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: isDestructive ? const Color(0xFFFF4444) : Colors.white.withValues(alpha: 0.7), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: isDestructive ? const Color(0xFFFF4444) : Colors.white, fontSize: 16),
            ),
          ),
          if (hasToggle)
            Switch(value: true, onChanged: (v) {}, activeColor: const Color(0xFF4CAF50))
          else
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 20),
        ],
      ),
    );
  }
}

// ============================================================================
// DIALOGS
// ============================================================================

class _DailySpinDialog extends StatefulWidget {
  const _DailySpinDialog();

  @override
  State<_DailySpinDialog> createState() => _DailySpinDialogState();
}

class _DailySpinDialogState extends State<_DailySpinDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isSpinning = false;
  bool _hasSpun = false;
  int _wonAmount = 0;

  final List<int> _prizes = [500, 1000, 2500, 5000, 1000, 10000, 500, 25000];
  final List<Color> _colors = [
    const Color(0xFF2A2A2A),
    const Color(0xFFD4AF37).withValues(alpha: 0.25),
    const Color(0xFF2A2A2A),
    const Color(0xFFD4AF37).withValues(alpha: 0.35),
    const Color(0xFF2A2A2A),
    const Color(0xFFD4AF37).withValues(alpha: 0.25),
    const Color(0xFF2A2A2A),
    const Color(0xFFD4AF37).withValues(alpha: 0.45),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 4), vsync: this);
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spin() {
    if (_isSpinning || _hasSpun) return;
    setState(() => _isSpinning = true);
    _controller.reset();

    final random = Random();
    final prizeIndex = random.nextInt(_prizes.length);
    final rotations = 5 + random.nextDouble() * 3;
    // Calculate angle so that segment prizeIndex lands at the TOP (where pointer is)
    // Wheel draws segment 0 at top (-pi/2), segments go clockwise
    // Transform.rotate with positive angle rotates counter-clockwise
    // To land on segment N, rotate so that segment N aligns with the pointer at top
    final segmentAngle = 2 * pi / _prizes.length;
    // Rotate counter-clockwise: higher segments come to top
    // For segment N to be at top, we need to rotate by (N * segmentAngle) + half segment for centering
    final targetAngle = rotations * 2 * pi + (prizeIndex * segmentAngle) + (segmentAngle / 2);

    _animation = Tween<double>(
      begin: 0,
      end: targetAngle,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward().then((_) async {
      // Add the chips to the user's account
      await UserService().addChips(_prizes[prizeIndex]);
      setState(() {
        _isSpinning = false;
        _hasSpun = true;
        _wonAmount = _prizes[prizeIndex];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 360,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh_rounded, color: Colors.white.withValues(alpha: 0.7), size: 26),
                    const SizedBox(width: 10),
                    const Text(
                      'Daily Spin',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) => Transform.rotate(
                          angle: _animation.value,
                          child: CustomPaint(size: const Size(180, 180), painter: _WheelPainter(_prizes, _colors)),
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Center(
                            child: Icon(Icons.monetization_on_outlined,
                                color: Colors.white.withValues(alpha: 0.8), size: 22)),
                      ),
                      const Positioned(top: 0, child: _WheelPointer()),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                if (_hasSpun)
                  Column(
                    children: [
                      Icon(Icons.check_circle_rounded, color: const Color(0xFF22C55E), size: 48),
                      const SizedBox(height: 12),
                      Text(
                        '+$_wonAmount',
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'chips added',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Collect', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSpinning ? Colors.grey : Colors.white.withValues(alpha: 0.1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isSpinning ? null : _spin,
                      child: Text(
                        _isSpinning ? 'Spinning...' : 'SPIN FREE',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
}

class _GemWheelDialog extends StatefulWidget {
  const _GemWheelDialog();

  @override
  State<_GemWheelDialog> createState() => _GemWheelDialogState();
}

class _GemWheelDialogState extends State<_GemWheelDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isSpinning = false;
  bool _hasSpun = false;
  int _wonAmount = 0;
  static const int _spinCost = 50;

  int get _gemsBalance => UserPreferences.gems;

  final List<int> _prizes = [1000, 2500, 5000, 10000, 2500, 25000, 5000, 50000, 1000, 100000];
  final List<Color> _colors = [
    const Color(0xFF2A2A2A),
    const Color(0xFF9C27B0).withValues(alpha: 0.25),
    const Color(0xFF2A2A2A),
    const Color(0xFF9C27B0).withValues(alpha: 0.35),
    const Color(0xFF2A2A2A),
    const Color(0xFF9C27B0).withValues(alpha: 0.25),
    const Color(0xFF2A2A2A),
    const Color(0xFF9C27B0).withValues(alpha: 0.45),
    const Color(0xFF2A2A2A),
    const Color(0xFF9C27B0).withValues(alpha: 0.30),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 5), vsync: this);
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spin() async {
    if (_isSpinning || _gemsBalance < _spinCost) return;

    // Deduct gems using UserService (syncs to Firestore)
    await UserService().spendGems(_spinCost);

    setState(() {
      _isSpinning = true;
      _hasSpun = false;
    });
    _controller.reset();

    final random = Random();
    final prizeIndex = random.nextInt(_prizes.length);
    final rotations = 6 + random.nextDouble() * 4;
    final targetAngle = rotations * 2 * pi + (prizeIndex / _prizes.length) * 2 * pi;

    _animation = Tween<double>(
      begin: 0,
      end: targetAngle,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward().then((_) async {
      final wonChips = _prizes[prizeIndex];
      await UserService().addChips(wonChips);
      setState(() {
        _isSpinning = false;
        _hasSpun = true;
        _wonAmount = wonChips;
      });
    });
  }

  String _formatNumber(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K' : '$n';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
          maxWidth: 360,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.donut_large_rounded, color: Colors.white.withValues(alpha: 0.7), size: 24),
                        const SizedBox(width: 10),
                        const Text(
                          'Gem Wheel',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.diamond_outlined, color: Colors.white.withValues(alpha: 0.8), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '$_gemsBalance',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) => Transform.rotate(
                          angle: _animation.value,
                          child: CustomPaint(size: const Size(200, 200), painter: _GemWheelPainter(_prizes, _colors)),
                        ),
                      ),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Center(
                            child: Icon(Icons.diamond_outlined, color: Colors.white.withValues(alpha: 0.8), size: 24)),
                      ),
                      const Positioned(top: 0, child: _WheelPointer()),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_hasSpun)
                  Column(
                    children: [
                      Icon(Icons.check_circle_rounded, color: const Color(0xFF22C55E), size: 48),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.monetization_on_outlined, color: Colors.white.withValues(alpha: 0.7), size: 28),
                          const SizedBox(width: 8),
                          Text(
                            _formatNumber(_wonAmount),
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'chips won',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9C27B0),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _gemsBalance >= _spinCost
                                  ? () {
                                      setState(() => _hasSpun = false);
                                      _spin();
                                    }
                                  : null,
                              child: const Text('Spin Again'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSpinning ? Colors.grey : Colors.white.withValues(alpha: 0.1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isSpinning || _gemsBalance < _spinCost ? null : _spin,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isSpinning ? 'Spinning...' : 'SPIN',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          if (!_isSpinning) ...[
                            const SizedBox(width: 10),
                            Row(
                              children: [
                                Icon(Icons.diamond_outlined, color: Colors.white.withValues(alpha: 0.7), size: 16),
                                const SizedBox(width: 4),
                                const Text('50', style: TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ],
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
}

// ============================================================================
// WHEEL PAINTERS
// ============================================================================

class _WheelPointer extends StatelessWidget {
  const _WheelPointer();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(20, 16), painter: _PointerPainter());
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WheelPainter extends CustomPainter {
  final List<int> prizes;
  final List<Color> colors;
  _WheelPainter(this.prizes, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * pi / prizes.length;

    for (int i = 0; i < prizes.length; i++) {
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2 + i * segmentAngle,
        segmentAngle,
        true,
        paint,
      );

      final textAngle = -pi / 2 + i * segmentAngle + segmentAngle / 2;
      final textX = center.dx + radius * 0.65 * cos(textAngle);
      final textY = center.dy + radius * 0.65 * sin(textAngle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${prizes[i]}',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + pi / 2);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GemWheelPainter extends CustomPainter {
  final List<int> prizes;
  final List<Color> colors;
  _GemWheelPainter(this.prizes, this.colors);

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K' : '$n';

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * pi / prizes.length;

    for (int i = 0; i < prizes.length; i++) {
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2 + i * segmentAngle,
        segmentAngle,
        true,
        paint,
      );

      final textAngle = -pi / 2 + i * segmentAngle + segmentAngle / 2;
      final textX = center.dx + radius * 0.7 * cos(textAngle);
      final textY = center.dy + radius * 0.7 * sin(textAngle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: _fmt(prizes[i]),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + pi / 2);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// ACHIEVEMENT CARD
// ============================================================================

class _AchievementData {
  final String emoji;
  final String title;
  final String description;
  final bool isUnlocked;
  final double progress;

  const _AchievementData(this.emoji, this.title, this.description, this.isUnlocked, this.progress);
}

class _AchievementCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final bool isUnlocked;
  final double progress;

  const _AchievementCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.isUnlocked,
    required this.progress,
  });

  // 100 achievements - all locked for new account
  static const List<_AchievementData> _achievements = [
    // Beginner (1-10)
    _AchievementData('🏆', 'First Win', 'Win your first poker hand', false, 0.0),
    _AchievementData('🎮', 'First Game', 'Complete your first game', false, 0.0),
    _AchievementData('💵', 'First Chips', 'Earn chips from a pot', false, 0.0),
    _AchievementData('🤝', 'First Friend', 'Add your first friend', false, 0.0),
    _AchievementData('📱', 'Daily Player', 'Play 7 days in a row', false, 0.0),
    _AchievementData('⭐', 'Rising Star', 'Reach level 5', false, 0.0),
    _AchievementData('🎯', 'Sharp Shooter', 'Win 3 hands in a row', false, 0.0),
    _AchievementData('🔥', 'Hot Start', 'Win first hand of a game', false, 0.0),
    _AchievementData('💪', 'Getting Strong', 'Reach level 10', false, 0.0),
    _AchievementData('📈', 'On The Rise', 'Win 5 games total', false, 0.0),

    // Hands (11-25)
    _AchievementData('🃏', 'Royal Flush', 'Hit a Royal Flush', false, 0.0),
    _AchievementData('🎰', 'Straight Flush', 'Hit a Straight Flush', false, 0.0),
    _AchievementData('4️⃣', 'Four of a Kind', 'Hit Four of a Kind', false, 0.0),
    _AchievementData('🏠', 'Full House', 'Hit a Full House', false, 0.0),
    _AchievementData('♠️', 'Flush Master', 'Hit a Flush', false, 0.0),
    _AchievementData('📊', 'Straight Draw', 'Hit a Straight', false, 0.0),
    _AchievementData('3️⃣', 'Three of a Kind', 'Hit Three of a Kind', false, 0.0),
    _AchievementData('✌️', 'Two Pair Pro', 'Hit Two Pair', false, 0.0),
    _AchievementData('👫', 'Pair Up', 'Win with a Pair', false, 0.0),
    _AchievementData('🎲', 'Lucky 7s', 'Win with pocket 7s', false, 0.0),
    _AchievementData('♦️', 'Diamond Hand', 'Win with diamond flush', false, 0.0),
    _AchievementData('♥️', 'Heart Breaker', 'Win with heart flush', false, 0.0),
    _AchievementData('♣️', 'Club Crusher', 'Win with club flush', false, 0.0),
    _AchievementData('🂡', 'Ace High', 'Win with Ace high', false, 0.0),
    _AchievementData('👑', 'Pocket Kings', 'Win with pocket Kings', false, 0.0),

    // Wins (26-40)
    _AchievementData('🔥', 'Win Streak 3', 'Win 3 hands in a row', false, 0.0),
    _AchievementData('🔥', 'Win Streak 5', 'Win 5 hands in a row', false, 0.0),
    _AchievementData('🔥', 'Win Streak 10', 'Win 10 hands in a row', false, 0.0),
    _AchievementData('🔥', 'Win Streak 20', 'Win 20 hands in a row', false, 0.0),
    _AchievementData('🏅', '10 Wins', 'Win 10 games total', false, 0.0),
    _AchievementData('🏅', '50 Wins', 'Win 50 games total', false, 0.0),
    _AchievementData('🏅', '100 Wins', 'Win 100 games total', false, 0.0),
    _AchievementData('🏅', '500 Wins', 'Win 500 games total', false, 0.0),
    _AchievementData('🏅', '1000 Wins', 'Win 1000 games total', false, 0.0),
    _AchievementData('💯', 'Perfect Game', 'Win without losing a hand', false, 0.0),
    _AchievementData('🎯', 'Flawless Victory', 'Win with all chips doubled', false, 0.0),
    _AchievementData('⚡', 'Quick Win', 'Win a game under 5 minutes', false, 0.0),
    _AchievementData('🐢', 'Patient Win', 'Win a game over 30 minutes', false, 0.0),
    _AchievementData('🎪', 'Comeback King', 'Win after being down 90%', false, 0.0),
    _AchievementData('🦁', 'Dominant Win', 'Win with 10x starting chips', false, 0.0),

    // Chips (41-55)
    _AchievementData('💰', 'First 10K', 'Accumulate 10,000 chips', false, 0.0),
    _AchievementData('💰', 'First 100K', 'Accumulate 100,000 chips', false, 0.0),
    _AchievementData('💰', 'First Million', 'Accumulate 1,000,000 chips', false, 0.0),
    _AchievementData('💰', '10 Million', 'Accumulate 10,000,000 chips', false, 0.0),
    _AchievementData('💰', '100 Million', 'Accumulate 100,000,000 chips', false, 0.0),
    _AchievementData('🤑', 'Big Winner', 'Win 50,000 chips in one hand', false, 0.0),
    _AchievementData('💎', 'High Roller', 'Play at VIP stakes', false, 0.0),
    _AchievementData('🏦', 'Banker', 'Save 500,000 chips', false, 0.0),
    _AchievementData('💵', 'Cash Cow', 'Win 10 cash games', false, 0.0),
    _AchievementData('📦', 'Chip Collector', 'Collect daily bonus 30 times', false, 0.0),
    _AchievementData('🎁', 'Daily Bonus', 'Claim your first daily bonus', false, 0.0),
    _AchievementData('🎡', 'Spin Winner', 'Win 10,000 from the wheel', false, 0.0),
    _AchievementData('💫', 'Jackpot', 'Hit the jackpot on the wheel', false, 0.0),
    _AchievementData('🌟', 'Mega Jackpot', 'Win 100,000 from the wheel', false, 0.0),
    _AchievementData('✨', 'Ultra Jackpot', 'Win 1,000,000 from the wheel', false, 0.0),

    // Multiplayer (56-70)
    _AchievementData('⚔️', 'Duel Winner', 'Win your first heads-up duel', false, 0.0),
    _AchievementData('⚔️', '10 Duels Won', 'Win 10 heads-up duels', false, 0.0),
    _AchievementData('⚔️', '50 Duels Won', 'Win 50 heads-up duels', false, 0.0),
    _AchievementData('👥', 'Table Regular', 'Play 50 multiplayer games', false, 0.0),
    _AchievementData('🎭', 'Social Player', 'Play with 20 different players', false, 0.0),
    _AchievementData('🗣️', 'Chatty', 'Send 100 chat messages', false, 0.0),
    _AchievementData('👋', 'Friendly', 'Add 10 friends', false, 0.0),
    _AchievementData('🤜', 'Rival', 'Beat the same player 5 times', false, 0.0),
    _AchievementData('🏰', 'Private Host', 'Host 10 private games', false, 0.0),
    _AchievementData('🎪', 'Party Starter', 'Fill a table with friends', false, 0.0),
    _AchievementData('👑', 'Table King', 'Win 5 games at same table', false, 0.0),
    _AchievementData('🌍', 'World Player', 'Play in 5 time zones', false, 0.0),
    _AchievementData('🌎', 'Globe Trotter', 'Play in 10 countries', false, 0.0),
    _AchievementData('🏆', 'Tournament Win', 'Win a Sit & Go tournament', false, 0.0),
    _AchievementData('🥇', 'Champion', 'Win 10 Sit & Go tournaments', false, 0.0),

    // Bluffing (71-80)
    _AchievementData('🎭', 'Bluff Master', 'Win with a bluff 10 times', false, 0.0),
    _AchievementData('🤥', 'Big Bluff', 'Win an all-in bluff', false, 0.0),
    _AchievementData('😏', 'Stone Cold', 'Bluff successfully 5 times in one game', false, 0.0),
    _AchievementData('🎪', 'Show Stopper', 'Win with high card only', false, 0.0),
    _AchievementData('🃏', 'Wild Card', 'Win with 7-2 offsuit', false, 0.0),
    _AchievementData('🎲', 'Risk Taker', 'Go all-in preflop 10 times', false, 0.0),
    _AchievementData('😎', 'Cool Under Pressure', 'Win when down to 1 big blind', false, 0.0),
    _AchievementData('🧊', 'Ice Cold', 'Fold pocket Aces preflop', false, 0.0),
    _AchievementData('🔮', 'Mind Reader', 'Call a bluff correctly 10 times', false, 0.0),
    _AchievementData('🎯', 'Perfect Read', 'Predict opponent cards correctly', false, 0.0),

    // All-In (81-90)
    _AchievementData('🌟', 'All In Win', 'Win your first all-in', false, 0.0),
    _AchievementData('🌟', '10 All In Wins', 'Win 10 all-in hands', false, 0.0),
    _AchievementData('🌟', '50 All In Wins', 'Win 50 all-in hands', false, 0.0),
    _AchievementData('🌟', '100 All In Wins', 'Win 100 all-in hands', false, 0.0),
    _AchievementData('💥', 'Double Up', 'Double your chips in one hand', false, 0.0),
    _AchievementData('💥', 'Triple Up', 'Triple your chips in one hand', false, 0.0),
    _AchievementData('🚀', 'Moon Shot', 'Win 10x your bet in one hand', false, 0.0),
    _AchievementData('☄️', 'Comet', 'Win 5 all-ins in a row', false, 0.0),
    _AchievementData('🌌', 'Galaxy Brain', 'Win 10 all-ins in a row', false, 0.0),
    _AchievementData('👑', 'All In King', 'Win 20 all-ins in a row', false, 0.0),

    // Special (91-100)
    _AchievementData('🎄', 'Holiday Special', 'Play on Christmas Day', false, 0.0),
    _AchievementData('🎃', 'Spooky Win', 'Win on Halloween', false, 0.0),
    _AchievementData('❤️', 'Valentine Luck', 'Win on Valentine\'s Day', false, 0.0),
    _AchievementData('🍀', 'St Patrick', 'Win on St. Patrick\'s Day', false, 0.0),
    _AchievementData('🎆', 'New Year', 'Play on New Year\'s Day', false, 0.0),
    _AchievementData('🌙', 'Night Owl', 'Play between 12am and 4am', false, 0.0),
    _AchievementData('🌅', 'Early Bird', 'Play between 5am and 7am', false, 0.0),
    _AchievementData('📅', 'Weekly Streak', 'Play every day for a week', false, 0.0),
    _AchievementData('🗓️', 'Monthly Streak', 'Play every day for a month', false, 0.0),
    _AchievementData('👑', 'Legend', 'Unlock all other achievements', false, 0.0),
  ];

  factory _AchievementCard.fromIndex(int index) {
    final data = _achievements[index];
    return _AchievementCard(
      emoji: data.emoji,
      title: data.title,
      description: data.description,
      isUnlocked: data.isUnlocked,
      progress: data.progress,
    );
  }

  void _showAchievementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isUnlocked ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isUnlocked ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isUnlocked ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(emoji, style: TextStyle(fontSize: 26, color: isUnlocked ? null : Colors.grey)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: isUnlocked ? Colors.white.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  description,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              if (isUnlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white.withValues(alpha: 0.6), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'UNLOCKED',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                )
              else if (progress > 0)
                Column(
                  children: [
                    Text(
                      '${(progress * 100).toInt()}% Complete',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.4)),
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, color: Colors.white.withValues(alpha: 0.3), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'LOCKED',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAchievementDialog(context),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isUnlocked ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isUnlocked ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isUnlocked ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(emoji, style: TextStyle(fontSize: 16, color: isUnlocked ? null : Colors.grey)),
                  ),
                ),
                if (isUnlocked)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0A0A0A), width: 1.5),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 7),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isUnlocked ? Colors.white.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.5),
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (!isUnlocked && progress > 0 && progress < 1) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                  minHeight: 3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// RANK TIER WIDGET
// ============================================================================

class _RankTier extends StatelessWidget {
  final String name;
  final Color color;
  final bool isActive;

  const _RankTier({required this.name, required this.color, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(6),
            border: isActive ? Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1) : null,
          ),
          child: Center(
            child: Icon(
              Icons.military_tech,
              size: 14,
              color: isActive ? Colors.white.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          name,
          style: TextStyle(
            color: isActive ? Colors.white.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.25),
            fontSize: 8,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// CUSTOMIZATION CARD - Simplified
// ============================================================================

class _CustomizationCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String price;
  final bool isOwned;

  const _CustomizationCard({required this.emoji, required this.name, required this.price, this.isOwned = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!isOwned) {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: const Color(0xFF121212),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('💎', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          price,
                          style: const TextStyle(color: Color(0xFF2196F3), fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Purchased $name!'), backgroundColor: const Color(0xFF4CAF50)),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2196F3),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Buy', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
      child: Container(
        width: 90,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOwned ? const Color(0xFF4CAF50).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOwned ? const Color(0xFF4CAF50).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (isOwned)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: const Color(0xFF4CAF50), size: 12),
                  const SizedBox(width: 4),
                  const Text(
                    'Owned',
                    style: TextStyle(color: Color(0xFF4CAF50), fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💎', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 4),
                  Text(
                    price,
                    style: const TextStyle(color: Color(0xFF2196F3), fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CHEST CARD
// ============================================================================

class _ChestCard extends StatelessWidget {
  final String name;
  final String emoji;
  final int price;
  final List<String> rewards;
  final List<Color> gradient;

  const _ChestCard({
    required this.name,
    required this.emoji,
    required this.price,
    required this.rewards,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showChestDialog(context),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [gradient[0].withValues(alpha: 0.3), gradient[1].withValues(alpha: 0.15)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: gradient[0].withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: gradient[0].withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 32))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: rewards
                        .take(3)
                        .map(
                          (reward) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              reward,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: gradient[0], borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Text('💎', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    price.toString(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 50))),
              ),
              const SizedBox(height: 20),
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Possible Rewards:',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...rewards.map(
                      (reward) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(Icons.star, color: gradient[0], size: 16),
                            const SizedBox(width: 8),
                            Text(reward, style: const TextStyle(color: Colors.white, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showChestOpenAnimation(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gradient[0],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('💎', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            'Open ($price)',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ],
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
  }

  void _showChestOpenAnimation(BuildContext context) {
    // Simulate random reward
    final randomReward = rewards[DateTime.now().millisecond % rewards.length];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 20),
              const Text(
                '🎉 You Got! 🎉',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  randomReward,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Collect',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// FRIEND AVATAR EXPANDED
// ============================================================================

class _FriendAvatarExpanded extends StatelessWidget {
  final String name;
  final bool isOnline;
  final VoidCallback onChallenge;
  final VoidCallback onGift;

  const _FriendAvatarExpanded({
    required this.name,
    required this.isOnline,
    required this.onChallenge,
    required this.onGift,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFriendOptions(context),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    name[0],
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (isOnline)
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
          const SizedBox(height: 6),
          Text(name, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
        ],
      ),
    );
  }

  void _showFriendOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile Header
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(
                    name[0],
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF4CAF50) : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOnline ? 'Online Now' : 'Last seen 2h ago',
                    style: TextStyle(color: isOnline ? const Color(0xFF4CAF50) : Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Rank Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                ),
                child: const Text(
                  '🏆 Gold III',
                  style: TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),
              // Stats Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ProfileStat(label: 'Games', value: '1,247'),
                        ),
                        Expanded(
                          child: _ProfileStat(label: 'Wins', value: '623'),
                        ),
                        Expanded(
                          child: _ProfileStat(label: 'Win Rate', value: '50%'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ProfileStat(label: 'Best Hand', value: 'Royal Flush'),
                        ),
                        Expanded(
                          child: _ProfileStat(label: 'Biggest Pot', value: '125K'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Achievements Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: const [
                    Text('🏆', style: TextStyle(fontSize: 24)),
                    Text('⭐', style: TextStyle(fontSize: 24)),
                    Text('🎯', style: TextStyle(fontSize: 24)),
                    Text('💎', style: TextStyle(fontSize: 24)),
                    Text('🔥', style: TextStyle(fontSize: 24)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onChallenge();
                      },
                      icon: const Text('⚔️', style: TextStyle(fontSize: 16)),
                      label: const Text('Challenge'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onGift();
                      },
                      icon: const Text('🎁', style: TextStyle(fontSize: 16)),
                      label: const Text('Gift'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to friends!'), backgroundColor: Color(0xFF2196F3)),
                  );
                },
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add Friend'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PROFILE STAT
// ============================================================================

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
      ],
    );
  }
}

// ============================================================================
// STAKE OPTION
// ============================================================================

class _StakeOption extends StatelessWidget {
  final String amount;
  final bool isSelected;

  const _StakeOption({required this.amount, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFE91E63).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isSelected ? const Color(0xFFE91E63) : Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            amount,
            style: TextStyle(
              color: isSelected ? const Color(0xFFE91E63) : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// GIFT OPTION
// ============================================================================

class _GiftOption extends StatelessWidget {
  final String emoji;
  final String label;
  final String amount;
  final bool isSelected;

  const _GiftOption({required this.emoji, required this.label, required this.amount, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF4CAF50).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isSelected ? const Color(0xFF4CAF50) : Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              color: isSelected ? const Color(0xFF4CAF50) : Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TIER REWARD
// ============================================================================

class _TierReward extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isFree;

  const _TierReward({required this.emoji, required this.label, required this.isFree});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16))),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9)),
        if (!isFree)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👑', style: TextStyle(fontSize: 7)),
              const SizedBox(width: 2),
              Text('Premium', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 7)),
            ],
          ),
      ],
    );
  }
}

// ============================================================================
// PREMIUM BENEFIT - Simplified
// ============================================================================

class _PremiumBenefit extends StatelessWidget {
  final String icon;
  final String text;

  const _PremiumBenefit({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}

// ============================================================================
// CHIP GRAPH PAINTER
// ============================================================================

class _ChipGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Sample data points (normalized 0-1)
    final dataPoints = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]; // All at 50% for new player

    final paint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF4CAF50).withValues(alpha: 0.3), const Color(0xFF4CAF50).withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();
    final stepWidth = size.width / (dataPoints.length - 1);

    // Start the path
    final firstY = size.height * (1 - dataPoints[0]);
    path.moveTo(0, firstY);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, firstY);

    // Draw the line and fill
    for (int i = 1; i < dataPoints.length; i++) {
      final x = stepWidth * i;
      final y = size.height * (1 - dataPoints[i]);
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    // Complete the fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw fill first, then line
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw dots at each point
    final dotPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < dataPoints.length; i++) {
      final x = stepWidth * i;
      final y = size.height * (1 - dataPoints[i]);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(
        Offset(x, y),
        6,
        Paint()
          ..color = const Color(0xFF4CAF50).withValues(alpha: 0.3)
          ..style = PaintingStyle.fill,
      );
    }

    // Draw baseline
    final baselinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), baselinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Lucky Hand Dialog - Shows today's lucky hand bonus
class _LuckyHandDialog extends StatelessWidget {
  const _LuckyHandDialog();

  @override
  Widget build(BuildContext context) {
    final luckyHand = UserPreferences.todaysLuckyHand;
    final winsToday = UserPreferences.luckyHandWinsToday;
    final totalEarned = winsToday * luckyHand.bonusReward;

    return Dialog(
      backgroundColor: const Color(0xFF121212),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
          maxWidth: 360,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(luckyHand.emoji, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    const Text(
                      'Lucky Hand',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Resets daily at midnight',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                ),
                const SizedBox(height: 24),

                // Today's Lucky Hand Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFD4AF37).withValues(alpha: 0.2),
                        const Color(0xFFD4AF37).withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "TODAY'S LUCKY HAND",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        luckyHand.name,
                        style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        luckyHand.description,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🪙', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              '+${UserPreferences.formatChips(luckyHand.bonusReward)}',
                              style:
                                  const TextStyle(color: Color(0xFF22C55E), fontSize: 20, fontWeight: FontWeight.w700),
                            ),
                            Text(' per win',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Today's Stats
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            winsToday.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                          ),
                          Text('Wins Today',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                        ],
                      ),
                      Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.1)),
                      Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🪙', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 4),
                              Text(
                                UserPreferences.formatChips(totalEarned),
                                style: const TextStyle(
                                    color: Color(0xFF22C55E), fontSize: 24, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          Text('Earned Today',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // How it works
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF2196F3), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Win any game with a ${luckyHand.name} to earn the bonus!',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Got it!', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// BROWSE TEAMS SHEET
// ============================================================================

class _BrowseTeamsSheet extends StatefulWidget {
  final TeamService teamService;
  final Future<void> Function() onJoin;

  const _BrowseTeamsSheet({required this.teamService, required this.onJoin});

  @override
  State<_BrowseTeamsSheet> createState() => _BrowseTeamsSheetState();
}

class _BrowseTeamsSheetState extends State<_BrowseTeamsSheet> {
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
