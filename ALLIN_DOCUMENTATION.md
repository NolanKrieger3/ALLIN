# ALLIN - Complete Project Documentation

> **Last Updated**: February 2026  
> **Purpose**: Comprehensive documentation for AI assistants and developers to understand the ALLIN poker app codebase.

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Technology Stack](#technology-stack)
3. [Architecture Overview](#architecture-overview)
4. [Directory Structure](#directory-structure)
5. [Data Models](#data-models)
6. [Services Layer](#services-layer)
7. [Screens & Navigation](#screens--navigation)
8. [Game Logic](#game-logic)
9. [Firebase Integration](#firebase-integration)
10. [Build & Deployment](#build--deployment)

---

## Project Overview

**ALLIN** is a cross-platform Texas Hold'em poker game built with Flutter. It features real-time multiplayer gameplay, social features (friends, teams), and an in-app economy.

### Key Features

| Feature | Description |
|---------|-------------|
| 🎮 **Single Player** | Play against AI bots with adjustable difficulty |
| 👥 **Multiplayer** | Real-time heads-up and multi-player poker via Firebase |
| 🏆 **Sit & Go** | Tournament-style games with 6 players |
| 💰 **Cash Games** | Join tables by stake level (micro to high) |
| 👫 **Friends System** | Add friends, send invites, see online status |
| 🏠 **Teams/Clubs** | Create or join teams with chat |
| 🛒 **Shop** | Buy chips, gems, cosmetics |
| 📚 **Tutorial** | Interactive poker lessons |

### Current Version
- **Version**: 1.0.0+1
- **Dart SDK**: ^3.6.0
- **Platforms**: iOS, Android, Web (debug), Windows (debug)

---

## Technology Stack

### Core Dependencies

```yaml
# Framework
flutter: 3.10+
dart: ^3.6.0

# State Management
provider: ^6.1.2

# Backend
firebase_core: ^4.4.0
firebase_auth: ^6.1.4
cloud_firestore: ^6.1.2

# Networking
http: ^1.6.0

# Local Storage
shared_preferences: ^2.2.2
```

### Firebase Services Used
- **Firebase Auth**: Anonymous & email/password authentication
- **Firebase Realtime Database**: Game rooms, real-time game state
- **Cloud Firestore**: User profiles, friends, teams

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  ┌─────────────┐  ┌──────────┐  ┌─────────────────────────┐ │
│  │   Screens   │  │   Tabs   │  │        Widgets          │ │
│  │ game_screen │  │ home_tab │  │ animated_buttons        │ │
│  │ lobby_screen│  │profile_tab│ │ friends_widgets         │ │
│  │ multiplayer │  │ shop_tab │  │ game_ui_widgets         │ │
│  └─────────────┘  └──────────┘  └─────────────────────────┘ │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                     SERVICES LAYER                           │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ GameService (Facade)                                    ││
│  │  ├── RoomService (room CRUD, joining, leaving)          ││
│  │  ├── GameFlowService (start game, deal cards, new hand) ││
│  │  ├── GameActionService (fold, call, raise, showdown)    ││
│  │  └── BotService (AI decision making)                    ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐│
│  │ AuthService │ │ UserService │ │ FriendsService          ││
│  │ TeamService │ │ HandEvaluator│ │ UserPreferences        ││
│  └─────────────┘ └─────────────┘ └─────────────────────────┘│
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                      DATA LAYER                              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐│
│  │  GameRoom   │ │  GamePlayer │ │      PlayingCard        ││
│  │    Team     │ │    Friend   │ │         User            ││
│  └─────────────┘ └─────────────┘ └─────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
lib/
├── main.dart                    # App entry point, Firebase init
├── firebase_options.dart        # Firebase configuration
│
├── config/
│   ├── routes.dart              # Named routes
│   └── theme.dart               # App theme (dark mode)
│
├── models/
│   ├── game_room.dart           # GameRoom model + exports
│   ├── game_player.dart         # GamePlayer model
│   ├── playing_card.dart        # PlayingCard model
│   ├── friend.dart              # Friend & FriendRequest models
│   ├── team.dart                # Team model
│   └── user.dart                # User profile model
│
├── providers/
│   └── app_state.dart           # Global app state (theme, etc.)
│
├── services/
│   ├── game_service.dart        # Facade for all game operations
│   ├── room_service.dart        # Room CRUD operations
│   ├── game_flow_service.dart   # Game lifecycle (start, deal, new hand)
│   ├── game_action_service.dart # Player actions (fold, call, raise)
│   ├── bot_service.dart         # AI bot logic
│   ├── hand_evaluator.dart      # Poker hand evaluation
│   ├── pot_service.dart         # Pot calculations & side pots
│   ├── auth_service.dart        # Firebase authentication
│   ├── user_service.dart        # User profile operations
│   ├── friends_service.dart     # Friends system
│   ├── team_service.dart        # Teams/clubs
│   └── user_preferences.dart    # Local storage (SharedPreferences)
│
├── screens/
│   ├── home_screen.dart         # Main navigation shell
│   ├── game_screen.dart         # Single-player vs bots (~3000 lines)
│   ├── multiplayer_game_screen.dart # Online multiplayer
│   ├── lobby_screen.dart        # Multiplayer lobby
│   ├── quick_play_screen.dart   # Cash game stake selection
│   ├── sit_and_go_screen.dart   # Sit & Go buy-in selection
│   ├── sit_and_go_waiting_screen.dart # SNG waiting room
│   ├── tutorial_screen.dart     # Interactive poker tutorial
│   ├── username_setup_screen.dart # First-time username setup
│   └── tabs/
│       ├── home_tab.dart        # Home/play tab (~3300 lines)
│       ├── profile_tab.dart     # Profile & settings
│       └── shop_tab.dart        # In-app store
│
├── widgets/
│   ├── animated_buttons.dart    # Fancy animated buttons
│   ├── custom_button.dart       # Standard buttons
│   ├── friends_widgets.dart     # Friends list, add friend dialogs
│   ├── game_ui_widgets.dart     # Poker table UI components
│   ├── mobile_wrapper.dart      # Max-width constraint for web
│   └── shared_widgets.dart      # Common reusable widgets
│
└── utils/
    └── (utility functions)
```

---

## Data Models

### GameRoom
Main model for a poker game room.

```dart
class GameRoom {
  final String id;              // Room code (6 chars)
  final String hostId;          // Creator's UID
  final List<GamePlayer> players;
  final int maxPlayers;         // 2-6
  final int bigBlind;           // Big blind amount
  final int smallBlind;         // Usually bigBlind / 2
  final String status;          // 'waiting', 'in_progress', 'finished'
  final String phase;           // 'preflop', 'flop', 'turn', 'river', 'showdown'
  final int pot;                // Current pot size
  final int currentBet;         // Bet to match
  final String? currentTurnPlayerId;
  final int dealerIndex;
  final List<PlayingCard> communityCards;
  final String gameType;        // 'cash', 'sitandgo', 'private'
  final bool isPrivate;         // Room code sharing
  final bool bbHasOption;       // BB can raise if no one raised
  final int turnTimeLimit;      // Seconds per turn (default 10)
}
```

### GamePlayer
Represents a player in a game room.

```dart
class GamePlayer {
  final String uid;
  final String displayName;
  final int chips;              // Current chip stack
  final int currentBet;         // Bet this betting round
  final int totalContributed;   // Total chips in pot this hand
  final bool hasFolded;
  final bool hasActed;          // Has acted this round
  final bool isReady;           // Ready to start
  final List<PlayingCard> cards; // Hole cards (2)
  final String? lastAction;     // 'fold', 'check', 'call', 'raise', 'all-in'
  final DateTime lastActiveAt;  // For inactivity detection
}
```

### PlayingCard
```dart
class PlayingCard {
  final String rank;  // '2'-'10', 'J', 'Q', 'K', 'A'
  final String suit;  // '♠', '♥', '♦', '♣'
}
```

---

## Services Layer

### GameService (Facade Pattern)
Central service that delegates to specialized services:

```dart
class GameService {
  final RoomService _roomService;       // Room operations
  final GameActionService _actionService; // Player actions
  final GameFlowService _flowService;   // Game lifecycle
  final BotService _botService;         // AI bots
  
  // Room Management
  Future<GameRoom> createRoom({...});
  Future<void> joinRoom(String roomId);
  Future<void> leaveRoom(String roomId);
  Stream<GameRoom?> watchRoom(String roomId);
  
  // Game Flow
  Future<void> startGame(String roomId);
  Future<void> newHand(String roomId);
  
  // Player Actions
  Future<void> fold(String roomId);
  Future<void> call(String roomId);
  Future<void> raise(String roomId, int amount);
  Future<void> allIn(String roomId);
}
```

### HandEvaluator
Evaluates poker hands and determines winners.

```dart
enum HandRank {
  highCard, onePair, twoPair, threeOfAKind,
  straight, flush, fullHouse, fourOfAKind,
  straightFlush, royalFlush
}

class HandEvaluator {
  static EvaluatedHand evaluateBestHand(
    List<PlayingCard> holeCards,
    List<PlayingCard> communityCards
  );
  
  static List<GamePlayer> determineWinners(
    List<GamePlayer> players,
    List<PlayingCard> communityCards
  );
}
```

### BotService
AI opponent logic with three difficulty levels:

- **Easy**: Mostly passive, calls often, rarely bluffs
- **Medium**: Balanced play, position-aware
- **Hard**: Aggressive, considers pot odds, sophisticated bluffing

---

## Screens & Navigation

### Main Flow
```
main.dart
  └── _AuthCheckScreen (splash + auth)
        ├── UsernameSetupScreen (first time)
        └── HomeScreen (main shell)
              ├── HomeTab (index 0)
              ├── ProfileTab (index 1)  
              └── ShopTab (index 2)
```

### Game Entry Points

| From | To | Description |
|------|-----|-------------|
| HomeTab | GameScreen | "Practice" - single player vs bots |
| HomeTab | QuickPlayScreen | Cash games - select stakes |
| HomeTab | SitAndGoScreen | Tournaments - select buy-in |
| HomeTab | LobbyScreen | Multiplayer lobby |
| LobbyScreen | MultiplayerGameScreen | Join online game |

### Key Screens

#### GameScreen (~3000 lines)
Single-player poker vs AI bots. Contains:
- Game setup (bot count, difficulty)
- Full poker table UI
- Betting actions
- Hand evaluation & showdown
- Animations (deal, fold, win)

#### MultiplayerGameScreen
Online multiplayer via Firebase Realtime Database. Features:
- Real-time state sync via `watchRoom()` stream
- Turn timer with visual countdown
- Showdown animations

#### HomeTab (~3300 lines)
Main landing screen with:
- Play mode cards (swipeable)
- Friends panel
- Team section
- Developer menu (debug)

---

## Game Logic

### Betting Flow

```
PREFLOP:
  1. Post blinds (SB, BB)
  2. Deal hole cards
  3. Action starts UTG (or dealer in heads-up)
  4. Continue until all active players have equal bets

FLOP/TURN/RIVER:
  1. Deal community cards (3/1/1)
  2. Action starts with first active player after dealer
  3. Continue until betting complete

SHOWDOWN:
  1. Evaluate all remaining hands
  2. Determine winner(s)
  3. Award pot (handle side pots if needed)
```

### Turn Order Logic
```dart
// Preflop (heads-up): Dealer acts first
// Preflop (3+ players): UTG (dealer + 3) acts first
// Post-flop: First active player after dealer
```

### All-In & Side Pots
When a player goes all-in for less than the bet, side pots are created automatically by `PotService`.

---

## Firebase Integration

### Realtime Database Structure
```
/rooms/{roomId}
  ├── id: "ABC123"
  ├── hostId: "user_uid"
  ├── status: "in_progress"
  ├── phase: "flop"
  ├── pot: 500
  ├── currentBet: 100
  ├── currentTurnPlayerId: "user_uid"
  ├── communityCards: [{rank, suit}, ...]
  ├── deck: ["A|♠", "K|♥", ...]
  └── players: [
        {uid, displayName, chips, cards, hasFolded, ...}
      ]
```

### Authentication Flow
1. App starts → Check auth state
2. If no user → Sign in anonymously
3. If first time → Username setup screen
4. Sync user data from Firestore

---

## Build & Deployment

### Development
```bash
# Run on Chrome (web debug)
flutter run -d chrome

# Run on Windows
flutter run -d windows

# Hot reload
r (in terminal)
```

### Production Builds
```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (requires Mac)
flutter build ipa --release

# Web
flutter build web --release
```

---

## Quick Reference

### Key Commands
| Command | Description |
|---------|-------------|
| `flutter run -d chrome` | Run web debug |
| `flutter build web` | Build for web |
| `flutter analyze` | Check for issues |
| `flutter pub get` | Get dependencies |

### Important Files
| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry, Firebase init |
| `lib/services/game_service.dart` | Game facade |
| `lib/screens/game_screen.dart` | Solo play |
| `lib/screens/multiplayer_game_screen.dart` | Online play |
| `lib/services/hand_evaluator.dart` | Hand ranking |

### Firebase URLs
- Realtime Database: `https://allin-d0e2d-default-rtdb.firebaseio.com`

---

*Documentation auto-generated for AI assistant context.*
