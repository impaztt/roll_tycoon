import '../../park/domain/tile.dart';

/// Staff role (per design doc §16.1). MVP only ships janitor; mechanic in v2.
enum StaffType { janitor }

enum StaffState { idle, movingToTask, working, resting }

class Staff {
  final String id;
  final StaffType type;
  TileCoord position;
  StaffState state;
  String? targetTrashId;
  List<TileCoord> path;
  double workProgressSec;

  Staff({
    required this.id,
    required this.type,
    required this.position,
    this.state = StaffState.idle,
    this.targetTrashId,
    List<TileCoord>? path,
    this.workProgressSec = 0.0,
  }) : path = path ?? const [];

  String get emoji {
    switch (type) {
      case StaffType.janitor:
        return '🧹';
    }
  }

  String get name {
    switch (type) {
      case StaffType.janitor:
        return '청소부';
    }
  }
}
