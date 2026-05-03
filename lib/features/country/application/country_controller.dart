import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/game_constants.dart';
import '../../economy/domain/currency.dart';
import '../../park/application/park_simulation.dart';
import '../../park/domain/facility.dart';
import '../../park/domain/park.dart';
import '../../park/domain/tile.dart';
import '../../staff/domain/staff.dart';
import '../domain/country.dart';
import '../domain/parcel.dart';

/// Top-level state — the player's country (planet) plus camera/UX state.
class CountryState {
  final Country country;
  final String? activeParcelId; // null when looking at the globe
  final int tickCounter;
  final String? toast;
  CountryState({
    required this.country,
    this.activeParcelId,
    this.tickCounter = 0,
    this.toast,
  });

  CountryState copyWith({
    Country? country,
    String? activeParcelId,
    bool clearActiveParcel = false,
    int? tickCounter,
    String? toast,
    bool clearToast = false,
  }) =>
      CountryState(
        country: country ?? this.country,
        activeParcelId:
            clearActiveParcel ? null : (activeParcelId ?? this.activeParcelId),
        tickCounter: tickCounter ?? this.tickCounter,
        toast: clearToast ? null : (toast ?? this.toast),
      );

  Parcel? get activeParcel {
    if (activeParcelId == null) return null;
    for (final p in country.parcels) {
      if (p.id == activeParcelId) return p;
    }
    return null;
  }
}

class BuildResult {
  final bool success;
  final String? failureReason;
  const BuildResult.ok()
      : success = true,
        failureReason = null;
  const BuildResult.fail(this.failureReason) : success = false;
}

class CountryController extends StateNotifier<CountryState> {
  CountryController()
      : super(CountryState(country: Country.fresh())) {
    _start();
  }

  final ParkSimulation _sim = ParkSimulation();
  final _uuid = const Uuid();
  Timer? _ticker;

  void _start() {
    _ticker = Timer.periodic(GameConstants.tickInterval, (_) => _tick());
  }

  void _tick() {
    var currency = state.country.currency;
    var memorySum = 0.0;
    var memoryCount = 0;

    for (final parcel in state.country.owned) {
      final park = parcel.park;
      if (park == null) continue;
      final result = _sim.tick(park, currency);
      currency = result.currency;
      if (result.newReviews.isNotEmpty) {
        park.recentReviews.insertAll(0, result.newReviews);
        if (park.recentReviews.length > 20) {
          park.recentReviews.removeRange(20, park.recentReviews.length);
        }
        park.visitorsToday += result.newReviews.length;
        final ms = result.newReviews
            .map((r) => r.memoryScore)
            .reduce((a, b) => a + b)
            .toDouble() /
            result.newReviews.length;
        park.memoryScore = (park.memoryScore * 0.9) + (ms * 0.1);
      }
      memorySum += park.memoryScore;
      memoryCount += 1;
    }

    if (memoryCount > 0) {
      state.country.memoryScore = memorySum / memoryCount;
    }
    state.country.currency = currency;
    state = state.copyWith(tickCounter: state.tickCounter + 1);
  }

  // ---------- Globe navigation ----------

  /// Enter a parcel — creates the embedded park lazily on first entry.
  void enterParcel(String parcelId) {
    final parcel = state.country.parcels.firstWhere((p) => p.id == parcelId);
    if (!parcel.isOwned) {
      _toast('아직 소유한 땅이 아니에요.');
      return;
    }
    parcel.park ??= Park.initial();
    state = state.copyWith(activeParcelId: parcelId);
  }

  void leaveParcel() {
    state = state.copyWith(clearActiveParcel: true);
  }

  /// Buy the next parcel. Cost grows per [parcelCostFor].
  BuildResult buyParcel(String parcelId) {
    final country = state.country;
    final parcel = country.parcels.firstWhere((p) => p.id == parcelId);
    if (parcel.isOwned) return const BuildResult.fail('이미 가진 땅이에요.');

    final cost = country.nextParcelCost;
    final spent = country.currency.spendCoin(cost);
    if (spent == null) {
      return BuildResult.fail('$cost코인이 필요해요.');
    }
    country.currency = spent;
    parcel.isOwned = true;
    parcel.park = Park.initial();
    state = state.copyWith(tickCounter: state.tickCounter + 1);
    return const BuildResult.ok();
  }

  // ---------- Inside a parcel ----------

  Park? get _activePark => state.activeParcel?.park;

  BuildResult buildFacility(FacilityMaster master, TileCoord origin) {
    final park = _activePark;
    if (park == null) return const BuildResult.fail('먼저 땅을 선택하세요.');

    for (var dy = 0; dy < master.sizeY; dy++) {
      for (var dx = 0; dx < master.sizeX; dx++) {
        final c = TileCoord(origin.x + dx, origin.y + dy);
        if (!park.inBounds(c)) {
          return const BuildResult.fail('이 공간에는 시설이 들어가기 어려워요.');
        }
        if (park.tileAt(c) != TileKind.grass) {
          return const BuildResult.fail('이미 다른 시설이 있어요.');
        }
      }
    }

    final spent = state.country.currency.spendCoin(master.buildCost);
    if (spent == null) return const BuildResult.fail('코인이 부족해요.');

    for (var dy = 0; dy < master.sizeY; dy++) {
      for (var dx = 0; dx < master.sizeX; dx++) {
        park.setTile(
            TileCoord(origin.x + dx, origin.y + dy), TileKind.facility);
      }
    }
    final placed = PlacedFacility(
      instanceId: _uuid.v4(),
      master: master,
      origin: origin,
    );
    park.facilities[placed.instanceId] = placed;

    state.country.currency = spent;
    state = state.copyWith(tickCounter: state.tickCounter + 1);
    return const BuildResult.ok();
  }

  BuildResult buildPath(TileCoord at) {
    final park = _activePark;
    if (park == null) return const BuildResult.fail('먼저 땅을 선택하세요.');
    if (!park.inBounds(at)) {
      return const BuildResult.fail('이 공간에는 길을 놓을 수 없어요.');
    }
    final kind = park.tileAt(at);
    if (kind == TileKind.path || kind == TileKind.entrance) {
      return const BuildResult.fail('이미 길이에요.');
    }
    if (kind != TileKind.grass) {
      return const BuildResult.fail('시설 위에는 길을 놓을 수 없어요.');
    }
    const pathCost = 25;
    final spent = state.country.currency.spendCoin(pathCost);
    if (spent == null) return const BuildResult.fail('코인이 부족해요.');
    park.setTile(at, TileKind.path);
    state.country.currency = spent;
    state = state.copyWith(tickCounter: state.tickCounter + 1);
    return const BuildResult.ok();
  }

  BuildResult hireJanitor() {
    final park = _activePark;
    if (park == null) return const BuildResult.fail('먼저 땅을 선택하세요.');
    const cost = 200;
    final spent = state.country.currency.spendCoin(cost);
    if (spent == null) return const BuildResult.fail('코인이 부족해요.');
    final s = Staff(
      id: _uuid.v4(),
      type: StaffType.janitor,
      position: TileCoord(GameConstants.entranceX, GameConstants.entranceY + 1),
    );
    park.staff[s.id] = s;
    state.country.currency = spent;
    state = state.copyWith(tickCounter: state.tickCounter + 1);
    return const BuildResult.ok();
  }

  void demolishFacility(String instanceId) {
    final park = _activePark;
    if (park == null) return;
    final f = park.facilities.remove(instanceId);
    if (f == null) return;
    for (final c in f.tiles()) {
      park.setTile(c, TileKind.grass);
    }
    final refund = (f.master.buildCost ~/ 2);
    state.country.currency = state.country.currency.addCoin(refund);
    state = state.copyWith(tickCounter: state.tickCounter + 1);
  }

  BuildResult upgradeFacility(String instanceId) {
    final park = _activePark;
    if (park == null) return const BuildResult.fail('먼저 땅을 선택하세요.');
    final f = park.facilities[instanceId];
    if (f == null) return const BuildResult.fail('시설을 찾을 수 없어요.');
    final cost = upgradeCost(f);
    final spent = state.country.currency.spendCoin(cost);
    if (spent == null) return const BuildResult.fail('코인이 부족해요.');
    f.level += 1;
    state.country.currency = spent;
    state = state.copyWith(tickCounter: state.tickCounter + 1);
    return const BuildResult.ok();
  }

  int upgradeCost(PlacedFacility f) {
    var v = 1.0;
    for (var i = 0; i < f.level; i++) {
      v *= 1.45;
    }
    return (f.master.buildCost * 0.6 * v).round();
  }

  // ---------- UX ----------

  void _toast(String msg) {
    state = state.copyWith(toast: msg);
  }

  void showToast(String msg) => _toast(msg);

  void dismissToast() {
    state = state.copyWith(clearToast: true);
  }

  Currency get currency => state.country.currency;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final countryControllerProvider =
    StateNotifierProvider<CountryController, CountryState>(
  (ref) => CountryController(),
);
