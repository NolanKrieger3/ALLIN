import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_preferences.dart';

/// Service for managing user profile data in Firestore
class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Default values for new users
  static const int defaultChips = 1000;
  static const int defaultGems = 100;

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Get user document reference
  DocumentReference? get _userDoc {
    final uid = _currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  /// Check if current user has a username set in Firestore
  Future<bool> hasUsername() async {
    final doc = _userDoc;
    if (doc == null) return false;

    try {
      final snapshot = await doc.get();
      if (!snapshot.exists) return false;

      final data = snapshot.data() as Map<String, dynamic>?;
      final username = data?['username'] as String?;
      return username != null && username.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get the current user's username from Firestore
  Future<String?> getUsername() async {
    final doc = _userDoc;
    if (doc == null) return null;

    try {
      final snapshot = await doc.get();
      if (!snapshot.exists) return null;

      final data = snapshot.data() as Map<String, dynamic>?;
      return data?['username'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Set username in Firestore and sync to local preferences
  Future<void> setUsername(String username) async {
    final doc = _userDoc;
    if (doc == null) throw Exception('User not logged in');

    final uid = _currentUserId!;

    // Check if username is already taken
    final existing =
        await _firestore.collection('users').where('usernameLower', isEqualTo: username.toLowerCase()).get();

    // If someone else has this username, throw error
    for (final existingDoc in existing.docs) {
      if (existingDoc.id != uid) {
        throw Exception('Username already taken');
      }
    }

    // Save to Firestore
    await doc.set({
      'username': username,
      'usernameLower': username.toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Also update local preferences for quick access
    await UserPreferences.setUsername(username);
  }

  /// Load username from Firestore and sync to local preferences
  /// Call this on app start after user is authenticated
  Future<String?> syncUsername() async {
    final username = await getUsername();

    if (username != null && username.isNotEmpty) {
      // Sync to local preferences
      await UserPreferences.setUsername(username);
      return username;
    } else {
      // No username in Firestore, clear local
      await UserPreferences.clearUsername();
      return null;
    }
  }

  /// Check if a username is available
  Future<bool> isUsernameAvailable(String username) async {
    if (username.isEmpty) return false;

    final existing =
        await _firestore.collection('users').where('usernameLower', isEqualTo: username.toLowerCase()).get();

    // Available if no one has it, or only current user has it
    for (final doc in existing.docs) {
      if (doc.id != _currentUserId) {
        return false;
      }
    }
    return true;
  }

  /// Update user's online status
  Future<void> setOnlineStatus(bool isOnline) async {
    final doc = _userDoc;
    if (doc == null) return;

    try {
      await doc.set({
        'isOnline': isOnline,
        'lastOnline': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Ignore errors
    }
  }

  /// Get full user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    final doc = _userDoc;
    if (doc == null) return null;

    try {
      final snapshot = await doc.get();
      if (!snapshot.exists) return null;
      return snapshot.data() as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Update user profile fields
  Future<void> updateProfile(Map<String, dynamic> data) async {
    final doc = _userDoc;
    if (doc == null) return;

    await doc.set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ===== CHIPS MANAGEMENT =====

  /// Get chips from Firestore
  Future<int> getChips() async {
    final doc = _userDoc;
    if (doc == null) return defaultChips;

    try {
      final snapshot = await doc.get();
      if (!snapshot.exists) return defaultChips;

      final data = snapshot.data() as Map<String, dynamic>?;
      return data?['chips'] as int? ?? defaultChips;
    } catch (e) {
      return defaultChips;
    }
  }

  /// Set chips in Firestore and sync to local
  Future<void> setChips(int amount) async {
    final doc = _userDoc;
    if (doc == null) return;

    await doc.set({
      'chips': amount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Sync to local
    await UserPreferences.setChips(amount);
  }

  /// Add chips (both Firestore and local)
  Future<void> addChips(int amount) async {
    final current = await getChips();
    await setChips(current + amount);
  }

  /// Spend chips (both Firestore and local)
  Future<bool> spendChips(int amount) async {
    final current = await getChips();
    if (current < amount) return false;
    await setChips(current - amount);
    return true;
  }

  // ===== GEMS MANAGEMENT =====

  /// Get gems from Firestore
  Future<int> getGems() async {
    final doc = _userDoc;
    if (doc == null) return defaultGems;

    try {
      final snapshot = await doc.get();
      if (!snapshot.exists) return defaultGems;

      final data = snapshot.data() as Map<String, dynamic>?;
      return data?['gems'] as int? ?? defaultGems;
    } catch (e) {
      return defaultGems;
    }
  }

  /// Set gems in Firestore and sync to local
  Future<void> setGems(int amount) async {
    final doc = _userDoc;
    if (doc == null) return;

    await doc.set({
      'gems': amount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Sync to local
    await UserPreferences.setGems(amount);
  }

  /// Add gems to current balance (use negative value to spend)
  Future<void> addGems(int amount) async {
    final currentGems = await getGems();
    final newGems = currentGems + amount;
    await setGems(newGems);
  }

  /// Spend gems (returns false if insufficient balance)
  Future<bool> spendGems(int amount) async {
    final currentGems = await getGems();
    if (currentGems < amount) return false;
    await setGems(currentGems - amount);
    return true;
  }

  // ===== FULL SYNC =====

  /// Sync all user data from Firestore to local preferences
  /// Call this on app start after user is authenticated
  Future<Map<String, dynamic>?> syncAllUserData() async {
    final doc = _userDoc;
    if (doc == null) return null;

    final currentUid = _currentUserId!;

    // Check if user has changed (account switch)
    final cachedUid = UserPreferences.cachedUid;
    if (cachedUid != null && cachedUid != currentUid) {
      // Different user - clear all old cached data
      await UserPreferences.clearAllUserData();
    }
    // Update cached UID
    await UserPreferences.setCachedUid(currentUid);

    try {
      final snapshot = await doc.get();

      if (!snapshot.exists) {
        // New user - create initial profile with defaults
        await doc.set({
          'chips': defaultChips,
          'gems': defaultGems,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await UserPreferences.setChips(defaultChips);
        await UserPreferences.setGems(defaultGems);
        await UserPreferences.clearUsername();
        return null;
      }

      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return null;

      // Sync username
      final username = data['username'] as String?;
      if (username != null && username.isNotEmpty) {
        await UserPreferences.setUsername(username);
      } else {
        await UserPreferences.clearUsername();
      }

      // Sync chips
      final chips = data['chips'] as int? ?? defaultChips;
      await UserPreferences.setChips(chips);

      // Sync gems
      final gems = data['gems'] as int? ?? defaultGems;
      await UserPreferences.setGems(gems);

      // Sync Pro Pass status
      final hasProPass = data['hasProPass'] as bool? ?? false;
      await UserPreferences.setProPass(hasProPass);

      return data;
    } catch (e) {
      return null;
    }
  }

  /// Check if user needs username setup (no username in Firestore)
  Future<bool> needsUsernameSetup() async {
    final username = await getUsername();
    return username == null || username.isEmpty;
  }

  /// Set Pro Pass status in Firestore and sync to local
  Future<void> setProPass(bool value) async {
    final doc = _userDoc;
    if (doc == null) {
      // Not logged in, just save locally
      await UserPreferences.setProPass(value);
      return;
    }

    try {
      await doc.set({
        'hasProPass': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update local preferences
      await UserPreferences.setProPass(value);
    } catch (e) {
      // If Firestore fails, still save locally
      await UserPreferences.setProPass(value);
    }
  }

  /// Get Pro Pass status from Firestore
  Future<bool> getProPass() async {
    final doc = _userDoc;
    if (doc == null) return UserPreferences.hasProPass;

    try {
      final snapshot = await doc.get();
      if (!snapshot.exists) return false;

      final data = snapshot.data() as Map<String, dynamic>?;
      return data?['hasProPass'] as bool? ?? false;
    } catch (e) {
      return UserPreferences.hasProPass;
    }
  }
}
