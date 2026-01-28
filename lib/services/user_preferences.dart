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

/// Service for managing user preferences stored locally
class UserPreferences {
  static const String _usernameKey = 'username';
  static const String _hasSetUsernameKey = 'has_set_username';
  static const String _chipsKey = 'chips';
  static const String _gemsKey = 'gems';
  static const String _luckyHandDateKey = 'lucky_hand_date';
  static const String _luckyHandIndexKey = 'lucky_hand_index';
  static const String _luckyHandWinsKey = 'lucky_hand_wins_today';
  static const String _hasProPassKey = 'has_pro_pass';
  static const int _defaultChips = 1000;
  static const int _defaultGems = 100;

  static SharedPreferences? _prefs;

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
    // Generate random name for testing
    return _generateRandomName();
  }

  /// Save username
  static Future<void> setUsername(String username) async {
    await _prefs?.setString(_usernameKey, username);
    await _prefs?.setBool(_hasSetUsernameKey, true);
  }

  /// Clear username (for testing)
  static Future<void> clearUsername() async {
    await _prefs?.remove(_usernameKey);
    await _prefs?.setBool(_hasSetUsernameKey, false);
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
}
