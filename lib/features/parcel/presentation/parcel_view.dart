import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../construction/application/build_mode_controller.dart';
import '../../country/application/country_controller.dart';
import '../../country/domain/biome.dart';
import '../../park/domain/facility.dart';
import '../../park/domain/facility_catalog.dart';
import '../../park/domain/park.dart';
import '../../park/domain/tile.dart';
import 'iso_projection.dart';
import 'parcel_painter.dart';

/// The view shown after zooming into a parcel — isometric park editor.
class ParcelView extends ConsumerStatefulWidget {
  const ParcelView({super.key});

  @override
  ConsumerState<ParcelView> createState() => _ParcelViewState();
}

class _ParcelViewState extends ConsumerState<ParcelView> {
  Offset _camera = Offset.zero;
  double _scale = 1.0;
  Offset? _gestureFocal;
  Offset? _gestureCamera;
  double? _gestureScale;
  TileCoord? _hover;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(countryControllerProvider);
    final parcel = state.activeParcel;
    if (parcel == null || parcel.park == null) {
      return const SizedBox.shrink();
    }
    final park = parcel.park!;
    final ui = ref.watch(uiControllerProvider);

    final biome = parcel.biome;
    final isValid = _checkValid(park, _hover, ui.selection);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Sky gradient that matches biome
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: biome.parcelSkyGradient,
                ),
              ),
            ),
          ),
          // Cloud silhouettes at the edges (suggests "floating in sky")
          const Positioned.fill(child: _EdgeClouds()),
          // The isometric park
          Positioned.fill(
            child: GestureDetector(
              onScaleStart: (d) {
                _gestureFocal = d.focalPoint;
                _gestureCamera = _camera;
                _gestureScale = _scale;
              },
              onScaleUpdate: (d) {
                setState(() {
                  _scale = (_gestureScale! * d.scale).clamp(0.6, 2.2);
                  final delta = d.focalPoint - _gestureFocal!;
                  _camera = _gestureCamera! + delta;
                });
              },
              onTapUp: (details) =>
                  _handleTap(details.localPosition, park, ui, biome),
              child: CustomPaint(
                painter: ParcelPainter(
                  park: park,
                  biome: biome,
                  selectedFacilityId: ui.selectedFacilityInstanceId,
                  hoveredTile: _hover,
                  buildSelection: ui.selection,
                  isValidPlacement: isValid,
                  cameraOffset: _camera,
                  cameraScale: _scale,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // Top bar — back to globe + currency
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
              child: _ParcelTopBar(
                biomeName: biome.displayName,
                emoji: biome.emoji,
                onBack: () {
                  ref
                      .read(countryControllerProvider.notifier)
                      .leaveParcel();
                  ref.read(uiControllerProvider.notifier).exitBuildMode();
                  ref
                      .read(uiControllerProvider.notifier)
                      .selectPlacedFacility(null);
                },
                coin: state.country.currency.coin,
                heart: state.country.currency.heart,
                memoryScore: state.country.memoryScore.round(),
              ),
            ),
          ),
          // Bottom layer
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _bottomLayer(context, ui),
          ),
        ],
      ),
    );
  }

  Widget _bottomLayer(BuildContext context, UiState ui) {
    if (ui.mode == UiMode.building) return const _BuildPanel();
    if (ui.selectedFacilityInstanceId != null) {
      return _FacilityCard(instanceId: ui.selectedFacilityInstanceId!);
    }
    return const _ParcelMenu();
  }

  void _handleTap(Offset local, Park park, UiState ui, Biome biome) {
    final tile = _screenToTile(local);
    if (tile == null) return;
    if (ui.mode == UiMode.building) {
      final ctrl = ref.read(countryControllerProvider.notifier);
      final uiCtrl = ref.read(uiControllerProvider.notifier);
      final sel = ui.selection;
      if (sel == null) {
        uiCtrl.showMessage('어떤 시설을 지을지 골라주세요.');
        return;
      }
      final r = switch (sel) {
        FacilitySelection(:final master) => ctrl.buildFacility(master, tile),
        PathSelection() => ctrl.buildPath(tile),
        HireJanitorSelection() => ctrl.hireJanitor(),
        DemolishSelection() => _demolish(park, tile, ctrl),
      };
      if (!r.success && r.failureReason != null) {
        uiCtrl.showMessage(r.failureReason!);
      } else if (sel is FacilitySelection) {
        uiCtrl.showMessage('${sel.master.name} 설치 완료!');
      } else if (sel is HireJanitorSelection) {
        uiCtrl.showMessage('청소부를 고용했어요.');
      } else if (sel is DemolishSelection && r.success) {
        uiCtrl.showMessage('철거했어요. 절반의 코인을 돌려받았어요.');
      }
      return;
    }
    final fid = _facilityAt(park, tile);
    ref.read(uiControllerProvider.notifier).selectPlacedFacility(fid);
  }

  BuildResult _demolish(
      Park park, TileCoord tile, CountryController ctrl) {
    final fid = _facilityAt(park, tile);
    if (fid == null) return const BuildResult.fail('철거할 시설이 없어요.');
    ctrl.demolishFacility(fid);
    return const BuildResult.ok();
  }

  String? _facilityAt(Park park, TileCoord tile) {
    for (final f in park.facilities.values) {
      for (final c in f.tiles()) {
        if (c == tile) return f.instanceId;
      }
    }
    return null;
  }

  /// Reverse-projection: screen → grid tile, accounting for camera & scale.
  TileCoord? _screenToTile(Offset screenLocal) {
    final size = MediaQuery.of(context).size;
    final originX = size.width / 2 + _camera.dx;
    final originY = size.height * 0.30 + _camera.dy;
    final adjusted = Offset(
      (screenLocal.dx - originX) / _scale,
      (screenLocal.dy - originY) / _scale,
    );
    final grid = IsoProjection.unproject(adjusted);
    final gx = grid.dx.floor();
    final gy = grid.dy.floor();
    return TileCoord(gx, gy);
  }

  bool _checkValid(Park park, TileCoord? tile, BuildSelection? sel) {
    if (tile == null || sel == null) return true;
    if (sel is FacilitySelection) {
      for (var dy = 0; dy < sel.master.sizeY; dy++) {
        for (var dx = 0; dx < sel.master.sizeX; dx++) {
          final c = TileCoord(tile.x + dx, tile.y + dy);
          if (!park.inBounds(c)) return false;
          if (park.tileAt(c) != TileKind.grass) return false;
        }
      }
    }
    if (sel is PathSelection) {
      if (!park.inBounds(tile)) return false;
      if (park.tileAt(tile) != TileKind.grass) return false;
    }
    return true;
  }
}

class _EdgeClouds extends StatelessWidget {
  const _EdgeClouds();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _CloudPainter()),
    );
  }
}

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    // Soft horizon clouds
    canvas.drawOval(
      Rect.fromLTWH(-60, size.height * 0.65, size.width + 120, 80),
      p,
    );
    canvas.drawOval(
      Rect.fromLTWH(-40, size.height * 0.78, size.width + 80, 100),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ParcelTopBar extends StatelessWidget {
  final String biomeName;
  final String emoji;
  final VoidCallback onBack;
  final int coin;
  final int heart;
  final int memoryScore;
  const _ParcelTopBar({
    required this.biomeName,
    required this.emoji,
    required this.onBack,
    required this.coin,
    required this.heart,
    required this.memoryScore,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.public),
          tooltip: '행성으로',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(biomeName,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: PastelColors.textPrimary)),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              _pill('🪙', coin),
              const SizedBox(width: 8),
              _pill('💖', heart),
              const SizedBox(width: 8),
              _pill('✨', memoryScore),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill(String emoji, int value) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 3),
      Text(_fmt(value),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PastelColors.textPrimary)),
    ]);
  }

  static String _fmt(int n) {
    if (n < 1000) return n.toString();
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }
}

class _ParcelMenu extends ConsumerWidget {
  const _ParcelMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiCtrl = ref.read(uiControllerProvider.notifier);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _menuBtn('🛠️', '건설', uiCtrl.enterBuildMode),
                  _menuBtn('📊', '리포트', () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const _ParkReportScreen(),
                    ));
                  }),
                  _menuBtn('🏦', '은행', () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      duration: Duration(seconds: 1),
                      content: Text('은행은 v1에서 열려요.'),
                    ));
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuBtn(String emoji, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: PastelColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _BuildPanel extends ConsumerWidget {
  const _BuildPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(uiControllerProvider);
    final ctrl = ref.read(uiControllerProvider.notifier);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text('🛠️ 건설 모드',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: ctrl.exitBuildMode,
                    child: const Text('완료'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 86,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _BuildItem(
                      emoji: '🟫',
                      label: '길',
                      cost: 25,
                      selected: ui.selection is PathSelection,
                      onTap: ctrl.selectPath,
                    ),
                    for (final m in FacilityCatalog.all)
                      _BuildItem(
                        emoji: m.emoji,
                        label: m.name,
                        cost: m.buildCost,
                        selected: ui.selection is FacilitySelection &&
                            (ui.selection as FacilitySelection).master.id ==
                                m.id,
                        onTap: () => ctrl.selectFacilityToBuild(m),
                      ),
                    _BuildItem(
                      emoji: '🧹',
                      label: '청소부\n고용',
                      cost: 200,
                      selected: ui.selection is HireJanitorSelection,
                      onTap: ctrl.selectHireJanitor,
                    ),
                    _BuildItem(
                      emoji: '🧨',
                      label: '철거',
                      cost: 0,
                      selected: ui.selection is DemolishSelection,
                      onTap: ctrl.selectDemolish,
                      destructive: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildItem extends StatelessWidget {
  final String emoji;
  final String label;
  final int cost;
  final bool selected;
  final VoidCallback onTap;
  final bool destructive;
  const _BuildItem({
    required this.emoji,
    required this.label,
    required this.cost,
    required this.selected,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (destructive ? PastelColors.danger : PastelColors.primary)
            .withValues(alpha: 0.4)
        : PastelColors.surfaceMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 76,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: PastelColors.textPrimary)),
              if (cost > 0)
                Text('🪙$cost',
                    style: const TextStyle(
                        fontSize: 9, color: PastelColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FacilityCard extends ConsumerWidget {
  final String instanceId;
  const _FacilityCard({required this.instanceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(countryControllerProvider);
    final ctrl = ref.read(countryControllerProvider.notifier);
    final uiCtrl = ref.read(uiControllerProvider.notifier);
    final park = state.activeParcel?.park;
    if (park == null) return const SizedBox.shrink();
    final f = park.facilities[instanceId];
    if (f == null) return const SizedBox.shrink();
    final waiting = park.guests.values
        .where((g) => g.targetFacilityId == instanceId)
        .length;
    final upgradeCost = ctrl.upgradeCost(f);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFD8A8),
                          Color(0xFFFFB5A7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(f.master.emoji,
                          style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.master.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        Text(
                            'Lv.${f.level}  ·  ${_statusText(f.status)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: PastelColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => uiCtrl.selectPlacedFacility(null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _statRow('오늘 매출', '🪙${f.incomeToday}'),
              _statRow('오늘 탑승', '${f.totalRidesToday}회'),
              _statRow('대기 손님', '$waiting명'),
              _statRow('1회 가격', '🪙${f.effectivePricePerRide.round()}'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: PastelColors.primary,
                        foregroundColor: PastelColors.textPrimary,
                      ),
                      onPressed: () {
                        final r = ctrl.upgradeFacility(instanceId);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          duration: const Duration(seconds: 1),
                          content: Text(r.success
                              ? '업그레이드 완료! Lv.${f.level}'
                              : r.failureReason ?? '실패'),
                        ));
                      },
                      child: Text('업그레이드  🪙$upgradeCost'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor:
                          PastelColors.danger.withValues(alpha: 0.6),
                    ),
                    onPressed: () {
                      ctrl.demolishFacility(instanceId);
                      uiCtrl.selectPlacedFacility(null);
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: PastelColors.textSecondary)),
            Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PastelColors.textPrimary)),
          ],
        ),
      );

  String _statusText(FacilityStatus s) => switch (s) {
        FacilityStatus.operating => '운영 중',
        FacilityStatus.needsPath => '길 연결 필요',
        FacilityStatus.paused => '일시정지',
        FacilityStatus.broken => '고장',
      };
}

/// Inline report screen for the active parcel.
class _ParkReportScreen extends ConsumerWidget {
  const _ParkReportScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(countryControllerProvider);
    final park = state.activeParcel?.park;
    if (park == null) {
      return const Scaffold(body: Center(child: Text('땅을 먼저 선택해주세요.')));
    }
    return Scaffold(
      backgroundColor: PastelColors.background,
      appBar: AppBar(title: const Text('이 땅의 리포트')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard(park),
          const SizedBox(height: 12),
          _statGrid(park),
          const SizedBox(height: 16),
          const Text('최근 손님 리뷰',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (park.recentReviews.isEmpty)
            const _SoftCard(
                child: Text('아직 손님이 없어요. 시설을 짓고 길로 연결해보세요.'))
          else
            ...park.recentReviews.take(8).map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.text,
                              style: const TextStyle(fontSize: 13)),
                          Text('추억 ${r.memoryScore}점',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: PastelColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _summaryCard(Park park) {
    final summary = _oneLine(park);
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('한 줄 요약',
              style: TextStyle(
                  fontSize: 11, color: PastelColors.textSecondary)),
          const SizedBox(height: 6),
          Text(summary,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: PastelColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _statGrid(Park park) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.7,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _bigStat('방문객', '${park.visitorsToday}명', PastelColors.info),
        _bigStat('오늘 매출', '🪙${park.incomeToday}', PastelColors.premium),
        _bigStat('만족도', '${park.satisfaction.round()}점',
            _grade(park.satisfaction)),
        _bigStat('청결도', '${park.cleanliness.round()}점',
            _grade(park.cleanliness)),
        _bigStat('추억 점수', '${park.memoryScore.round()}점',
            PastelColors.secondary),
        _bigStat(
            '평균 대기',
            park.avgWaitSec < 60
                ? '${park.avgWaitSec.round()}초'
                : '${(park.avgWaitSec / 60).toStringAsFixed(1)}분',
            _waitColor(park.avgWaitSec)),
      ],
    );
  }

  Widget _bigStat(String label, String value, Color color) => _SoftCard(
        color: color.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: PastelColors.textSecondary)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: PastelColors.textPrimary)),
          ],
        ),
      );

  String _oneLine(Park park) {
    if (park.facilities.isEmpty) return '아직 시설이 없어요. 회전목마부터 지어볼까요?';
    if (park.visitorsToday == 0) return '시설을 길과 연결하면 손님이 와요.';
    if (park.satisfaction >= 80 && park.cleanliness >= 75) {
      return '오늘 손님들이 정말 즐거워했어요!';
    }
    if (park.cleanliness < 60) return '쓰레기가 쌓여 청결도가 떨어졌어요.';
    if (park.avgWaitSec > 60) return '대기열이 길어요. 비슷한 시설을 추가해보세요.';
    return '공원이 자라고 있어요.';
  }

  Color _grade(double v) => v >= 80
      ? PastelColors.success
      : v >= 60
          ? PastelColors.info
          : v >= 40
              ? PastelColors.warning
              : PastelColors.danger;

  Color _waitColor(double s) => s < 30
      ? PastelColors.success
      : s < 90
          ? PastelColors.warning
          : PastelColors.danger;
}

class _SoftCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  const _SoftCard({required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
