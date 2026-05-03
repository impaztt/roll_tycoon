import 'package:flutter/foundation.dart';

import '../../park/domain/tile.dart';

/// Guest archetype (per design doc §15.1, §164.3).
/// MVP ships 3 types; design doc has 8.
enum GuestType { general, family, teen }

/// State machine (per design doc §150.2).
enum GuestState {
  entering,
  walking, // moving toward currentTarget
  queuing,
  riding,
  resting,
  leaving,
  gone, // ready to be cleaned up
}

/// Mood — surfaces as the head-icon (per design doc §126.2).
enum GuestMood { happy, neutral, hungry, tired, frustrated, dirty, photo }

/// A guest in the park.
///
/// MVP keeps things simple — desires are summarized into a single mood/target,
/// not the 9-axis system in §15.2 (that's for v1+).
class Guest {
  final String id;
  final GuestType type;
  TileCoord position; // current tile
  GuestState state;
  GuestMood mood;
  String? targetFacilityId; // facility instanceId being walked to / queued at
  List<TileCoord> path; // remaining waypoints
  double waitTimeSec; // accumulated time in current state
  double rideProgressSec;
  int spentCoin;
  int satisfaction; // 0-100, evolves through visit
  double waitToleranceSec; // how long they'll queue before giving up

  Guest({
    required this.id,
    required this.type,
    required this.position,
    this.state = GuestState.entering,
    this.mood = GuestMood.neutral,
    this.targetFacilityId,
    List<TileCoord>? path,
    this.waitTimeSec = 0.0,
    this.rideProgressSec = 0.0,
    this.spentCoin = 0,
    this.satisfaction = 75,
    double? waitToleranceSec,
  })  : path = path ?? const [],
        waitToleranceSec = waitToleranceSec ?? _toleranceFor(type);

  static double _toleranceFor(GuestType type) {
    // Per design doc §149.5 wait tolerance table.
    switch (type) {
      case GuestType.family:
        return 300; // 5 min
      case GuestType.teen:
        return 360; // 6 min
      case GuestType.general:
        return 240; // 4 min
    }
  }

  String get emoji {
    switch (type) {
      case GuestType.family:
        return '👨‍👩‍👧';
      case GuestType.teen:
        return '🧑‍🎤';
      case GuestType.general:
        return '🧍';
    }
  }
}

/// One unit of trash on a tile.
@immutable
class Trash {
  final String id;
  final TileCoord position;
  const Trash({required this.id, required this.position});
}
