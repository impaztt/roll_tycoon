import 'package:flutter/foundation.dart';

/// Player currencies (per design doc §11.1). MVP uses coin/gem/heart only.
@immutable
class Currency {
  final int coin;
  final int gem;
  final int heart;

  const Currency({
    required this.coin,
    required this.gem,
    required this.heart,
  });

  Currency copyWith({int? coin, int? gem, int? heart}) => Currency(
        coin: coin ?? this.coin,
        gem: gem ?? this.gem,
        heart: heart ?? this.heart,
      );

  Currency addCoin(int amount) => copyWith(coin: coin + amount);
  Currency addHeart(int amount) => copyWith(heart: heart + amount);

  /// Returns null if the coin cost cannot be paid.
  Currency? spendCoin(int amount) {
    if (coin < amount) return null;
    return copyWith(coin: coin - amount);
  }

  static const initial = Currency(coin: 5000, gem: 50, heart: 0);
}
