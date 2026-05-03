import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/pastel_card.dart';
import '../../country/application/country_controller.dart';
import '../../country/domain/biome.dart';
import '../../country/domain/parcel.dart';
import 'globe_painter.dart' show GlobePainter, ParcelHit;
import 'starfield.dart';

/// The home screen — a rotating planet of parcels.
///
/// Drag to spin, tap a parcel to select. Tap "방문" on an owned parcel to
/// zoom in; tap "구매" on a locked parcel to spend coin and unlock it.
class GlobeView extends ConsumerStatefulWidget {
  const GlobeView({super.key});

  @override
  ConsumerState<GlobeView> createState() => _GlobeViewState();
}

class _GlobeViewState extends ConsumerState<GlobeView>
    with SingleTickerProviderStateMixin {
  double _lat = -0.4; // small downward tilt so the player sees the top
  double _lon = 0.0;
  double _spinVelocity = 0.0; // rad/sec, decays
  double _gestureStartLat = 0;
  double _gestureStartLon = 0;
  Offset? _gestureStartFocal;
  String? _selectedParcelId;
  final Map<String, ParcelHit> _hitMap = {};

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _animPhase = 0;
  double _pulse = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt =
        ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;
    setState(() {
      // ambient drift when no input
      if (_spinVelocity.abs() < 0.0001 && _gestureStartFocal == null) {
        _lon += 0.05 * dt;
      } else {
        _lon += _spinVelocity * dt;
        // friction
        _spinVelocity *= math.pow(0.95, dt * 60).toDouble();
      }
      _animPhase = (_animPhase + dt * 0.05) % 1.0;
      _pulse = (math.sin(elapsed.inMilliseconds / 700) * 0.5 + 0.5);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(countryControllerProvider);
    final country = state.country;

    final ownedCount = country.owned.length;
    final nextCost = country.nextParcelCost;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1438),
      body: Stack(
        children: [
          // Starfield + nebula gradient
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1A1438),
                    Color(0xFF382764),
                    Color(0xFF6B5BA8),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: StarfieldPainter(phase: _animPhase)),
          ),
          // The planet
          GestureDetector(
            onScaleStart: (d) {
              _gestureStartFocal = d.focalPoint;
              _gestureStartLat = _lat;
              _gestureStartLon = _lon;
              _spinVelocity = 0;
            },
            onScaleUpdate: (d) {
              if (_gestureStartFocal == null) return;
              final delta = d.focalPoint - _gestureStartFocal!;
              setState(() {
                _lon = _gestureStartLon + delta.dx * 0.005;
                _lat = (_gestureStartLat - delta.dy * 0.005)
                    .clamp(-math.pi / 2 + 0.1, math.pi / 2 - 0.1);
              });
            },
            onScaleEnd: (d) {
              _spinVelocity = d.velocity.pixelsPerSecond.dx * 0.005;
              _gestureStartFocal = null;
            },
            onTapUp: (d) => _handleTap(d.localPosition, country.parcels),
            child: CustomPaint(
              painter: GlobePainter(
                parcels: country.parcels,
                rotationLat: _lat,
                rotationLon: _lon,
                selectedParcelId: _selectedParcelId,
                hoveredParcelId: null,
                pulse: _pulse,
                hitMap: _hitMap,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          // Top status bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: _GlobeTopBar(
                countryName: country.name,
                level: country.level,
                ownedCount: ownedCount,
                totalCount: country.parcels.length,
                coin: country.currency.coin,
                heart: country.currency.heart,
                memoryScore: country.memoryScore.round(),
              ),
            ),
          ),
          // Bottom selection panel — slides up when a parcel is picked
          if (_selectedParcelId != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ParcelInfoPanel(
                parcel: country.parcels.firstWhere(
                  (p) => p.id == _selectedParcelId,
                ),
                nextCost: nextCost,
                onClose: () => setState(() => _selectedParcelId = null),
                onEnter: () {
                  ref
                      .read(countryControllerProvider.notifier)
                      .enterParcel(_selectedParcelId!);
                },
                onBuy: () {
                  final r = ref
                      .read(countryControllerProvider.notifier)
                      .buyParcel(_selectedParcelId!);
                  if (!r.success && r.failureReason != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      duration: const Duration(seconds: 2),
                      content: Text(r.failureReason!),
                    ));
                  }
                },
              ),
            ),
          if (state.toast != null)
            _toastOverlay(context, state.toast!, () {
              ref.read(countryControllerProvider.notifier).dismissToast();
            }),
        ],
      ),
    );
  }

  void _handleTap(Offset local, List<Parcel> parcels) {
    // Hit-test against the disc map populated during the last paint.
    String? hit;
    var closestDist = double.infinity;
    _hitMap.forEach((id, h) {
      final d = (local - h.center).distance;
      if (d <= h.radius * 1.5 && d < closestDist) {
        hit = id;
        closestDist = d;
      }
    });
    setState(() => _selectedParcelId = hit);
  }

  Widget _toastOverlay(BuildContext context, String msg, VoidCallback dismiss) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(msg),
      ));
      dismiss();
    });
    return const SizedBox.shrink();
  }
}

class _GlobeTopBar extends StatelessWidget {
  final String countryName;
  final int level;
  final int ownedCount;
  final int totalCount;
  final int coin;
  final int heart;
  final int memoryScore;
  const _GlobeTopBar({
    required this.countryName,
    required this.level,
    required this.ownedCount,
    required this.totalCount,
    required this.coin,
    required this.heart,
    required this.memoryScore,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(countryName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  Text('Lv.$level · 땅 $ownedCount/$totalCount',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  _glassPill('🪙', _fmt(coin)),
                  const SizedBox(width: 10),
                  _glassPill('💖', _fmt(heart)),
                  const SizedBox(width: 10),
                  _glassPill('✨', memoryScore.toString()),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _glassPill(String emoji, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  static String _fmt(int n) {
    if (n < 1000) return n.toString();
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }
}

class _ParcelInfoPanel extends StatelessWidget {
  final Parcel parcel;
  final int nextCost;
  final VoidCallback onClose;
  final VoidCallback onEnter;
  final VoidCallback onBuy;
  const _ParcelInfoPanel({
    required this.parcel,
    required this.nextCost,
    required this.onClose,
    required this.onEnter,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final park = parcel.park;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: PastelCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          parcel.biome.surfaceColor,
                          parcel.biome.edgeColor,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(parcel.biome.emoji,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(parcel.biome.displayName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          parcel.isOwned ? '소유한 땅' : '잠긴 땅',
                          style: TextStyle(
                            fontSize: 12,
                            color: parcel.isOwned
                                ? PastelColors.primaryDark
                                : PastelColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (parcel.isOwned && park != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      _miniStat(
                          '🏰 시설', '${park.facilities.length}'),
                      const SizedBox(width: 16),
                      _miniStat(
                          '😊 만족', '${park.satisfaction.round()}'),
                      const SizedBox(width: 16),
                      _miniStat('🪙 매출', '${park.incomeToday}'),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: parcel.isOwned
                    ? FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: PastelColors.primary,
                          foregroundColor: PastelColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: onEnter,
                        child: const Text('이 땅으로 들어가기 →'),
                      )
                    : FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: PastelColors.accent,
                          foregroundColor: PastelColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: onBuy,
                        child: Text('🪙 $nextCost  땅 구매하기'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: PastelColors.textSecondary)),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: PastelColors.textPrimary)),
      ],
    );
  }
}
