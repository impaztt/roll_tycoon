import 'package:flutter/foundation.dart';

import '../../park/domain/park.dart';
import 'biome.dart';

/// A single piece of land on the globe (per DESIGN.md §5).
class Parcel {
  final String id;
  final double lat; // radians, -pi/2..pi/2
  final double lon; // radians, -pi..pi
  final Biome biome;
  final int purchaseCost;
  bool isOwned;
  Park? park; // populated when purchased

  Parcel({
    required this.id,
    required this.lat,
    required this.lon,
    required this.biome,
    required this.purchaseCost,
    this.isOwned = false,
    this.park,
  });
}

/// Cost curve for the n-th parcel acquisition (per DESIGN.md §6.2).
/// First parcel is free (tutorial), subsequent costs grow exponentially
/// so the late game requires multi-parcel income to keep expanding.
int parcelCostFor(int ownedCount) {
  if (ownedCount == 0) return 0;
  if (ownedCount == 1) return 2000;
  // 1500 * pow(2.4, n-2) for n>=2
  var cost = 1500.0;
  for (var i = 0; i < ownedCount - 1; i++) {
    cost *= 2.4;
  }
  return cost.round();
}

/// Snapshot of a parcel's state for UI lists.
@immutable
class ParcelSummary {
  final String id;
  final String biomeName;
  final bool isOwned;
  final int incomePerMin;
  final int facilityCount;
  final double satisfaction;
  const ParcelSummary({
    required this.id,
    required this.biomeName,
    required this.isOwned,
    required this.incomePerMin,
    required this.facilityCount,
    required this.satisfaction,
  });
}
