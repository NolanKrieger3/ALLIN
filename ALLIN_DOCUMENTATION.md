# ALLIN - Complete Project Documentation

> **Purpose**: This document provides comprehensive documentation for the ALLIN poker mobile app. It is structured for AI assistants (like Claude) to quickly understand the codebase, architecture, and business goals.

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Business Goals & App Store Launch Plan](#business-goals--app-store-launch-plan)
3. [Technology Stack](#technology-stack)
4. [Architecture Overview](#architecture-overview)
5. [Directory Structure](#directory-structure)
6. [Core Files Deep Dive](#core-files-deep-dive)
7. [Data Models](#data-models)
8. [Services Layer](#services-layer)
9. [Screens & Navigation](#screens--navigation)
10. [Widgets Library](#widgets-library)
11. [State Management](#state-management)
12. [Firebase Integration](#firebase-integration)
13. [Game Logic](#game-logic)
14. [Build & Deployment](#build--deployment)
15. [Common Patterns & Conventions](#common-patterns--conventions)

---

## Project Overview

**ALLIN** is a cross-platform mobile poker game built with Flutter, targeting iOS and Android platforms. The app offers Texas Hold'em poker gameplay with real-time multiplayer capabilities, social features (friends, teams), and a full in-app economy (chips, gems, shop).

### Key Features

- 🎮 **Real-time Multiplayer Poker** - Texas Hold'em with 2+ players
- 👥 **Social System** - Friends, friend requests, game invites
- 🏆 **Teams/Clubs** - Create or join teams with chat functionality
- 🛒 **In-App Shop** - Currency purchases, cosmetics, daily bonuses
- 📚 **Interactive Tutorial** - Learn poker with guided lessons
- 🎨 **Dark Theme UI** - Premium casino-style dark interface
- 🔐 **Firebase Auth** - Username/password authentication

### Current Version

- **Version**: 1.0.0+1
- **Dart SDK**: ^3.6.0
- **Flutter**: 3.10+

---

## Business Goals & App Store Launch Plan

### Mission

Create an engaging, social poker experience that captures the excitement of live poker while being accessible to casual and serious players.

### App Store Launch Checklist

#### Pre-Launch Requirements

- [ ] **Privacy Policy** - Required for both stores
- [ ] **Terms of Service** - Required for gambling-adjacent apps
- [ ] **Age Rating** - Likely 17+ due to simulated gambling
- [ ] **App Icons** - All required sizes for iOS and Android
- [ ] **Screenshots** - 5-10 per device size
- [ ] **App Preview Videos** - Highly recommended
- [ ] **Store Descriptions** - Optimized for ASO

#### Google Play Store

1. Create Google Play Developer account ($25 one-time)
2. Generate signed app bundle: `flutter build appbundle --release`
3. Complete store listing with required assets
4. Set up in-app purchases in Play Console
5. Submit for review

#### Apple App Store

1. Enroll in Apple Developer Program ($99/year)
2. Configure code signing in Xcode
3. Create App Store Connect listing
4. Build and archive: `flutter build ipa --release`
5. Upload via Transporter or Xcode
6. Submit for review

### Monetization Strategy

- **Chip Packs** - Virtual currency purchases
- **Gem Packs** - Premium currency for cosmetics
- **VIP/Pro Pass** - Subscription for bonuses
- **Cosmetics** - Card backs, avatars, emotes

### Target Metrics

- Daily Active Users (DAU)
- Average Session Length
- Retention (D1, D7, D30)
- ARPU (Average Revenue Per User)
- Conversion Rate (free to paying)

---

## Technology Stack

### Core Framework

```yaml
Framework: Flutter 3.10+
Language: Dart
Platforms: iOS, Android, Web (debug), Windows (debug)
```

### Dependencies

```yaml
# State Management
provider: ^6.1.2

# Backend / Database
firebase_core: ^4.4.0
firebase_auth: ^6.1.4
cloud_firestore: ^6.1.2

# Networking
http: ^1.6.0

# Local Storage
shared_preferences: ^2.2.2

# UI
cupertino_icons: ^1.0.8
```

### Development Tools

```yaml
flutter_lints: ^5.0.0
```

---

## Architecture Overview

ALLIN follows a **clean architecture** pattern with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER                      │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────────┐ │
│  │ Screens │  │   Tabs  │  │ Widgets │  │ Animated Buttons│ │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────────┬────────┘ │
└───────┼────────────┼────────────┼────────────────┼──────────┘
        │            │            │                │
        └────────────┴────────────┴────────────────┘
                              │
┌─────────────────────────────┼───────────────────────────────┐
│                     STATE MANAGEMENT                         │
│                    ┌────────┴────────┐                       │
│                    │    Provider     │                       │
│                    │   (AppState)    │                       │
│                    └────────┬────────┘                       │
└─────────────────────────────┼───────────────────────────────┘
                              │
┌─────────────────────────────┼───────────────────────────────┐
│                      SERVICES LAYER                          │
│  ┌───────────┐ ┌────────────┐ ┌──────────┐ ┌─────────────┐  │
│  │AuthService│ │GameService │ │UserService│ │FriendsService│ │
│  └───────────┘ └────────────┘ └──────────┘ └─────────────┘  │
│  ┌───────────┐ ┌────────────┐ ┌───────────────────────────┐ │
│  │TeamService│ │HandEvaluator│ │    UserPreferences      │ │
│  └───────────┘ └────────────┘ └───────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────┼───────────────────────────────┐
│                       DATA LAYER                             │
│  ┌──────────────────────────┴─────────────────────────────┐ │
│  │                      Firebase                           │ │
│  │   ┌────────────┐  ┌─────────────┐  ┌────────────────┐  │ │
│  │   │ Firestore  │  │ Realtime DB │  │  Firebase Auth │  │ │
│  │   │  (Users,   │  │ (Game Rooms,│  │  (Accounts)    │  │ │
│  │   │  Friends)  │  │   Teams)    │  │                │  │ │
│  │   └────────────┘  └─────────────┘  └────────────────┘  │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Design Principles

1. **Composition over Inheritance** - Small, focused widgets
2. **Single Responsibility** - Each service handles one domain
3. **Separation of Concerns** - UI, logic, and data are isolated
4. **Const Constructors** - Used wherever possible for performance
5. **Named Parameters** - For clarity in function calls

---

## Directory Structure

```
allin/
├── lib/
│   ├── main.dart                 # App entry point, Firebase init
│   ├── firebase_options.dart     # Auto-generated Firebase config
│   │
│   ├── config/                   # App-wide configuration
│   │   ├── routes.dart           # Navigation routes
│   │   └── theme.dart            # Material 3 theming
│   │
│   ├── models/                   # Data classes (JSON serialization)
│   │   ├── user.dart             # User profile model
│   │   ├── game_room.dart        # Game room, players, cards
│   │   ├── friend.dart           # Friend, FriendRequest, GameInvite
│   │   └── team.dart             # Team, TeamMember, TeamChat
│   │
│   ├── providers/                # State management
│   │   └── app_state.dart        # Global app state (coins, theme)
│   │
│   ├── services/                 # Business logic & API calls
│   │   ├── auth_service.dart     # Firebase authentication
│   │   ├── game_service.dart     # Multiplayer game management
│   │   ├── user_service.dart     # User profile CRUD
│   │   ├── user_preferences.dart # Local storage (SharedPrefs)
│   │   ├── friends_service.dart  # Friends system
│   │   ├── team_service.dart     # Teams/clubs system
│   │   └── hand_evaluator.dart   # Poker hand ranking logic
│   │
│   ├── screens/                  # Full-page views
│   │   ├── home_screen.dart      # Main navigation container
│   │   ├── lobby_screen.dart     # Game lobby & matchmaking
│   │   ├── multiplayer_game_screen.dart # Live poker table
│   │   ├── game_screen.dart      # Single-player practice
│   │   ├── quick_play_screen.dart
│   │   ├── sit_and_go_screen.dart
│   │   ├── sit_and_go_waiting_screen.dart
│   │   ├── tutorial_screen.dart  # Interactive poker tutorial
│   │   ├── username_setup_screen.dart # Account creation
│   │   └── tabs/                 # Home screen tabs
│   │       ├── home_tab.dart     # Main menu, quick play
│   │       ├── shop_tab.dart     # Store, purchases
│   │       └── profile_tab.dart  # User profile, settings
│   │
│   ├── widgets/                  # Reusable UI components
│   │   ├── animated_buttons.dart # Tap animations
│   │   ├── custom_button.dart    # Styled buttons
│   │   ├── friends_widgets.dart  # Friend list, add friend
│   │   ├── shared_widgets.dart   # Common UI elements
│   │   └── mobile_wrapper.dart   # Mobile-first responsive wrapper
│   │
│   └── utils/                    # Helper functions
│       └── helpers.dart          # Snackbars, dialogs, validation
│
├── android/                      # Android native code
│   ├── app/
│   │   └── google-services.json  # Firebase Android config
│   └── build.gradle.kts
│
├── ios/                          # iOS native code
│   └── Runner/
│       └── Info.plist
│
├── web/                          # Web platform (debug)
├── windows/                      # Windows platform (debug)
├── test/                         # Unit and widget tests
│
├── pubspec.yaml                  # Dependencies & assets
├── firebase.json                 # Firebase hosting config
└── analysis_options.yaml         # Linter rules
```

---

## Core Files Deep Dive

### `lib/main.dart` - Application Entry Point

**Purpose**: Initializes Firebase, sets up the Provider, and determines the initial screen based on auth state.

```dart
// Key initialization sequence:
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await UserPreferences.init();
  runApp(const MyApp());
}
```

**Flow**:

1. Initialize Flutter binding
2. Initialize Firebase
3. Initialize SharedPreferences (local storage)
4. Run app with Provider wrapper
5. Check auth state → Route to Home or Username Setup

### `lib/config/theme.dart` - Material 3 Theming

**Colors**:

- Primary: `#6366F1` (Indigo)
- Secondary: `#8B5CF6` (Purple)
- Accent: `#06B6D4` (Cyan)
- Background: `#0A0A0A` (Near black)
- Gold: `#D4AF37` (Premium accent)
- Green: `#00D46A` (Success/positive actions)

**Theme Features**:

- Material 3 design system
- Light and dark themes (dark is primary)
- Consistent border radius (12-16px)
- Card elevation with shadows

### `lib/config/routes.dart` - Navigation

**Routes**:

```dart
static const String home = '/';
static const String usernameSetup = '/username-setup';
```

Uses `onGenerateRoute` for dynamic routing with arguments.

---

## Data Models

### `models/user.dart` - User Profile

```dart
class User {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final DateTime createdAt;

  // JSON serialization included
  factory User.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
  User copyWith({...});
}
```

### `models/game_room.dart` - Game State

**Core Classes**:

```dart
// A playing card
class PlayingCard {
  final String rank;  // 'A', 'K', 'Q', 'J', '10'-'2'
  final String suit;  // '♠', '♥', '♦', '♣'
}

// A player in the game
class GamePlayer {
  final String uid;
  final String displayName;
  final int chips;
  final List<PlayingCard> cards;      // Hole cards
  final bool hasFolded;
  final int currentBet;
  final int totalContributed;          // For side pots
  final bool isReady;
  final bool hasActed;
  final String? lastAction;            // 'CALL', 'RAISE', 'FOLD', etc.
  final DateTime? lastActiveAt;        // Heartbeat for disconnect detection
}

// The game room itself
class GameRoom {
  final String id;
  final String hostId;
  final List<GamePlayer> players;
  final int maxPlayers;                // Default: 2
  final int bigBlind;                  // Default: 100
  final int smallBlind;                // Default: 50
  final String status;                 // 'waiting', 'playing', 'finished'
  final String phase;                  // 'preflop', 'flop', 'turn', 'river', 'showdown'
  final int pot;
  final int currentBet;
  final String? currentTurnPlayerId;
  final int dealerIndex;
  final List<PlayingCard> communityCards;
  final List<String> deck;
  final String gameType;               // 'cash', 'sitandgo', 'headsup'
  final bool isPrivate;
  final int turnTimeLimit;             // Default: 30 seconds
}
```

### `models/friend.dart` - Social Features

```dart
class Friend {
  final String id;
  final String username;
  final bool isOnline;
  final String? currentGame;  // Room code if in a game
  final int rank;
  final int chips;
}

class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromUsername;
  final String toUserId;
  final FriendRequestStatus status;  // pending, accepted, rejected
}

class GameInvite {
  final String id;
  final String fromUserId;
  final String roomId;
  final DateTime expiresAt;
}
```

### `models/team.dart` - Teams/Clubs

```dart
class TeamMember {
  final String uid;
  final String displayName;
  final String rank;           // 'captain', 'officer', 'member'
  final int totalWinnings;
}

class Team {
  final String id;
  final String name;
  final String description;
  final int emblemIndex;       // Team logo selection
  final String captainId;
  final List<TeamMember> members;
  final bool isOpen;           // Open to join vs invite-only
  final int totalWinnings;
}

class TeamChatMessage {
  final String id;
  final String senderUid;
  final String message;
  final DateTime timestamp;
}
```

---

## Services Layer

### `services/auth_service.dart` - Authentication

**Purpose**: Handles Firebase Authentication with username-based login.

**Key Methods**:

```dart
// Username → internal email conversion
String _usernameToEmail(String username) {
  return '${username.toLowerCase().trim()}@allin.app';
}

// Core auth operations
Future<UserCredential> signInWithUsername({username, password});
Future<UserCredential> registerWithUsername({username, password});
Future<void> signOut();
Future<bool> tryAutoLogin();  // Uses cached credentials
```

**Flow**:

1. User enters username + password
2. Username converted to fake email (`username@allin.app`)
3. Firebase handles actual auth
4. Credentials cached locally for auto-login

### `services/game_service.dart` - Game Management

**Purpose**: Manages multiplayer poker games via Firebase Realtime Database REST API.

**Database URL**: `https://allin-d0e2d-default-rtdb.firebaseio.com`

**Key Methods**:

```dart
// Room management
Future<GameRoom> createRoom({bigBlind, startingChips, isPrivate, gameType});
Future<void> joinRoom(String roomId, {startingChips});
Future<void> leaveRoom(String roomId);
Stream<GameRoom?> watchRoom(String roomId);

// Game actions
Future<void> startGame(String roomId, {skipReadyCheck});
Future<void> playerAction(String roomId, String action, {int? raiseAmount});
Future<void> newHand(String roomId);

// Matchmaking
Future<List<GameRoom>> fetchJoinableRoomsByBlind(int bigBlind, {gameType});
Stream<List<GameRoom>> getAvailableRooms();

// Heartbeat (disconnect detection)
Future<void> sendHeartbeat(String roomId);
Future<void> removeInactivePlayers(String roomId);
```

**Game Phases**:

```dart
enum GamePhase {
  preflop,
  flop,
  turn,
  river,
  showdown,
  waitingForPlayers
}
```

### `services/user_service.dart` - User Data

**Purpose**: Manages user profile data in Firestore (cloud persistence).

**Key Methods**:

```dart
// Profile
Future<bool> hasUsername();
Future<void> setUsername(String username);
Future<bool> isUsernameAvailable(String username);
Future<Map<String, dynamic>?> getUserProfile();

// Chips (virtual currency)
Future<int> getChips();
Future<void> setChips(int amount);
Future<void> addChips(int amount);
Future<bool> spendChips(int amount);

// Gems (premium currency)
Future<int> getGems();
Future<void> setGems(int amount);

// Sync
Future<Map<String, dynamic>?> syncAllUserData();
```

### `services/user_preferences.dart` - Local Storage

**Purpose**: Fast local storage using SharedPreferences for offline access and caching.

**Key Properties**:

```dart
static bool get hasSetUsername;
static String get username;
static String? get cachedPassword;  // For auto-login
static int get chips;               // Default: 1000
static int get gems;                // Default: 100
static bool get hasProPass;         // VIP status
```

**Lucky Hand System** (Daily bonus):

```dart
class LuckyHandType {
  final String name;        // e.g., "Royal Flush"
  final String emoji;       // e.g., "👑"
  final int bonusReward;    // e.g., 25000
}
```

### `services/hand_evaluator.dart` - Poker Logic

**Purpose**: Evaluates and compares poker hands according to Texas Hold'em rules.

**Hand Rankings** (low to high):

```dart
enum HandRank {
  highCard,
  onePair,
  twoPair,
  threeOfAKind,
  straight,
  flush,
  fullHouse,
  fourOfAKind,
  straightFlush,
  royalFlush,
}
```

**Key Method**:

```dart
static EvaluatedHand evaluateBestHand(
  List<PlayingCard> holeCards,
  List<PlayingCard> communityCards
);
// Returns best 5-card hand from 7 cards (21 combinations checked)
```

### `services/friends_service.dart` - Social

**Purpose**: Real-time friends, requests, and game invites via Firestore.

**Streams** (real-time updates):

```dart
Stream<List<Friend>> friendsStream;
Stream<List<FriendRequest>> friendRequestsStream;
Stream<List<GameInvite>> gameInvitesStream;
Stream<List<AppNotification>> notificationsStream;
```

**Key Methods**:

```dart
Future<List<Friend>> searchUsers(String query);
Future<bool> sendFriendRequest(String toUserId);
Future<void> acceptFriendRequest(String requestId);
Future<void> sendGameInvite(String friendId, String roomId);
```

### `services/team_service.dart` - Teams

**Purpose**: Team/club management via Firebase Realtime Database.

**Costs**:

- Create team: 1,000,000 chips
- Join team: 1,000 chips

**Key Methods**:

```dart
Future<Team> createTeam({name, description, emblemIndex, isOpen});
Future<void> joinTeam(String teamId);
Future<void> leaveTeam(String teamId);
Future<Team?> getUserTeam();
Stream<Team?> watchTeam(String teamId);
Future<void> sendMessage(String teamId, String message);
```

---

## Screens & Navigation

### Screen Hierarchy

```
_AuthCheckScreen (Splash)
    │
    ├── UsernameSetupScreen (if no account)
    │
    └── HomeScreen (if authenticated)
            │
            ├── [Tab 0] ShopTab
            ├── [Tab 1] HomeTab (default)
            │       ├── LobbyScreen → MultiplayerGameScreen
            │       ├── QuickPlayScreen
            │       ├── SitAndGoScreen → SitAndGoWaitingScreen
            │       ├── TutorialScreen
            │       └── GameScreen (practice)
            │
            └── [Tab 2] ProfileTab
```

### `HomeScreen` - Main Navigation

Uses `IndexedStack` with bottom navigation:

- Tab 0: Shop (🛒)
- Tab 1: Home (🏠) - Default
- Tab 2: Profile (👤)

### `MultiplayerGameScreen` - Core Gameplay

**Features**:

- Real-time game state via `StreamBuilder`
- Turn timer with auto-fold
- Fold animation
- Showdown with winning hand highlight
- Auto-start when enough players join
- Auto-new-hand after each round

**Key Components**:

- Player cards display
- Community cards
- Pot and betting info
- Action buttons (Fold, Check/Call, Raise, All-In)
- Turn indicator

### `LobbyScreen` - Matchmaking

**Game Modes**:

1. **Cash Games** - 5 stake levels (Micro → VIP)
2. **Sit & Go** - Tournament style with prize pools
3. **Private Rooms** - Share room code with friends

**Stake Levels Example**:

```dart
StakeLevel(
  name: 'Micro',
  smallBlind: 10,
  bigBlind: 20,
  minBuyIn: 200,
  maxBuyIn: 2000,
  color: Color(0xFF4CAF50),
)
```

### `TutorialScreen` - Learn Poker

Interactive tutorial with:

- Leo the Lion mascot 🦁
- Step-by-step lessons
- Required actions (fold, check, raise, all-in)
- Visual highlights
- Bot opponents

**Lessons**:

1. First Hand (Pocket Aces - strong hand)
2. When to Fold (7-2 offsuit - weak hand)
3. Reading the Board (flush draws)

---

## Widgets Library

### `mobile_wrapper.dart`

Responsive wrapper that constrains content to mobile width (430px max).

```dart
MobileWrapper(
  child: Scaffold(...),  // Your content
  maxWidth: 430,         // iPhone 14 Pro Max width
)
```

### `animated_buttons.dart`

**AnimatedTapButton** - Scale-down animation on press:

```dart
AnimatedTapButton(
  onTap: () => doSomething(),
  scaleDown: 0.95,
  child: Container(...),
)
```

### `friends_widgets.dart`

- `AddFriendDialog` - Search and add friends
- `FriendsListDialog` - View friends list
- `GameInviteCard` - Accept/decline invites

### `shared_widgets.dart`

Common UI elements like:

- Balance chips display
- Loading indicators
- Empty states

---

## State Management

### Provider Pattern

Single `AppState` class with `ChangeNotifier`:

```dart
class AppState extends ChangeNotifier {
  // Theme
  ThemeMode _themeMode = ThemeMode.system;
  void toggleTheme();

  // Loading
  bool _isLoading = false;
  void setLoading(bool loading);

  // Currency (single source of truth)
  int _coins = 10000;
  int _gems = 100;
  void addCoins(int amount);
  void spendCoins(int amount);

  // Formatting
  String formatCurrency(int amount);  // "10,000" or "1.5M"
}
```

**Usage**:

```dart
// Access state
final appState = context.watch<AppState>();
final coins = appState.coins;

// Update state
context.read<AppState>().addCoins(1000);
```

---

## Firebase Integration

### Firestore (Cloud Database)

**Collections**:

- `users` - User profiles, chips, friends list
- `friendRequests` - Pending friend requests
- `gameInvites` - Game invitations

**User Document Structure**:

```json
{
  "username": "PlayerName",
  "usernameLower": "playername",
  "chips": 10000,
  "gems": 100,
  "isOnline": true,
  "lastOnline": "<timestamp>",
  "createdAt": "<timestamp>",
  "updatedAt": "<timestamp>"
}
```

### Realtime Database

**Paths**:

- `/game_rooms/{roomId}` - Game room state
- `/teams/{teamId}` - Team data and chat

**Why Realtime DB for Games?**

- Lower latency for real-time updates
- Simpler REST API for frequent writes
- Better suited for fast-changing game state

### Firebase Auth

- Email/Password auth (emails auto-generated from usernames)
- Anonymous auth for dev/testing
- Persistent login via cached credentials

---

## Game Logic

### Texas Hold'em Flow

```
1. WAITING      - Players join room
2. PREFLOP      - Blinds posted, 2 hole cards dealt
3. FLOP         - 3 community cards revealed
4. TURN         - 4th community card
5. RIVER        - 5th community card
6. SHOWDOWN     - Best hand wins
7. FINISHED     - Chips distributed, new hand starts
```

### Betting Actions

```dart
'fold'   - Give up, lose any chips bet
'check'  - Pass (only if no bet to call)
'call'   - Match current bet
'raise'  - Increase the bet
'allin'  - Bet all remaining chips
```

### Hand Evaluation

Best 5-card hand from 7 cards (2 hole + 5 community):

1. Generate all 21 combinations
2. Evaluate each for rank
3. Compare tiebreakers if same rank
4. Return best hand with description

---

## Build & Deployment

### Development Commands

```bash
# Get dependencies
flutter pub get

# Run in debug mode
flutter run

# Run on specific device
flutter run -d chrome    # Web
flutter run -d windows   # Windows
flutter run -d <device>  # iOS/Android

# Analyze code
flutter analyze

# Run tests
flutter test
```

### Production Build

```bash
# Android APK (testing/sideload)
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (requires macOS)
flutter build ios --release
flutter build ipa --release
```

### Assets Configuration

Assets are defined in `pubspec.yaml`:

```yaml
flutter:
  uses-material-design: true
  # Add assets here when needed:
  # assets:
  #   - assets/images/
  #   - assets/audio/
```

---

## Common Patterns & Conventions

### Widget Construction

```dart
// Use const constructors
const Text('Hello');

// Named parameters for clarity
CustomButton(
  text: 'Play',
  onTap: () => startGame(),
  color: Colors.green,
);
```

### Null Safety

```dart
// Use null-aware operators
final name = user?.displayName ?? 'Anonymous';

// Check mounted before setState in async
if (mounted) {
  setState(() => _isLoading = false);
}
```

### Error Handling

```dart
try {
  await someAsyncOperation();
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### Async Patterns

```dart
// Use FutureBuilder for one-time async
FutureBuilder<User>(
  future: loadUser(),
  builder: (context, snapshot) {
    if (snapshot.hasData) return UserWidget(snapshot.data!);
    return LoadingWidget();
  },
);

// Use StreamBuilder for real-time updates
StreamBuilder<GameRoom?>(
  stream: gameService.watchRoom(roomId),
  builder: (context, snapshot) {
    // Handle loading, error, data states
  },
);
```

### Color Conventions

```dart
// App colors
const goldAccent = Color(0xFFD4AF37);
const greenSuccess = Color(0xFF00D46A);
const darkBackground = Color(0xFF0A0A0A);
const cardBackground = Color(0xFF141414);

// Opacity patterns
Colors.white.withOpacity(0.1)  // Subtle backgrounds
Colors.white.withOpacity(0.4)  // Secondary text
Colors.white.withOpacity(0.9)  // Primary text
```

---

## Quick Reference

### Important Files by Feature

| Feature    | Primary File           | Supporting Files                        |
| ---------- | ---------------------- | --------------------------------------- |
| Auth       | `auth_service.dart`    | `username_setup_screen.dart`            |
| Game Logic | `game_service.dart`    | `hand_evaluator.dart`, `game_room.dart` |
| UI Theme   | `theme.dart`           | `mobile_wrapper.dart`                   |
| State      | `app_state.dart`       | `user_preferences.dart`                 |
| Friends    | `friends_service.dart` | `friend.dart`, `friends_widgets.dart`   |
| Teams      | `team_service.dart`    | `team.dart`                             |
| Shop       | `shop_tab.dart`        | `user_service.dart`                     |

### File Size Reference

| Category | Files | Approximate Lines |
| -------- | ----- | ----------------- |
| Screens  | 10+   | 10,000+           |
| Services | 7     | 3,500+            |
| Models   | 4     | 800+              |
| Widgets  | 5     | 500+              |
| Config   | 2     | 150+              |

---

## For AI Assistants

When working with this codebase:

1. **Game state is in Firebase Realtime Database** - Use `GameService` for all game operations
2. **User data is in Firestore** - Use `UserService` for profile/currency operations
3. **Local cache uses SharedPreferences** - Use `UserPreferences` for fast reads
4. **All screens use `MobileWrapper`** - Ensures consistent mobile-first layout
5. **Dark theme is primary** - Background is `#0A0A0A`, gold accent is `#D4AF37`
6. **Provider is used for global state** - Access via `context.read<AppState>()`
7. **Real-time updates use StreamBuilder** - Games update live without polling
8. **Check `mounted` before `setState`** - Prevents errors in async callbacks

### Common Tasks

**Add new screen**:

1. Create in `lib/screens/`
2. Add route in `lib/config/routes.dart`
3. Wrap with `MobileWrapper`

**Add new service**:

1. Create in `lib/services/`
2. Use singleton pattern if needed
3. Initialize in `main.dart` if required at startup

**Modify game logic**:

1. Update `GameRoom` model if new fields needed
2. Modify `GameService` methods
3. Update `MultiplayerGameScreen` UI

---

## 🔍 Full-Stack Architecture Assessment

### ✅ What's GOOD About Current Flow

| Aspect                    | Status      | Notes                                      |
| ------------------------- | ----------- | ------------------------------------------ |
| **Clean Architecture**    | ✅ Solid    | Good separation: screens → services → data |
| **State Management**      | ✅ Good     | Provider works well for this scale         |
| **Real-time Multiplayer** | ✅ Working  | Firebase RTDB handles game state           |
| **Auth System**           | ✅ Good     | Username/password with Firebase Auth       |
| **Social Features**       | ✅ Good     | Friends, teams, invites all implemented    |
| **Hand Evaluation**       | ✅ Complete | Proper poker hand ranking                  |
| **UI/UX**                 | ✅ Polished | Dark theme, animations, mobile-first       |

### ⚠️ CRITICAL GAPS for App Store Production

Current architecture has **client-side game logic** - this is a **major security risk** for a real poker app:

```
CURRENT FLOW (Vulnerable):
┌──────────┐                    ┌──────────────┐
│  Client  │ ──── writes ────▶ │ Firebase DB  │
│ (Flutter)│ ◀─── reads ─────  │ (Game State) │
└──────────┘                    └──────────────┘
     ▲
     │ 🚨 PROBLEM: Client controls game logic!
     │    - Deck shuffling on client
     │    - Bet validation on client
     │    - Winner determination on client
     │    - Cheaters can modify data directly
```

### 🏗️ RECOMMENDED Full-Stack Architecture

For a **production poker app** that can't be cheated:

```
PRODUCTION FLOW (Secure):
┌──────────┐                    ┌──────────────┐         ┌──────────────┐
│  Client  │ ──── actions ────▶ │   Backend    │ ──────▶ │   Database   │
│ (Flutter)│ ◀─── state ──────  │   Server     │ ◀────── │  (Firebase)  │
└──────────┘                    └──────────────┘         └──────────────┘
                                       │
                                       ▼
                               ┌──────────────┐
                               │ Game Engine  │
                               │ • Deck/RNG   │
                               │ • Validation │
                               │ • Hand Eval  │
                               │ • Pot Math   │
                               └──────────────┘
```

### 📋 What You Need to Add for Full-Stack

| Component              | Purpose                  | Options                                  |
| ---------------------- | ------------------------ | ---------------------------------------- |
| **Backend Server**     | Authoritative game logic | Firebase Cloud Functions, Node.js, or Go |
| **Server-Side RNG**    | Secure deck shuffling    | Cryptographic RNG on server              |
| **Action Validation**  | Prevent cheating         | All bets/actions verified server-side    |
| **Security Rules**     | Lock down database       | Firebase rules to block direct writes    |
| **Rate Limiting**      | Prevent abuse            | Cloud Functions or API gateway           |
| **Analytics**          | Track metrics            | Firebase Analytics or Mixpanel           |
| **Crash Reporting**    | Monitor stability        | Firebase Crashlytics                     |
| **Push Notifications** | Re-engage users          | Firebase Cloud Messaging                 |
| **In-App Purchases**   | Monetization             | RevenueCat or native IAP                 |

### 🗺️ Production Roadmap

#### Phase 1: MVP (Current)

- [x] Core poker gameplay
- [x] Multiplayer with Firebase RTDB
- [x] User accounts & auth
- [x] Friends & teams
- [x] Shop UI

#### Phase 2: Security Hardening

- [ ] Move deck shuffling to Cloud Functions
- [ ] Server-side action validation
- [ ] Firebase Security Rules lockdown
- [ ] Rate limiting on game actions

#### Phase 3: Monetization

- [ ] Integrate RevenueCat or native IAP
- [ ] Chip/gem purchase flow
- [ ] Receipt validation on server
- [ ] VIP subscription system

#### Phase 4: App Store Launch

- [ ] Privacy Policy & Terms of Service
- [ ] App icons (all sizes)
- [ ] Screenshots & preview video
- [ ] Store descriptions (ASO optimized)
- [ ] Beta testing (TestFlight / Play Console)
- [ ] Submit for review

#### Phase 5: Post-Launch

- [ ] Firebase Analytics integration
- [ ] Crashlytics for stability monitoring
- [ ] Push notifications for engagement
- [ ] A/B testing for features
- [ ] Seasonal events & promotions

---

_Last updated: January 30, 2026_
_Documentation version: 1.1_
