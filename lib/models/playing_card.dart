/// Represents a playing card
class PlayingCard {
  final String rank;
  final String suit;

  PlayingCard({required this.rank, required this.suit});

  Map<String, dynamic> toJson() => {'rank': rank, 'suit': suit};

  factory PlayingCard.fromJson(Map<String, dynamic> json) {
    return PlayingCard(
      rank: json['rank'] as String,
      suit: json['suit'] as String,
    );
  }

  @override
  String toString() => '$rank$suit';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayingCard && other.rank == rank && other.suit == suit;
  }

  @override
  int get hashCode => rank.hashCode ^ suit.hashCode;
}
