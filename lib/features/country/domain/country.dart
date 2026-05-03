import 'dart:math' as math;

import '../../economy/domain/currency.dart';
import 'biome.dart';
import 'parcel.dart';

/// The player's country = a single planet of parcels.
///
/// Owns currency, level, and the parcel list. The simulation tick iterates
/// each owned parcel's [Park] and rolls their income up here.
class Country {
  final String name;
  int level;
  int exp;
  Currency currency;
  double memoryScore; // averaged across parcels

  final List<Parcel> parcels;

  Country({
    required this.name,
    this.level = 1,
    this.exp = 0,
    required this.currency,
    this.memoryScore = 70,
    required this.parcels,
  });

  Iterable<Parcel> get owned => parcels.where((p) => p.isOwned);

  /// Cost the player would pay to unlock the next parcel.
  int get nextParcelCost => parcelCostFor(owned.length);

  /// Build a fresh country with a starter planet of ~24 parcels at
  /// roughly even spacing on the sphere.
  factory Country.fresh({String name = '꿈빛 행성'}) {
    final parcels = _generateInitialParcels();
    // Give the first parcel for free as starter land (per DESIGN.md §6.1).
    parcels.first.isOwned = true;
    parcels.first.park = null; // park will be created lazily on first entry
    return Country(
      name: name,
      currency: Currency.initial,
      parcels: parcels,
    );
  }

  static List<Parcel> _generateInitialParcels() {
    // Roughly evenly distribute 24 points on a sphere using a Fibonacci spiral.
    // Then assign biomes by lat band so the planet looks like it has poles.
    const n = 24;
    final goldenAngle = math.pi * (3 - math.sqrt(5));
    final parcels = <Parcel>[];
    for (var i = 0; i < n; i++) {
      final y = 1 - (i / (n - 1)) * 2; // 1 .. -1
      final lat = math.asin(y);
      final lon = goldenAngle * i;
      final biome = _biomeForLat(lat, i);
      parcels.add(Parcel(
        id: 'p$i',
        lat: lat,
        lon: ((lon + math.pi) % (2 * math.pi)) - math.pi,
        biome: biome,
        purchaseCost: 0, // set per-acquisition via Country.nextParcelCost
      ));
    }
    return parcels;
  }

  static Biome _biomeForLat(double lat, int seed) {
    // Polar = starlight/cloud, equator = sweet/ocean, mid = forest/meadow.
    final absLat = lat.abs();
    if (absLat > 1.1) return Biome.starlight;
    if (absLat > 0.85) return Biome.cloud;
    if (absLat > 0.45) {
      return seed.isEven ? Biome.forest : Biome.meadow;
    }
    return seed % 3 == 0 ? Biome.ocean : Biome.sweetGarden;
  }
}
