import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Lucky hand types with their display info and bonus rewards
class LuckyHandType {
  final String name;
  final String emoji;
  final String description;
  final int bonusReward;

  const LuckyHandType({required this.name, required this.emoji, required this.description, required this.bonusReward});

  static const List<LuckyHandType> allHands = [
    LuckyHandType(name: 'High Card', emoji: '🃏', description: 'Win with just a high card', bonusReward: 500),
    LuckyHandType(name: 'One Pair', emoji: '👯', description: 'Win with a pair', bonusReward: 750),
    LuckyHandType(name: 'Two Pair', emoji: '✌️', description: 'Win with two pairs', bonusReward: 1000),
    LuckyHandType(name: 'Three of a Kind', emoji: '🎲', description: 'Win with trips', bonusReward: 1500),
    LuckyHandType(name: 'Straight', emoji: '📈', description: 'Win with a straight', bonusReward: 2000),
    LuckyHandType(name: 'Flush', emoji: '🎴', description: 'Win with a flush', bonusReward: 2500),
    LuckyHandType(name: 'Full House', emoji: '🏠', description: 'Win with a full house', bonusReward: 3000),
    LuckyHandType(name: 'Four of a Kind', emoji: '🎰', description: 'Win with quads', bonusReward: 5000),
    LuckyHandType(name: 'Straight Flush', emoji: '🔥', description: 'Win with a straight flush', bonusReward: 10000),
    LuckyHandType(name: 'Royal Flush', emoji: '👑', description: 'Win with a royal flush', bonusReward: 25000),
  ];
}

/// Available avatars in the game
class GameAvatars {
  /// All available avatars with their unlock status
  /// First 3 are unlocked by default, rest require unlocking
  static const List<String> all = [
    '👤', // Default - always unlocked
    '🎭', // Unlocked
    '🎩', // Unlocked
    '👑', // Locked - Premium
    '🦊', // Locked - Level 10
    '🐺', // Locked - Level 20
    '🦁', // Locked - Level 30
    '🐲', // Locked - Level 40
    '🦅', // Locked - Win 100 games
    '🤖', // Locked - Play 500 hands
    '👻', // Locked - Halloween event
    '🎅', // Locked - Holiday event
  ];

  /// Number of avatars unlocked by default
  static const int defaultUnlocked = 3;

  /// Check if an avatar is unlocked
  static bool isUnlocked(int index) {
    // First 3 are always unlocked
    if (index < defaultUnlocked) return true;
    // TODO: Add unlock logic for other avatars based on achievements
    return false;
  }

  /// Get unlock requirement text for locked avatars
  static String getUnlockRequirement(int index) {
    switch (index) {
      case 3:
        return 'Get Pro Pass';
      case 4:
        return 'Reach Level 10';
      case 5:
        return 'Reach Level 20';
      case 6:
        return 'Reach Level 30';
      case 7:
        return 'Reach Level 40';
      case 8:
        return 'Win 100 games';
      case 9:
        return 'Play 500 hands';
      case 10:
        return 'Halloween Event';
      case 11:
        return 'Holiday Event';
      default:
        return 'Locked';
    }
  }
}

/// Service for managing user preferences stored locally
class UserPreferences {
  static const String _usernameKey = 'username';
  static const String _hasSetUsernameKey = 'has_set_username';
  static const String _cachedUidKey = 'cached_uid';
  static const String _cachedPasswordKey = 'cached_password';
  static const String _chipsKey = 'chips';
  static const String _gemsKey = 'gems';
  static const String _avatarKey = 'selected_avatar';
  static const String _luckyHandDateKey = 'lucky_hand_date';
  static const String _luckyHandIndexKey = 'lucky_hand_index';
  static const String _luckyHandWinsKey = 'lucky_hand_wins_today';
  static const String _hasProPassKey = 'has_pro_pass';
  static const String _proPassTierKey = 'pro_pass_tier';
  static const String _proPassXpKey = 'pro_pass_xp';
  static const int _defaultChips = 1000;
  static const int _defaultGems = 100;

  // Stats keys
  static const String _gamesPlayedKey = 'games_played';
  static const String _gamesWonKey = 'games_won';
  static const String _handsPlayedKey = 'hands_played';
  static const String _handsWonKey = 'hands_won';
  static const String _highCardsKey = 'high_cards';
  static const String _onePairsKey = 'one_pairs';
  static const String _twoPairsKey = 'two_pairs';
  static const String _threeOfKindsKey = 'three_of_kinds';
  static const String _straightsKey = 'straights';
  static const String _flushesKey = 'flushes';
  static const String _fullHousesKey = 'full_houses';
  static const String _fourOfKindsKey = 'four_of_kinds';
  static const String _straightFlushesKey = 'straight_flushes';
  static const String _royalFlushesKey = 'royal_flushes';
  static const String _allInsWonKey = 'all_ins_won';
  static const String _biggestPotKey = 'biggest_pot';
  static const String _totalChipsWonKey = 'total_chips_won';
  static const String _sitAndGoWinsKey = 'sit_and_go_wins';
  static const String _currentWinStreakKey = 'current_win_streak';
  static const String _bestWinStreakKey = 'best_win_streak';
  static const String _dailyBonusClaimsKey = 'daily_bonus_claims';

  static SharedPreferences? _prefs;

  /// Cached random name for the session (so it doesn't change on every access)
  static String? _cachedRandomName;

  /// Initialize shared preferences
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Check if user has Pro Pass (for dev testing)
  static bool get hasProPass {
    return _prefs?.getBool(_hasProPassKey) ?? false;
  }

  /// Set Pro Pass status (for dev testing)
  static Future<void> setProPass(bool value) async {
    await _prefs?.setBool(_hasProPassKey, value);
  }

  /// Get the selected avatar emoji
  static String get avatar {
    final index = _prefs?.getInt(_avatarKey) ?? 0;
    if (index >= 0 && index < GameAvatars.all.length) {
      return GameAvatars.all[index];
    }
    return GameAvatars.all[0];
  }

  /// Get the selected avatar index
  static int get avatarIndex {
    return _prefs?.getInt(_avatarKey) ?? 0;
  }

  /// Set the selected avatar by index
  static Future<void> setAvatar(int index) async {
    if (index >= 0 && index < GameAvatars.all.length && GameAvatars.isUnlocked(index)) {
      await _prefs?.setInt(_avatarKey, index);
    }
  }

  /// Check if user has set their username
  static bool get hasSetUsername {
    return _prefs?.getBool(_hasSetUsernameKey) ?? false;
  }

  /// Get the saved username, or generate a random one for testing
  static String get username {
    final saved = _prefs?.getString(_usernameKey);
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }
    // Use cached random name if available, otherwise generate and cache one
    // This ensures the name stays consistent within a session
    _cachedRandomName ??= _generateRandomName();
    return _cachedRandomName!;
  }

  /// Save username
  static Future<void> setUsername(String username) async {
    await _prefs?.setString(_usernameKey, username);
    await _prefs?.setBool(_hasSetUsernameKey, true);
    _cachedRandomName = null; // Clear cached random name when real username is set
  }

  /// Clear username (for testing)
  static Future<void> clearUsername() async {
    await _prefs?.remove(_usernameKey);
    await _prefs?.setBool(_hasSetUsernameKey, false);
    _cachedRandomName = null; // Clear cached random name
  }

  /// Get cached Firebase UID
  static String? get cachedUid {
    return _prefs?.getString(_cachedUidKey);
  }

  /// Set cached Firebase UID
  static Future<void> setCachedUid(String uid) async {
    await _prefs?.setString(_cachedUidKey, uid);
  }

  /// Get cached password for auto-login
  static String? get cachedPassword {
    return _prefs?.getString(_cachedPasswordKey);
  }

  /// Set cached password for auto-login
  static Future<void> setCachedPassword(String password) async {
    await _prefs?.setString(_cachedPasswordKey, password);
  }

  /// Clear all user data (when switching accounts)
  static Future<void> clearAllUserData() async {
    await _prefs?.remove(_usernameKey);
    await _prefs?.setBool(_hasSetUsernameKey, false);
    await _prefs?.remove(_cachedUidKey);
    await _prefs?.remove(_cachedPasswordKey);
    await _prefs?.setInt(_chipsKey, _defaultChips);
    await _prefs?.setInt(_gemsKey, _defaultGems);
    _cachedRandomName = null; // Clear cached random name
  }

  /// Generate a random fun name for testing
  static String _generateRandomName() {
    final adjectives = [
      'Lucky',
      'Wild',
      'Slick',
      'Crafty',
      'Bold',
      'Swift',
      'Clever',
      'Sly',
      'Sharp',
      'Cool',
      'Hot',
      'Ice',
      'Fire',
      'Thunder',
      'Shadow',
      'Golden',
      'Silver',
      'Iron',
      'Steel',
      'Diamond',
      'Royal',
      'Ace',
      'King',
      'Queen',
    ];

    final nouns = [
      'Shark',
      'Wolf',
      'Fox',
      'Eagle',
      'Tiger',
      'Lion',
      'Bear',
      'Hawk',
      'Viper',
      'Dragon',
      'Phoenix',
      'Maverick',
      'Bluffer',
      'Dealer',
      'Player',
      'Gambler',
      'Hustler',
      'Pro',
      'Champ',
      'Legend',
      'Boss',
      'Chief',
      'Duke',
    ];

    final random = Random();
    final adjective = adjectives[random.nextInt(adjectives.length)];
    final noun = nouns[random.nextInt(nouns.length)];
    final number = random.nextInt(99) + 1;

    return '$adjective$noun$number';
  }

  /// Get current chip balance
  static int get chips {
    return _prefs?.getInt(_chipsKey) ?? _defaultChips;
  }

  /// Set chip balance
  static Future<void> setChips(int amount) async {
    await _prefs?.setInt(_chipsKey, amount);
  }

  /// Add chips to balance
  static Future<void> addChips(int amount) async {
    final current = chips;
    await setChips(current + amount);
  }

  /// Spend chips (deduct from balance)
  static Future<bool> spendChips(int amount) async {
    final current = chips;
    if (current < amount) return false;
    await setChips(current - amount);
    return true;
  }

  /// Get current gem balance
  static int get gems {
    return _prefs?.getInt(_gemsKey) ?? _defaultGems;
  }

  /// Set gem balance
  static Future<void> setGems(int amount) async {
    await _prefs?.setInt(_gemsKey, amount);
  }

  /// Add gems to balance
  static Future<void> addGems(int amount) async {
    final current = gems;
    await setGems(current + amount);
  }

  /// Format number with commas
  static String formatChips(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(amount % 1000000 == 0 ? 0 : 1)}M';
    }
    if (amount >= 1000) {
      final thousands = amount ~/ 1000;
      final remainder = amount % 1000;
      if (remainder == 0) {
        return '${thousands}K';
      }
      return '${thousands},${remainder.toString().padLeft(3, '0')}';
    }
    return amount.toString();
  }

  // ============================================================================
  // DAILY LUCKY HAND SYSTEM
  // ============================================================================

  /// Get today's date as a string (YYYY-MM-DD)
  static String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Check if lucky hand needs to be refreshed for a new day
  static void _refreshLuckyHandIfNeeded() {
    final savedDate = _prefs?.getString(_luckyHandDateKey);
    final today = _getTodayString();

    if (savedDate != today) {
      // New day! Generate a new lucky hand
      final random = Random();
      final newIndex = random.nextInt(LuckyHandType.allHands.length);
      _prefs?.setString(_luckyHandDateKey, today);
      _prefs?.setInt(_luckyHandIndexKey, newIndex);
      _prefs?.setInt(_luckyHandWinsKey, 0); // Reset daily wins
    }
  }

  /// Get today's lucky hand
  static LuckyHandType get todaysLuckyHand {
    _refreshLuckyHandIfNeeded();
    final index = _prefs?.getInt(_luckyHandIndexKey) ?? 0;
    return LuckyHandType.allHands[index.clamp(0, LuckyHandType.allHands.length - 1)];
  }

  /// Get how many times the lucky hand has been won today
  static int get luckyHandWinsToday {
    _refreshLuckyHandIfNeeded();
    return _prefs?.getInt(_luckyHandWinsKey) ?? 0;
  }

  /// Record a lucky hand win and add bonus chips
  static Future<int> recordLuckyHandWin() async {
    _refreshLuckyHandIfNeeded();
    final currentWins = luckyHandWinsToday;
    final bonus = todaysLuckyHand.bonusReward;

    await _prefs?.setInt(_luckyHandWinsKey, currentWins + 1);
    await addChips(bonus);

    return bonus;
  }

  /// Check if a hand name matches today's lucky hand
  static bool isLuckyHand(String handName) {
    final lucky = todaysLuckyHand.name.toLowerCase();
    final check = handName.toLowerCase();

    // Handle variations in naming
    if (lucky.contains('high card') && check.contains('high card')) return true;
    if (lucky.contains('one pair') && (check.contains('pair') && !check.contains('two'))) return true;
    if (lucky.contains('two pair') && check.contains('two pair')) return true;
    if (lucky.contains('three of a kind') && (check.contains('three') || check.contains('trips'))) return true;
    if (lucky.contains('straight') &&
        !lucky.contains('flush') &&
        check.contains('straight') &&
        !check.contains('flush')) return true;
    if (lucky.contains('flush') &&
        !lucky.contains('straight') &&
        !lucky.contains('royal') &&
        check.contains('flush') &&
        !check.contains('straight') &&
        !check.contains('royal')) return true;
    if (lucky.contains('full house') && check.contains('full house')) return true;
    if (lucky.contains('four of a kind') && (check.contains('four') || check.contains('quads'))) return true;
    if (lucky.contains('straight flush') &&
        !lucky.contains('royal') &&
        check.contains('straight flush') &&
        !check.contains('royal')) return true;
    if (lucky.contains('royal flush') && check.contains('royal')) return true;

    return lucky == check;
  }

  // ============================================================================
  // PRO PASS TIER & XP SYSTEM
  // ============================================================================

  /// Get current Pro Pass tier (1-50)
  static int get proPassTier {
    return _prefs?.getInt(_proPassTierKey) ?? 1;
  }

  /// Set Pro Pass tier
  static Future<void> setProPassTier(int tier) async {
    await _prefs?.setInt(_proPassTierKey, tier.clamp(1, 50));
  }

  /// Get current Pro Pass XP
  static int get proPassXp {
    return _prefs?.getInt(_proPassXpKey) ?? 0;
  }

  /// Set Pro Pass XP
  static Future<void> setProPassXp(int xp) async {
    await _prefs?.setInt(_proPassXpKey, xp);
  }

  /// Get XP required for a specific tier
  static int xpForTier(int tier) {
    // Progressive XP requirements: base 500 + 100 per tier
    return 500 + (tier * 100);
  }

  /// Add XP and handle tier ups
  static Future<int> addProPassXp(int amount) async {
    int currentXp = proPassXp + amount;
    int currentTier = proPassTier;
    int tiersGained = 0;

    // Check for tier ups
    while (currentTier < 50 && currentXp >= xpForTier(currentTier)) {
      currentXp -= xpForTier(currentTier);
      currentTier++;
      tiersGained++;
    }

    await setProPassXp(currentXp);
    await setProPassTier(currentTier);

    return tiersGained;
  }

  // ============================================================================
  // GAME STATISTICS
  // ============================================================================

  // Games
  static int get gamesPlayed => _prefs?.getInt(_gamesPlayedKey) ?? 0;
  static int get gamesWon => _prefs?.getInt(_gamesWonKey) ?? 0;
  static double get winRate => gamesPlayed > 0 ? (gamesWon / gamesPlayed * 100) : 0.0;

  // Hands
  static int get handsPlayed => _prefs?.getInt(_handsPlayedKey) ?? 0;
  static int get handsWon => _prefs?.getInt(_handsWonKey) ?? 0;

  // Winning hands breakdown
  static int get highCards => _prefs?.getInt(_highCardsKey) ?? 0;
  static int get onePairs => _prefs?.getInt(_onePairsKey) ?? 0;
  static int get twoPairs => _prefs?.getInt(_twoPairsKey) ?? 0;
  static int get threeOfKinds => _prefs?.getInt(_threeOfKindsKey) ?? 0;
  static int get straights => _prefs?.getInt(_straightsKey) ?? 0;
  static int get flushes => _prefs?.getInt(_flushesKey) ?? 0;
  static int get fullHouses => _prefs?.getInt(_fullHousesKey) ?? 0;
  static int get fourOfKinds => _prefs?.getInt(_fourOfKindsKey) ?? 0;
  static int get straightFlushes => _prefs?.getInt(_straightFlushesKey) ?? 0;
  static int get royalFlushes => _prefs?.getInt(_royalFlushesKey) ?? 0;

  // Straight+ total
  static int get straightPlusTotal => straights + flushes + fullHouses + fourOfKinds + straightFlushes + royalFlushes;

  // Other stats
  static int get allInsWon => _prefs?.getInt(_allInsWonKey) ?? 0;
  static int get biggestPot => _prefs?.getInt(_biggestPotKey) ?? 0;
  static int get totalChipsWon => _prefs?.getInt(_totalChipsWonKey) ?? 0;
  static int get sitAndGoWins => _prefs?.getInt(_sitAndGoWinsKey) ?? 0;
  static int get currentWinStreak => _prefs?.getInt(_currentWinStreakKey) ?? 0;
  static int get bestWinStreak => _prefs?.getInt(_bestWinStreakKey) ?? 0;
  static int get dailyBonusClaims => _prefs?.getInt(_dailyBonusClaimsKey) ?? 0;

  /// Record a game played
  static Future<void> recordGamePlayed({required bool won}) async {
    await _prefs?.setInt(_gamesPlayedKey, gamesPlayed + 1);
    if (won) {
      await _prefs?.setInt(_gamesWonKey, gamesWon + 1);
      final newStreak = currentWinStreak + 1;
      await _prefs?.setInt(_currentWinStreakKey, newStreak);
      if (newStreak > bestWinStreak) {
        await _prefs?.setInt(_bestWinStreakKey, newStreak);
      }
    } else {
      await _prefs?.setInt(_currentWinStreakKey, 0);
    }
    // Award XP for playing
    await addProPassXp(won ? 50 : 10);
  }

  /// Record a hand won with specific hand type
  static Future<void> recordHandWon(String handType, int potSize) async {
    await _prefs?.setInt(_handsPlayedKey, handsPlayed + 1);
    await _prefs?.setInt(_handsWonKey, handsWon + 1);
    await _prefs?.setInt(_totalChipsWonKey, totalChipsWon + potSize);

    if (potSize > biggestPot) {
      await _prefs?.setInt(_biggestPotKey, potSize);
    }

    // Record by hand type
    final type = handType.toLowerCase();
    if (type.contains('royal')) {
      await _prefs?.setInt(_royalFlushesKey, royalFlushes + 1);
    } else if (type.contains('straight flush')) {
      await _prefs?.setInt(_straightFlushesKey, straightFlushes + 1);
    } else if (type.contains('four') || type.contains('quads')) {
      await _prefs?.setInt(_fourOfKindsKey, fourOfKinds + 1);
    } else if (type.contains('full house')) {
      await _prefs?.setInt(_fullHousesKey, fullHouses + 1);
    } else if (type.contains('flush')) {
      await _prefs?.setInt(_flushesKey, flushes + 1);
    } else if (type.contains('straight')) {
      await _prefs?.setInt(_straightsKey, straights + 1);
    } else if (type.contains('three') || type.contains('trips')) {
      await _prefs?.setInt(_threeOfKindsKey, threeOfKinds + 1);
    } else if (type.contains('two pair')) {
      await _prefs?.setInt(_twoPairsKey, twoPairs + 1);
    } else if (type.contains('pair')) {
      await _prefs?.setInt(_onePairsKey, onePairs + 1);
    } else {
      await _prefs?.setInt(_highCardsKey, highCards + 1);
    }

    // Award XP for winning hand
    await addProPassXp(5);
  }

  /// Record an all-in win
  static Future<void> recordAllInWon() async {
    await _prefs?.setInt(_allInsWonKey, allInsWon + 1);
    await addProPassXp(25);
  }

  /// Record a Sit & Go tournament win
  static Future<void> recordSitAndGoWin() async {
    await _prefs?.setInt(_sitAndGoWinsKey, sitAndGoWins + 1);
    await addProPassXp(100);
  }

  /// Record daily bonus claim
  static Future<void> recordDailyBonusClaim() async {
    await _prefs?.setInt(_dailyBonusClaimsKey, dailyBonusClaims + 1);
    await addProPassXp(20);
  }

  /// Get achievement progress for a specific achievement ID
  static int getAchievementProgress(String achievementId) {
    switch (achievementId) {
      case 'hands_won':
        return handsWon;
      case 'flush':
        return flushes;
      case 'straight':
        return straights;
      case 'full_house':
        return fullHouses;
      case 'games_won':
        return gamesWon;
      case 'win_streak':
        return bestWinStreak;
      case 'tournaments':
        return sitAndGoWins;
      case 'all_in':
        return allInsWon;
      case 'chip_earner':
        return totalChipsWon;
      case 'big_pot':
        return biggestPot;
      case 'daily_bonus':
        return dailyBonusClaims;
      default:
        return 0;
    }
  }
}
