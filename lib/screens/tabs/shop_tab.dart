import 'package:flutter/material.dart';
import '../../widgets/animated_buttons.dart';
import '../../services/user_preferences.dart';
import 'profile_tab.dart'; // For dialog widgets

class ShopTab extends StatefulWidget {
  const ShopTab({super.key});

  @override
  State<ShopTab> createState() => ShopTabState();
}

class ShopTabState extends State<ShopTab> with SingleTickerProviderStateMixin {
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
                    BalanceChip(
                        emoji: '🪙',
                        amount: UserPreferences.formatChips(UserPreferences.chips),
                        color: Colors.white.withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    BalanceChip(
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
          AnimatedTapButton(
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
                child: AnimatedTapButton(
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
                child: AnimatedTapButton(
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

          // Starter Pack - Compact horizontal card with rocket trail effect
          _buildStarterPackCard(),
          const SizedBox(height: 14),

          // VIP Bundle - Premium vertical card with animated shimmer border
          _buildVIPBundleCard(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildStarterPackCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0D3B4A),
            const Color(0xFF0A2530),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4DD0E1).withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4DD0E1).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rocket icon with glow
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4DD0E1), Color(0xFF26C6DA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4DD0E1).withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Starter Pack',
                      style: TextStyle(
                        color: Color(0xFF4DD0E1),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4DD0E1).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '50% OFF',
                        style: TextStyle(color: Color(0xFF4DD0E1), fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildStarterItem(Icons.paid_rounded, '10K'),
                    const SizedBox(width: 12),
                    _buildStarterItem(Icons.diamond_rounded, '50'),
                    const SizedBox(width: 12),
                    _buildStarterItem(Icons.style_rounded, 'Card'),
                  ],
                ),
              ],
            ),
          ),
          // Price column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$5.99',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4DD0E1), Color(0xFF00ACC1)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '\$2.99',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStarterItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF4DD0E1).withValues(alpha: 0.7), size: 14),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildVIPBundleCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D1F0D), Color(0xFF1A1208)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          width: 2,
          color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Crown header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFD4AF37).withValues(alpha: 0.2),
                  const Color(0xFFD4AF37).withValues(alpha: 0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFFD4AF37), size: 16),
                const SizedBox(width: 6),
                const Text(
                  'BEST VALUE',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.auto_awesome, color: Color(0xFFD4AF37), size: 16),
              ],
            ),
          ),
          // Main content
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Premium emblem
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFD4AF37), Color(0xFFB8860B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                // VIP content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VIP Bundle',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildVIPItem(Icons.paid_rounded, '100,000 Chips'),
                      const SizedBox(height: 4),
                      _buildVIPItem(Icons.diamond_rounded, '500 Gems'),
                      const SizedBox(height: 4),
                      _buildVIPItem(Icons.collections_rounded, 'Royal Card Set'),
                    ],
                  ),
                ),
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'SAVE 60%',
                        style: TextStyle(color: Color(0xFFEF4444), fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\$49.99',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFD4AF37)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        '\$19.99',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVIPItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFD4AF37).withValues(alpha: 0.8), size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
        ),
      ],
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
                child: CurrencyCard(
                  emoji: '🪙',
                  amount: '100K',
                  price: '\$0.99',
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CurrencyCard(
                  emoji: '🪙',
                  amount: '1M',
                  price: '\$4.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+100K',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CurrencyCard(
                  emoji: '🪙',
                  amount: '4M',
                  price: '\$9.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+400K',
                  isBest: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CurrencyCard(
                  emoji: '🪙',
                  amount: '12M',
                  price: '\$19.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+1.2M',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CurrencyCard(
                  emoji: '🪙',
                  amount: '40M',
                  price: '\$49.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+4M',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CurrencyCard(
                  emoji: '🪙',
                  amount: '120M',
                  price: '\$99.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+12M',
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
                child: CurrencyCard(
                  emoji: '💎',
                  amount: '80',
                  price: '\$0.99',
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CurrencyCard(
                  emoji: '💎',
                  amount: '500',
                  price: '\$4.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+50',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CurrencyCard(
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
                child: CurrencyCard(
                  emoji: '💎',
                  amount: '2,500',
                  price: '\$19.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+500',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CurrencyCard(
                  emoji: '💎',
                  amount: '6,500',
                  price: '\$49.99',
                  color: Colors.white.withValues(alpha: 0.6),
                  bonus: '+1500',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CurrencyCard(
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
          CosmeticCategoryDropdown(
            emoji: '🎴',
            title: 'Card Backs',
            commonItems: [
              CosmeticItemData(emoji: '🎴', name: 'Classic', price: 'Equipped', isOwned: true),
              CosmeticItemData(emoji: '🟤', name: 'Wood', price: '100'),
              CosmeticItemData(emoji: '🔘', name: 'Simple', price: '150'),
            ],
            rareItems: [
              CosmeticItemData(emoji: '🌟', name: 'Gold', price: '500'),
              CosmeticItemData(emoji: '🔵', name: 'Ocean', price: '500'),
              CosmeticItemData(emoji: '🟢', name: 'Forest', price: '600'),
            ],
            epicItems: [
              CosmeticItemData(emoji: '💎', name: 'Diamond', price: '1,000'),
              CosmeticItemData(emoji: '🔥', name: 'Fire', price: '1,200'),
              CosmeticItemData(emoji: '❄️', name: 'Ice', price: '1,200'),
            ],
            legendaryItems: [
              CosmeticItemData(emoji: '👑', name: 'Royal', price: '2,500'),
              CosmeticItemData(emoji: '🌈', name: 'Prismatic', price: '3,000'),
              CosmeticItemData(emoji: '⚡', name: 'Thunder', price: '3,500'),
            ],
          ),
          SizedBox(height: 12),

          // Table Themes Category
          CosmeticCategoryDropdown(
            emoji: '🎨',
            title: 'Table Themes',
            commonItems: [
              CosmeticItemData(emoji: '🟢', name: 'Classic', price: 'Equipped', isOwned: true),
              CosmeticItemData(emoji: '🟤', name: 'Brown', price: '100'),
              CosmeticItemData(emoji: '⚫', name: 'Dark', price: '150'),
            ],
            rareItems: [
              CosmeticItemData(emoji: '🔵', name: 'Royal Blue', price: '500'),
              CosmeticItemData(emoji: '🟣', name: 'Velvet', price: '750'),
              CosmeticItemData(emoji: '🔴', name: 'Vegas', price: '750'),
            ],
            epicItems: [
              CosmeticItemData(emoji: '⬛', name: 'Midnight', price: '1,000'),
              CosmeticItemData(emoji: '🌊', name: 'Ocean', price: '1,200'),
              CosmeticItemData(emoji: '🌸', name: 'Sakura', price: '1,200'),
            ],
            legendaryItems: [
              CosmeticItemData(emoji: '✨', name: 'Galaxy', price: '2,500'),
              CosmeticItemData(emoji: '🌋', name: 'Volcanic', price: '3,000'),
              CosmeticItemData(emoji: '💫', name: 'Nebula', price: '3,500'),
            ],
          ),
          SizedBox(height: 12),

          // Avatars Category
          CosmeticCategoryDropdown(
            emoji: '👤',
            title: 'Avatars',
            commonItems: [
              CosmeticItemData(emoji: '👤', name: 'Default', price: 'Equipped', isOwned: true),
              CosmeticItemData(emoji: '😊', name: 'Smiley', price: '100'),
              CosmeticItemData(emoji: '😐', name: 'Neutral', price: '100'),
            ],
            rareItems: [
              CosmeticItemData(emoji: '🤠', name: 'Cowboy', price: '300'),
              CosmeticItemData(emoji: '🎩', name: 'Fancy', price: '500'),
              CosmeticItemData(emoji: '🧢', name: 'Cool Guy', price: '400'),
            ],
            epicItems: [
              CosmeticItemData(emoji: '👸', name: 'Royalty', price: '750'),
              CosmeticItemData(emoji: '🤖', name: 'Robot', price: '800'),
              CosmeticItemData(emoji: '🦊', name: 'Fox', price: '850'),
            ],
            legendaryItems: [
              CosmeticItemData(emoji: '👽', name: 'Alien', price: '2,000'),
              CosmeticItemData(emoji: '🐉', name: 'Dragon', price: '2,500'),
              CosmeticItemData(emoji: '👻', name: 'Phantom', price: '3,000'),
            ],
          ),
          SizedBox(height: 12),

          // Emotes Category
          CosmeticCategoryDropdown(
            emoji: '😎',
            title: 'Emotes',
            commonItems: [
              CosmeticItemData(emoji: '👍', name: 'GG', price: 'Free', isOwned: true),
              CosmeticItemData(emoji: '👋', name: 'Wave', price: '50'),
              CosmeticItemData(emoji: '👏', name: 'Clap', price: '75'),
            ],
            rareItems: [
              CosmeticItemData(emoji: '😎', name: 'Cool', price: '200'),
              CosmeticItemData(emoji: '🤣', name: 'LOL', price: '200'),
              CosmeticItemData(emoji: '😱', name: 'Shock', price: '300'),
            ],
            epicItems: [
              CosmeticItemData(emoji: '🎉', name: 'Party', price: '500'),
              CosmeticItemData(emoji: '🃏', name: 'Bluff', price: '600'),
              CosmeticItemData(emoji: '💪', name: 'Flex', price: '550'),
            ],
            legendaryItems: [
              CosmeticItemData(emoji: '🔥', name: 'On Fire', price: '1,500'),
              CosmeticItemData(emoji: '💎', name: 'Rich', price: '2,000'),
              CosmeticItemData(emoji: '👑', name: 'King', price: '2,500'),
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
          ModernChestCard(
            name: 'Bronze Chest',
            emoji: '🧰',
            price: 50,
            rewards: ['500-2K Chips', 'Common Emote', 'Card Back'],
            gradient: [const Color(0xFF8D6E63), const Color(0xFF5D4037)],
            rarity: 'Common',
          ),
          const SizedBox(height: 14),
          ModernChestCard(
            name: 'Silver Chest',
            emoji: '🪨',
            price: 150,
            rewards: ['2K-10K Chips', 'Rare Emote', 'Table Theme'],
            gradient: [const Color(0xFF90A4AE), const Color(0xFF607D8B)],
            rarity: 'Rare',
          ),
          const SizedBox(height: 14),
          ModernChestCard(
            name: 'Gold Chest',
            emoji: '👑',
            price: 500,
            rewards: ['10K-50K Chips', 'Epic Items', 'Dealer Skin'],
            gradient: [const Color(0xFFFFD54F), const Color(0xFFFF8F00)],
            rarity: 'Epic',
            isBest: true,
          ),
          const SizedBox(height: 14),
          ModernChestCard(
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
    showDialog(context: context, builder: (context) => const DailySpinDialog()).then((_) => refreshBalance());
  }

  void _showGemWheelDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const GemWheelDialog()).then((_) => refreshBalance());
  }

  void _showLuckyHandDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const LuckyHandDialog()).then((_) => refreshBalance());
  }
}

// Balance chip widget for header
class BalanceChip extends StatelessWidget {
  final String emoji;
  final String amount;
  final Color color;

  const BalanceChip({required this.emoji, required this.amount, required this.color});

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
class DevMenuItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  const DevMenuItem({required this.icon, required this.color, required this.title, required this.onTap});

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
class SectionLabel extends StatelessWidget {
  final String emoji;
  final String title;

  const SectionLabel({required this.emoji, required this.title});

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
class CurrencyCard extends StatelessWidget {
  final String emoji;
  final String amount;
  final String price;
  final Color color;
  final String? bonus;
  final bool isBest;

  const CurrencyCard({
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
          _buildStackedEmoji(emoji, amount),
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

  /// Build stacked emoji visual based on amount tier
  Widget _buildStackedEmoji(String emoji, String amount) {
    // Determine stack count based on amount
    int stackCount = 1;
    final amountLower = amount.toLowerCase();
    if (amountLower.contains('m')) {
      // Millions
      final num = double.tryParse(amountLower.replaceAll('m', '').replaceAll(',', '')) ?? 1;
      if (num >= 100) {
        stackCount = 5;
      } else if (num >= 10) {
        stackCount = 4;
      } else if (num >= 1) {
        stackCount = 3;
      }
    } else if (amountLower.contains('k')) {
      // Thousands
      final num = double.tryParse(amountLower.replaceAll('k', '').replaceAll(',', '')) ?? 1;
      if (num >= 10) {
        stackCount = 3;
      } else if (num >= 1) {
        stackCount = 2;
      }
    } else {
      // Plain numbers
      final num = int.tryParse(amount.replaceAll(',', '')) ?? 0;
      if (num >= 1000) {
        stackCount = 3;
      } else if (num >= 500) {
        stackCount = 2;
      }
    }

    if (stackCount == 1) {
      return Text(emoji, style: const TextStyle(fontSize: 22));
    }

    // Build stacked emojis with slight offset
    return SizedBox(
      height: 28 + (stackCount - 1) * 3.0,
      width: 30 + (stackCount - 1) * 6.0,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(stackCount, (i) {
          return Positioned(
            left: i * 4.0,
            bottom: i * 2.0,
            child: Text(
              emoji,
              style: TextStyle(
                fontSize: 18,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// Cosmetic item widget
class CosmeticItem extends StatelessWidget {
  final String emoji;
  final String name;
  final String price;
  final bool isOwned;

  const CosmeticItem({required this.emoji, required this.name, required this.price, this.isOwned = false});

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
class CosmeticItemData {
  final String emoji;
  final String name;
  final String price;
  final bool isOwned;

  const CosmeticItemData({required this.emoji, required this.name, required this.price, this.isOwned = false});
}

// Cosmetic category dropdown with rarity sub-dropdowns
class CosmeticCategoryDropdown extends StatefulWidget {
  final String emoji;
  final String title;
  final List<CosmeticItemData> commonItems;
  final List<CosmeticItemData> rareItems;
  final List<CosmeticItemData> epicItems;
  final List<CosmeticItemData> legendaryItems;

  const CosmeticCategoryDropdown({
    required this.emoji,
    required this.title,
    required this.commonItems,
    required this.rareItems,
    required this.epicItems,
    required this.legendaryItems,
  });

  @override
  State<CosmeticCategoryDropdown> createState() => CosmeticCategoryDropdownState();
}

class CosmeticCategoryDropdownState extends State<CosmeticCategoryDropdown> {
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
            RaritySubDropdown(rarity: 'Common', color: const Color(0xFF9E9E9E), items: widget.commonItems),
            RaritySubDropdown(rarity: 'Rare', color: const Color(0xFF2196F3), items: widget.rareItems),
            RaritySubDropdown(rarity: 'Epic', color: const Color(0xFF9C27B0), items: widget.epicItems),
            RaritySubDropdown(rarity: 'Legendary', color: const Color(0xFFD4AF37), items: widget.legendaryItems),
          ],
        ],
      ),
    );
  }
}

// Rarity sub-dropdown widget
class RaritySubDropdown extends StatefulWidget {
  final String rarity;
  final Color color;
  final List<CosmeticItemData> items;

  const RaritySubDropdown({required this.rarity, required this.color, required this.items});

  @override
  State<RaritySubDropdown> createState() => RaritySubDropdownState();
}

class RaritySubDropdownState extends State<RaritySubDropdown> {
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
                    (item) => CosmeticGridItem(
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
class CosmeticGridItem extends StatelessWidget {
  final String emoji;
  final String name;
  final String price;
  final bool isOwned;
  final Color rarityColor;

  const CosmeticGridItem({
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
class HotDealCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> items;
  final String price;
  final String originalPrice;
  final List<Color> gradient;
  final bool isBest;
  final Color? accentColor;

  const HotDealCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    required this.price,
    required this.originalPrice,
    required this.gradient,
    this.isBest = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.12),
            accent.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.25),
                  accent.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: accent, size: 26),
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
                      style: TextStyle(color: accent, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    if (isBest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accent, accent.withValues(alpha: 0.7)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'BEST VALUE',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: items
                      .map(
                        (item) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item,
                            style: TextStyle(
                                color: accent.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w500),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                originalPrice,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  price,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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
class ModernChestCard extends StatelessWidget {
  final String name;
  final String emoji;
  final int price;
  final List<String> rewards;
  final List<Color> gradient;
  final String rarity;
  final bool isBest;

  const ModernChestCard({
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
