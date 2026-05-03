import 'dart:collection';

import '../domain/park.dart';
import '../domain/tile.dart';

/// Breadth-first search over walkable (path/entrance) tiles.
///
/// Returns the tiles to walk through to reach `goal` from `start`,
/// excluding `start` itself. Returns null if unreachable.
///
/// MVP uses BFS — fine for a 20x20 grid. We'll switch to A* with caching
/// when the grid expands or thousands of guests path each tick.
class Pathfinder {
  static const _neighbors = <TileCoord>[
    TileCoord(0, 1),
    TileCoord(0, -1),
    TileCoord(1, 0),
    TileCoord(-1, 0),
  ];

  /// Path from start to a goal cell. The goal itself need not be walkable —
  /// guests "arrive" by stepping onto an adjacent walkable tile, then
  /// magically enter. This matches §149.3: facilities have one entrance
  /// tile that connects to a path.
  static List<TileCoord>? findPath(
    Park park,
    TileCoord start,
    TileCoord goal,
  ) {
    if (start == goal) return const [];

    final visited = <TileCoord>{start};
    final cameFrom = <TileCoord, TileCoord>{};
    final queue = Queue<TileCoord>()..add(start);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current == goal) {
        return _reconstruct(cameFrom, current);
      }

      for (final delta in _neighbors) {
        final next = current + delta;
        if (visited.contains(next)) continue;
        if (!park.isWalkable(next) && next != goal) continue;
        visited.add(next);
        cameFrom[next] = current;
        queue.add(next);
      }
    }
    return null;
  }

  static List<TileCoord> _reconstruct(
    Map<TileCoord, TileCoord> cameFrom,
    TileCoord goal,
  ) {
    final path = <TileCoord>[];
    var cursor = goal;
    while (cameFrom.containsKey(cursor)) {
      path.add(cursor);
      cursor = cameFrom[cursor]!;
    }
    return path.reversed.toList();
  }
}
