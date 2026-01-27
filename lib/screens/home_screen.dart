import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import '../widgets/mobile_wrapper.dart';
import '../widgets/friends_widgets.dart';
import '../models/friend.dart';
import '../services/friends_service.dart';
import 'game_screen.dart';
import 'lobby_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1;

  @override
  Widget build(BuildContext context) {
    return MobileWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            _ShopTab(),
            _HomeTab(),
            _ProfileTab(),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, Icons.shopping_bag_outlined, Icons.shopping_bag),
            _buildNavItem(1, Icons.home_outlined, Icons.home_rounded),
            _buildNavItem(2, Icons.person_outline_rounded, Icons.person_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          isActive ? activeIcon : icon,
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
          size: 26,
        ),
      ),
    );
  }
}

// ============================================================================
// HOME TAB - Main Play Screen
// ============================================================================

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  bool _clubExpanded = false;
  final FriendsService _friendsService = FriendsService();
  List<Friend> _friends = [];
  int _unreadNotifications = 0;
  int _pendingFriendRequests = 0;
  StreamSubscription? _friendsSub;
  StreamSubscription? _notificationsSub;
  StreamSubscription? _requestsSub;

  @override
  void initState() {
    super.initState();
    _friendsService.initialize();
    _loadFriendsData();
    
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

  @override
  void dispose() {
    _friendsSub?.cancel();
    _notificationsSub?.cancel();
    _requestsSub?.cancel();
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
          child: NotificationPanel(
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddFriendDialog(),
    );
  }

  void _showFriendsListDialog() {
    showDialog(
      context: context,
      builder: (context) => const FriendsListDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // App Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('👤', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Greeting
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                        const Text(
                          'Player123',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification Bell
                  GestureDetector(
                    onTap: _showNotificationPanel,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(
                              Icons.notifications_outlined,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 22,
                            ),
                          ),
                          if (_unreadNotifications > 0 || _pendingFriendRequests > 0)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF4444),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${_unreadNotifications + _pendingFriendRequests}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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

          // Balance Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _BalanceCard(
                      emoji: '🪙',
                      label: 'Chips',
                      value: '1,000',
                      gradient: const [Color(0xFFD4AF37), Color(0xFFB8860B)],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BalanceCard(
                      emoji: '💎',
                      label: 'Gems',
                      value: '100',
                      gradient: const [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick Actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _QuickPlayCard(
                      title: 'MULTIPLAYER',
                      subtitle: 'Play Now',
                      emoji: '🎮',
                      gradient: const [Color(0xFF1E88E5), Color(0xFF1565C0)],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LobbyScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickPlayCard(
                      title: 'PRACTICE',
                      subtitle: 'vs AI',
                      emoji: '🤖',
                      gradient: const [Color(0xFF43A047), Color(0xFF2E7D32)],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GameScreen(gameMode: 'Practice'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Private Room Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showCreateRoomDialog(context),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF4CAF50).withValues(alpha: 0.2),
                              const Color(0xFF4CAF50).withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Text('➕', style: TextStyle(fontSize: 22)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Create Room',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Host a private game',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showJoinRoomDialog(context),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF2196F3).withValues(alpha: 0.2),
                              const Color(0xFF2196F3).withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Text('🔗', style: TextStyle(fontSize: 22)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Join Room',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Enter room code',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
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

          // Club Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _clubExpanded = !_clubExpanded),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFE91E63).withValues(alpha: 0.15),
                            const Color(0xFFE91E63).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE91E63).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE91E63).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(child: Text('🎯', style: TextStyle(fontSize: 24))),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Club',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Join or create a club',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: _clubExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_clubExpanded) ...[                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '🎯',
                            style: TextStyle(fontSize: 40),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No Club Yet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Join a club to compete in championships\nand earn exclusive rewards!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {},
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFE91E63)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Create Club',
                                    style: TextStyle(color: Color(0xFFE91E63)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE91E63),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Join Club',
                                    style: TextStyle(color: Colors.white),
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

          // Bottom spacing
          const SliverToBoxAdapter(
            child: SizedBox(height: 30),
          ),
        ],
      ),
    );
  }

  void _showCreateRoomDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text('➕', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Create Private Room',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your room code will be generated',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LobbyScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Create Room',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
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
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text('🔗', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Join Private Room',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the room code from your friend',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: codeController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: 'XXXXXX',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    letterSpacing: 8,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (codeController.text.length == 6) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LobbyScreen()),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Join Room',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
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
// SHOP TAB
// ============================================================================

class _ShopTab extends StatefulWidget {
  const _ShopTab();

  @override
  State<_ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<_ShopTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedCategory = 0;

  final List<Map<String, dynamic>> _categories = [
    {'icon': '🎁', 'name': 'Featured'},
    {'icon': '💎', 'name': 'Currency'},
    {'icon': '🎨', 'name': 'Cosmetics'},
    {'icon': '📦', 'name': 'Chests'},
  ];

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
          // Header with balance
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Shop',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    _BalanceChip(emoji: '🪙', amount: '50,000', color: const Color(0xFFD4AF37)),
                    const SizedBox(width: 8),
                    _BalanceChip(emoji: '💎', amount: '100', color: const Color(0xFF9C27B0)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Category Tabs
          Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                color: const Color(0xFF2196F3),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(3),
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: _categories.map((cat) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(cat['icon'], style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(cat['name']),
                  ],
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),
          
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFeaturedTab(),
                _buildCurrencyTab(),
                _buildCosmeticsTab(),
                _buildChestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Daily Bonus Banner
          GestureDetector(
            onTap: () => _showDailySpinDialog(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Text('🎡', style: TextStyle(fontSize: 36)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'DAILY BONUS',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Free Daily Spin!',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Win chips, gems & more',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'CLAIM',
                      style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Premium Wheel
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showGemWheelDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF9C27B0).withValues(alpha: 0.5),
                          const Color(0xFFE91E63).withValues(alpha: 0.4),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        const Text('🎰', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        const Text(
                          'Gem Wheel',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Win up to 100K',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('💎', style: TextStyle(fontSize: 14)),
                              SizedBox(width: 4),
                              Text('50', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showLuckyHandDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFD4AF37).withValues(alpha: 0.5),
                          const Color(0xFFFF9800).withValues(alpha: 0.4),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        const Text('🃏', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        const Text(
                          'Lucky Hand',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mystery bonus',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'FREE',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
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
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'Hot Deals',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'LIMITED',
                  style: TextStyle(color: Color(0xFFE91E63), fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          
          // Starter Pack
          _HotDealCard(
            title: 'Starter Pack',
            subtitle: 'Perfect for new players',
            emoji: '🚀',
            items: ['10,000 Chips', '50 Gems', 'Gold Card Back'],
            price: '\$2.99',
            originalPrice: '\$5.99',
            gradient: [const Color(0xFF2196F3), const Color(0xFF1565C0)],
          ),
          const SizedBox(height: 12),
          
          // VIP Bundle
          _HotDealCard(
            title: 'VIP Bundle',
            subtitle: 'Best value pack',
            emoji: '👑',
            items: ['100,000 Chips', '500 Gems', 'Royal Set'],
            price: '\$19.99',
            originalPrice: '\$49.99',
            gradient: [const Color(0xFFD4AF37), const Color(0xFFB8860B)],
            isBest: true,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildCurrencyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gems Section
          const _SectionLabel(emoji: '💎', title: 'Gems'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _CurrencyCard(emoji: '💎', amount: '100', price: '\$0.99', color: const Color(0xFF9C27B0))),
              const SizedBox(width: 10),
              Expanded(child: _CurrencyCard(emoji: '💎', amount: '500', price: '\$4.99', color: const Color(0xFF9C27B0), bonus: '+50')),
              const SizedBox(width: 10),
              Expanded(child: _CurrencyCard(emoji: '💎', amount: '1,200', price: '\$9.99', color: const Color(0xFF9C27B0), bonus: '+200', isBest: true)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _CurrencyCard(emoji: '💎', amount: '2,500', price: '\$19.99', color: const Color(0xFF9C27B0), bonus: '+500')),
              const SizedBox(width: 10),
              Expanded(child: _CurrencyCard(emoji: '💎', amount: '6,500', price: '\$49.99', color: const Color(0xFF9C27B0), bonus: '+1500')),
              const SizedBox(width: 10),
              Expanded(child: _CurrencyCard(emoji: '💎', amount: '14K', price: '\$99.99', color: const Color(0xFF9C27B0), bonus: '+4000')),
            ],
          ),
          const SizedBox(height: 28),
          
          // Chips Section
          const _SectionLabel(emoji: '🪙', title: 'Chips'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _CurrencyCard(emoji: '🪙', amount: '10K', price: '\$0.99', color: const Color(0xFFD4AF37))),
              const SizedBox(width: 10),
              Expanded(child: _CurrencyCard(emoji: '🪙', amount: '50K', price: '\$4.99', color: const Color(0xFFD4AF37), bonus: '+5K')),
              const SizedBox(width: 10),
              Expanded(child: _CurrencyCard(emoji: '🪙', amount: '150K', price: '\$9.99', color: const Color(0xFFD4AF37), bonus: '+25K', isBest: true)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _CurrencyCard(emoji: '🪙', amount: '500K', price: '\$19.99', color: const Color(0xFFD4AF37), bonus: '+100K')),
              const SizedBox(width: 10),
              Expanded(child: _CurrencyCard(emoji: '🪙', amount: '1.5M', price: '\$49.99', color: const Color(0xFFD4AF37), bonus: '+350K')),
              const SizedBox(width: 10),
              Expanded(child: _CurrencyCard(emoji: '🪙', amount: '5M', price: '\$99.99', color: const Color(0xFFD4AF37), bonus: '+1.5M')),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildCosmeticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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

  static void _showDailySpinDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _DailySpinDialog(),
    );
  }

  static void _showGemWheelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _GemWheelDialog(),
    );
  }

  static void _showLuckyHandDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _LuckyHandDialog(),
    );
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
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            amount,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
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
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// Currency card widget
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
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBest ? color : color.withValues(alpha: 0.3),
          width: isBest ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          if (isBest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'BEST VALUE',
                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
              ),
            )
          else if (bonus != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                bonus!,
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
              ),
            )
          else
            const SizedBox(height: 18),
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 4),
          Text(
            amount,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              price,
              style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700),
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

  const _CosmeticItem({
    required this.emoji,
    required this.name,
    required this.price,
    this.isOwned = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isOwned ? null : () => _showPurchaseDialog(context),
      child: Container(
        width: 90,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
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
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💎', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(price, style: const TextStyle(color: Color(0xFF9C27B0), fontSize: 20, fontWeight: FontWeight.w700)),
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
                      child: const Text('Buy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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

  const _CosmeticItemData({
    required this.emoji,
    required this.name,
    required this.price,
    this.isOwned = false,
  });
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Rarity sub-dropdowns
          if (_isExpanded) ...[
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            _RaritySubDropdown(
              rarity: 'Common',
              color: const Color(0xFF9E9E9E),
              items: widget.commonItems,
            ),
            _RaritySubDropdown(
              rarity: 'Rare',
              color: const Color(0xFF2196F3),
              items: widget.rareItems,
            ),
            _RaritySubDropdown(
              rarity: 'Epic',
              color: const Color(0xFF9C27B0),
              items: widget.epicItems,
            ),
            _RaritySubDropdown(
              rarity: 'Legendary',
              color: const Color(0xFFD4AF37),
              items: widget.legendaryItems,
            ),
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

  const _RaritySubDropdown({
    required this.rarity,
    required this.color,
    required this.items,
  });

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
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.08),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.rarity,
                    style: TextStyle(
                      color: widget.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${widget.items.length} items',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 20,
                  ),
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
              children: widget.items.map((item) => _CosmeticGridItem(
                emoji: item.emoji,
                name: item.name,
                price: item.price,
                isOwned: item.isOwned,
                rarityColor: widget.color,
              )).toList(),
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
            color: isOwned 
                ? const Color(0xFF4CAF50).withValues(alpha: 0.5) 
                : rarityColor.withValues(alpha: 0.3),
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
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💎', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(price, style: TextStyle(color: rarityColor, fontSize: 20, fontWeight: FontWeight.w700)),
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
                      child: const Text('Buy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
  final String emoji;
  final List<String> items;
  final String price;
  final String originalPrice;
  final List<Color> gradient;
  final bool isBest;

  const _HotDealCard({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.items,
    required this.price,
    required this.originalPrice,
    required this.gradient,
    this.isBest = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradient[0].withValues(alpha: 0.3), gradient[1].withValues(alpha: 0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gradient[0].withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: gradient[0].withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 32))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    if (isBest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('BEST', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: items.map((item) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(item, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 9)),
                  )).toList(),
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
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: gradient[0],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Modern chest card widget
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
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: gradient[0].withValues(alpha: isBest ? 0.8 : 0.4), width: isBest ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: gradient[0].withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: gradient[0].withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(rarity, style: TextStyle(color: gradient[0], fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: rewards.map((reward) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(reward, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
                    )).toList(),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: gradient[0],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Text('💎', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(price.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: gradient[0].withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(rarity, style: TextStyle(color: gradient[0], fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 20),
              Text('Possible Rewards:', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
              const SizedBox(height: 10),
              ...rewards.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: gradient[0], size: 16),
                    const SizedBox(width: 8),
                    Text(r, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              )),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opened $name!'), backgroundColor: gradient[0]),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gradient[0],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text('Open for $price', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
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
  const _ProfileTab();

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

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _friendsSub = _friendsService.friendsStream.listen((friends) {
      if (mounted) setState(() => _friends = friends);
    });
  }

  @override
  void dispose() {
    _friendsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final friends = await _friendsService.getAllFriends();
    if (mounted) setState(() => _friends = friends);
  }

  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddFriendDialog(),
    );
  }

  void _showFriendsListDialog() {
    showDialog(
      context: context,
      builder: (context) => const FriendsListDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Profile Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showSettings(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.settings_outlined,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Profile Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFD4AF37).withValues(alpha: 0.15),
                      const Color(0xFFD4AF37).withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: Text('👤', style: TextStyle(fontSize: 36)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Player123',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.military_tech, color: Color(0xFF9E9E9E), size: 16),
                          const SizedBox(width: 4),
                          const Text(
                            'Unranked',
                            style: TextStyle(
                              color: Color(0xFF9E9E9E),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
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

          // Ranked Season Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF9C27B0).withValues(alpha: 0.2),
                      const Color(0xFF673AB7).withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9C27B0), Color(0xFF673AB7)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text('🏅', style: TextStyle(fontSize: 22)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Season 1',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        color: Color(0xFF4CAF50),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '28 days remaining',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Bronze III',
                              style: TextStyle(
                                color: Color(0xFFCD7F32),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '0 / 100 RP',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Rank tiers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _RankTier(name: 'Bronze', color: const Color(0xFFCD7F32), isActive: true),
                        _RankTier(name: 'Silver', color: const Color(0xFFC0C0C0), isActive: false),
                        _RankTier(name: 'Gold', color: const Color(0xFFFFD700), isActive: false),
                        _RankTier(name: 'Platinum', color: const Color(0xFFE5E4E2), isActive: false),
                        _RankTier(name: 'Diamond', color: const Color(0xFF00BCD4), isActive: false),
                        _RankTier(name: 'Champion', color: const Color(0xFFFF6B35), isActive: false),
                        _RankTier(name: 'Legend', color: const Color(0xFF9C27B0), isActive: false),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Progress bar
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          height: 8,
                          width: 0, // 0% progress
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFCD7F32), Color(0xFFB87333)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Win ranked games to earn RP and climb!',
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
            ),
          ),

          // Friends Online
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FRIENDS',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      GestureDetector(
                        onTap: _showFriendsListDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_friends.where((f) => f.isOnline).length} online',
                            style: const TextStyle(
                              color: Color(0xFF4CAF50),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        if (_friends.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                Icon(Icons.people_outline, 
                                    color: Colors.white.withValues(alpha: 0.3), size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  'No friends yet',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Add friends to play together!',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: _friends.take(4).map((friend) => 
                              _FriendAvatarExpanded(
                                name: friend.username, 
                                isOnline: friend.isOnline, 
                                onChallenge: () => _showChallengeDialog(context, friend.username),
                                onGift: () => _showGiftDialog(context, friend.username),
                              ),
                            ).toList(),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _showAddFriendDialog,
                                icon: const Icon(Icons.person_add_outlined, size: 18),
                                label: const Text('Add Friend'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _showFriendsListDialog,
                                icon: const Icon(Icons.people_outline, size: 18),
                                label: const Text('View All'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
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
          ),

          // Statistics Dropdown
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _statisticsExpanded = !_statisticsExpanded),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2196F3).withValues(alpha: 0.15),
                            const Color(0xFF2196F3).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(child: Text('📊', style: TextStyle(fontSize: 24))),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Statistics',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '0 games played',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: _statisticsExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 28,
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: _StatCard(value: '0', label: 'Games')),
                        const SizedBox(width: 10),
                        const Expanded(child: _StatCard(value: '0', label: 'Wins')),
                        const SizedBox(width: 10),
                        const Expanded(child: _StatCard(value: '0%', label: 'Win Rate')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Expanded(child: _StatCard(value: '0', label: 'Best Streak')),
                        const SizedBox(width: 10),
                        const Expanded(child: _StatCard(value: '0', label: 'Earnings')),
                        const SizedBox(width: 10),
                        const Expanded(child: _StatCard(value: 'Lv.1', label: 'Level')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Expanded(child: _StatCard(value: '-', label: 'Rank')),
                        const SizedBox(width: 10),
                        const Expanded(child: _StatCard(value: '1,000', label: 'ELO')),
                        const SizedBox(width: 10),
                        const Expanded(child: _StatCard(value: '0', label: 'Trophies')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Expanded(child: _StatCard(value: '0', label: 'Duels Won')),
                        const SizedBox(width: 10),
                        const Expanded(child: _StatCard(value: '0', label: 'Tournaments')),
                        const SizedBox(width: 10),
                        const Expanded(child: _StatCard(value: '0', label: 'Hands')),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Profit/Loss Graph
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Chip Balance History',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '7 Days',
                                  style: TextStyle(
                                    color: Color(0xFF4CAF50),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Simple line graph representation
                          SizedBox(
                            height: 100,
                            child: CustomPaint(
                              size: const Size(double.infinity, 100),
                              painter: _ChipGraphPainter(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Mon',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                'Tue',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                'Wed',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                'Thu',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                'Fri',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                'Sat',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                'Sun',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 10,
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
            ),

          // Achievements Dropdown
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _achievementsExpanded = !_achievementsExpanded),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFD4AF37).withValues(alpha: 0.15),
                            const Color(0xFFD4AF37).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(child: Text('🏆', style: TextStyle(fontSize: 24))),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Achievements',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '0 / 100 Unlocked',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: _achievementsExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 28,
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _AchievementCard.fromIndex(index),
                  childCount: 100,
                ),
              ),
            ),

          // Season Pass
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SEASON PASS',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'FREE',
                          style: TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4CAF50).withValues(alpha: 0.15),
                          const Color(0xFF4CAF50).withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text('🏆', style: TextStyle(fontSize: 24)),
                                const SizedBox(width: 10),
                                const Text(
                                  'Tier 1',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '0 / 1000 XP',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: 0.0,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                        const SizedBox(height: 16),
                        // Premium Pass Button - integrated into Season Pass
                        GestureDetector(
                          onTap: () => _showPremiumPassDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: Text('👑', style: TextStyle(fontSize: 18)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Premium Pass',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          'Unlock exclusive rewards & 2x XP!',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.8),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('💎', style: TextStyle(fontSize: 12)),
                                      const SizedBox(width: 4),
                                      const Text(
                                        '500',
                                        style: TextStyle(
                                          color: Color(0xFFB8860B),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
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

          // Referral Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _referralExpanded = !_referralExpanded),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4CAF50).withValues(alpha: 0.15),
                            const Color(0xFF4CAF50).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(child: Text('🎁', style: TextStyle(fontSize: 24))),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Invite Friends',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Earn rewards for referrals',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: _referralExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_referralExpanded) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Your Referral Code',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 13,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '0 invited',
                                  style: TextStyle(
                                    color: Color(0xFF4CAF50),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'ALLIN-ABC123',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () {},
                                  child: Icon(
                                    Icons.copy,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Rewards per friend',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
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
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
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
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 11,
                                    ),
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
          const SliverToBoxAdapter(
            child: SizedBox(height: 40),
          ),
        ],
      ),
    );
  }

  void _showChallengeDialog(BuildContext context, String friendName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text('⚔️', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Challenge $friendName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Send a heads-up duel challenge!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select Stakes',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text('🎁', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Gift to $friendName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _GiftOption(
                      emoji: '🪙',
                      label: 'Chips',
                      amount: '1,000',
                      isSelected: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GiftOption(
                      emoji: '💎',
                      label: 'Gems',
                      amount: '10',
                      isSelected: false,
                    ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: 360,
          ),
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Text('👑', style: TextStyle(fontSize: 40)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Premium Pass',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock exclusive rewards!',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
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
                          const SnackBar(
                            content: Text('Premium Pass purchased!'),
                            backgroundColor: Color(0xFFD4AF37),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('💎', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          const Text(
                            'Buy for 500 Gems',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Maybe Later',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
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
              const Divider(color: Colors.white12, height: 24),
              _SettingsItem(icon: Icons.logout, title: 'Log Out', isDestructive: true),
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

  const _BalanceCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradient[0].withValues(alpha: 0.2), gradient[1].withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gradient[0].withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.add_circle_outline, color: Colors.white.withValues(alpha: 0.4), size: 22),
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
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

  const _ShopItemCard({
    required this.emoji,
    required this.amount,
    required this.price,
    this.isBest = false,
  });

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
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'BEST',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              price,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
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
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  name[0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
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
        Text(
          name,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool hasToggle;
  final bool isDestructive;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.hasToggle = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            icon,
            color: isDestructive ? const Color(0xFFFF4444) : Colors.white.withValues(alpha: 0.7),
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isDestructive ? const Color(0xFFFF4444) : Colors.white,
                fontSize: 16,
              ),
            ),
          ),
          if (hasToggle)
            Switch(
              value: true,
              onChanged: (v) {},
              activeColor: const Color(0xFF4CAF50),
            )
          else
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
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

class _DailySpinDialogState extends State<_DailySpinDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isSpinning = false;
  bool _hasSpun = false;
  int _wonAmount = 0;

  final List<int> _prizes = [500, 1000, 2500, 5000, 1000, 10000, 500, 25000];
  final List<Color> _colors = [
    const Color(0xFFE53935),
    const Color(0xFF1E88E5),
    const Color(0xFF43A047),
    const Color(0xFFFB8C00),
    const Color(0xFF8E24AA),
    const Color(0xFF00ACC1),
    const Color(0xFFD81B60),
    const Color(0xFFFFB300),
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
    final targetAngle = rotations * 2 * pi + (prizeIndex / _prizes.length) * 2 * pi;
    
    _animation = Tween<double>(begin: 0, end: targetAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    
    _controller.forward().then((_) {
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
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🎡 Daily Spin',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) => Transform.rotate(
                      angle: _animation.value,
                      child: CustomPaint(
                        size: const Size(180, 180),
                        painter: _WheelPainter(_prizes, _colors),
                      ),
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
                    child: const Center(child: Text('🪙', style: TextStyle(fontSize: 18))),
                  ),
                  const Positioned(top: 0, child: _WheelPointer()),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (_hasSpun)
              Column(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  Text(
                    '+$_wonAmount',
                    style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
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
                    backgroundColor: _isSpinning ? Colors.grey : const Color(0xFF4CAF50),
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
    );
  }
}

class _GemWheelDialog extends StatefulWidget {
  const _GemWheelDialog();

  @override
  State<_GemWheelDialog> createState() => _GemWheelDialogState();
}

class _GemWheelDialogState extends State<_GemWheelDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isSpinning = false;
  bool _hasSpun = false;
  int _wonAmount = 0;
  int _gemsBalance = 100;
  static const int _spinCost = 50;

  final List<int> _prizes = [1000, 2500, 5000, 10000, 2500, 25000, 5000, 50000, 1000, 100000];
  final List<Color> _colors = [
    const Color(0xFF1976D2),
    const Color(0xFF388E3C),
    const Color(0xFFF57C00),
    const Color(0xFF7B1FA2),
    const Color(0xFF00796B),
    const Color(0xFFC2185B),
    const Color(0xFF512DA8),
    const Color(0xFFD4AF37),
    const Color(0xFF0097A7),
    const Color(0xFFFF5722),
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

  void _spin() {
    if (_isSpinning || _gemsBalance < _spinCost) return;
    setState(() {
      _isSpinning = true;
      _hasSpun = false;
      _gemsBalance -= _spinCost;
    });
    _controller.reset();
    
    final random = Random();
    final prizeIndex = random.nextInt(_prizes.length);
    final rotations = 6 + random.nextDouble() * 4;
    final targetAngle = rotations * 2 * pi + (prizeIndex / _prizes.length) * 2 * pi;
    
    _animation = Tween<double>(begin: 0, end: targetAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    
    _controller.forward().then((_) {
      setState(() {
        _isSpinning = false;
        _hasSpun = true;
        _wonAmount = _prizes[prizeIndex];
      });
    });
  }

  String _formatNumber(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K' : '$n';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('🎰 Gem Wheel', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text('$_gemsBalance', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) => Transform.rotate(
                      angle: _animation.value,
                      child: CustomPaint(
                        size: const Size(200, 200),
                        painter: _GemWheelPainter(_prizes, _colors),
                      ),
                    ),
                  ),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFE91E63)]),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Center(child: Text('💎', style: TextStyle(fontSize: 20))),
                  ),
                  const Positioned(top: 0, child: _WheelPointer()),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_hasSpun)
              Column(
                children: [
                  const Text('🎉 JACKPOT!', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 8),
                      Text(_formatNumber(_wonAmount), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
                    ],
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
                          onPressed: _gemsBalance >= _spinCost ? () { setState(() => _hasSpun = false); _spin(); } : null,
                          child: const Text('Again 💎50'),
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
                    backgroundColor: _isSpinning ? Colors.grey : const Color(0xFF9C27B0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isSpinning || _gemsBalance < _spinCost ? null : _spin,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_isSpinning ? 'Spinning...' : 'SPIN', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      if (!_isSpinning) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('💎 50', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
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
    return CustomPaint(
      size: const Size(20, 16),
      painter: _PointerPainter(),
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..style = PaintingStyle.fill;
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
      final paint = Paint()..color = colors[i % colors.length]..style = PaintingStyle.fill;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2 + i * segmentAngle, segmentAngle, true, paint);

      final textAngle = -pi / 2 + i * segmentAngle + segmentAngle / 2;
      final textX = center.dx + radius * 0.65 * cos(textAngle);
      final textY = center.dy + radius * 0.65 * sin(textAngle);

      final textPainter = TextPainter(
        text: TextSpan(text: '${prizes[i]}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
      final paint = Paint()..color = colors[i % colors.length]..style = PaintingStyle.fill;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2 + i * segmentAngle, segmentAngle, true, paint);

      final textAngle = -pi / 2 + i * segmentAngle + segmentAngle / 2;
      final textX = center.dx + radius * 0.7 * cos(textAngle);
      final textY = center.dy + radius * 0.7 * sin(textAngle);

      final textPainter = TextPainter(
        text: TextSpan(text: _fmt(prizes[i]), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black54, blurRadius: 2)])),
        textDirection: TextDirection.ltr,
      )..layout();
      
      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + pi / 2);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }

    canvas.drawCircle(center, radius, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
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
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isUnlocked
                ? const Color(0xFFD4AF37).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUnlocked
                        ? const Color(0xFFD4AF37).withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: TextStyle(
                      fontSize: 36,
                      color: isUnlocked ? null : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: isUnlocked ? const Color(0xFFD4AF37) : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              if (isUnlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'UNLOCKED',
                        style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
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
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 150,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                          minHeight: 6,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, color: Colors.white.withValues(alpha: 0.4), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'LOCKED',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isUnlocked
              ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnlocked
                ? const Color(0xFFD4AF37).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: TextStyle(
                        fontSize: 18,
                        color: isUnlocked ? null : Colors.grey,
                      ),
                    ),
                  ),
                ),
                if (isUnlocked)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: isUnlocked ? Colors.white : Colors.white.withValues(alpha: 0.6),
                fontSize: 9,
                fontWeight: FontWeight.w600,
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

  const _RankTier({
    required this.name,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: isActive ? Border.all(color: color, width: 2) : null,
          ),
          child: Center(
            child: Icon(
              Icons.military_tech,
              size: 18,
              color: isActive ? color : Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            color: isActive ? color : Colors.white.withValues(alpha: 0.3),
            fontSize: 9,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// CUSTOMIZATION CARD
// ============================================================================

class _CustomizationCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String price;
  final bool isOwned;

  const _CustomizationCard({
    required this.emoji,
    required this.name,
    required this.price,
    this.isOwned = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!isOwned) {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('💎', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          price,
                          style: const TextStyle(
                            color: Color(0xFF2196F3),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
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
                                SnackBar(
                                  content: Text('Purchased $name!'),
                                  backgroundColor: const Color(0xFF4CAF50),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2196F3),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
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
          color: isOwned
              ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOwned
                ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
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
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
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
                    style: const TextStyle(
                      color: Color(0xFF2196F3),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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
            colors: [
              gradient[0].withValues(alpha: 0.3),
              gradient[1].withValues(alpha: 0.15),
            ],
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
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: rewards.take(3).map((reward) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        reward,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: gradient[0],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Text('💎', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    price.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
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
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 50)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
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
                    ...rewards.map((reward) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(Icons.star, color: gradient[0], size: 16),
                          const SizedBox(width: 8),
                          Text(
                            reward,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
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
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
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
          Text(
            name,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  void _showFriendOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
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
                    style: TextStyle(
                      color: isOnline ? const Color(0xFF4CAF50) : Colors.grey,
                      fontSize: 13,
                    ),
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
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                    const SnackBar(
                      content: Text('Added to friends!'),
                      backgroundColor: Color(0xFF2196F3),
                    ),
                  );
                },
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add Friend'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
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
// PROFILE STAT
// ============================================================================

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
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

  const _StakeOption({
    required this.amount,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFE91E63).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFE91E63)
              : Colors.white.withValues(alpha: 0.1),
        ),
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

  const _GiftOption({
    required this.emoji,
    required this.label,
    required this.amount,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF4CAF50)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
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

  const _TierReward({
    required this.emoji,
    required this.label,
    required this.isFree,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isFree
                ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                : const Color(0xFFD4AF37).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFree
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
                  : const Color(0xFFD4AF37).withValues(alpha: 0.5),
            ),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
          ),
        ),
        if (!isFree)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👑', style: TextStyle(fontSize: 8)),
              const SizedBox(width: 2),
              Text(
                'Premium',
                style: TextStyle(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                  fontSize: 8,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ============================================================================
// PREMIUM BENEFIT
// ============================================================================

class _PremiumBenefit extends StatelessWidget {
  final String icon;
  final String text;

  const _PremiumBenefit({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
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
        colors: [
          const Color(0xFF4CAF50).withValues(alpha: 0.3),
          const Color(0xFF4CAF50).withValues(alpha: 0.0),
        ],
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

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      baselinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Lucky Hand Dialog - A card picking mini-game
class _LuckyHandDialog extends StatefulWidget {
  const _LuckyHandDialog();

  @override
  State<_LuckyHandDialog> createState() => _LuckyHandDialogState();
}

class _LuckyHandDialogState extends State<_LuckyHandDialog> with TickerProviderStateMixin {
  bool _hasPlayed = false;
  int? _selectedCard;
  bool _isRevealing = false;
  int _wonAmount = 0;
  
  // Card prizes - one card is the jackpot!
  final List<int> _cardPrizes = [500, 1000, 2500, 5000, 10000];
  final List<bool> _cardFlipped = [false, false, false, false, false];
  final List<AnimationController> _flipControllers = [];
  final List<Animation<double>> _flipAnimations = [];

  @override
  void initState() {
    super.initState();
    // Shuffle prizes
    _cardPrizes.shuffle(Random());
    
    // Create flip animations for each card
    for (int i = 0; i < 5; i++) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      );
      _flipControllers.add(controller);
      _flipAnimations.add(
        Tween<double>(begin: 0, end: pi).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeInOut),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _flipControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _selectCard(int index) {
    if (_hasPlayed || _isRevealing) return;
    
    setState(() {
      _selectedCard = index;
      _isRevealing = true;
    });
    
    // Flip the selected card
    _flipControllers[index].forward().then((_) {
      setState(() {
        _cardFlipped[index] = true;
        _wonAmount = _cardPrizes[index];
      });
      
      // Reveal all other cards after a delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        for (int i = 0; i < 5; i++) {
          if (i != index) {
            Future.delayed(Duration(milliseconds: (i * 100)), () {
              if (!mounted) return;
              _flipControllers[i].forward();
              setState(() => _cardFlipped[i] = true);
            });
          }
        }
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            setState(() {
              _hasPlayed = true;
              _isRevealing = false;
            });
          }
        });
      });
    });
  }

  Color _getPrizeColor(int prize) {
    if (prize >= 10000) return const Color(0xFFD4AF37);
    if (prize >= 5000) return const Color(0xFF9C27B0);
    if (prize >= 2500) return const Color(0xFF2196F3);
    return const Color(0xFF4CAF50);
  }

  String _formatPrize(int prize) {
    if (prize >= 1000) return '${prize ~/ 1000}K';
    return '$prize';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🃏', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                const Text(
                  'Lucky Hand',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _hasPlayed ? 'You won!' : 'Pick a card to reveal your prize!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            // Cards row
            SizedBox(
              height: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => _selectCard(index),
                      child: AnimatedBuilder(
                        animation: _flipAnimations[index],
                        builder: (context, child) {
                          final angle = _flipAnimations[index].value;
                          final showFront = angle < pi / 2;
                          
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(angle),
                            child: Container(
                              width: 50,
                              height: 75,
                              decoration: BoxDecoration(
                                gradient: showFront
                                    ? const LinearGradient(
                                        colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: showFront ? null : _getPrizeColor(_cardPrizes[index]),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedCard == index
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.3),
                                  width: _selectedCard == index ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_selectedCard == index
                                            ? Colors.white
                                            : const Color(0xFFD4AF37))
                                        .withValues(alpha: 0.3),
                                    blurRadius: _selectedCard == index ? 12 : 4,
                                    spreadRadius: _selectedCard == index ? 2 : 0,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: showFront
                                    ? const Text('?', style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                      ))
                                    : Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()..rotateY(pi),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Text('🪙', style: TextStyle(fontSize: 18)),
                                            Text(
                                              _formatPrize(_cardPrizes[index]),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
            
            // Result or instruction
            if (_hasPlayed) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _getPrizeColor(_wonAmount).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _getPrizeColor(_wonAmount).withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(
                      '+${_wonAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                      style: TextStyle(
                        color: _getPrizeColor(_wonAmount),
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Collect', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF4CAF50), size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Tap any card to reveal!',
                      style: TextStyle(color: Color(0xFF4CAF50), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
