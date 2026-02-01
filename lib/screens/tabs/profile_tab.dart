import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../widgets/shared_widgets.dart';
import '../../widgets/friends_widgets.dart';
import '../../services/friends_service.dart';
import '../../services/user_preferences.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../services/game_service.dart';
import '../multiplayer_game_screen.dart';

class ProfileTab extends StatefulWidget {
  final VoidCallback? onChipsChanged;

  const ProfileTab({super.key, this.onChipsChanged});

  @override
  State<ProfileTab> createState() => ProfileTabState();
}

class ProfileTabState extends State<ProfileTab> {
  bool _achievementsExpanded = false;
  bool _statisticsExpanded = false;
  bool _referralExpanded = false;
  final FriendsService _friendsService = FriendsService();
  StreamSubscription? _friendsSub;
  StreamSubscription? _authSub;
  String _displayUsername = '';
  String _selectedAvatar = 'ðŸ‘¤';

  @override
  void initState() {
    super.initState();
    _displayUsername = UserPreferences.username;
    _selectedAvatar = UserPreferences.avatar;
    _loadFriends();
    _friendsSub = _friendsService.friendsStream.listen((friends) {
      if (mounted) setState(() {}); // Rebuild on friends update
    });
    // Listen for auth state changes to refresh username
    // Wrapped with try-catch for Windows desktop Firebase threading issues
    _authSub = AuthService().authStateChanges.listen(
      (user) async {
        if (!mounted) return;
        // Use post frame callback to ensure we're on the UI thread
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          if (user != null) {
            // Sync data from Firestore when user changes
            try {
              await UserService().syncAllUserData();
              if (mounted) {
                setState(() {
                  _displayUsername = UserPreferences.username;
                });
              }
            } catch (e) {
              debugPrint('Profile sync error: $e');
            }
          }
        });
      },
      onError: (e) {
        debugPrint('Auth state listener error: $e');
      },
    );
  }

  @override
  void dispose() {
    _friendsSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    await _friendsService.getAllFriends();
    if (mounted) setState(() {}); // Rebuild after loading
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
                      DevMenuItem(
                        icon: Icons.swap_horiz,
                        color: const Color(0xFFFF9800),
                        title: 'Sign In (Username)',
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _showUsernameSignIn(context);
                        },
                      ),
                      DevMenuItem(
                        icon: Icons.email,
                        color: const Color(0xFF9C27B0),
                        title: 'Sign In (Email - Dev)',
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _showAccountSwitcher(context);
                        },
                      ),
                      DevMenuItem(
                        icon: Icons.person_add,
                        color: const Color(0xFF673AB7),
                        title: 'Create Test Account (Email)',
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _showCreateTestAccount(context);
                        },
                      ),
                      DevMenuItem(
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
                          final newValue = !UserPreferences.hasProPass;
                          await UserService().setProPass(newValue);
                          if (mounted) {
                            setState(() {});
                            widget.onChipsChanged?.call();
                            parentScaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(newValue ? 'Pro Pass enabled!' : 'Pro Pass disabled!'),
                                backgroundColor: const Color(0xFFFFD700),
                              ),
                            );
                          }
                        },
                      ),
                      DevMenuItem(
                        icon: Icons.diamond_outlined,
                        color: const Color(0xFF00BCD4),
                        title: 'Add 1000 Gems',
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          final currentGems = UserPreferences.gems;
                          final newGems = currentGems + 1000;
                          await UserPreferences.setGems(newGems);
                          await UserService().setGems(newGems);
                          if (mounted) {
                            setState(() {});
                            parentScaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Added 1000 gems! Total: $newGems'),
                                backgroundColor: const Color(0xFF00BCD4),
                              ),
                            );
                          }
                        },
                      ),
                      DevMenuItem(
                        icon: Icons.bug_report,
                        color: const Color(0xFF9C27B0),
                        title: 'Debug Pro Pass Status',
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          final localProPass = UserPreferences.hasProPass;
                          final firestoreProPass = await UserService().getProPass();
                          if (mounted) {
                            parentScaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Local: $localProPass | Firestore: $firestoreProPass'),
                                backgroundColor: Colors.purple,
                                duration: const Duration(seconds: 5),
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

  // Achievement category chip builder
  Widget _buildCategoryChip(String label, IconData icon, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // TODO: Filter achievements by category
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    )
                  : null,
              color: isSelected ? null : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: isSelected ? null : Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Rarity badge builder for legend
  Widget _buildRarityBadge(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Tier icon builder for achievement tiers
  Widget _buildTierIcon(String tier, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Center(
            child: _getTierMedalIcon(tier, color, 22),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tier,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Get medal icon with tier-appropriate styling
  Widget _getTierMedalIcon(String tier, Color color, double size) {
    IconData iconData;
    List<Color> gradientColors;

    switch (tier.toLowerCase()) {
      case 'bronze':
        iconData = Icons.military_tech_rounded;
        gradientColors = [const Color(0xFFCD7F32), const Color(0xFF8B4513)];
        break;
      case 'silver':
        iconData = Icons.military_tech_rounded;
        gradientColors = [const Color(0xFFC0C0C0), const Color(0xFF808080)];
        break;
      case 'gold':
        iconData = Icons.military_tech_rounded;
        gradientColors = [const Color(0xFFFFD700), const Color(0xFFDAA520)];
        break;
      case 'platinum':
        iconData = Icons.military_tech_rounded;
        gradientColors = [const Color(0xFFE5E4E2), const Color(0xFFB8B8B8)];
        break;
      case 'diamond':
        iconData = Icons.diamond_rounded;
        gradientColors = [const Color(0xFFB9F2FF), const Color(0xFF00CED1)];
        break;
      case 'champion':
        iconData = Icons.emoji_events_rounded;
        gradientColors = [const Color(0xFFFF6B6B), const Color(0xFFEE5253)];
        break;
      case 'legend':
        iconData = Icons.auto_awesome_rounded;
        gradientColors = [const Color(0xFFDA70D6), const Color(0xFF9932CC)];
        break;
      default:
        iconData = Icons.military_tech_rounded;
        gradientColors = [color, color.withValues(alpha: 0.7)];
    }

    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: gradientColors,
      ).createShader(bounds),
      child: Icon(
        iconData,
        size: size,
        color: Colors.white,
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
                    GestureDetector(
                      onTap: () => _showAvatarPicker(context),
                      child: Stack(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(child: Text(_selectedAvatar, style: const TextStyle(fontSize: 26))),
                          ),
                          // Edit indicator
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF141414), width: 2),
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 10),
                            ),
                          ),
                        ],
                      ),
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
                          child: const Center(child: Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 20)),
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
                        RankTier(name: 'Bronze', color: Colors.white.withValues(alpha: 0.5), isActive: true),
                        RankTier(name: 'Silver', color: Colors.white.withValues(alpha: 0.3), isActive: false),
                        RankTier(name: 'Gold', color: Colors.white.withValues(alpha: 0.3), isActive: false),
                        RankTier(name: 'Platinum', color: Colors.white.withValues(alpha: 0.3), isActive: false),
                        RankTier(name: 'Diamond', color: Colors.white.withValues(alpha: 0.3), isActive: false),
                        RankTier(name: 'Champion', color: Colors.white.withValues(alpha: 0.3), isActive: false),
                        RankTier(name: 'Legend', color: Colors.white.withValues(alpha: 0.3), isActive: false),
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
                        gradient: _statisticsExpanded
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF6366F1).withValues(alpha: 0.15),
                                  const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                                ],
                              )
                            : null,
                        color: _statisticsExpanded ? null : Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _statisticsExpanded
                              ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(child: Icon(Icons.analytics_rounded, color: Colors.white, size: 20)),
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
                                  'Performance & Analytics',
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
                              color:
                                  _statisticsExpanded ? const Color(0xFF6366F1) : Colors.white.withValues(alpha: 0.4),
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

          // Statistics Content (Expandable) - Revamped
          if (_statisticsExpanded)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    // Hero Stats Row - Big numbers with trends
                    Row(
                      children: [
                        Expanded(
                            child: _buildHeroStatCard(
                                '1,247', 'Total Games', Icons.sports_esports, const Color(0xFF6366F1), '+12%')),
                        const SizedBox(width: 10),
                        Expanded(
                            child:
                                _buildHeroStatCard('847', 'Wins', Icons.emoji_events, const Color(0xFF10B981), '+8%')),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _buildHeroStatCard(
                                '67.9%', 'Win Rate', Icons.trending_up, const Color(0xFFFFBB00), '+2.3%')),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Chip Balance Graph - Premium Look
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.05),
                            Colors.white.withValues(alpha: 0.02),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Chip Balance',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        '2.4M',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.arrow_upward, size: 10, color: const Color(0xFF10B981)),
                                            const SizedBox(width: 2),
                                            const Text(
                                              '+340K',
                                              style: TextStyle(
                                                color: Color(0xFF10B981),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              _buildTimeRangeSelector(),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Smooth animated graph
                          SizedBox(
                            height: 140,
                            child: CustomPaint(
                              size: const Size(double.infinity, 140),
                              painter: AdvancedChipGraphPainter(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // X-axis labels
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                                .map((day) => Text(
                                      day,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Win/Loss Breakdown & Hand Stats Row
                    Row(
                      children: [
                        // Donut Chart - Win Distribution
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.05),
                                  Colors.white.withValues(alpha: 0.02),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Session Results',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 100,
                                  width: 100,
                                  child: CustomPaint(
                                    painter: WinLossDonutPainter(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildLegendDot(const Color(0xFF10B981), 'Win'),
                                    const SizedBox(width: 12),
                                    _buildLegendDot(const Color(0xFFEF4444), 'Loss'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Quick Stats Column
                        Expanded(
                          child: Column(
                            children: [
                              _buildMiniStatCard(
                                  Icons.local_fire_department, 'Best Streak', '12', const Color(0xFFFF6B35)),
                              const SizedBox(height: 8),
                              _buildMiniStatCard(Icons.monetization_on, 'Biggest Win', '450K', const Color(0xFFFFBB00)),
                              const SizedBox(height: 8),
                              _buildMiniStatCard(Icons.trending_up, 'ROI', '+24.7%', const Color(0xFF10B981)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Hand Frequency Bar Chart
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.05),
                            Colors.white.withValues(alpha: 0.02),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Winning Hands',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '847 hands',
                                  style: TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildHandBar('High Card', 0.35, '296', const Color(0xFF64748B)),
                          _buildHandBar('One Pair', 0.28, '237', const Color(0xFF3B82F6)),
                          _buildHandBar('Two Pair', 0.18, '152', const Color(0xFF8B5CF6)),
                          _buildHandBar('Three of a Kind', 0.09, '76', const Color(0xFFEC4899)),
                          _buildHandBar('Straight+', 0.10, '86', const Color(0xFFFFBB00)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Detailed Stats Grid
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.05),
                            Colors.white.withValues(alpha: 0.02),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detailed Statistics',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildDetailStat('Hands Played', '15,247')),
                              Expanded(child: _buildDetailStat('Showdowns', '4,821')),
                              Expanded(child: _buildDetailStat('All-Ins', '892')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildDetailStat('Fold Rate', '42%')),
                              Expanded(child: _buildDetailStat('Call Rate', '35%')),
                              Expanded(child: _buildDetailStat('Raise Rate', '23%')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildDetailStat('Tourneys Won', '23')),
                              Expanded(child: _buildDetailStat('Cash Games', '1,224')),
                              Expanded(child: _buildDetailStat('Sit & Go', '156')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildDetailStat('Current ELO', '1,847')),
                              Expanded(child: _buildDetailStat('Peak ELO', '2,124')),
                              Expanded(child: _buildDetailStat('Rank', '#1,247')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Achievements Section - HD Poker Style
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Header - Clickable
                  GestureDetector(
                    onTap: () => setState(() => _achievementsExpanded = !_achievementsExpanded),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFFFD700).withValues(alpha: 0.15),
                            const Color(0xFFFF8C00).withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Trophy Icon with Glow
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.emoji_events_rounded, color: Colors.white, size: 26),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ACHIEVEMENTS',
                                  style: TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Progress bar
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: 0.0, // 0/100 unlocked
                                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                                          minHeight: 6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '0 / 20',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedRotation(
                            turns: _achievementsExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 22,
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

          // Achievement Categories Filter (when expanded)
          if (_achievementsExpanded)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildCategoryChip('All', Icons.grid_view_rounded, true),
                      _buildCategoryChip('Hands', Icons.style_rounded, false),
                      _buildCategoryChip('Wins', Icons.emoji_events_rounded, false),
                      _buildCategoryChip('Chips', Icons.paid_rounded, false),
                      _buildCategoryChip('Social', Icons.group_rounded, false),
                      _buildCategoryChip('Skills', Icons.psychology_rounded, false),
                      _buildCategoryChip('Special', Icons.auto_awesome_rounded, false),
                    ],
                  ),
                ),
              ),
            ),

          // Rarity Legend (when expanded) - Now shows tiers
          if (_achievementsExpanded)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: SizedBox(
                  height: 70,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTierIcon('Bronze', const Color(0xFFCD7F32)),
                      _buildTierIcon('Silver', const Color(0xFFC0C0C0)),
                      _buildTierIcon('Gold', const Color(0xFFFFD700)),
                      _buildTierIcon('Platinum', const Color(0xFFE5E4E2)),
                      _buildTierIcon('Diamond', const Color(0xFFB9F2FF)),
                      _buildTierIcon('Champion', const Color(0xFFFF6B6B)),
                      _buildTierIcon('Legend', const Color(0xFFDA70D6)),
                    ],
                  ),
                ),
              ),
            ),

          // Achievement Grid (Expandable) - Larger cards
          if (_achievementsExpanded)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => AchievementCard.fromIndex(index),
                  childCount: 20,
                ),
              ),
            ),

          // Pro Subscription - Battle Pass Design
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Battle Pass Header - Clickable to open full view
                  GestureDetector(
                    onTap: () => _showBattlePassDialog(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF6366F1).withValues(alpha: 0.2),
                            const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                            const Color(0xFFD4AF37).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Pro Header Row
                          Row(
                            children: [
                              // Pro Icon
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(child: Icon(Icons.casino, color: Colors.white, size: 26)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'PRO',
                                          style: TextStyle(
                                            color: Color(0xFFD4AF37),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'ACTIVE',
                                            style: TextStyle(
                                              color: Color(0xFF10B981),
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Exclusive benefits & rewards',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'â€¢ Tap to view all',
                                          style: TextStyle(
                                            color: const Color(0xFF6366F1).withValues(alpha: 0.8),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Chevron indicator
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // XP Progress Section (compact)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              '7',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Tier 7',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              '2,450 / 3,000 XP',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.5),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '28 days left',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Animated XP Bar
                                Stack(
                                  children: [
                                    Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: 0.82,
                                      child: Container(
                                        height: 8,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFD4AF37)],
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
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

                          const SizedBox(height: 12),

                          // Divider
                          Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),

                          const SizedBox(height: 10),

                          // Upgrade to Pro Row (inside container)
                          GestureDetector(
                            onTap: () => _showPremiumPassDialog(context),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFD4AF37).withValues(alpha: 0.15),
                                    const Color(0xFFD4AF37).withValues(alpha: 0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                        child: Icon(Icons.workspace_premium, color: const Color(0xFFFFD700), size: 20)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              'Upgrade to Pro',
                                              style: TextStyle(
                                                color: Color(0xFFD4AF37),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEF4444),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: const Text(
                                                '-20%',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'Unlock all rewards + 2x XP',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.4),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.diamond, color: Color(0xFF00D4FF), size: 14),
                                      const SizedBox(width: 3),
                                      const Text(
                                        '400',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                                    size: 18,
                                  ),
                                ],
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
                            child: const Center(child: Text('ðŸŽ', style: TextStyle(fontSize: 18))),
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
                                  const Icon(Icons.paid, color: Color(0xFFFFD700), size: 26),
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
                                  const Icon(Icons.diamond, color: Color(0xFF00D4FF), size: 26),
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
                child: const Center(child: Text('âš”ï¸', style: TextStyle(fontSize: 36))),
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
                  StakeOption(amount: '1,000', isSelected: false),
                  StakeOption(amount: '5,000', isSelected: true),
                  StakeOption(amount: '10,000', isSelected: false),
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
                child: const Center(child: Text('ðŸŽ', style: TextStyle(fontSize: 36))),
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
                    child: GiftOption(icon: Icons.paid, label: 'Chips', amount: '1,000', isSelected: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GiftOption(icon: Icons.diamond, label: 'Gems', amount: '10', isSelected: false),
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

  void _showBattlePassDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E1E2E), Color(0xFF0D0D0D)],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Center(child: Icon(Icons.casino, color: Colors.white, size: 28)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'ALLIN PRO',
                                style: TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Exclusive benefits & rewards',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '28',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'DAYS LEFT',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // XP Progress
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Text('7',
                                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Current Tier',
                                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                  Text('2,450 / 3,000 XP',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('+550 XP to next',
                                style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Stack(
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: 0.82,
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFD4AF37)],
                                ),
                                borderRadius: BorderRadius.circular(5),
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.5), blurRadius: 8),
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

              // Tier Grid
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: 50,
                  itemBuilder: (context, index) {
                    final tier = index + 1;
                    final isUnlocked = tier <= 7;
                    final isCurrent = tier == 7;
                    final isPremiumReward = tier % 5 == 0;
                    final canClaim = isUnlocked && tier <= 6;

                    return _buildInteractiveTierRow(
                      context: context,
                      tier: tier,
                      isUnlocked: isUnlocked,
                      isCurrent: isCurrent,
                      isPremiumReward: isPremiumReward,
                      canClaim: canClaim,
                      freeReward: _getTierFreeReward(tier),
                      premiumReward: _getTierPremiumReward(tier),
                    );
                  },
                ),
              ),

              // Bottom Premium Button
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF0D0D0D).withValues(alpha: 0.9),
                      const Color(0xFF0D0D0D),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showPremiumPassDialog(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 22),
                          const SizedBox(width: 10),
                          const Text(
                            'Upgrade to Pro',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.diamond, color: Color(0xFF00D4FF), size: 14),
                                const SizedBox(width: 4),
                                const Text('400',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildInteractiveTierRow({
    required BuildContext context,
    required int tier,
    required bool isUnlocked,
    required bool isCurrent,
    required bool isPremiumReward,
    required bool canClaim,
    required Map<String, dynamic> freeReward,
    required Map<String, dynamic> premiumReward,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: isCurrent
            ? LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: 0.2),
                  const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                ],
              )
            : null,
        color: isCurrent ? null : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF6366F1).withValues(alpha: 0.5)
              : isPremiumReward
                  ? const Color(0xFFD4AF37).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Tier Badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: isUnlocked
                  ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                  : isCurrent
                      ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)])
                      : null,
              color: isUnlocked || isCurrent ? null : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: isUnlocked && !isCurrent
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                      '$tier',
                      style: TextStyle(
                        color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.5),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Free Reward
          Expanded(
            child: GestureDetector(
              onTap: () => _showRewardDetails(context, freeReward, 'Free Reward', tier, isUnlocked),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isUnlocked
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    freeReward['icon'] is IconData
                        ? Icon(freeReward['icon'] as IconData, color: Colors.white70, size: 24)
                        : Text(freeReward['icon'].toString(), style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getRewardTitle(freeReward),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: isUnlocked ? 0.9 : 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'FREE',
                          style: TextStyle(
                            color: const Color(0xFF10B981).withValues(alpha: isUnlocked ? 0.8 : 0.4),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Pro Reward
          Expanded(
            child: GestureDetector(
              onTap: () => _showRewardDetails(context, premiumReward, 'Pro Reward', tier, isUnlocked),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isPremiumReward
                      ? LinearGradient(
                          colors: [
                            const Color(0xFFD4AF37).withValues(alpha: 0.2),
                            const Color(0xFFD4AF37).withValues(alpha: 0.1),
                          ],
                        )
                      : null,
                  color: isPremiumReward ? null : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isPremiumReward
                        ? const Color(0xFFD4AF37).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    premiumReward['icon'] is IconData
                        ? Icon(premiumReward['icon'] as IconData, color: const Color(0xFFFFD700), size: 24)
                        : Text(premiumReward['icon'].toString(), style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getRewardTitle(premiumReward),
                            style: TextStyle(
                              color: isPremiumReward
                                  ? const Color(0xFFD4AF37).withValues(alpha: isUnlocked ? 1.0 : 0.6)
                                  : Colors.white.withValues(alpha: isUnlocked ? 0.9 : 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 10),
                              const SizedBox(width: 2),
                              Text(
                                'PREMIUM',
                                style: TextStyle(
                                  color: const Color(0xFFD4AF37).withValues(alpha: isUnlocked ? 0.8 : 0.4),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
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
          ),
        ],
      ),
    );
  }

  String _getRewardTitle(Map<String, dynamic> reward) {
    final label = reward['label'] as String;
    if (label.contains('K')) return '$label Chips';
    if (label == 'XP') return 'Bonus XP';
    if (label == 'Card' || label == 'Skin') return 'Card Back';
    if (label == 'Dice' || label == 'Chip') return 'Table Theme';
    if (label == 'Emote') return 'Emote Pack';
    if (label == 'Frame') return 'Avatar Frame';
    if (label == 'Trail') return 'Card Trail';
    if (label == 'Epic' || label == 'Legend') return 'Legendary Item';
    if (label == 'Rare') return 'Rare Emote';
    if (label == 'VIP') return 'VIP Badge';
    if (int.tryParse(label) != null) return '$label Gems';
    return label;
  }

  void _showRewardDetails(BuildContext context, Map<String, dynamic> reward, String type, int tier, bool isUnlocked) {
    final title = _getRewardTitle(reward);
    final isPremium = type == 'Premium Reward';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isPremium
                  ? [const Color(0xFF2A1A0A), const Color(0xFF1A1A1A)]
                  : [const Color(0xFF1A2A1A), const Color(0xFF1A1A1A)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPremium
                  ? const Color(0xFFD4AF37).withValues(alpha: 0.4)
                  : const Color(0xFF10B981).withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reward Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: isPremium
                      ? const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8860B)])
                      : const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isPremium ? const Color(0xFFD4AF37) : const Color(0xFF10B981)).withValues(alpha: 0.4),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Center(
                  child: reward['icon'] is IconData
                      ? Icon(reward['icon'] as IconData, color: Colors.white, size: 42)
                      : Text(reward['icon'].toString(), style: const TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 16),

              // Type Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isPremium ? const Color(0xFFD4AF37) : const Color(0xFF10B981)).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  type.toUpperCase(),
                  style: TextStyle(
                    color: isPremium ? const Color(0xFFD4AF37) : const Color(0xFF10B981),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Tier $tier Reward',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Status
              if (isUnlocked)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        isPremium ? 'Requires Premium' : 'Claimed!',
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline, color: Colors.white54, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Reach Tier $tier to unlock',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

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

  void _showPremiumPassDialog(BuildContext context) {
    final bool alreadyHasPro = UserPreferences.hasProPass;
    final int currentGems = UserPreferences.gems;
    const int proCost = 400;
    final bool canAfford = currentGems >= proCost;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85, maxWidth: 380),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF2A1A0A),
                const Color(0xFF1A1A1A),
                const Color(0xFF1A1A1A),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with crown
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFD4AF37).withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Crown with glow
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFD4AF37), Color(0xFFB8860B), Color(0xFFD4AF37)],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(child: Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 48)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ALLIN PRO',
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Unlock the ultimate poker experience',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Benefits Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      _buildPremiumBenefitCard(
                        icon: 'âš¡',
                        title: '2X XP BOOST',
                        description: 'Level up twice as fast on all games',
                        color: const Color(0xFF6366F1),
                      ),
                      const SizedBox(height: 10),
                      _buildPremiumBenefitCard(
                        icon: 'ðŸŽ´',
                        title: 'EXCLUSIVE CARD BACKS',
                        description: '5 premium animated card designs',
                        color: const Color(0xFF8B5CF6),
                      ),
                      const SizedBox(height: 10),
                      _buildPremiumBenefitCard(
                        icon: Icons.paid,
                        title: 'BONUS CHIPS',
                        description: 'Extra chips with every tier unlock',
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 10),
                      _buildPremiumBenefitCard(
                        icon: Icons.account_circle,
                        title: 'PREMIUM AVATAR FRAME',
                        description: 'Animated golden frame for your profile',
                        color: const Color(0xFFD4AF37),
                      ),
                      const SizedBox(height: 10),
                      _buildPremiumBenefitCard(
                        icon: Icons.chat_bubble,
                        title: 'EXCLUSIVE EMOTES',
                        description: '10 premium animated emotes',
                        color: const Color(0xFFEC4899),
                      ),
                      const SizedBox(height: 20),

                      // Reward Preview
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Premium Rewards Preview',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildMiniReward(Icons.diamond, '5K'),
                                _buildMiniReward(Icons.style, 'Epic'),
                                _buildMiniReward(Icons.theater_comedy, 'Rare'),
                                _buildMiniReward(Icons.auto_awesome, 'VIP'),
                                _buildMiniReward(Icons.emoji_events, 'Legend'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Purchase Button - different based on pro status
                      if (alreadyHasPro)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('âœ“', style: TextStyle(fontSize: 20, color: Colors.white)),
                              SizedBox(width: 8),
                              Text(
                                'Already Activated!',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: canAfford
                                  ? [const Color(0xFFD4AF37), const Color(0xFFB8860B)]
                                  : [Colors.grey.shade700, Colors.grey.shade800],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: canAfford
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: ElevatedButton(
                            onPressed: canAfford
                                ? () async {
                                    Navigator.pop(context);
                                    // Deduct gems and activate pro pass
                                    final newGems = currentGems - proCost;
                                    await UserPreferences.setGems(newGems);
                                    await UserService().setProPass(true);
                                    // Update Firestore gems
                                    await UserService().setGems(newGems);
                                    if (mounted) {
                                      setState(() {});
                                      widget.onChipsChanged?.call();
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 22),
                                            const SizedBox(width: 10),
                                            const Text('Pro Activated!', style: TextStyle(fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                        backgroundColor: const Color(0xFFD4AF37),
                                      ),
                                    );
                                  }
                                : () {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Not enough gems! You need 400'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.diamond, color: Color(0xFF00D4FF), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '400',
                                  style: TextStyle(
                                    color: canAfford ? Colors.white : Colors.white.withValues(alpha: 0.5),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '500',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: canAfford ? 0.6 : 0.3),
                                    fontSize: 14,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                if (!canAfford) ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    '(Need ${proCost - currentGems} more)',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      if (!alreadyHasPro) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Limited time 20% discount!',
                          style: TextStyle(color: const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Maybe Later',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumBenefitCard({
    required dynamic icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: icon is IconData
                  ? Icon(icon, color: color, size: 22)
                  : Text(icon.toString(), style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: color, size: 18),
        ],
      ),
    );
  }

  Widget _buildMiniReward(dynamic icon, String label) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFD4AF37).withValues(alpha: 0.3),
                const Color(0xFFD4AF37).withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
          ),
          child: Center(
            child: icon is IconData
                ? Icon(icon, color: const Color(0xFFFFD700), size: 18)
                : Text(icon.toString(), style: const TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9)),
      ],
    );
  }

  Widget _buildBattlePassTier({
    required int tier,
    required bool isUnlocked,
    required bool isCurrent,
    required bool isPremiumReward,
    required Map<String, dynamic> freeReward,
    required Map<String, dynamic> premiumReward,
  }) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        gradient: isCurrent
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: 0.3),
                  const Color(0xFF6366F1).withValues(alpha: 0.1),
                ],
              )
            : null,
        color: isCurrent ? null : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF6366F1).withValues(alpha: 0.5)
              : isPremiumReward
                  ? const Color(0xFFD4AF37).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Tier number header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                  : isCurrent
                      ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Center(
              child: Text(
                '$tier',
                style: TextStyle(
                  color: isUnlocked
                      ? const Color(0xFF10B981)
                      : isCurrent
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // Free reward
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: BoxDecoration(
                  color: isUnlocked ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      freeReward['icon'] is IconData
                          ? Icon(freeReward['icon'] as IconData,
                              color: isUnlocked ? Colors.white70 : Colors.white.withValues(alpha: 0.3), size: 20)
                          : Text(
                              freeReward['icon'].toString(),
                              style: TextStyle(
                                fontSize: 18,
                                color: isUnlocked ? null : Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                      const SizedBox(height: 2),
                      Text(
                        freeReward['label'] as String,
                        style: TextStyle(
                          color: isUnlocked ? Colors.white.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.3),
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Divider
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),

          // Premium reward
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: BoxDecoration(
                  gradient: isPremiumReward
                      ? LinearGradient(
                          colors: [
                            const Color(0xFFD4AF37).withValues(alpha: 0.15),
                            const Color(0xFFD4AF37).withValues(alpha: 0.05),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          premiumReward['icon'] is IconData
                              ? Icon(premiumReward['icon'] as IconData,
                                  color: isUnlocked ? const Color(0xFFFFD700) : Colors.white.withValues(alpha: 0.3),
                                  size: 20)
                              : Text(
                                  premiumReward['icon'].toString(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: isUnlocked ? null : Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                          const SizedBox(height: 2),
                          Text(
                            premiumReward['label'] as String,
                            style: TextStyle(
                              color: isPremiumReward
                                  ? const Color(0xFFD4AF37).withValues(alpha: isUnlocked ? 0.9 : 0.5)
                                  : Colors.white.withValues(alpha: isUnlocked ? 0.7 : 0.3),
                              fontSize: 8,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (!isUnlocked)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 10),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getTierFreeReward(int tier) {
    final rewards = [
      {'icon': Icons.paid, 'label': '500'},
      {'icon': Icons.auto_awesome, 'label': 'XP'},
      {'icon': Icons.paid, 'label': '1K'},
      {'icon': Icons.casino, 'label': 'Dice'},
      {'icon': Icons.paid, 'label': '2K'},
      {'icon': Icons.auto_awesome, 'label': 'XP'},
      {'icon': Icons.style, 'label': 'Card'},
      {'icon': Icons.paid, 'label': '3K'},
      {'icon': Icons.circle, 'label': 'Chip'},
      {'icon': Icons.paid, 'label': '5K'},
    ];
    return rewards[(tier - 1) % rewards.length];
  }

  Map<String, dynamic> _getTierPremiumReward(int tier) {
    final rewards = [
      {'icon': Icons.diamond, 'label': '50'},
      {'icon': Icons.style, 'label': 'Skin'},
      {'icon': Icons.diamond, 'label': '100'},
      {'icon': Icons.theater_comedy, 'label': 'Emote'},
      {'icon': Icons.workspace_premium, 'label': 'Epic'},
      {'icon': Icons.diamond, 'label': '150'},
      {'icon': Icons.filter_frames, 'label': 'Frame'},
      {'icon': Icons.diamond, 'label': '200'},
      {'icon': Icons.stars, 'label': 'Trail'},
      {'icon': Icons.emoji_events, 'label': 'Legend'},
    ];
    return rewards[(tier - 1) % rewards.length];
  }

  Widget _buildChallengeItem({
    required String icon,
    required String title,
    required int progress,
    required int total,
    required int xp,
    required bool isComplete,
    bool isWeekly = false,
  }) {
    final progressPercent = (progress / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isComplete ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isComplete ? const Color(0xFF10B981).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isComplete ? const Color(0xFF10B981).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isWeekly)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'WEEKLY',
                          style: const TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: progressPercent,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: isComplete ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$progress/$total',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isComplete
                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                  : const Color(0xFFFFBB00).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Text(isComplete ? 'âœ“' : 'âš¡', style: const TextStyle(fontSize: 10)),
                const SizedBox(width: 3),
                Text(
                  isComplete ? 'Done' : '+$xp',
                  style: TextStyle(
                    color: isComplete ? const Color(0xFF10B981) : const Color(0xFFFFBB00),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAvatarPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
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
                    'Choose Avatar',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Select your profile avatar',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
              ),
              const SizedBox(height: 20),
              // Avatar grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: GameAvatars.all.length,
                itemBuilder: (context, index) {
                  final avatar = GameAvatars.all[index];
                  final isUnlocked = GameAvatars.isUnlocked(index);
                  final isSelected = UserPreferences.avatarIndex == index;

                  return GestureDetector(
                    onTap: isUnlocked
                        ? () async {
                            await UserPreferences.setAvatar(index);
                            if (mounted) {
                              setState(() => _selectedAvatar = avatar);
                            }
                            Navigator.pop(dialogContext);
                          }
                        : () {
                            // Show unlock requirement
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('ðŸ”’ ${GameAvatars.getUnlockRequirement(index)}'),
                                backgroundColor: const Color(0xFF333333),
                              ),
                            );
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2196F3).withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2196F3)
                              : isUnlocked
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.03),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            avatar,
                            style: TextStyle(
                              fontSize: 28,
                              color: isUnlocked ? null : Colors.grey,
                            ),
                          ),
                          // Lock overlay for locked avatars
                          if (!isUnlocked)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(Icons.lock, color: Colors.white54, size: 20),
                              ),
                            ),
                          // Checkmark for selected
                          if (isSelected)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2196F3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 10),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'ðŸ”“ 3 avatars unlocked â€¢ ðŸ”’ ${GameAvatars.all.length - 3} locked',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
              ),
            ],
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
              SettingsItem(icon: Icons.volume_up, title: 'Sound', hasToggle: true),
              SettingsItem(icon: Icons.vibration, title: 'Vibration', hasToggle: true),
              SettingsItem(icon: Icons.notifications, title: 'Notifications', hasToggle: true),
              const Divider(color: Colors.white12, height: 24),
              SettingsItem(icon: Icons.help_outline, title: 'Help & Support'),
              SettingsItem(icon: Icons.info_outline, title: 'About'),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // STATISTICS HELPER WIDGETS
  // ============================================================================

  Widget _buildHeroStatCard(String value, String label, IconData icon, Color color, String trend) {
    final isPositive = trend.startsWith('+');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: isPositive
                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                      : const Color(0xFFEF4444).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTimeButton('7D', true),
          _buildTimeButton('1M', false),
          _buildTimeButton('ALL', false),
        ],
      ),
    );
  }

  Widget _buildTimeButton(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.4),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatCard(IconData icon, String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandBar(String hand, double percentage, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hand,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                count,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ============================================================================
// REUSABLE WIDGETS
// ============================================================================

class BalanceCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final List<Color> gradient;

  const BalanceCard({required this.emoji, required this.label, required this.value, required this.gradient});

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

class QuickPlayCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final List<Color> gradient;
  final VoidCallback onTap;

  const QuickPlayCard({
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

class ShopItemCard extends StatelessWidget {
  final String emoji;
  final String amount;
  final String price;
  final bool isBest;

  const ShopItemCard({required this.emoji, required this.amount, required this.price, this.isBest = false});

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

class StatCard extends StatelessWidget {
  final String value;
  final String label;

  const StatCard({required this.value, required this.label});

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

class FriendAvatar extends StatelessWidget {
  final String name;
  final bool isOnline;

  const FriendAvatar({required this.name, required this.isOnline});

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

class SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool hasToggle;
  final bool isDestructive;

  const SettingsItem({required this.icon, required this.title, this.hasToggle = false, this.isDestructive = false});

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

class DailySpinDialog extends StatefulWidget {
  const DailySpinDialog();

  @override
  State<DailySpinDialog> createState() => DailySpinDialogState();
}

class DailySpinDialogState extends State<DailySpinDialog> with SingleTickerProviderStateMixin {
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
    // Transform.rotate with positive angle rotates clockwise visually
    // To land on segment N, we subtract so segment N aligns with the pointer at top
    final segmentAngle = 2 * pi / _prizes.length;
    // Subtract: rotate so segment N comes to top position
    final targetAngle = rotations * 2 * pi - (prizeIndex * segmentAngle) - (segmentAngle / 2);

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
                          child: CustomPaint(size: const Size(180, 180), painter: WheelPainter(_prizes, _colors)),
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
                      const Positioned(top: 0, child: WheelPointer()),
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

class GemWheelDialog extends StatefulWidget {
  const GemWheelDialog();

  @override
  State<GemWheelDialog> createState() => GemWheelDialogState();
}

class GemWheelDialogState extends State<GemWheelDialog> with SingleTickerProviderStateMixin {
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
    // Calculate angle so that segment prizeIndex lands at the TOP (where pointer is)
    // Wheel draws segment 0 at top (-pi/2), segments go clockwise
    // Transform.rotate with positive angle rotates clockwise visually
    // Subtract so segment N comes to top position
    final segmentAngle = 2 * pi / _prizes.length;
    final targetAngle = rotations * 2 * pi - (prizeIndex * segmentAngle) - (segmentAngle / 2);

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
                          child: CustomPaint(size: const Size(200, 200), painter: GemWheelPainter(_prizes, _colors)),
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
                      const Positioned(top: 0, child: WheelPointer()),
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

class WheelPointer extends StatelessWidget {
  const WheelPointer();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(20, 16), painter: PointerPainter());
  }
}

class PointerPainter extends CustomPainter {
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

class WheelPainter extends CustomPainter {
  final List<int> prizes;
  final List<Color> colors;
  WheelPainter(this.prizes, this.colors);

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

class GemWheelPainter extends CustomPainter {
  final List<int> prizes;
  final List<Color> colors;
  GemWheelPainter(this.prizes, this.colors);

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
// ACHIEVEMENT CARD - TIERED SYSTEM
// ============================================================================

// Tier data for achievements
class TierInfo {
  final String name;
  final Color color;
  final List<Color> gradient;
  final IconData icon;
  final int requirement;

  const TierInfo(this.name, this.color, this.gradient, this.icon, this.requirement);
}

class AchievementData {
  final String id;
  final String title;
  final String description;
  final String category;
  final IconData icon;
  final List<int> tierRequirements; // Requirements for each tier
  final int currentProgress;
  final int currentTier; // 0 = none, 1 = bronze, 2 = silver, etc.

  const AchievementData({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.tierRequirements,
    this.currentProgress = 0,
    this.currentTier = 0,
  });
}

class AchievementCard extends StatelessWidget {
  final AchievementData data;

  const AchievementCard({required this.data, super.key});

  // Tier definitions with colors matching the image
  static const List<TierInfo> tiers = [
    TierInfo('Bronze', Color(0xFFCD7F32), [Color(0xFFCD7F32), Color(0xFF8B4513)], Icons.military_tech_rounded, 0),
    TierInfo('Silver', Color(0xFFC0C0C0), [Color(0xFFC0C0C0), Color(0xFF808080)], Icons.military_tech_rounded, 1),
    TierInfo('Gold', Color(0xFFFFD700), [Color(0xFFFFD700), Color(0xFFDAA520)], Icons.military_tech_rounded, 2),
    TierInfo('Platinum', Color(0xFFE5E4E2), [Color(0xFFE5E4E2), Color(0xFFB8B8B8)], Icons.military_tech_rounded, 3),
    TierInfo('Diamond', Color(0xFFB9F2FF), [Color(0xFFB9F2FF), Color(0xFF00CED1)], Icons.diamond_rounded, 4),
    TierInfo('Champion', Color(0xFFFF6B6B), [Color(0xFFFF6B6B), Color(0xFFEE5253)], Icons.emoji_events_rounded, 5),
    TierInfo('Legend', Color(0xFFDA70D6), [Color(0xFFDA70D6), Color(0xFF9932CC)], Icons.auto_awesome_rounded, 6),
  ];

  TierInfo? get currentTierInfo => data.currentTier > 0 ? tiers[data.currentTier - 1] : null;
  TierInfo? get nextTierInfo => data.currentTier < 7 ? tiers[data.currentTier] : null;

  int get nextTierRequirement => data.currentTier < data.tierRequirements.length
      ? data.tierRequirements[data.currentTier]
      : data.tierRequirements.last;

  double get progressToNextTier {
    if (data.currentTier >= 7) return 1.0;
    final prevReq = data.currentTier > 0 ? data.tierRequirements[data.currentTier - 1] : 0;
    final nextReq = nextTierRequirement;
    if (nextReq <= prevReq) return 1.0;
    return ((data.currentProgress - prevReq) / (nextReq - prevReq)).clamp(0.0, 1.0);
  }

  // 20 Tiered Achievements
  static const List<AchievementData> _achievements = [
    // Hands Category
    AchievementData(
      id: 'hands_won',
      title: 'Hand Winner',
      description: 'Win poker hands',
      category: 'hands',
      icon: Icons.style_rounded,
      tierRequirements: [10, 50, 150, 500, 1500, 5000, 15000],
    ),
    AchievementData(
      id: 'flush',
      title: 'Flush Master',
      description: 'Hit flushes',
      category: 'hands',
      icon: Icons.water_drop_rounded,
      tierRequirements: [1, 5, 15, 50, 150, 500, 1500],
    ),
    AchievementData(
      id: 'straight',
      title: 'Straight Shooter',
      description: 'Hit straights',
      category: 'hands',
      icon: Icons.linear_scale_rounded,
      tierRequirements: [1, 5, 15, 50, 150, 500, 1500],
    ),
    AchievementData(
      id: 'full_house',
      title: 'Full House',
      description: 'Hit full houses',
      category: 'hands',
      icon: Icons.home_rounded,
      tierRequirements: [1, 3, 10, 30, 100, 300, 1000],
    ),

    // Wins Category
    AchievementData(
      id: 'games_won',
      title: 'Winner',
      description: 'Win games',
      category: 'wins',
      icon: Icons.emoji_events_rounded,
      tierRequirements: [1, 10, 50, 150, 500, 1500, 5000],
    ),
    AchievementData(
      id: 'win_streak',
      title: 'Hot Streak',
      description: 'Win hands in a row',
      category: 'wins',
      icon: Icons.local_fire_department_rounded,
      tierRequirements: [3, 5, 7, 10, 15, 20, 30],
    ),
    AchievementData(
      id: 'tournaments',
      title: 'Tournament Pro',
      description: 'Win Sit & Go tournaments',
      category: 'wins',
      icon: Icons.workspace_premium_rounded,
      tierRequirements: [1, 5, 15, 50, 150, 500, 1500],
    ),
    AchievementData(
      id: 'all_in',
      title: 'All In Master',
      description: 'Win all-in hands',
      category: 'wins',
      icon: Icons.casino_rounded,
      tierRequirements: [5, 25, 75, 250, 750, 2500, 7500],
    ),

    // Chips Category
    AchievementData(
      id: 'chip_earner',
      title: 'Chip Collector',
      description: 'Earn chips total',
      category: 'chips',
      icon: Icons.paid_rounded,
      tierRequirements: [10000, 100000, 1000000, 10000000, 100000000, 500000000, 1000000000],
    ),
    AchievementData(
      id: 'big_pot',
      title: 'Big Winner',
      description: 'Win chips in a single hand',
      category: 'chips',
      icon: Icons.monetization_on_rounded,
      tierRequirements: [5000, 25000, 100000, 500000, 2000000, 10000000, 50000000],
    ),
    AchievementData(
      id: 'daily_bonus',
      title: 'Daily Devotee',
      description: 'Claim daily bonuses',
      category: 'chips',
      icon: Icons.calendar_today_rounded,
      tierRequirements: [7, 30, 90, 180, 365, 730, 1095],
    ),
    AchievementData(
      id: 'wheel_spin',
      title: 'Lucky Spinner',
      description: 'Spin the wheel',
      category: 'chips',
      icon: Icons.refresh_rounded,
      tierRequirements: [10, 50, 150, 500, 1500, 5000, 15000],
    ),

    // Social Category
    AchievementData(
      id: 'friends',
      title: 'Social Butterfly',
      description: 'Add friends',
      category: 'social',
      icon: Icons.people_rounded,
      tierRequirements: [1, 5, 15, 30, 50, 100, 200],
    ),
    AchievementData(
      id: 'multiplayer',
      title: 'Table Regular',
      description: 'Play multiplayer games',
      category: 'social',
      icon: Icons.groups_rounded,
      tierRequirements: [10, 50, 150, 500, 1500, 5000, 15000],
    ),
    AchievementData(
      id: 'team',
      title: 'Team Player',
      description: 'Earn team XP',
      category: 'social',
      icon: Icons.shield_rounded,
      tierRequirements: [100, 500, 2000, 10000, 50000, 200000, 1000000],
    ),
    AchievementData(
      id: 'gifter',
      title: 'Generous',
      description: 'Send gifts',
      category: 'social',
      icon: Icons.card_giftcard_rounded,
      tierRequirements: [1, 5, 15, 50, 150, 500, 1500],
    ),

    // Skills Category
    AchievementData(
      id: 'bluffer',
      title: 'Bluff Master',
      description: 'Win with bluffs',
      category: 'skills',
      icon: Icons.theater_comedy_rounded,
      tierRequirements: [5, 25, 75, 250, 750, 2500, 7500],
    ),
    AchievementData(
      id: 'folder',
      title: 'Discipline',
      description: 'Fold hands',
      category: 'skills',
      icon: Icons.pan_tool_rounded,
      tierRequirements: [50, 250, 750, 2500, 7500, 25000, 75000],
    ),

    // Special Category
    AchievementData(
      id: 'level',
      title: 'Leveler',
      description: 'Reach levels',
      category: 'special',
      icon: Icons.arrow_upward_rounded,
      tierRequirements: [5, 15, 30, 50, 75, 100, 150],
    ),
    AchievementData(
      id: 'play_time',
      title: 'Veteran',
      description: 'Play hours',
      category: 'special',
      icon: Icons.access_time_rounded,
      tierRequirements: [1, 10, 50, 150, 500, 1500, 5000],
    ),
  ];

  factory AchievementCard.fromIndex(int index) {
    return AchievementCard(data: _achievements[index]);
  }

  void _showAchievementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: currentTierInfo?.color.withValues(alpha: 0.5) ?? Colors.white.withValues(alpha: 0.1),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with category
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (currentTierInfo?.color ?? Colors.white).withValues(alpha: 0.2),
                      (currentTierInfo?.color ?? Colors.white).withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(data.icon, color: Colors.white.withValues(alpha: 0.6), size: 16),
                    const SizedBox(height: 4),
                    Text(
                      data.category.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Achievement icon
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: currentTierInfo != null
                              ? [
                                  currentTierInfo!.color.withValues(alpha: 0.3),
                                  currentTierInfo!.color.withValues(alpha: 0.1)
                                ]
                              : [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.03)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: currentTierInfo?.color ?? Colors.white.withValues(alpha: 0.15),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          data.icon,
                          size: 32,
                          color: currentTierInfo?.color ?? Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title
                    Text(
                      data.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.description,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Tier progress row
                    SizedBox(
                      height: 56,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(7, (i) {
                          final tier = tiers[i];
                          final isUnlocked = data.currentTier > i;
                          final isCurrent = data.currentTier == i + 1;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isUnlocked || isCurrent
                                      ? tier.color.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isUnlocked || isCurrent
                                        ? tier.color.withValues(alpha: 0.5)
                                        : Colors.white.withValues(alpha: 0.08),
                                    width: isCurrent ? 2 : 1,
                                  ),
                                  boxShadow: isCurrent
                                      ? [
                                          BoxShadow(color: tier.color.withValues(alpha: 0.4), blurRadius: 8),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: _buildTierMedalIcon(tier, isUnlocked || isCurrent, 18),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tier.name.substring(0, 1),
                                style: TextStyle(
                                  color: isUnlocked || isCurrent ? tier.color : Colors.white.withValues(alpha: 0.3),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Progress info
                    if (data.currentTier < 7) ...[
                      Text(
                        'Progress to ${nextTierInfo?.name ?? "Max"}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progressToNextTier,
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  nextTierInfo?.color ?? Colors.white,
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${data.currentProgress} / $nextTierRequirement',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: tiers[6].gradient),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'MAX TIER REACHED',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),

              // Close button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                    ),
                  ),
                  child: Text(
                    'CLOSE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  Widget _buildTierMedalIcon(TierInfo tier, bool isActive, double size) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isActive ? tier.gradient : [Colors.white.withValues(alpha: 0.2), Colors.white.withValues(alpha: 0.1)],
      ).createShader(bounds),
      child: Icon(tier.icon, size: size, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayTier = currentTierInfo;
    final displayColor = displayTier?.color ?? Colors.white.withValues(alpha: 0.3);

    return GestureDetector(
      onTap: () => _showAchievementDialog(context),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: displayTier != null
                ? [displayColor.withValues(alpha: 0.2), displayColor.withValues(alpha: 0.05)]
                : [Colors.white.withValues(alpha: 0.04), Colors.white.withValues(alpha: 0.02)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: displayTier != null ? displayColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
            width: displayTier != null ? 2 : 1,
          ),
          boxShadow:
              displayTier != null ? [BoxShadow(color: displayColor.withValues(alpha: 0.25), blurRadius: 10)] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Current tier indicator
            if (displayTier != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: displayTier.gradient),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  displayTier.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            else
              Container(
                width: 30,
                height: 3,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

            // Icon with tier-appropriate styling
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: displayTier != null
                      ? [displayColor.withValues(alpha: 0.3), displayColor.withValues(alpha: 0.1)]
                      : [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.02)],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      displayTier != null ? displayColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.1),
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  data.icon,
                  size: 20,
                  color: displayTier != null ? displayColor : Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Title
            Text(
              data.title,
              style: TextStyle(
                color: displayTier != null ? Colors.white : Colors.white.withValues(alpha: 0.5),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Progress bar to next tier
            if (data.currentTier < 7) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progressToNextTier,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    nextTierInfo?.color ?? Colors.white.withValues(alpha: 0.3),
                  ),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${data.currentProgress}/${nextTierRequirement}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 8,
                ),
              ),
            ] else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: displayColor, size: 10),
                  const SizedBox(width: 2),
                  Text(
                    'MAX',
                    style: TextStyle(color: displayColor, fontSize: 8, fontWeight: FontWeight.w700),
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
// RANK TIER WIDGET
// ============================================================================

class RankTier extends StatelessWidget {
  final String name;
  final Color color;
  final bool isActive;

  const RankTier({required this.name, required this.color, required this.isActive});

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

class CustomizationCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String price;
  final bool isOwned;

  const CustomizationCard({required this.emoji, required this.name, required this.price, this.isOwned = false});

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
                        const Text('ðŸ’Ž', style: TextStyle(fontSize: 16)),
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
                  const Text('ðŸ’Ž', style: TextStyle(fontSize: 10)),
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

class ChestCard extends StatelessWidget {
  final String name;
  final String emoji;
  final int price;
  final List<String> rewards;
  final List<Color> gradient;

  const ChestCard({
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
                  const Text('ðŸ’Ž', style: TextStyle(fontSize: 14)),
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
                          const Text('ðŸ’Ž', style: TextStyle(fontSize: 14)),
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
                'ðŸŽ‰ You Got! ðŸŽ‰',
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

class FriendAvatarExpanded extends StatelessWidget {
  final String name;
  final bool isOnline;
  final VoidCallback onChallenge;
  final VoidCallback onGift;

  const FriendAvatarExpanded({
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
                  'ðŸ† Gold III',
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
                          child: ProfileStat(label: 'Games', value: '1,247'),
                        ),
                        Expanded(
                          child: ProfileStat(label: 'Wins', value: '623'),
                        ),
                        Expanded(
                          child: ProfileStat(label: 'Win Rate', value: '50%'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ProfileStat(label: 'Best Hand', value: 'Royal Flush'),
                        ),
                        Expanded(
                          child: ProfileStat(label: 'Biggest Pot', value: '125K'),
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
                    Text('ðŸ†', style: TextStyle(fontSize: 24)),
                    Text('â­', style: TextStyle(fontSize: 24)),
                    Text('ðŸŽ¯', style: TextStyle(fontSize: 24)),
                    Text('ðŸ’Ž', style: TextStyle(fontSize: 24)),
                    Text('ðŸ”¥', style: TextStyle(fontSize: 24)),
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
                      icon: const Text('âš”ï¸', style: TextStyle(fontSize: 16)),
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
                      icon: const Text('ðŸŽ', style: TextStyle(fontSize: 16)),
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

class ProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const ProfileStat({required this.label, required this.value});

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

class StakeOption extends StatelessWidget {
  final String amount;
  final bool isSelected;

  const StakeOption({required this.amount, required this.isSelected});

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
          const Text('ðŸª™', style: TextStyle(fontSize: 14)),
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

class GiftOption extends StatelessWidget {
  final dynamic icon;
  final String label;
  final String amount;
  final bool isSelected;

  const GiftOption({required this.icon, required this.label, required this.amount, required this.isSelected});

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
          icon is IconData
              ? Icon(icon, color: isSelected ? const Color(0xFF4CAF50) : Colors.white70, size: 30)
              : Text(icon.toString(), style: const TextStyle(fontSize: 28)),
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

class TierReward extends StatelessWidget {
  final dynamic icon;
  final String label;
  final bool isFree;

  const TierReward({required this.icon, required this.label, required this.isFree});

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
          child: Center(
            child: icon is IconData
                ? Icon(icon, color: isFree ? Colors.white70 : const Color(0xFFFFD700), size: 18)
                : Text(icon.toString(), style: const TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9)),
        if (!isFree)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 8),
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

class PremiumBenefit extends StatelessWidget {
  final String icon;
  final String text;

  const PremiumBenefit({required this.icon, required this.text});

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

class ChipGraphPainter extends CustomPainter {
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

// ============================================================================
// ADVANCED CHIP GRAPH PAINTER - Smooth Bezier Curves with Glow
// ============================================================================

class AdvancedChipGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Sample data - chip balance over time (normalized 0-1)
    final dataPoints = [0.35, 0.42, 0.38, 0.55, 0.48, 0.72, 0.85];

    final stepWidth = size.width / (dataPoints.length - 1);

    // Create gradient for the line
    final lineGradient = LinearGradient(
      colors: [
        const Color(0xFF6366F1),
        const Color(0xFF8B5CF6),
        const Color(0xFF10B981),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    for (int i = 1; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Build smooth bezier path
    final path = Path();
    final fillPath = Path();

    // Calculate points
    final points = <Offset>[];
    for (int i = 0; i < dataPoints.length; i++) {
      final x = stepWidth * i;
      final y = size.height * (1 - dataPoints[i]);
      points.add(Offset(x, y));
    }

    // Start paths
    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    // Draw smooth curves using cubic bezier
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final controlX = (current.dx + next.dx) / 2;

      path.cubicTo(controlX, current.dy, controlX, next.dy, next.dx, next.dy);
      fillPath.cubicTo(controlX, current.dy, controlX, next.dy, next.dx, next.dy);
    }

    // Complete fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw gradient fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF6366F1).withValues(alpha: 0.25),
          const Color(0xFF8B5CF6).withValues(alpha: 0.1),
          const Color(0xFF8B5CF6).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Draw glow effect
    final glowPaint = Paint()
      ..shader = lineGradient
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);

    // Draw main line
    final linePaint = Paint()
      ..shader = lineGradient
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Draw dots at data points
    for (int i = 0; i < points.length; i++) {
      final point = points[i];

      // Outer glow
      canvas.drawCircle(
        point,
        8,
        Paint()
          ..color = const Color(0xFF6366F1).withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // White ring
      canvas.drawCircle(
        point,
        5,
        Paint()
          ..color = const Color(0xFF1A1A1A)
          ..style = PaintingStyle.fill,
      );

      // Colored center
      canvas.drawCircle(
        point,
        3,
        Paint()
          ..color = i == points.length - 1 ? const Color(0xFF10B981) : const Color(0xFF6366F1)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// WIN/LOSS DONUT CHART PAINTER
// ============================================================================

class WinLossDonutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final strokeWidth = 12.0;

    // Win percentage (68% wins)
    const winPercentage = 0.68;
    const lossPercentage = 1 - winPercentage;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Loss arc (draw first, underneath)
    final lossPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = -1.5708; // -90 degrees in radians (top)
    final winSweep = 2 * 3.14159 * winPercentage;
    final lossSweep = 2 * 3.14159 * lossPercentage;

    // Draw loss arc
    canvas.drawArc(rect, startAngle + winSweep, lossSweep, false, lossPaint);

    // Win arc with gradient
    final winPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + winSweep,
        colors: const [
          Color(0xFF10B981),
          Color(0xFF34D399),
        ],
      ).createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, winSweep, false, winPaint);

    // Glow effect on win arc
    final glowPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.3)
      ..strokeWidth = strokeWidth + 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(rect, startAngle, winSweep, false, glowPaint);

    // Center text
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '68%',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2 - 4),
    );

    // Sub text
    final subTextPainter = TextPainter(
      text: TextSpan(
        text: 'wins',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    subTextPainter.layout();
    subTextPainter.paint(
      canvas,
      Offset(center.dx - subTextPainter.width / 2, center.dy + 6),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Lucky Hand Dialog - Shows today's lucky hand bonus
class LuckyHandDialog extends StatelessWidget {
  const LuckyHandDialog();

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
                            const Text('ðŸª™', style: TextStyle(fontSize: 18)),
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
                              const Text('ðŸª™', style: TextStyle(fontSize: 16)),
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
