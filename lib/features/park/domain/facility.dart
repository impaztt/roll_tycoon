import 'package:flutter/foundation.dart';

import 'tile.dart';

/// Facility category (per design doc §13.1, §151.2).
enum FacilityCategory {
  attraction, // 놀이기구
  shop, // 음식/기념품 상점
  amenity, // 화장실, 벤치, 쓰레기통
  decoration, // 나무, 꽃
  staffRoom, // 청소부 휴게소
  path, // 길 (technically a tile, but treated uniformly)
}

/// Static blueprint for a facility — comes from a master data table
/// (per design doc §56.1, §151.2). MVP hard-codes a small catalog.
@immutable
class FacilityMaster {
  final String id;
  final String name;
  final String emoji; // visual placeholder until 3D assets exist
  final FacilityCategory category;
  final int sizeX;
  final int sizeY;
  final int unlockLevel;
  final int buildCost;
  final int basePricePerRide;
  final double baseIncomePerMin;
  final double maintenancePerMin;
  final int capacity;
  final double cycleTimeSec;
  final int excitement;
  final int fear;
  final int nausea;
  final List<String> themeTags;
  final bool generatesTrash;

  const FacilityMaster({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.sizeX,
    required this.sizeY,
    required this.unlockLevel,
    required this.buildCost,
    required this.basePricePerRide,
    required this.baseIncomePerMin,
    required this.maintenancePerMin,
    required this.capacity,
    required this.cycleTimeSec,
    required this.excitement,
    required this.fear,
    required this.nausea,
    required this.themeTags,
    required this.generatesTrash,
  });
}

/// Operating status of a placed facility (per design doc §151.1).
enum FacilityStatus {
  operating,
  needsPath,
  paused,
  broken,
}

/// A facility instance placed on the park grid.
class PlacedFacility {
  final String instanceId;
  final FacilityMaster master;
  final TileCoord origin; // bottom-left tile
  int rotation; // 0/90/180/270 — MVP doesn't actually rotate visually yet
  int level;
  int price;
  FacilityStatus status;
  double durability; // 0..100
  double cycleProgressSec; // current ride cycle progress
  int riders; // currently riding
  int totalRidesToday;
  int incomeToday;

  PlacedFacility({
    required this.instanceId,
    required this.master,
    required this.origin,
    this.rotation = 0,
    this.level = 1,
    int? price,
    this.status = FacilityStatus.needsPath,
    this.durability = 100.0,
    this.cycleProgressSec = 0.0,
    this.riders = 0,
    this.totalRidesToday = 0,
    this.incomeToday = 0,
  }) : price = price ?? master.basePricePerRide;

  /// Tiles this facility occupies.
  Iterable<TileCoord> tiles() sync* {
    for (var dy = 0; dy < master.sizeY; dy++) {
      for (var dx = 0; dx < master.sizeX; dx++) {
        yield TileCoord(origin.x + dx, origin.y + dy);
      }
    }
  }

  /// Single entrance tile (south side, center). MVP simplification —
  /// real game would let players choose entrance direction.
  TileCoord entranceTile() {
    return TileCoord(origin.x + master.sizeX ~/ 2, origin.y - 1);
  }

  /// Effective per-ride income at current level (per design doc §153.3).
  /// income = base × (1 + level × 0.18).
  double get effectivePricePerRide => price * (1 + (level - 1) * 0.18);

  /// Whether the facility can take another rider this cycle.
  bool get canBoard => riders < master.capacity && status == FacilityStatus.operating;
}
