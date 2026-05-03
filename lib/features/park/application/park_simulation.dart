import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../../core/constants/game_constants.dart';
import '../../economy/domain/currency.dart';
import '../../guest/domain/guest.dart';
import '../../staff/domain/staff.dart';
import '../domain/facility.dart';
import '../domain/park.dart';
import '../domain/tile.dart';
import 'pathfinding.dart';

/// Result returned from a single simulation tick.
class TickResult {
  final Currency currency;
  final List<GuestReview> newReviews;
  TickResult(this.currency, this.newReviews);
}

/// Mutates the park in place and returns updated currency.
///
/// One tick = GameConstants.tickSeconds of in-game time.
/// All time-based math uses tickSeconds, not real seconds — this lets
/// us speed up / slow down the simulation later without breaking balance.
class ParkSimulation {
  ParkSimulation({Random? random}) : _random = random ?? Random();

  final Random _random;
  final _uuid = const Uuid();
  double _spawnAccumulator = 0;
  double _trashAccumulator = 0;

  TickResult tick(Park park, Currency currency) {
    var money = currency;
    final reviews = <GuestReview>[];

    money = _payMaintenance(park, money);
    _maybeSpawnGuest(park);
    _maybeSpawnTrash(park);

    money = _stepFacilities(park, money);
    _stepGuests(park, reviews);
    _stepStaff(park);
    _updateAggregates(park);

    return TickResult(money, reviews);
  }

  // ---------- Guests ----------

  void _maybeSpawnGuest(Park park) {
    _spawnAccumulator += GameConstants.tickSeconds;
    final attractions = park.facilities.values
        .where((f) => f.master.category == FacilityCategory.attraction)
        .toList();
    if (attractions.isEmpty) return;
    if (park.guests.length >= GameConstants.maxConcurrentGuests) return;

    // Spawn rate scales with park reputation/level — MVP just uses a constant.
    while (_spawnAccumulator >= GameConstants.guestSpawnIntervalSeconds) {
      _spawnAccumulator -= GameConstants.guestSpawnIntervalSeconds;
      _spawnGuest(park);
    }
  }

  void _spawnGuest(Park park) {
    final entrance =
        TileCoord(GameConstants.entranceX, GameConstants.entranceY);
    final type = _pickGuestType();
    final guest = Guest(
      id: _uuid.v4(),
      type: type,
      position: entrance,
      state: GuestState.entering,
    );
    park.guests[guest.id] = guest;
  }

  GuestType _pickGuestType() {
    final roll = _random.nextDouble();
    if (roll < 0.45) return GuestType.general;
    if (roll < 0.80) return GuestType.family;
    return GuestType.teen;
  }

  void _stepGuests(Park park, List<GuestReview> reviews) {
    final removed = <String>[];

    for (final guest in park.guests.values) {
      switch (guest.state) {
        case GuestState.entering:
          _decideTarget(park, guest);
          break;
        case GuestState.walking:
          _walkOneStep(park, guest);
          break;
        case GuestState.queuing:
          _queueTick(park, guest);
          break;
        case GuestState.riding:
          // Ride progress is owned by the facility, which evicts riders.
          break;
        case GuestState.resting:
          guest.waitTimeSec += GameConstants.tickSeconds;
          if (guest.waitTimeSec > 4) {
            _decideTarget(park, guest);
          }
          break;
        case GuestState.leaving:
          _walkOneStep(park, guest);
          if (guest.position ==
              TileCoord(GameConstants.entranceX, GameConstants.entranceY)) {
            reviews.add(_emitReview(guest));
            guest.state = GuestState.gone;
          }
          break;
        case GuestState.gone:
          removed.add(guest.id);
          break;
      }
    }

    for (final id in removed) {
      park.guests.remove(id);
    }
  }

  void _decideTarget(Park park, Guest guest) {
    // MVP: pick a random open attraction or shop the guest can reach.
    final candidates = park.facilities.values
        .where((f) =>
            f.status == FacilityStatus.operating &&
            (f.master.category == FacilityCategory.attraction ||
                f.master.category == FacilityCategory.shop))
        .toList();

    candidates.shuffle(_random);

    for (final f in candidates) {
      final entrance = f.entranceTile();
      if (!park.isWalkable(entrance)) continue;
      final start = guest.state == GuestState.entering
          ? TileCoord(GameConstants.entranceX, GameConstants.entranceY)
          : guest.position;
      final path = Pathfinder.findPath(park, start, entrance);
      if (path == null) continue;
      guest.targetFacilityId = f.instanceId;
      guest.path = path;
      guest.state = GuestState.walking;
      guest.waitTimeSec = 0;
      return;
    }

    // No reachable facility — head home.
    _sendHome(park, guest);
  }

  void _walkOneStep(Park park, Guest guest) {
    if (guest.path.isEmpty) {
      _arriveAtTarget(park, guest);
      return;
    }
    // One tile per tick — guests move at ~5 tiles/sec at 200ms ticks.
    guest.position = guest.path.removeAt(0);
    if (guest.path.isEmpty) {
      _arriveAtTarget(park, guest);
    }
  }

  void _arriveAtTarget(Park park, Guest guest) {
    if (guest.state == GuestState.leaving) return;
    final target = guest.targetFacilityId;
    if (target == null) {
      _sendHome(park, guest);
      return;
    }
    final facility = park.facilities[target];
    if (facility == null || facility.status != FacilityStatus.operating) {
      _sendHome(park, guest);
      return;
    }
    guest.state = GuestState.queuing;
    guest.waitTimeSec = 0;
  }

  void _queueTick(Park park, Guest guest) {
    final facility = park.facilities[guest.targetFacilityId];
    if (facility == null) {
      _sendHome(park, guest);
      return;
    }
    guest.waitTimeSec += GameConstants.tickSeconds;
    if (guest.waitTimeSec > guest.waitToleranceSec) {
      // Gave up. Slight satisfaction hit.
      guest.satisfaction = (guest.satisfaction - 15).clamp(0, 100);
      guest.mood = GuestMood.frustrated;
      _sendHome(park, guest);
    }
    // Boarding handled in _stepFacilities so capacity is checked centrally.
  }

  void _sendHome(Park park, Guest guest) {
    final entrance =
        TileCoord(GameConstants.entranceX, GameConstants.entranceY);
    final path = Pathfinder.findPath(park, guest.position, entrance);
    guest.path = path ?? const [];
    guest.targetFacilityId = null;
    guest.state = GuestState.leaving;
  }

  GuestReview _emitReview(Guest guest) {
    // §150.6 — memory score combines satisfaction and what they did.
    final score = guest.satisfaction;
    final text = _reviewTextFor(guest);
    return GuestReview(
      guestId: guest.id,
      guestType: guest.type,
      memoryScore: score,
      text: text,
      at: DateTime.now(),
    );
  }

  String _reviewTextFor(Guest guest) {
    if (guest.satisfaction >= 85) {
      return '오늘 정말 즐거웠어요. 또 올게요!';
    }
    if (guest.mood == GuestMood.frustrated) {
      return '줄이 너무 길어서 포기했어요.';
    }
    if (guest.satisfaction >= 60) {
      return '괜찮은 하루였어요.';
    }
    return '뭔가 아쉬웠어요.';
  }

  // ---------- Facilities ----------

  Currency _stepFacilities(Park park, Currency money) {
    var coinDelta = 0;

    for (final f in park.facilities.values) {
      // Connectivity check — flips status to needsPath if the entrance
      // is no longer adjacent to a walkable tile.
      _refreshFacilityStatus(park, f);

      if (f.status != FacilityStatus.operating) continue;

      if (f.master.category == FacilityCategory.attraction ||
          f.master.category == FacilityCategory.shop) {
        // Board waiting guests up to capacity.
        final boarders = park.guests.values
            .where((g) =>
                g.state == GuestState.queuing &&
                g.targetFacilityId == f.instanceId)
            .take(f.master.capacity - f.riders)
            .toList();
        for (final g in boarders) {
          g.state = GuestState.riding;
          g.rideProgressSec = 0;
          f.riders += 1;
        }

        if (f.riders > 0) {
          f.cycleProgressSec += GameConstants.tickSeconds;
          if (f.cycleProgressSec >= f.master.cycleTimeSec) {
            // Cycle complete — discharge riders, take payment, generate XP.
            final price = f.effectivePricePerRide.round();
            final earned = price * f.riders;
            f.incomeToday += earned;
            f.totalRidesToday += f.riders;
            coinDelta += earned;

            final ridersList = park.guests.values
                .where((g) =>
                    g.state == GuestState.riding &&
                    g.targetFacilityId == f.instanceId)
                .toList();
            for (final g in ridersList) {
              g.spentCoin += price;
              g.state = GuestState.resting;
              g.waitTimeSec = 0;
              g.mood = GuestMood.happy;
              // Excitement boosts satisfaction lightly.
              g.satisfaction =
                  (g.satisfaction + (f.master.excitement / 10)).clamp(0, 100).round();
            }
            f.riders = 0;
            f.cycleProgressSec = 0;
          }
        }
      }
    }
    return money.addCoin(coinDelta);
  }

  Currency _payMaintenance(Park park, Currency money) {
    var costPerTick = 0.0;
    for (final f in park.facilities.values) {
      // maintenancePerMin → per tick: divide by 60, multiply by tickSeconds.
      costPerTick += f.master.maintenancePerMin / 60 * GameConstants.tickSeconds;
    }
    if (costPerTick <= 0) return money;
    final rounded = costPerTick.round();
    if (rounded <= 0) return money; // accumulate for later if subtick
    return money.copyWith(coin: (money.coin - rounded).clamp(0, 1 << 30));
  }

  void _refreshFacilityStatus(Park park, PlacedFacility f) {
    if (f.status == FacilityStatus.broken) return;
    final entrance = f.entranceTile();
    final connected = park.isWalkable(entrance) ||
        _hasWalkableNeighbor(park, entrance);
    f.status = connected ? FacilityStatus.operating : FacilityStatus.needsPath;
  }

  bool _hasWalkableNeighbor(Park park, TileCoord c) {
    const deltas = [
      TileCoord(0, 1),
      TileCoord(0, -1),
      TileCoord(1, 0),
      TileCoord(-1, 0),
    ];
    for (final d in deltas) {
      if (park.isWalkable(c + d)) return true;
    }
    return false;
  }

  // ---------- Trash & cleanliness ----------

  void _maybeSpawnTrash(Park park) {
    final shops = park.facilities.values
        .where((f) => f.master.generatesTrash)
        .toList();
    if (shops.isEmpty) return;

    _trashAccumulator += shops.length *
        GameConstants.trashSpawnPerShopPerSecond *
        GameConstants.tickSeconds;

    while (_trashAccumulator >= 1.0) {
      _trashAccumulator -= 1.0;
      final shop = shops[_random.nextInt(shops.length)];
      final spawn = TileCoord(shop.origin.x, shop.origin.y - 1);
      if (!park.inBounds(spawn)) continue;
      final id = _uuid.v4();
      park.trash[id] = Trash(id: id, position: spawn);
      // Cleanliness drops a little per piece of trash.
      park.cleanliness =
          (park.cleanliness - GameConstants.trashCleanlinessImpact)
              .clamp(0, 100);
    }
  }

  // ---------- Staff ----------

  void _stepStaff(Park park) {
    for (final s in park.staff.values) {
      switch (s.state) {
        case StaffState.idle:
          _assignTrashTo(park, s);
          break;
        case StaffState.movingToTask:
          if (s.path.isEmpty) {
            s.state = StaffState.working;
            s.workProgressSec = 0;
            break;
          }
          s.position = s.path.removeAt(0);
          if (s.path.isEmpty) {
            s.state = StaffState.working;
            s.workProgressSec = 0;
          }
          break;
        case StaffState.working:
          s.workProgressSec += GameConstants.tickSeconds;
          if (s.workProgressSec >= 1.0) {
            final tid = s.targetTrashId;
            if (tid != null && park.trash.remove(tid) != null) {
              park.cleanliness =
                  (park.cleanliness + GameConstants.trashCleanlinessImpact)
                      .clamp(0, 100);
            }
            s.targetTrashId = null;
            s.state = StaffState.idle;
          }
          break;
        case StaffState.resting:
          break;
      }
    }
  }

  void _assignTrashTo(Park park, Staff s) {
    if (park.trash.isEmpty) return;
    // Closest trash by manhattan distance.
    Trash? best;
    int bestDist = 1 << 30;
    for (final t in park.trash.values) {
      final d = s.position.manhattanTo(t.position);
      if (d < bestDist) {
        bestDist = d;
        best = t;
      }
    }
    if (best == null) return;
    final path = Pathfinder.findPath(park, s.position, best.position);
    if (path == null) return;
    s.targetTrashId = best.id;
    s.path = path;
    s.state = StaffState.movingToTask;
  }

  // ---------- Aggregates ----------

  void _updateAggregates(Park park) {
    if (park.guests.isEmpty) return;
    var sum = 0;
    var count = 0;
    var waitSum = 0.0;
    for (final g in park.guests.values) {
      sum += g.satisfaction;
      count += 1;
      if (g.state == GuestState.queuing) waitSum += g.waitTimeSec;
    }
    if (count > 0) {
      park.satisfaction = sum / count;
      park.avgWaitSec = waitSum / count;
    }
  }
}
