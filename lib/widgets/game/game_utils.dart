import '../../services/hand_evaluator.dart';
import '../../services/currency_service.dart';

/// Format chips for display (e.g., 12000 -> "12k", 1000000 -> "1M")
/// Delegates to CurrencyService.formatChips for consistency
String formatChips(int chips) {
  return CurrencyService.formatChips(chips);
}

/// Get short hand name for display
String getShortHandName(HandRank rank) {
  switch (rank) {
    case HandRank.royalFlush:
      return 'Royal!';
    case HandRank.straightFlush:
      return 'Str Flush';
    case HandRank.fourOfAKind:
      return 'Quads';
    case HandRank.fullHouse:
      return 'Full House';
    case HandRank.flush:
      return 'Flush';
    case HandRank.straight:
      return 'Straight';
    case HandRank.threeOfAKind:
      return 'Trips';
    case HandRank.twoPair:
      return 'Two Pair';
    case HandRank.onePair:
      return 'Pair';
    case HandRank.highCard:
      return 'High Card';
  }
}

/// Get avatar for a player name
String getAvatarForName(String name, {bool isBot = false, String? userAvatar}) {
  if (userAvatar != null) return userAvatar;
  if (isBot) return getBotAvatar(name);
  if (name.isEmpty) return '👤';

  final firstChar = name[0].toLowerCase();
  final avatars = {
    'a': '👨',
    'b': '🧔',
    'c': '👩',
    'd': '🧑',
    'e': '👴',
    'f': '👵',
    'g': '🦊',
    'h': '🦄',
    'i': '🐸',
    'j': '🐵',
    'k': '🐻',
    'l': '🐼',
    'm': '🦁',
    'n': '🐯',
    'o': '🐨',
    'p': '🐷',
    'q': '🐰',
    'r': '🐶',
    's': '🐱',
    't': '🐲',
    'u': '🦋',
    'v': '🦅',
    'w': '🐺',
    'x': '🦈',
    'y': '🦜',
    'z': '🦎',
  };
  return avatars[firstChar] ?? '👤';
}

/// Get bot-specific avatar
String getBotAvatar(String name) {
  final botAvatars = ['🤖', '🦊', '🐸', '🦁', '🐼', '🐮', '🐧', '🐯', '🐻', '🦄', '🐵', '🐺'];
  // Extract number from bot name or use hash
  final numMatch = RegExp(r'\d+').firstMatch(name);
  if (numMatch != null) {
    final num = int.tryParse(numMatch.group(0)!) ?? 0;
    return botAvatars[num % botAvatars.length];
  }
  // Use name hash for consistent avatar
  return botAvatars[name.hashCode.abs() % botAvatars.length];
}
