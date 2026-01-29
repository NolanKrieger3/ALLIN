import 'package:flutter/material.dart';
import '../widgets/mobile_wrapper.dart';
import '../widgets/animated_buttons.dart';
import 'tabs/home_tab.dart';
import 'tabs/shop_tab.dart';
import 'tabs/profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1;
  // Keys to force rebuild when needed
  final GlobalKey<HomeTabState> _homeTabKey = GlobalKey<HomeTabState>();
  final GlobalKey<ShopTabState> _shopTabKey = GlobalKey<ShopTabState>();

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
            ShopTab(key: _shopTabKey),
            HomeTab(
              key: _homeTabKey,
              onNavigateToShop: () => setState(() => _currentIndex = 0),
            ),
            ProfileTab(onChipsChanged: _refreshAllBalances),
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
    return AnimatedTapButton(
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
