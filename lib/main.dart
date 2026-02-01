import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/app_state.dart';
import 'services/user_preferences.dart';
import 'services/user_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling for desktop platforms
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  await UserPreferences.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'ALLIN_HOTRELOAD_5555',
            debugShowCheckedModeBanner: false,

            // Theming
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: appState.themeMode,

            // Start with splash screen that checks auth state
            home: const _AuthCheckScreen(),
            routes: AppRoutes.routes,
            onGenerateRoute: AppRoutes.onGenerateRoute,
          );
        },
      ),
    );
  }
}

/// Splash screen that checks authentication and syncs user data
class _AuthCheckScreen extends StatefulWidget {
  const _AuthCheckScreen();

  @override
  State<_AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<_AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    // Use post frame callback to avoid navigation while building
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndNavigate();
    });
  }

  void _goToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      final auth = FirebaseAuth.instance;
      final userService = UserService();

      // Add small delay to let Firebase Auth settle on desktop platforms
      // This helps avoid threading issues with the native plugin
      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Check if already signed in
      if (auth.currentUser != null) {
        // User is already signed in - sync their data from Firestore
        final needsSetup = await userService.needsUsernameSetup();

        if (mounted) {
          if (needsSetup) {
            // User has auth but no username (shouldn't happen normally)
            Navigator.of(context).pushReplacementNamed('/username-setup');
          } else {
            // Sync data and go to home
            await userService.syncAllUserData();
            if (mounted) {
              _goToHome();
            }
          }
        }
        return;
      }

      // Not signed in - check if we have cached credentials for auto-login
      if (UserPreferences.hasSetUsername && UserPreferences.cachedPassword != null) {
        // Try auto-login with cached credentials
        try {
          final username = UserPreferences.username;
          final password = UserPreferences.cachedPassword!;
          await auth.signInWithEmailAndPassword(
            email: '${username.toLowerCase()}@allin.app',
            password: password,
          );
          // Auto-login successful - sync and go home
          await userService.syncAllUserData();
          if (mounted) {
            _goToHome();
          }
          return;
        } catch (e) {
          // Auto-login failed - clear cached data and go to setup
          debugPrint('Auto-login failed: $e');
          await UserPreferences.clearAllUserData();
        }
      }

      // No valid session - go to username setup (create account)
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/username-setup');
      }
    } catch (e) {
      // Handle any Firebase Auth errors gracefully
      debugPrint('Auth check error: $e');
      // On error, still navigate to setup screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/username-setup');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.casino, color: Colors.white, size: 50),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: Color(0xFFD4AF37),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
