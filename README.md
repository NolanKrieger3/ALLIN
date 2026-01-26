# ALLIN

A cross-platform mobile application built with Flutter for iOS and Android.

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.10+)
- [Android Studio](https://developer.android.com/studio) or [Xcode](https://developer.apple.com/xcode/) (for iOS)
- VS Code with Flutter extension

### Installation

```bash
# Get dependencies
flutter pub get

# Run the app
flutter run
```

### Build for Production

```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (requires macOS)
flutter build ios --release
```

## 📁 Project Structure

```
lib/
├── config/          # App configuration (theme, routes)
├── models/          # Data models
├── providers/       # State management (Provider)
├── screens/         # App screens/pages
├── services/        # API and external services
├── utils/           # Helper functions
├── widgets/         # Reusable UI components
└── main.dart        # App entry point
```

## 🎨 Features

- ✅ Material Design 3 theming (light/dark mode)
- ✅ Clean architecture structure
- ✅ State management with Provider
- ✅ HTTP service for API calls
- ✅ Navigation/routing setup
- ✅ Reusable widgets

## 📱 Publishing to App Stores

### Google Play Store
1. Create a [Google Play Developer account](https://play.google.com/console)
2. Generate a signed app bundle: `flutter build appbundle`
3. Upload to Play Console and complete store listing

### Apple App Store
1. Enroll in [Apple Developer Program](https://developer.apple.com/programs/)
2. Configure signing in Xcode
3. Build: `flutter build ipa`
4. Upload via App Store Connect

## 📚 Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Provider Package](https://pub.dev/packages/provider)
- [App Store Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Policies](https://play.google.com/about/developer-content-policy/)

