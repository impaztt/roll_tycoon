import 'package:flutter/foundation.dart';

import '../../../core/constants/game_constants.dart';
import '../../guest/domain/guest.dart';
import '../../staff/domain/staff.dart';
import 'facility.dart';
import 'tile.dart';

/// Top-level state of the player's park.
///
/// Holds tile grid, facility instances, guests, staff, and aggregate metrics.
/// Mutated by the game tick loop in features/park/application/park_simulation.dart.
class Park {
  final int width;
  final int height;

  // Grid: which kind occupies each tile.
  final List<List<TileKind>> tiles;

  final Map<String, PlacedFacility> facilities;
  final Map<String, Guest> guests;
  final Map<String, Staff> staff;
  final Map<String, Trash> trash;

  // Aggregate stats (per design doc §147.2 — what the top bar shows)
  int level;
  int exp;

  // 0..100 averages over recent guest visits
  double satisfaction;
  double cleanliness;
  double memoryScore; // 추억 점수 average — the differentiator (§58)

  // Today's running totals (reset on day rollover; MVP just accumulates)
  int visitorsToday;
  int incomeToday;
  double avgWaitSec;

  // Reviews (per design doc §42, §150.7) — most recent first, capped to 20.
  final List<GuestReview> recentReviews;

  Park({
    required this.width,
    required this.height,
    required this.tiles,
    required this.facilities,
    required this.guests,
    required this.staff,
    required this.trash,
    this.level = 1,
    this.exp = 0,
    this.satisfaction = 75,
    this.cleanliness = 90,
    this.memoryScore = 70,
    this.visitorsToday = 0,
    this.incomeToday = 0,
    this.avgWaitSec = 0,
    List<GuestReview>? recentReviews,
  }) : recentReviews = recentReviews ?? <GuestReview>[];

  factory Park.initial() {
    final tiles = List.generate(
      GameConstants.worldHeight,
      (y) => List.generate(
        GameConstants.worldWidth,
        (x) => TileKind.grass,
      ),
    );

    // Mark the entrance tile.
    tiles[GameConstants.entranceY][GameConstants.entranceX] = TileKind.entrance;

    // Lay a starter path strip from entrance going inward, so the very
    // first guest can actually reach a facility the player places nearby.
    for (var y = 1; y <= 4; y++) {
      tiles[y][GameConstants.entranceX] = TileKind.path;
    }

    return Park(
      width: GameConstants.worldWidth,
      height: GameConstants.worldHeight,
      tiles: tiles,
      facilities: {},
      guests: {},
      staff: {},
      trash: {},
    );
  }

  bool inBounds(TileCoord c) =>
      c.x >= 0 && c.x < width && c.y >= 0 && c.y < height;

  TileKind tileAt(TileCoord c) => tiles[c.y][c.x];
  void setTile(TileCoord c, TileKind kind) => tiles[c.y][c.x] = kind;

  bool isWalkable(TileCoord c) {
    if (!inBounds(c)) return false;
    final k = tileAt(c);
    return k == TileKind.path || k == TileKind.entrance;
  }
}

/// A short review left by a guest on exit (per design doc §42, §150.7).
@immutable
class GuestReview {
  final String guestId;
  final GuestType guestType;
  final int memoryScore; // 0..100
  final String text;
  final DateTime at;

  const GuestReview({
    required this.guestId,
    required this.guestType,
    required this.memoryScore,
    required this.text,
    required this.at,
  });
}
