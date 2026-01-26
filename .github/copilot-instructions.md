# ALLIN - Flutter App Development Guidelines

## Project Overview
Cross-platform mobile app for iOS and Android using Flutter with Material Design 3.

## Tech Stack
- **Framework**: Flutter 3.10+
- **Language**: Dart
- **State Management**: Provider
- **HTTP Client**: http package
- **Local Storage**: shared_preferences

## Architecture
Follow the clean architecture pattern:
- `screens/` - Full page widgets
- `widgets/` - Reusable UI components
- `models/` - Data classes with JSON serialization
- `services/` - API calls and external integrations
- `providers/` - State management classes
- `utils/` - Helper functions
- `config/` - App-wide configuration

## Coding Standards
- Use `const` constructors where possible
- Prefer composition over inheritance
- Keep widgets small and focused
- Use named parameters for clarity
- Follow Dart effective style guide

## Commands
- `flutter run` - Run in debug mode
- `flutter test` - Run tests
- `flutter analyze` - Check for issues
- `flutter build apk` - Build Android
- `flutter build ios` - Build iOS
