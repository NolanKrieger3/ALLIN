import 'package:flutter/material.dart';

/// Global app state provider using ChangeNotifier
/// For complex apps, consider using Riverpod or BLoC
class AppState extends ChangeNotifier {
  // Theme mode
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  // Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // User authentication state
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  void setAuthenticated(bool authenticated) {
    _isAuthenticated = authenticated;
    notifyListeners();
  }

  // Player currency - single source of truth
  int _coins = 10000;
  int get coins => _coins;

  int _gems = 100;
  int get gems => _gems;

  void setCoins(int amount) {
    _coins = amount;
    notifyListeners();
  }

  void addCoins(int amount) {
    _coins += amount;
    notifyListeners();
  }

  void spendCoins(int amount) {
    if (_coins >= amount) {
      _coins -= amount;
      notifyListeners();
    }
  }

  void setGems(int amount) {
    _gems = amount;
    notifyListeners();
  }

  void addGems(int amount) {
    _gems += amount;
    notifyListeners();
  }

  void spendGems(int amount) {
    if (_gems >= amount) {
      _gems -= amount;
      notifyListeners();
    }
  }

  /// Format coins/gems for display (e.g., 10000 -> "10,000")
  String formatCurrency(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      final formatted = amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
      return formatted;
    }
    return amount.toString();
  }
}
