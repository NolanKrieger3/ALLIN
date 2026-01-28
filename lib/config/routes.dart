import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/username_setup_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String usernameSetup = '/username-setup';
  // Add more routes as your app grows
  // static const String profile = '/profile';
  // static const String settings = '/settings';

  static Map<String, WidgetBuilder> get routes => {
        // Note: '/' is handled by home property in MaterialApp, don't add it here
        usernameSetup: (context) => const UsernameSetupScreen(),
        // Add more routes here
      };

  // For named navigation with arguments
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        );
      case usernameSetup:
        return MaterialPageRoute(
          builder: (context) => const UsernameSetupScreen(),
        );
      // Add more cases for routes with arguments
      default:
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(
              child: Text('Route not found'),
            ),
          ),
        );
    }
  }
}
