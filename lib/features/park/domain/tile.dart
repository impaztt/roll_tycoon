import 'package:flutter/foundation.dart';

/// Grid coordinate (per design doc §13.2 grid-based placement).
@immutable
class TileCoord {
  final int x;
  final int y;
  const TileCoord(this.x, this.y);

  TileCoord operator +(TileCoord other) => TileCoord(x + other.x, y + other.y);

  double distanceTo(TileCoord other) {
    final dx = (x - other.x).toDouble();
    final dy = (y - other.y).toDouble();
    return (dx * dx + dy * dy);
  }

  int manhattanTo(TileCoord other) =>
      (x - other.x).abs() + (y - other.y).abs();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TileCoord && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x,$y)';
}

/// What occupies a tile. Path tiles are walkable, facility tiles aren't,
/// but each facility has an entrance tile that connects to a path.
enum TileKind { grass, path, facility, entrance }
