import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user preferences stored locally
class UserPreferences {
  static const String _usernameKey = 'username';
  static const String _hasSetUsernameKey = 'has_set_username';
  
  static SharedPreferences? _prefs;
  
  /// Initialize shared preferences
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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
      'Lucky', 'Wild', 'Slick', 'Crafty', 'Bold', 'Swift', 'Clever', 'Sly',
      'Sharp', 'Cool', 'Hot', 'Ice', 'Fire', 'Thunder', 'Shadow', 'Golden',
      'Silver', 'Iron', 'Steel', 'Diamond', 'Royal', 'Ace', 'King', 'Queen',
    ];
    
    final nouns = [
      'Shark', 'Wolf', 'Fox', 'Eagle', 'Tiger', 'Lion', 'Bear', 'Hawk',
      'Viper', 'Dragon', 'Phoenix', 'Maverick', 'Bluffer', 'Dealer', 'Player',
      'Gambler', 'Hustler', 'Pro', 'Champ', 'Legend', 'Boss', 'Chief', 'Duke',
    ];
    
    final random = Random();
    final adjective = adjectives[random.nextInt(adjectives.length)];
    final noun = nouns[random.nextInt(nouns.length)];
    final number = random.nextInt(99) + 1;
    
    return '$adjective$noun$number';
  }
}
