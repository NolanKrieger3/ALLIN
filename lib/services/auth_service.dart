import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_preferences.dart';

/// Service for handling Firebase Authentication
/// Uses username + password authentication (internally uses email auth with generated emails)
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Domain for auto-generated emails from usernames
  static const String _emailDomain = 'allin.app';

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Convert username to internal email format
  String _usernameToEmail(String username) {
    return '${username.toLowerCase().trim()}@$_emailDomain';
  }

  /// Sign in anonymously (for dev/testing only)
  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  /// Sign in with username and password
  Future<UserCredential> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final email = _usernameToEmail(username);
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Register with username and password
  /// Creates Firebase auth account and stores username in Firestore
  Future<UserCredential> registerWithUsername({
    required String username,
    required String password,
  }) async {
    final email = _usernameToEmail(username);

    // Check if username is already taken in Firestore
    final existing =
        await _firestore.collection('users').where('usernameLower', isEqualTo: username.toLowerCase().trim()).get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Username already taken');
    }

    // Create Firebase auth account
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (credential.user != null) {
      await credential.user!.updateDisplayName(username);

      // Store user data in Firestore
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'username': username,
        'usernameLower': username.toLowerCase().trim(),
        'chips': 1000,
        'gems': 100,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Cache credentials locally for auto-login
      await UserPreferences.setUsername(username);
      await UserPreferences.setCachedUid(credential.user!.uid);
      await UserPreferences.setCachedPassword(password);
    }

    return credential;
  }

  /// Sign in with email and password (for dev menu/testing)
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Register with email and password (for dev menu/testing)
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (displayName != null && credential.user != null) {
      await credential.user!.updateDisplayName(displayName);
    }

    return credential;
  }

  /// Try to auto-login with cached credentials
  /// Returns true if login successful, false otherwise
  Future<bool> tryAutoLogin() async {
    final cachedUsername = UserPreferences.username;
    final cachedPassword = UserPreferences.cachedPassword;

    if (cachedUsername.isEmpty || cachedPassword == null || cachedPassword.isEmpty) {
      return false;
    }

    try {
      await signInWithUsername(username: cachedUsername, password: cachedPassword);
      return true;
    } catch (e) {
      // Auto-login failed - credentials may be invalid
      return false;
    }
  }

  /// Update display name
  Future<void> updateDisplayName(String displayName) async {
    await currentUser?.updateDisplayName(displayName);
  }

  /// Sign out and clear local user data (DEV ONLY)
  Future<void> signOut() async {
    await UserPreferences.clearAllUserData();
    await _auth.signOut();
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
