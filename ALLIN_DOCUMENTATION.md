# ALLIN - Deep Technical Documentation

> **Last Updated**: February 2026  
> **Purpose**: In-depth documentation for debugging game logic and flow errors

---

## 📋 Table of Contents

1. [Complete Game Lifecycle](#complete-game-lifecycle)
2. [File Responsibilities](#file-responsibilities)
3. [Room Creation Flow](#room-creation-flow)
4. [Game Start Flow](#game-start-flow)
5. [Betting Round Flow](#betting-round-flow)
6. [Phase Transitions](#phase-transitions)
7. [Showdown & Winner Determination](#showdown--winner-determination)
8. [New Hand Flow](#new-hand-flow)
9. [Player Disconnect Handling](#player-disconnect-handling)
10. [Common Bugs & Debugging](#common-bugs--debugging)
11. [Firebase Data Structure](#firebase-data-structure)
12. [State Machine Diagrams](#state-machine-diagrams)
13. [Function Call Chains](#function-call-chains)

---

## Complete Game Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        COMPLETE GAME LIFECYCLE                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. ROOM CREATION                                                        │
│     └── quick_play_screen.dart → room_service.dart.createRoom()          │
│                                                                          │
│  2. PLAYER JOINS                                                         │
│     └── room_service.dart.joinRoom()                                     │
│                                                                          │
│  3. GAME STARTS (when 2+ players ready)                                  │
│     └── multiplayer_game_screen.dart._tryAutoStart()                     │
│         └── game_flow_service.dart.startGame()                           │
│             ├── Create & shuffle deck                                    │
│             ├── Deal 2 cards to each player                              │
│             ├── Post blinds (SB & BB)                                    │
│             ├── Set phase = 'preflop'                                    │
│             └── Set currentTurnPlayerId = first to act                   │
│                                                                          │
│  4. BETTING ROUNDS (preflop → flop → turn → river)                       │
│     └── multiplayer_game_screen.dart (UI)                                │
│         └── game_action_service.dart.playerAction()                      │
│             ├── Validate action                                          │
│             ├── Update player state (chips, bet, hasActed)               │
│             ├── Check if betting round complete                          │
│             └── Advance to next player OR next phase                     │
│                                                                          │
│  5. PHASE ADVANCEMENT                                                    │
│     └── game_action_service.dart._advancePhase()                         │
│         ├── Deal community cards from deck                               │
│         ├── Reset hasActed for all players                               │
│         ├── Set currentBet = 0                                           │
│         └── Set currentTurnPlayerId = first active after dealer          │
│                                                                          │
│  6. SHOWDOWN (all betting complete OR only 1 player remains)             │
│     └── game_action_service.dart._handleShowdown()                       │
│         ├── Evaluate all hands (hand_evaluator.dart)                     │
│         ├── Determine winner(s)                                          │
│         ├── Award pot (handle side pots)                                 │
│         └── Set phase = 'showdown', status = 'finished'                  │
│                                                                          │
│  7. NEW HAND (if 2+ players have chips)                                  │
│     └── multiplayer_game_screen.dart triggers after delay                │
│         └── game_flow_service.dart.newHand()                             │
│             ├── Remove eliminated players                                │
│             ├── Create fresh deck                                        │
│             ├── Rotate dealer                                            │
│             └── Start new preflop                                        │
│                                                                          │
│  8. GAME END (only 1 player has chips)                                   │
│     └── game_flow_service.dart.newHand() detects < 2 players             │
│         └── Set status = 'finished'                                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## File Responsibilities

### Core Service Files

| File | Location | Primary Responsibility | Key Functions |
|------|----------|----------------------|---------------|
| **room_service.dart** | `lib/services/` | Room CRUD, player management, heartbeat, cleanup | `createRoom()`, `joinRoom()`, `leaveRoom()`, `sendHeartbeat()`, `removeInactivePlayers()`, `fetchRoom()`, `watchRoom()` |
| **game_flow_service.dart** | `lib/services/` | Game lifecycle (start, new hand, timeouts) | `startGame()`, `newHand()`, `handleTurnTimeout()`, `_createShuffledDeck()` |
| **game_action_service.dart** | `lib/services/` | Player actions during gameplay | `playerAction()`, `fold()`, `call()`, `raise()`, `allIn()`, `_advancePhase()`, `_handleShowdown()`, `_dealToShowdown()`, `_isBettingRoundComplete()` |
| **bot_service.dart** | `lib/services/` | AI decision making | `decideAction()`, `addBotsToRoom()`, `_evaluateHandStrength()` |
| **hand_evaluator.dart** | `lib/services/` | Poker hand ranking & comparison | `evaluateBestHand()`, `determineWinners()`, `compareHands()`, `_evaluateHand()` |
| **pot_service.dart** | `lib/services/` | Pot calculations & side pots | `calculateSidePots()`, `distributePot()` |
| **game_service.dart** | `lib/services/` | Facade - clean API, delegates to specialized services | Wraps all game operations |
| **currency_service.dart** | `lib/services/` | Chip/gem balance management | `getChips()`, `spendChips()`, `addChips()`, `canAfford()` |

### Screen Files

| File | Location | Primary Responsibility | Key Interactions |
|------|----------|----------------------|------------------|
| **quick_play_screen.dart** | `lib/screens/` | Blind level selection, matchmaking, room finding/creation | → `room_service.createRoom()`, `joinRoom()`, `fetchJoinableRoomsByBlind()` |
| **multiplayer_game_screen.dart** | `lib/screens/` | Online game UI, real-time state sync, turn timer, action buttons | → `game_action_service.playerAction()`, `game_flow_service.newHand()`, heartbeat system |
| **game_screen.dart** | `lib/screens/` | Single-player vs bots (~3000 lines) | Self-contained game logic |
| **sit_and_go_waiting_screen.dart** | `lib/screens/` | Tournament lobby, player waiting | → `room_service.watchRoom()` |
| **lobby_screen.dart** | `lib/screens/` | Multiplayer room browser | → `room_service.fetchRooms()` |

### Model Files

| File | Location | Contains | Key Fields |
|------|----------|----------|------------|
| **game_room.dart** | `lib/models/` | `GameRoom` class + exports | `id`, `status`, `phase`, `players`, `pot`, `currentBet`, `communityCards`, `deck`, `dealerIndex`, `currentTurnPlayerId` |
| **game_player.dart** | `lib/models/` | `GamePlayer` class with `copyWith()` | `uid`, `chips`, `currentBet`, `totalContributed`, `hasFolded`, `hasActed`, `cards`, `lastAction`, `lastActiveAt` |
| **playing_card.dart** | `lib/models/` | `PlayingCard` class | `rank`, `suit` |

---

## Room Creation Flow

### Entry Point: `quick_play_screen.dart` → `_startGame()`

```
User taps PLAY button
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│  _startGame() in quick_play_screen.dart                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Get selected blind level from BlindLevels.all[index]        │
│     └── Contains: bigBlind, smallBlind, buyIn, displayName      │
│                                                                 │
│  2. Validate chip balance (CurrencyService.canAfford())         │
│     └── If insufficient: Show snackbar, return                  │
│                                                                 │
│  3. Matchmaking loop (5 attempts with increasing delay):        │
│     │                                                           │
│     ├──► _gameService.fetchJoinableRoomsByBlind(bigBlind)       │
│     │    └── Returns rooms matching blind & 'quickplay' type    │
│     │                                                           │
│     ├──► For each room found, try:                              │
│     │    └── _gameService.joinRoom(room.id, startingChips)      │
│     │        ├── Success: roomId = room.id, break               │
│     │        └── Fail: try next room                            │
│     │                                                           │
│     └──► If no room found after all attempts:                   │
│          └── Create new room                                    │
│                                                                 │
│  4. If still no roomId, create room:                            │
│     └── _gameService.createRoom(bigBlind, buyIn, 'quickplay')   │
│         └── Returns new GameRoom with generated ID              │
│                                                                 │
│  5. Navigate to MultiplayerGameScreen(roomId, autoStart: true)  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Sit & Go Tournament Flow

### Overview

Sit & Go tournaments differ from Quick Play:
- **Quick Play**: 2 players, starts immediately when both ready
- **Sit & Go**: 6 players required, uses a waiting lobby screen

### Entry Point: `lobby_screen.dart` → `_joinSitAndGo()`

```
User taps Sit & Go buy-in level
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│  _joinSitAndGo(buyIn) in lobby_screen.dart                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Fetch available Sit & Go rooms:                              │
│     └── _gameService.fetchAvailableSitAndGoRooms()               │
│         └── room_service.fetchAvailableRooms('sitandgo')         │
│             └── Filters: status='waiting', !isFull, !isPrivate   │
│                          gameType='sitandgo', user not in room   │
│                                                                  │
│  2. Filter rooms by buy-in level (bigBlind):                     │
│     └── matchingRooms = rooms.where(r => r.bigBlind == buyIn)    │
│                                                                  │
│  3. Prioritize rooms with most players (fill existing lobbies):  │
│     └── Sort by players.length descending                        │
│     └── Pick first non-empty room, else any matching room        │
│                                                                  │
│  4. Join or Create:                                              │
│     │                                                            │
│     ├── IF room found:                                           │
│     │   └── _gameService.joinRoom(room.id, startingChips)        │
│     │                                                            │
│     └── ELSE (no rooms):                                         │
│         └── _gameService.createSitAndGoRoom(bigBlind, chips)     │
│             └── Creates room with maxPlayers=6, gameType='sitandgo'│
│                                                                  │
│  5. Navigate to SitAndGoWaitingScreen (NOT MultiplayerGameScreen)│
│     └── SitAndGoWaitingScreen(roomId, buyIn, requiredPlayers: 6) │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Sit & Go Room Creation: `room_service.dart` → `createSitAndGoRoom()`

```dart
FUNCTION: createSitAndGoRoom({startingChips, bigBlind})
│
├── 1. Generate room ID
│
├── 2. Create GameRoom with Sit & Go specific settings:
│      └── GameRoom(
│            maxPlayers: 6,              // Always 6 for Sit & Go
│            gameType: 'sitandgo',       // Different from 'quickplay'
│            bigBlind: bigBlind,
│            players: [hostPlayer],
│          )
│
├── 3. HTTP PUT to Firebase with:
│      └── 'defaultChips': startingChips  // For new joiners
│      └── 'lastActivityAt': timestamp    // For stale room cleanup
│
└── 4. Return GameRoom
```

### Waiting Screen: `sit_and_go_waiting_screen.dart`

```
┌─────────────────────────────────────────────────────────────────┐
│  SitAndGoWaitingScreen                                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  STATE:                                                          │
│  - roomId: String (the room to watch)                            │
│  - requiredPlayers: int (default 6)                              │
│  - _room: GameRoom? (current room state)                         │
│  - _isStarting: bool (prevent double-start)                      │
│                                                                  │
│  ON INIT:                                                        │
│  1. Subscribe to room updates:                                   │
│     └── _gameService.watchRoom(roomId).listen((room) {...})      │
│                                                                  │
│  2. Start heartbeat timer (every 10 seconds):                    │
│     └── _gameService.sendHeartbeat(roomId)                       │
│                                                                  │
│  ON ROOM UPDATE:                                                 │
│  │                                                               │
│  ├── Update UI with current player count                         │
│  │                                                               │
│  ├── IF players.length >= requiredPlayers && !_isStarting:       │
│  │   └── _startGame()                                            │
│  │       ├── If host: _gameService.startGame(roomId)             │
│  │       └── Navigate to MultiplayerGameScreen                   │
│  │                                                               │
│  └── IF room.status == 'playing' && !_isStarting:                │
│      └── _navigateToGame() (someone else started it)             │
│                                                                  │
│  ON DISPOSE:                                                     │
│  - If not starting game: _gameService.leaveRoom(roomId)          │
│  - Cancel heartbeat timer                                        │
│                                                                  │
│  UI FEATURES:                                                    │
│  - Progress indicator (e.g., "3/6 Players")                      │
│  - List of joined players                                        │
│  - "Fill with Bots" button (for testing)                         │
│  - "Leave" button                                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Sit & Go vs Quick Play Comparison

| Aspect | Quick Play | Sit & Go |
|--------|------------|----------|
| **Players** | 2 | 6 |
| **Game Type** | `'quickplay'` | `'sitandgo'` |
| **Matchmaking** | Join or create, start immediately | Join waiting lobby, wait for 6 |
| **Navigation** | → `MultiplayerGameScreen` | → `SitAndGoWaitingScreen` → `MultiplayerGameScreen` |
| **Start Trigger** | Host auto-starts when 2 ready | Auto-starts when 6 players join |
| **Fetch Function** | `fetchJoinableRoomsByBlind()` | `fetchAvailableSitAndGoRooms()` |
| **Create Function** | `createRoom()` | `createSitAndGoRoom()` |

### Sit & Go Debugging

**Bug: Players 3+ can't join lobby**

Debug points in `room_service.dart` → `fetchAvailableRooms()`:
```
Check filter conditions:
  □ room.status == 'waiting' (not 'playing')
  □ room.isFull == false (players < maxPlayers)
  □ room.gameType == 'sitandgo'
  □ room.isPrivate == false
  □ User not already in room.players
```

**Bug: Game starts with wrong player count**

Check:
- `requiredPlayers` passed to `SitAndGoWaitingScreen` (should be 6)
- `requiredPlayers` passed to `MultiplayerGameScreen`
- Room's `maxPlayers` value in Firebase

**Bug: Waiting screen stuck**

Check:
- Is `watchRoom()` stream receiving updates?
- Is heartbeat being sent (keeps room alive)?
- Is room being cleaned up by `cleanupStaleRooms()`? (5 min timeout for waiting rooms)

---

### Room Creation: `room_service.dart` → `createRoom()`

```dart
FUNCTION: createRoom({bigBlind, startingChips, gameType, isPrivate, maxPlayers})
│
├── 1. Generate 6-character alphanumeric room ID
│      └── _generateRoomId() → "ABC123"
│
├── 2. Get current user info
│      ├── currentUserId (from Firebase Auth)
│      └── _getDisplayName() (from Firestore)
│
├── 3. Create host GamePlayer object:
│      └── GamePlayer(
│            uid: userId,
│            username: displayName,
│            chips: startingChips,
│            cards: [],           // Empty until game starts
│            hasFolded: false,
│            hasActed: false,
│            currentBet: 0,
│            totalContributed: 0,
│            isReady: true,       // Host auto-ready
│            lastActiveAt: now,
│          )
│
├── 4. Build room data map for Firebase:
│      {
│        'id': roomId,
│        'hostId': userId,
│        'players': [hostPlayer.toJson()],
│        'maxPlayers': maxPlayers,
│        'bigBlind': bigBlind,
│        'smallBlind': bigBlind ~/ 2,
│        'status': 'waiting',
│        'phase': 'waiting_for_players',
│        'pot': 0,
│        'currentBet': 0,
│        'communityCards': [],
│        'deck': [],
│        'gameType': gameType,
│        'isPrivate': isPrivate,
│        'createdAt': timestamp,
│        'lastActivityAt': timestamp,
│      }
│
├── 5. HTTP PUT to Firebase Realtime Database
│      └── PUT /game_rooms/{roomId}.json?auth={token}
│
└── 6. Return GameRoom.fromJson(roomData, roomId)
```

### Join Room: `room_service.dart` → `joinRoom()`

```dart
FUNCTION: joinRoom(roomId, {startingChips})
│
├── 1. Fetch current room state
│      └── fetchRoom(roomId) → GameRoom
│
├── 2. Validation checks:
│      ├── Room exists? ─────────────────► throw 'Room not found'
│      ├── Status == 'waiting'? ─────────► throw 'Game already started'
│      ├── players.length < maxPlayers? ─► throw 'Room is full'
│      └── Already in room? ─────────────► return (no-op)
│
├── 3. Create new GamePlayer:
│      └── GamePlayer(
│            uid: currentUserId,
│            username: await _getDisplayName(),
│            chips: startingChips ?? bigBlind * 100,
│            cards: [],
│            hasFolded: false,
│            hasActed: false,
│            currentBet: 0,
│            totalContributed: 0,
│            isReady: true,
│            lastActiveAt: now,
│          )
│
├── 4. Append to players array
│      └── updatedPlayers = [...room.players, newPlayer]
│
└── 5. HTTP PATCH to Firebase
       └── PATCH /game_rooms/{roomId}.json
           body: { 'players': [...], 'lastActivityAt': timestamp }
```

---

## Game Start Flow

### Trigger: `multiplayer_game_screen.dart` → `_tryAutoStart()`

```
StreamBuilder receives room update
         │
         ▼
_tryAutoStart(room) called
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│  CONDITIONS TO START:                                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ✓ _hasAutoStarted == false (prevent double-start)               │
│  ✓ _isLoading == false                                           │
│  ✓ room.status == 'waiting'                                      │
│  ✓ room.players.length >= requiredPlayers (usually 2)            │
│  ✓ Current user is host (room.hostId == currentUserId)           │
│  ✓ All players are ready (every player.isReady == true)          │
│                                                                  │
│  If ALL conditions met:                                          │
│  └── _hasAutoStarted = true                                      │
│      _gameService.startGame(room.id)                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Game Start: `game_flow_service.dart` → `startGame()`

```dart
FUNCTION: startGame(roomId)
│
├── 1. Fetch current room state
│      └── Guard: If status == 'playing' && phase != 'waiting_for_players'
│          └── Already started, return early
│
├── 2. CREATE SHUFFLED DECK (52 cards)
│      └── _createShuffledDeck()
│          ├── Generate all 52 cards: ['2|♠', '3|♠', ... 'A|♣']
│          └── Shuffle using Fisher-Yates algorithm
│
├── 3. DEAL HOLE CARDS (2 per player)
│      │
│      for each player in room.players:
│      │   ├── card1 = deck.removeLast()  // e.g., 'A|♠'
│      │   ├── card2 = deck.removeLast()
│      │   ├── Parse cards: 'A|♠'.split('|') → ['A', '♠']
│      │   └── Create PlayingCard objects
│      │
│      └── deck now has ~48 cards remaining
│
├── 4. DETERMINE POSITIONS
│      │
│      dealerIndex = Random().nextInt(numPlayers)
│      │
│      ├── HEADS-UP (2 players):
│      │   ├── sbIndex = dealerIndex        (dealer is SB)
│      │   └── bbIndex = (dealer + 1) % 2   (other is BB)
│      │
│      └── 3+ PLAYERS:
│          ├── sbIndex = (dealer + 1) % n
│          └── bbIndex = (dealer + 2) % n
│
├── 5. POST BLINDS
│      │
│      ├── Small Blind:
│      │   ├── sbAmount = min(player.chips, smallBlind)
│      │   └── Update: chips -= sbAmount, currentBet = sbAmount
│      │
│      └── Big Blind:
│          ├── bbAmount = min(player.chips, bigBlind)
│          └── Update: chips -= bbAmount, currentBet = bbAmount
│
├── 6. DETERMINE FIRST TO ACT (Preflop)
│      │
│      ├── HEADS-UP: firstToAct = dealerIndex
│      │   └── Dealer (SB) acts first preflop
│      │
│      └── 3+ PLAYERS: firstToAct = (dealer + 3) % n
│          └── UTG (Under The Gun) acts first
│
└── 7. UPDATE FIREBASE
       HTTP PATCH /game_rooms/{roomId}.json
       {
         'status': 'playing',
         'phase': 'preflop',
         'players': [...updated players with cards...],
         'deck': [...remaining ~48 cards...],
         'communityCards': [],
         'pot': sbAmount + bbAmount,
         'currentBet': bigBlind,
         'dealerIndex': dealerIndex,
         'currentTurnPlayerId': players[firstToAct].uid,
         'turnStartTime': timestamp,
         'lastRaiseAmount': bigBlind,
         'smallBlindIndex': sbIndex,
         'bigBlindIndex': bbIndex,
         'bbHasOption': true,
       }
```

---

## Betting Round Flow

### UI → Service Call

```
┌─────────────────────────────────────────────────────────────────┐
│  multiplayer_game_screen.dart - Action Buttons                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  User taps FOLD:                                                 │
│  └── _gameService.fold(widget.roomId)                            │
│      └── game_action_service.playerAction(roomId, 'fold')        │
│                                                                  │
│  User taps CHECK:                                                │
│  └── _gameService.check(widget.roomId)                           │
│      └── game_action_service.playerAction(roomId, 'check')       │
│                                                                  │
│  User taps CALL:                                                 │
│  └── _gameService.call(widget.roomId)                            │
│      └── game_action_service.playerAction(roomId, 'call')        │
│                                                                  │
│  User taps RAISE with slider amount:                             │
│  └── _gameService.raise(widget.roomId, amount)                   │
│      └── game_action_service.playerAction(roomId, 'raise',       │
│                                            raiseAmount: amount)  │
│                                                                  │
│  User taps ALL-IN:                                               │
│  └── _gameService.allIn(widget.roomId)                           │
│      └── game_action_service.playerAction(roomId, 'all-in')      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Action Processing: `game_action_service.dart` → `playerAction()`

```dart
FUNCTION: playerAction(roomId, action, {raiseAmount})
│
├── 1. FETCH & VALIDATE
│      ├── fetchRoom(roomId)
│      ├── Guard: room.status == 'playing' ?
│      ├── Guard: currentTurnPlayerId == myUserId ?
│      │   └── "Not your turn!" → return
│      └── Find player in players array
│
├── 2. PROCESS ACTION (switch on action)
│      │
│      ├── 'fold':
│      │   └── player.copyWith(hasFolded: true, hasActed: true,
│      │                        lastAction: 'FOLD')
│      │
│      ├── 'check':
│      │   ├── Guard: currentBet == player.currentBet ?
│      │   │   └── Else throw "Cannot check"
│      │   └── player.copyWith(hasActed: true, lastAction: 'CHECK')
│      │   └── If BB checking preflop: bbHasOption = false
│      │
│      ├── 'call':
│      │   ├── callAmount = currentBet - player.currentBet
│      │   ├── actualCall = min(callAmount, player.chips)
│      │   ├── pot += actualCall
│      │   └── player.copyWith(
│      │         chips: chips - actualCall,
│      │         currentBet: currentBet + actualCall,
│      │         totalContributed: += actualCall,
│      │         hasActed: true,
│      │         lastAction: (all-in?) 'ALL-IN' : 'CALL'
│      │       )
│      │
│      ├── 'raise':
│      │   ├── totalBet = raiseAmount (total, not increment)
│      │   ├── amountToAdd = totalBet - player.currentBet
│      │   ├── Validate: totalBet >= currentBet + lastRaiseAmount
│      │   ├── pot += amountToAdd
│      │   ├── newCurrentBet = totalBet
│      │   ├── newLastRaiseAmount = totalBet - oldCurrentBet
│      │   ├── RESET hasActed = false for all OTHER active players
│      │   │   └── They must respond to the raise
│      │   ├── bbHasOption = false
│      │   └── player.copyWith(...)
│      │
│      └── 'all-in':
│          ├── allInAmount = player.chips
│          ├── newTotalBet = player.currentBet + allInAmount
│          ├── pot += allInAmount
│          ├── If newTotalBet > currentBet:
│          │   ├── Update currentBet, lastRaiseAmount
│          │   ├── Reset hasActed for others
│          │   └── bbHasOption = false
│          └── player.copyWith(chips: 0, lastAction: 'ALL-IN', ...)
│
└── 3. POST-ACTION → _processPostAction()
```

### Post-Action Logic: `_processPostAction()`

```dart
FUNCTION: _processPostAction(roomId, room, players, pot, ...)
│
├── 1. CHECK: Only 1 player remaining?
│      │
│      activePlayers = players.where(p => !p.hasFolded)
│      │
│      if (activePlayers.length == 1):
│      │   ├── INSTANT WIN - everyone else folded
│      │   ├── winner.chips += pot
│      │   └── Update Firebase:
│      │       {
│      │         'phase': 'showdown',
│      │         'status': 'finished',
│      │         'pot': 0,
│      │         'winnerId': winner.uid,
│      │         'winningHandName': 'All Others Folded'
│      │       }
│      └── return
│
├── 2. CHECK: Betting round complete?
│      │
│      └── _isBettingRoundComplete(players, room, currentBet, bbHasOption)
│          │
│          if (complete):
│          │   └── _advancePhase(roomId, room, players, pot)
│          │       └── (see Phase Transitions section)
│          │
│          else:
│          │   └── Find next player to act
│
└── 3. FIND NEXT PLAYER
       │
       └── _findNextPlayer(players, currentPlayerIndex)
           │
           Loop from currentIndex + 1, wrapping around:
           │   ├── Skip folded players
           │   ├── Skip all-in players (chips == 0)
           │   └── Return first valid player
           │
           Update Firebase:
           {
             'players': [...],
             'pot': newPot,
             'currentBet': newCurrentBet,
             'currentTurnPlayerId': nextPlayerId,
             'turnStartTime': now,
             ...
           }
```

### Betting Complete Check (Inline in `_processPostAction()`)

Note: The actual implementation handles betting completion inline within `_processPostAction()` rather than a separate function:

```dart
// In _processPostAction():
│
├── playersWhoCanAct = players.where(p => !p.hasFolded && p.chips > 0)
│
├── allPlayersActed = playersWhoCanAct.every(p => p.hasActed)
│
├── allBetsEqual = playersWhoCanAct.every(p => p.currentBet == currentBet)
│
├── BB OPTION HANDLING (preflop only):
│   │
│   bbOptionUsed = !room.bbHasOption  // Start with inverse
│   │
│   if (room.bbHasOption):
│   │   ├── Get bbIndex based on heads-up or 3+ players
│   │   ├── if (current acting player IS the BB):
│   │   │   └── bbOptionUsed = true  // BB used their option
│   │   └── if (action == 'raise' || action == 'allin'):
│   │       └── bbOptionUsed = true  // Raise cancels BB option
│
├── bettingComplete = allPlayersActed && allBetsEqual &&
│                     (isPreflop ? bbOptionUsed : true)
│
└── if (bettingComplete): _advancePhase(...)
   else: update Firebase with next player
```

---

## Phase Transitions

### Advance Phase: `game_action_service.dart` → `_advancePhase()`

```dart
FUNCTION: _advancePhase(roomId, room, players, pot)
│
├── 1. DETERMINE NEXT PHASE
│      │
│      switch (room.phase):
│      │   'preflop' → 'flop'
│      │   'flop'    → 'turn'
│      │   'turn'    → 'river'
│      │   'river'   → 'showdown'
│
├── 2. CHECK: All-in & call situation (run out early?)
│      │
│      playersWithChips = activePlayers.where(p => p.chips > 0)
│      │
│      if (playersWithChips.length <= 1 && activePlayers.length >= 2):
│      │   └── All remaining players are all-in
│      │       └── _dealToShowdown(roomId, room, players, pot)
│      │           (Deals all remaining community cards at once)
│      │       └── return
│
├── 3. DEAL COMMUNITY CARDS (if not showdown)
│      │
│      deck = List.from(room.deck)
│      communityCards = List.from(room.communityCards)
│      │
│      if (nextPhase == 'flop'):
│      │   └── Deal 3 cards from deck.removeLast()
│      │
│      if (nextPhase == 'turn' || nextPhase == 'river'):
│      │   └── Deal 1 card from deck.removeLast()
│
├── 4. RESET PLAYER STATE FOR NEW ROUND
│      │
│      for each player:
│      │   if (!player.hasFolded):
│      │       player.copyWith(
│      │         hasActed: false,   // Must act again
│      │         currentBet: 0,     // New betting round
│      │       )
│
├── 5. FIND FIRST TO ACT (post-flop)
│      │
│      Start from (dealerIndex + 1)
│      Loop through players:
│      │   Skip folded
│      │   Skip all-in (chips == 0)
│      │   First valid = firstToAct
│
└── 6. UPDATE FIREBASE or SHOWDOWN
       │
       if (nextPhase == 'showdown'):
       │   └── _handleShowdown(roomId, room, players, pot, communityCards)
       │
       else:
           HTTP PATCH {
             'phase': nextPhase,
             'communityCards': [...],
             'deck': [...],
             'players': [...],
             'currentBet': 0,
             'currentTurnPlayerId': firstToActId,
             'turnStartTime': now,
             'bbHasOption': false,
           }
```

### Deal to Showdown (All-in): `_dealToShowdown()`

```dart
FUNCTION: _dealToShowdown(roomId, room, players, pot)
│
├── PURPOSE: When all active players are all-in and no betting actions
│            remain, deal all remaining community cards at once
│
├── Cards needed (INCLUDING BURN CARDS):
│   │   phase    │ community │ burns │ cards needed │
│   │ 'preflop' │     0     │   3   │   8 (3+3+2)  │  ← burn+3flop+burn+turn+burn+river
│   │ 'flop'    │     3     │   2   │   4 (2+2)    │  ← burn+turn+burn+river
│   │ 'turn'    │     4     │   1   │   2 (1+1)    │  ← burn+river
│   │ 'river'   │     5     │   0   │   0          │  ← already complete
│
├── SAFETY CHECK: deck.length >= required cards
│   └── If preflop: requires >= 8 cards in deck
│
├── Deal remaining cards with burns:
│   └── For each street: deck.removeLast() for burn, then community cards
│
├── Evaluate hands via HandEvaluator.determineWinners()
│
├── Distribute pot via PotService.distributePots()
│
└── Update Firebase with showdown results
```

---

## Showdown & Winner Determination

### Handle Showdown: `game_action_service.dart` → `_handleShowdown()`

```dart
FUNCTION: _handleShowdown(roomId, room, players, pot, communityCards)
│
├── 1. PARSE COMMUNITY CARDS
│      │
│      For each card string (e.g., 'A|♥'):
│      └── Split and create PlayingCard(rank: 'A', suit: '♥')
│
├── 2. GET ACTIVE PLAYERS
│      │
│      activePlayers = players.where(p => !p.hasFolded)
│
├── 3. DETERMINE WINNERS
│      │
│      └── HandEvaluator.determineWinners(activePlayers, communityCards)
│          │
│          For each player:
│          │   └── evaluateBestHand(player.cards, communityCards)
│          │       └── Returns EvaluatedHand with rank and kickers
│          │
│          Sort by hand strength (descending)
│          │
│          Find all players with best hand (ties possible)
│          │
│          └── Return list of winners
│
├── 4. AWARD POT
│      │
│      winAmount = pot ~/ winners.length  // Integer division
│      remainder = pot % winners.length   // First winner gets extra
│      │
│      for each winner:
│      │   winner.chips += winAmount
│      │   if (first winner): winner.chips += remainder
│
├── 5. GET WINNING HAND NAME
│      │
│      └── HandEvaluator.evaluateBestHand(winner.cards, communityCards)
│          └── Returns handName: "Royal Flush", "Full House", etc.
│
└── 6. UPDATE FIREBASE
       HTTP PATCH {
         'phase': 'showdown',
         'status': 'finished',
         'players': [...updated chips...],
         'pot': 0,
         'winnerId': winners[0].uid,
         'winnerIds': winners.map(w => w.uid),
         'winningHandName': handName,
         'communityCards': [...],
       }
```

### Hand Evaluation: `hand_evaluator.dart`

```
┌─────────────────────────────────────────────────────────────────┐
│  HandEvaluator.evaluateBestHand(holeCards, communityCards)       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  INPUT: 2 hole cards + 5 community cards = 7 cards               │
│                                                                  │
│  PROCESS:                                                        │
│  1. Generate all C(7,5) = 21 combinations of 5 cards             │
│  2. Evaluate each combination:                                   │
│     └── _evaluateHand(5 cards) → EvaluatedHand                   │
│  3. Return the best hand                                         │
│                                                                  │
│  OUTPUT: EvaluatedHand {                                         │
│    rank: HandRank (enum),                                        │
│    kickers: List<int> (for tiebreakers),                         │
│    handName: String (display name),                              │
│    bestCards: List<PlayingCard> (the 5 cards used)               │
│  }                                                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  HAND RANKINGS (HandRank enum, low to high)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  0. highCard      - No pairs, best 5 cards                       │
│  1. onePair       - Two cards same rank                          │
│  2. twoPair       - Two different pairs                          │
│  3. threeOfAKind  - Three cards same rank                        │
│  4. straight      - Five consecutive ranks                       │
│  5. flush         - Five cards same suit                         │
│  6. fullHouse     - Three of a kind + pair                       │
│  7. fourOfAKind   - Four cards same rank                         │
│  8. straightFlush - Straight + flush                             │
│  9. royalFlush    - A-K-Q-J-10 same suit                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  HandEvaluator.determineWinners(players, communityCards)         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. For each player, evaluate their best hand                    │
│  2. Sort players by hand strength (EvaluatedHand.compareTo)      │
│  3. Find all players tied for best hand                          │
│  4. Return list of winners                                       │
│                                                                  │
│  TIE-BREAKING:                                                   │
│  - Compare HandRank first (higher wins)                          │
│  - If same rank, compare kickers in order                        │
│  - Kickers are card values: A=14, K=13, Q=12, J=11, 10-2         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## New Hand Flow

### Trigger: `multiplayer_game_screen.dart`

```
StreamBuilder detects room.phase == 'showdown' && status == 'finished'
         │
         ▼
Show showdown animation (winner, hand name)
         │
         ▼ (after 4 second delay)
         │
_gameService.newHand(roomId)
```

### New Hand: `game_flow_service.dart` → `newHand()`

```dart
FUNCTION: newHand(roomId)
│
├── 1. FETCH & VALIDATE
│      │
│      fetchRoom(roomId)
│      │
│      Guard: room.phase == 'showdown' || status == 'finished'
│      └── Else: print warning, return
│
├── 2. REMOVE ELIMINATED PLAYERS
│      │
│      players = room.players.where(p => p.chips > 0)
│      │
│      if (players.length < 2):
│      │   └── GAME OVER - only 1 player has chips
│      │       Update status = 'finished'
│      │       return
│
├── 3. CREATE FRESH DECK
│      │
│      └── _createShuffledDeck() → 52 shuffled cards
│
├── 4. ROTATE DEALER
│      │
│      newDealerIndex = (room.dealerIndex + 1) % players.length
│
├── 5. CALCULATE NEW POSITIONS
│      │
│      (Same logic as startGame)
│      │
│      HEADS-UP:
│      │   sbIndex = newDealerIndex
│      │   bbIndex = (newDealerIndex + 1) % 2
│      │
│      3+ PLAYERS:
│          sbIndex = (newDealerIndex + 1) % n
│          bbIndex = (newDealerIndex + 2) % n
│
├── 6. POST BLINDS
│      │
│      (Same as startGame)
│
├── 7. DEAL NEW CARDS & RESET STATE
│      │
│      for each player:
│      │   ├── Deal 2 cards from deck.removeLast()
│      │   └── Reset: hasFolded=false, hasActed=false,
│      │              currentBet=0, totalContributed=0,
│      │              lastAction=null, cards=[newCards]
│      │
│      (Keep blind bets for SB/BB players)
│
├── 8. DETERMINE FIRST TO ACT
│      │
│      (Same as startGame preflop logic)
│
└── 9. UPDATE FIREBASE
       HTTP PATCH {
         'status': 'playing',
         'phase': 'preflop',
         'players': [...reset players with new cards...],
         'deck': [...fresh deck minus dealt cards...],
         'communityCards': [],
         'pot': sbAmount + bbAmount,
         'currentBet': bigBlind,
         'dealerIndex': newDealerIndex,
         'currentTurnPlayerId': firstToActId,
         'turnStartTime': now,
         ...
         'winnerId': null,
         'winnerIds': null,
         'winningHandName': null,
         'bbHasOption': true,
       }
```

---

## Player Disconnect Handling

### Heartbeat System

```
┌─────────────────────────────────────────────────────────────────┐
│  multiplayer_game_screen.dart - Heartbeat                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  _startHeartbeat() called on initState:                          │
│                                                                  │
│  1. Send immediate heartbeat                                     │
│     └── _gameService.sendHeartbeat(roomId)                       │
│                                                                  │
│  2. Start periodic timer (every 5 seconds):                      │
│     └── Timer.periodic(Duration(seconds: 5), (_) {               │
│           _gameService.sendHeartbeat(roomId);                    │
│           _gameService.removeInactivePlayers(roomId);  // host   │
│         });                                                      │
│                                                                  │
│  _stopHeartbeat() called on dispose                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Send Heartbeat: `room_service.dart` → `sendHeartbeat()`

```dart
FUNCTION: sendHeartbeat(roomId)
│
├── 1. Fetch room
│
├── 2. Find current player in players array
│
├── 3. Update their lastActiveAt timestamp
│      │
│      player.copyWith(lastActiveAt: DateTime.now())
│
└── 4. HTTP PATCH players array to Firebase
```

### Remove Inactive Players: `room_service.dart` → `removeInactivePlayers()`

```dart
FUNCTION: removeInactivePlayers(roomId)
│
├── 1. GUARD: Only host can remove players
│      │
│      if (room.hostId != currentUserId): return
│      if (room.status == 'finished'): return
│
├── 2. CALCULATE INACTIVE TIMEOUT
│      │
│      const TIMEOUT_SECONDS = 15
│      │
│      activePlayers = room.players.where(player => {
│        if (player.lastActiveAt == null):
│          // New player, use room creation time
│          return now - room.createdAt < TIMEOUT
│        else:
│          return now - player.lastActiveAt < TIMEOUT
│      })
│
├── 3. CHECK IF PLAYERS REMOVED
│      │
│      if (activePlayers.length < room.players.length):
│      │   └── Some players disconnected!
│
├── 4. HANDLE EMPTY ROOM
│      │
│      if (activePlayers.isEmpty):
│      │   └── DELETE room from Firebase
│      │       return
│
├── 5. ★ CRITICAL: GAME IN PROGRESS, ONLY 1 PLAYER LEFT
│      │
│      if (room.status == 'playing' && activePlayers.length == 1):
│      │   │
│      │   winner = activePlayers.first
│      │   winner.chips += room.pot  // Award pot
│      │   │
│      │   HTTP PATCH {
│      │     'players': [winner],
│      │     'status': 'finished',
│      │     'phase': 'showdown',
│      │     'pot': 0,
│      │     'winnerId': winner.uid,
│      │     'winningHandName': 'Opponent Disconnected',
│      │   }
│      │   return
│
└── 6. NORMAL REMOVAL
       │
       HTTP PATCH {
         'players': activePlayers,
         'hostId': activePlayers.first.uid,  // New host if needed
       }
```

### Leave Room: `room_service.dart` → `leaveRoom()`

```dart
FUNCTION: leaveRoom(roomId)
│
├── 1. Fetch room
│
├── 2. Remove current player from array
│      │
│      updatedPlayers = room.players.where(p => p.uid != currentUserId)
│
├── 3. HANDLE EMPTY ROOM
│      │
│      if (updatedPlayers.isEmpty):
│      │   └── DELETE room from Firebase
│      │       return
│
├── 4. ★ CRITICAL: GAME IN PROGRESS, ONLY 1 PLAYER LEFT
│      │
│      if (room.status == 'playing' && updatedPlayers.length == 1):
│      │   │
│      │   winner = updatedPlayers.first
│      │   winner.chips += room.pot  // Award pot
│      │   │
│      │   HTTP PATCH {
│      │     'players': [winner],
│      │     'status': 'finished',
│      │     'phase': 'showdown',
│      │     'pot': 0,
│      │     'winnerId': winner.uid,
│      │     'winningHandName': 'Opponent Left',
│      │   }
│      │   return
│
└── 5. NORMAL LEAVE
       │
       HTTP PATCH {
         'players': updatedPlayers,
         'hostId': updatedPlayers.first.uid,  // Transfer host if needed
       }
```

---

## Common Bugs & Debugging

### Bug #1: Cards Not Dealt / Wrong Cards

**Symptoms**: 
- Players have same cards
- No cards dealt
- Wrong number of cards

**Debug Points**:
```
game_flow_service.dart:
  └── _createShuffledDeck() - Is deck created correctly?
  └── startGame() - Is dealing loop executing?
  └── newHand() - Is fresh deck created?
```

**Common Causes**:
```dart
// ❌ WRONG - map() is lazy, may not execute side effects
final dealtPlayers = room.players.map((p) {
  final card1 = deck.removeLast();  // May not execute!
  ...
});

// ✅ CORRECT - explicit for loop guarantees execution
final dealtPlayers = <GamePlayer>[];
for (final player in room.players) {
  final card1 = deck.removeLast();  // Guaranteed
  ...
  dealtPlayers.add(newPlayer);
}
```

**Debug Steps**:
1. Add print statement in dealing loop
2. Check deck length before/after dealing
3. Verify players array length

---

### Bug #2: Turn Not Advancing

**Symptoms**:
- Game stuck on one player's turn
- Timer keeps resetting but turn doesn't change

**Debug Points**:
```
game_action_service.dart:
  └── playerAction() - Is action being processed?
  └── _findNextPlayer() - Is it returning correct player?
  └── _processPostAction() - Is Firebase being updated?
```

**Common Causes**:
- Player's `hasActed` not being set to `true`
- All other players marked as folded
- `currentTurnPlayerId` not being updated
- Infinite loop in `_findNextPlayer` (no valid next player)

**Debug Steps**:
1. Log the action received
2. Log the player state before/after action
3. Log the next player ID being set
4. Check Firebase directly for room state

---

### Bug #3: Phase Not Advancing

**Symptoms**:
- All players have acted but phase doesn't change
- Stuck on flop/turn/river forever

**Debug Points**:
```
game_action_service.dart:
  └── _processPostAction() - Check betting complete logic (inline, not separate function)
  └── _advancePhase() - Is it being called?
  └── Check bbHasOption handling

game_flow_service.dart:
  └── handleTurnTimeout() - Does NOT check betting complete!
      ⚠️ After timeout fold, it just moves to next player without
         checking if phase should advance. This could cause bugs.
```

**Common Causes**:
- BB still has option but hasn't used it
- Player is all-in but hasn't "acted" (no hasActed flag)
- `hasActed` incorrectly reset after a raise

**Debug Checklist**:
```
□ All active players have hasActed == true
□ All active players have currentBet >= room.currentBet (or are all-in)
□ If preflop, bbHasOption == false OR BB has acted
□ _advancePhase is being called after betting complete
```

---

### Bug #4: Pot Not Awarded

**Symptoms**:
- Winner determined but chips not added
- Pot shows 0 but winner didn't receive chips

**Debug Points**:
```
game_action_service.dart:
  └── _handleShowdown() - Is pot being added?
  └── Check winner.copyWith() is being used
  
pot_service.dart (if side pots):
  └── calculateSidePots()
  └── distributePot()
```

**Common Causes**:
- `copyWith()` result not being assigned back
- Side pot calculation returning wrong amounts
- Firebase patch failing silently

**Debug Steps**:
1. Log pot value before distribution
2. Log winner chips before/after
3. Verify the patch payload includes updated players

---

### Bug #5: Game Not Starting

**Symptoms**:
- Players in room but game never starts
- "Waiting for players" forever

**Debug Points**:
```
multiplayer_game_screen.dart:
  └── _tryAutoStart() - Check all conditions

Conditions to check:
  □ _hasAutoStarted == false
  □ room.players.length >= requiredPlayers
  □ currentUser is host (room.hostId == userId)
  □ All players have isReady == true
```

**Common Causes**:
- Not all players are ready
- Current user isn't the host
- `_hasAutoStarted` flag already true from previous game
- requiredPlayers set higher than actual players

---

### Bug #6: Disconnect Not Detected

**Symptoms**:
- Player left but game continues waiting for them
- "Waiting for opponent" shows indefinitely

**Debug Points**:
```
multiplayer_game_screen.dart:
  └── _startHeartbeat() - Is timer running?

room_service.dart:
  └── sendHeartbeat() - Is it updating lastActiveAt?
  └── removeInactivePlayers() - Is host calling this?
```

**Common Causes**:
- Heartbeat timer not started
- Only HOST removes inactive players
- If host leaves, no one is checking for inactive
- Timeout is 15 seconds (inactiveTimeoutSeconds constant)

**Key Insight**:
```
The removeInactivePlayers() function only runs if:
  room.hostId == currentUserId

If the HOST disconnects:
  - No one is calling removeInactivePlayers
  - Other players stay stuck
  - SOLUTION: Transfer host before disconnect, or have all players check

⚠️ KNOWN GAP: When a non-host player disconnects mid-turn:
  - Their turn timer will expire
  - handleTurnTimeout() folds them and moves to next player
  - BUT: handleTurnTimeout() does NOT check if phase should advance!
  - This could leave game in inconsistent state
```

---

### Bug #7: Double Actions / Race Conditions

**Symptoms**:
- Player acts twice
- Wrong player's turn after action
- Actions seem "lost"

**Debug Points**:
```
Is there a lock/guard preventing double-taps?
Is there async/await properly handling order?
Are multiple HTTP requests racing?
```

**Common Causes**:
- No debounce on action buttons
- `_isLoading` guard not being used
- Stale room state being used for calculations

**Prevention Pattern**:
```dart
bool _isProcessingAction = false;

Future<void> _handleAction() async {
  if (_isProcessingAction) return;  // Guard
  _isProcessingAction = true;
  
  try {
    await _gameService.call(roomId);
  } finally {
    _isProcessingAction = false;
  }
}
```

---

### Bug #8: Community Cards Wrong

**Symptoms**:
- Flop has wrong number of cards
- Same card appears multiple times
- Cards don't match what was dealt

**Debug Points**:
```
game_action_service.dart:
  └── _advancePhase() - How many cards dealt per phase?
  
Check deck manipulation:
  - deck.removeLast() removes from END
  - Are cards being removed or just read?
```

**Expected Community Cards**:
```
Phase     | Cards | Total Community
----------|-------|----------------
preflop   |   0   |      0
flop      |   3   |      3
turn      |   1   |      4
river     |   1   |      5
showdown  |   0   |      5
```

---

## Firebase Data Structure

### Complete Room Document

```json
{
  "id": "ABC123",
  "hostId": "firebase_uid_string",
  
  "status": "playing",
  // Values: "waiting" | "playing" | "finished"
  
  "phase": "flop",
  // Values: "waiting_for_players" | "preflop" | "flop" | "turn" | "river" | "showdown"
  
  "players": [
    {
      "uid": "firebase_uid_string",
      "username": "Player1",
      "avatarEmoji": "👤",
      
      "chips": 950,
      "currentBet": 50,
      "totalContributed": 50,
      
      "hasFolded": false,
      "hasActed": true,
      "isReady": true,
      
      "lastAction": "CALL",
      // Values: null | "FOLD" | "CHECK" | "CALL" | "RAISE" | "ALL-IN"
      
      "lastActiveAt": 1706745600000,
      // Milliseconds since epoch
      
      "cards": [
        {"rank": "A", "suit": "♠"},
        {"rank": "K", "suit": "♠"}
      ]
    },
    // ... more players
  ],
  
  "maxPlayers": 6,
  "bigBlind": 100,
  "smallBlind": 50,
  
  "pot": 300,
  "currentBet": 100,
  "lastRaiseAmount": 100,
  
  "dealerIndex": 0,
  "smallBlindIndex": 1,
  "bigBlindIndex": 0,
  
  "currentTurnPlayerId": "firebase_uid_string",
  "turnStartTime": 1706745600000,
  "turnTimeLimit": 10,
  
  "bbHasOption": false,
  
  "communityCards": ["A|♥", "K|♦", "Q|♣"],
  // String format: "{rank}|{suit}"
  
  "deck": ["2|♠", "3|♠", "4|♠", ...],
  // Remaining cards after dealing
  
  "winnerId": null,
  "winnerIds": null,
  "winningHandName": null,
  // Set after showdown
  
  "gameType": "quickplay",
  // Values: "quickplay" | "sitandgo" | "private"
  
  "isPrivate": false,
  
  "createdAt": 1706745500000,
  "lastActivityAt": 1706745600000
}
```

---

## State Machine Diagrams

### Room Status State Machine

```
                         ┌──────────────┐
                         │   WAITING    │
                         │              │
                         │ players can  │
                         │ join/leave   │
                         └──────┬───────┘
                                │
                    startGame() │ (2+ players ready)
                                │
                                ▼
                         ┌──────────────┐
                    ┌───►│   PLAYING    │◄───┐
                    │    │              │    │
          newHand() │    │ actions in   │    │ newHand()
        (2+ players)│    │ progress     │    │ (2+ players)
                    │    └──────┬───────┘    │
                    │           │            │
                    │           │ showdown   │
                    │           │            │
                    │           ▼            │
                    │    ┌──────────────┐    │
                    └────│   FINISHED   │────┘
                         │              │
                         │ winner       │
                         │ determined   │
                         └──────┬───────┘
                                │
                    newHand()   │ (< 2 players)
                                │
                                ▼
                         ┌──────────────┐
                         │  GAME OVER   │
                         │              │
                         │ room can be  │
                         │ deleted      │
                         └──────────────┘
```

### Betting Phase State Machine

```
                         ┌──────────────┐
          startGame() ──►│   PREFLOP    │
                         │              │
                         │ 2 cards each │
                         │ blinds posted│
                         └──────┬───────┘
                                │
                                │ betting complete
                                ▼
                         ┌──────────────┐
                         │    FLOP      │
                         │              │
                         │ 3 community  │
                         │ cards dealt  │
                         └──────┬───────┘
                                │
                                │ betting complete
                                ▼
                         ┌──────────────┐
                         │    TURN      │
                         │              │
                         │ 1 community  │
                         │ card dealt   │
                         └──────┬───────┘
                                │
                                │ betting complete
                                ▼
                         ┌──────────────┐
                         │    RIVER     │
                         │              │
                         │ 1 community  │
                         │ card dealt   │
                         └──────┬───────┘
                                │
                                │ betting complete
                                ▼
                         ┌──────────────┐
                         │  SHOWDOWN    │
                         │              │
                         │ hands eval'd │
                         │ pot awarded  │
                         └──────────────┘

* "betting complete" = all active players acted AND matched bet
* Can SKIP to showdown from ANY phase if only 1 player remains
* Can DEAL all remaining cards if everyone is all-in
```

### Player Action Flow

```
                      ┌────────────────────┐
                      │  Player's Turn     │
                      │                    │
                      │ currentTurnPlayer  │
                      │ == this player     │
                      └─────────┬──────────┘
                                │
          ┌─────────┬───────────┼───────────┬─────────┐
          │         │           │           │         │
          ▼         ▼           ▼           ▼         ▼
      ┌───────┐ ┌───────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
      │ FOLD  │ │ CHECK │ │  CALL   │ │ RAISE   │ │ ALL-IN  │
      └───┬───┘ └───┬───┘ └────┬────┘ └────┬────┘ └────┬────┘
          │         │          │           │           │
          │         │          │           │           │
          │    (only if   (match      (increase   (bet all
          │    currentBet  current      bet,       remaining
          │    == myBet)   bet)        reset       chips)
          │                            others'
          │                            hasActed)
          │         │          │           │           │
          ▼         ▼          ▼           ▼           ▼
      ┌───────────────────────────────────────────────────┐
      │              _processPostAction()                  │
      └─────────────────────────┬─────────────────────────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                 │
              ▼                 ▼                 ▼
      ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
      │ Only 1 player │ │    Betting    │ │ Next player   │
      │ remains?      │ │   complete?   │ │ to act        │
      │               │ │               │ │               │
      │ Award pot &   │ │ _advancePhase │ │ Update turn   │
      │ finish game   │ │               │ │               │
      └───────────────┘ └───────────────┘ └───────────────┘
```

---

## Function Call Chains

### Quick Reference: Action → Result

```
USER TAPS FOLD:
  multiplayer_game_screen._handleFold()
    → game_service.fold(roomId)
      → game_action_service.playerAction(roomId, 'fold')
        → _processPostAction()
          → [update Firebase OR _advancePhase OR instant win]

USER TAPS CALL:
  multiplayer_game_screen._handleCall()
    → game_service.call(roomId)
      → game_action_service.playerAction(roomId, 'call')
        → _processPostAction()
          → [update Firebase OR _advancePhase OR instant win]

USER TAPS RAISE:
  multiplayer_game_screen._handleRaise(amount)
    → game_service.raise(roomId, amount)
      → game_action_service.playerAction(roomId, 'raise', raiseAmount: amount)
        → _processPostAction()
          → [update Firebase OR _advancePhase OR instant win]

BETTING ROUND COMPLETE:
  _processPostAction()
    → _isBettingRoundComplete() returns true
      → _advancePhase(roomId, room, players, pot)
        → [deal cards, reset state, update phase]
          → [if river complete: _handleShowdown()]

SHOWDOWN:
  _handleShowdown()
    → HandEvaluator.determineWinners()
      → [award pot to winners]
        → [update Firebase: status='finished', phase='showdown']

NEW HAND TRIGGER:
  StreamBuilder sees room.phase == 'showdown' && status == 'finished'
    → Future.delayed(4 seconds)
      → game_service.newHand(roomId)
        → game_flow_service.newHand()
          → [remove eliminated, shuffle, deal, post blinds]

HEARTBEAT:
  Timer every 5 seconds
    → game_service.sendHeartbeat(roomId)
      → room_service.sendHeartbeat()
        → [update lastActiveAt for current player]
    → game_service.removeInactivePlayers(roomId) [host only]
      → room_service.removeInactivePlayers()
        → [check timeouts, remove inactive, handle mid-game disconnect]
```

---

## ⚠️ Identified Issues & Recommended Fixes

### Issue #1: `handleTurnTimeout()` Doesn't Advance Phase

**Location**: [game_flow_service.dart](lib/services/game_flow_service.dart#L248-L296)

**Problem**: When a player times out, `handleTurnTimeout()` folds them and moves to the next player, but it does NOT check if the betting round is complete. If the timed-out player was the last to act, the phase won't advance.

**Fix Required**: After folding the timed-out player, call the same betting-complete logic used in `_processPostAction()`:
```dart
// After folding timed-out player, check if betting complete
final playersWhoCanAct = updatedPlayers.where((p) => !p.hasFolded && p.chips > 0).toList();
final allPlayersActed = playersWhoCanAct.every((p) => p.hasActed);
final allBetsEqual = playersWhoCanAct.every((p) => p.currentBet == room.currentBet);

if (allPlayersActed && allBetsEqual) {
  // Call _advancePhase logic or refactor to shared function
}
```

---

### Issue #2: Bot `raise` Doesn't Always Reset Others' `hasActed`

**Location**: [game_action_service.dart](lib/services/game_action_service.dart#L280-L314)

**Problem**: In `botAction()`, when bot raises but doesn't have enough chips (goes all-in instead), the `hasActed` flag for other players is NOT reset. This could allow phase to advance prematurely.

**Current Code** (lines ~280-300):
```dart
if (addAmount > player.chips) {
  // Goes all-in instead - but doesn't reset others' hasActed!
  ...
  if (newTotalBet > currentBet) {
    currentBet = newTotalBet;
    // Missing: Reset hasActed for other players
  }
}
```

**Fix Required**: Add the hasActed reset when all-in exceeds current bet.

---

### Issue #3: Missing `winningHandName` Field When Single Player Wins

**Location**: [game_action_service.dart](lib/services/game_action_service.dart#L349-L362)

**Problem**: When all but one player folds (instant win), the `winningHandName` is not set in Firebase. The UI may show "undefined" or empty.

**Current Code**:
```dart
'winnerId': updatedPlayers[winnerIndex].uid,
// Missing: 'winningHandName': 'All Others Folded',
```

**Note**: This is handled in some paths but not consistently. Verify all instant-win paths set this field.

---

### Issue #4: 1.5 Second Delay Before Phase Advance

**Location**: [game_action_service.dart](lib/services/game_action_service.dart#L427)

**Current**:
```dart
if (bettingComplete) {
  await Future.delayed(const Duration(milliseconds: 1500));  // ⬅️ This
  await _advancePhase(roomId, room, updatedPlayers, pot);
}
```

**Consideration**: This hardcoded delay can feel sluggish. Consider:
- Making it configurable
- Reducing it for experienced players
- Removing it for all-bot scenarios

---

### Optimization #1: Redundant `hasActed = true` Assignment

**Location**: [game_action_service.dart](lib/services/game_action_service.dart#L84) and [line 184](lib/services/game_action_service.dart#L184)

`hasActed = true` is set at line 84 (before switch) AND again at line 184 (after switch). The second assignment is redundant.

---

### Optimization #2: Consider Database Transactions

**Issue**: Multiple players acting simultaneously could cause race conditions. The current retry logic in `joinRoom()` helps, but game actions don't have similar protection.

**Recommendation**: Consider Firebase transactions or optimistic locking for critical state updates.

---

## Quick Debug Commands

### Print Statements to Add

```dart
// In playerAction() - track action flow
print('🎯 ACTION: $action by ${player.username}');
print('   chips: ${player.chips}, currentBet: ${player.currentBet}');
print('   room currentBet: ${room.currentBet}, pot: ${room.pot}');

// In _processPostAction() - track betting state
print('📊 BETTING CHECK:');
for (final p in playersWhoCanAct) {
  print('   ${p.username}: acted=${p.hasActed}, bet=${p.currentBet}, chips=${p.chips}');
}
print('   bbHasOption: ${room.bbHasOption}');

// In _advancePhase() - track phase changes
print('⏩ ADVANCING: ${room.phase} → $nextPhase');
print('   community cards: ${newCommunityCards.length}');
print('   deck remaining: ${deck.length}');

// In _handleShowdown() - track winner
print('🏆 SHOWDOWN:');
print('   winners: ${winners.map((w) => w.username)}');
print('   hand: $handName');
print('   pot distributed: $pot');
```

### Firebase Console Check

1. Go to: https://console.firebase.google.com
2. Select ALLIN project
3. Realtime Database → game_rooms → {roomId}
4. Check:
   - `status` value
   - `phase` value
   - `currentTurnPlayerId`
   - `players` array (expand to see each player's state)
   - `deck` length
   - `communityCards` length

---

*Deep technical documentation for ALLIN poker game - February 2026*
