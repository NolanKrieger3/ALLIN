import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing in-game currencies (chips and gems)
/// Centralized currency management for the entire app
class CurrencyService {
  static const String _chipsKey = 'chips';
  static const String _gemsKey = 'gems';
  static const int defaultChips = 10000;
  static const int defaultGems = 100;

  static SharedPreferences? _prefs;

  /// Initialize currency service (call after UserPreferences.init())
  static Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
  }

  // ============ CHIPS ============

  /// Get current chip balance
  static int get chips {
    return _prefs?.getInt(_chipsKey) ?? defaultChips;
  }

  /// Set chip balance directly
  static Future<void> setChips(int amount) async {
    await _prefs?.setInt(_chipsKey, amount.clamp(0, 999999999));
  }

  /// Add chips to balance (winnings, bonuses, purchases)
  static Future<void> addChips(int amount) async {
    if (amount <= 0) return;
    final current = chips;
    await setChips(current + amount);
  }

  /// Spend chips (buy-ins, purchases)
  /// Returns true if successful, false if insufficient balance
  static Future<bool> spendChips(int amount) async {
    if (amount <= 0) return true;
    final current = chips;
    if (current < amount) return false;
    await setChips(current - amount);
    return true;
  }

  /// Check if user can afford an amount
  static bool canAfford(int amount) {
    return chips >= amount;
  }

  // ============ GEMS ============

  /// Get current gem balance
  static int get gems {
    return _prefs?.getInt(_gemsKey) ?? defaultGems;
  }

  /// Set gem balance directly
  static Future<void> setGems(int amount) async {
    await _prefs?.setInt(_gemsKey, amount.clamp(0, 999999999));
  }

  /// Add gems to balance
  static Future<void> addGems(int amount) async {
    if (amount <= 0) return;
    final current = gems;
    await setGems(current + amount);
  }

  /// Spend gems
  /// Returns true if successful, false if insufficient balance
  static Future<bool> spendGems(int amount) async {
    if (amount <= 0) return true;
    final current = gems;
    if (current < amount) return false;
    await setGems(current - amount);
    return true;
  }

  /// Check if user can afford gems
  static bool canAffordGems(int amount) {
    return gems >= amount;
  }

  // ============ FORMATTING ============

  /// Format chips with K/M suffixes for display
  static String formatChips(int amount) {
    if (amount >= 1000000) {
      final millions = amount / 1000000;
      return '${millions.toStringAsFixed(millions % 1 == 0 ? 0 : 1)}M';
    }
    if (amount >= 10000) {
      final thousands = amount / 1000;
      return '${thousands.toStringAsFixed(thousands % 1 == 0 ? 0 : 1)}K';
    }
    if (amount >= 1000) {
      return '${amount ~/ 1000},${(amount % 1000).toString().padLeft(3, '0')}';
    }
    return amount.toString();
  }

  /// Format gems for display
  static String formatGems(int amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toString();
  }

  /// Format chips with full number (no abbreviation)
  static String formatChipsFull(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  // ============ RESET ============

  /// Reset to default values (for testing or new accounts)
  static Future<void> reset() async {
    await setChips(defaultChips);
    await setGems(defaultGems);
  }
}

/// Blind level configuration for Quick Play
class BlindLevels {
  /// All available blind levels
  /// Format: small blind, big blind, buy-in amount
  static const List<BlindLevel> all = [
    BlindLevel(small: 25, big: 50, buyIn: 2500),
    BlindLevel(small: 100, big: 200, buyIn: 10000),
    BlindLevel(small: 500, big: 1000, buyIn: 50000),
    BlindLevel(small: 2500, big: 5000, buyIn: 250000),
  ];

  /// Get the highest blind level a player can afford
  static int getHighestAffordableIndex(int chipBalance) {
    for (int i = all.length - 1; i >= 0; i--) {
      if (chipBalance >= all[i].buyIn) {
        return i;
      }
    }
    return 0;
  }

  /// Check if player can afford a specific level
  static bool canAfford(int index, int chipBalance) {
    if (index < 0 || index >= all.length) return false;
    return chipBalance >= all[index].buyIn;
  }
}

/// Single blind level configuration
class BlindLevel {
  final int small;
  final int big;
  final int buyIn;

  const BlindLevel({
    required this.small,
    required this.big,
    required this.buyIn,
  });

  String get label => '${_formatShort(small)}/${_formatShort(big)}';
  String get buyInLabel => _formatShort(buyIn);

  static String _formatShort(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(0)}M';
    }
    if (amount >= 1000) {
      final k = amount / 1000;
      return k % 1 == 0 ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    }
    return amount.toString();
  }
}
