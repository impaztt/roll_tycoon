import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/math/vec3.dart';
import '../../country/domain/biome.dart';
import '../../country/domain/parcel.dart';

/// Renders the 3D planet with parcels using a hand-rolled CustomPainter.
///
/// Strategy:
/// - The sphere itself is a radial-gradient circle with an atmosphere ring
///   behind it. We don't ray-trace lighting; the gradient does the work.
/// - Each parcel projects its lat/lon to a 3D point on a unit sphere,
///   gets rotated by the camera, then orthographically projected to 2D.
/// - Back-facing parcels (z < 0 after rotation) are skipped.
/// - Front parcels are drawn as soft pastel discs scaled by perspective z
///   so they shrink near the limb. Ownership gets a glow + a tiny landmark
///   icon; locked parcels render as muted with a lock dot.
class GlobePainter extends CustomPainter {
  final List<Parcel> parcels;
  final double rotationLat; // pitch (X axis)
  final double rotationLon; // yaw (Y axis)
  final String? selectedParcelId;
  final String? hoveredParcelId;
  final double pulse; // 0..1 ambient pulse for selected / unlock candidate

  /// Output: filled while painting so the gesture handler can hit-test.
  /// (parcelId → screen disc center + radius after this paint.)
  final Map<String, ParcelHit> hitMap;

  GlobePainter({
    required this.parcels,
    required this.rotationLat,
    required this.rotationLon,
    required this.selectedParcelId,
    required this.hoveredParcelId,
    required this.pulse,
    required this.hitMap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.36;

    _paintAtmosphere(canvas, center, radius);
    _paintSphere(canvas, center, radius);
    _paintParcels(canvas, center, radius);
    _paintHighlight(canvas, center, radius);
  }

  void _paintAtmosphere(Canvas canvas, Offset c, double r) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFCDB4F6).withValues(alpha: 0.35),
          const Color(0xFFCDB4F6).withValues(alpha: 0.0),
        ],
        stops: const [0.7, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.45));
    canvas.drawCircle(c, r * 1.45, glow);
  }

  void _paintSphere(Canvas canvas, Offset c, double r) {
    // Base sphere: radial gradient gives the illusion of curvature.
    final base = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 1.05,
        colors: const [
          Color(0xFFE4F8EE),
          Color(0xFFB6E0BF),
          Color(0xFF7FB39B),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, base);

    // Soft specular highlight near top-left.
    final hi = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.55),
        radius: 0.6,
        colors: [
          Colors.white.withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, hi);

    // Terminator shadow on the bottom-right limb to deepen the 3D feel.
    final shade = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.5, 0.55),
        radius: 0.95,
        colors: [
          const Color(0xFF2C3E50).withValues(alpha: 0.28),
          const Color(0xFF2C3E50).withValues(alpha: 0.0),
        ],
        stops: const [0.6, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, shade);
  }

  void _paintParcels(Canvas canvas, Offset c, double r) {
    hitMap.clear();
    for (final parcel in parcels) {
      final v = Vec3.fromLatLon(parcel.lat, parcel.lon)
          .rotateY(rotationLon)
          .rotateX(rotationLat);
      if (v.z < -0.05) continue; // back of sphere

      final screen = Offset(c.dx + v.x * r, c.dy - v.y * r);
      // perspective: tiles near the limb look smaller
      final perspective = (v.z * 0.5 + 0.7).clamp(0.4, 1.2);
      final discR = r * 0.10 * perspective;
      hitMap[parcel.id] = ParcelHit(center: screen, radius: discR);

      _paintParcelDisc(canvas, parcel, screen, discR);
    }
  }

  void _paintParcelDisc(Canvas canvas, Parcel parcel, Offset center, double r) {
    if (!parcel.isOwned) {
      // Locked: muted disc with a tiny lock dot.
      final muted = Paint()
        ..color = parcel.biome.surfaceColor.withValues(alpha: 0.55);
      canvas.drawCircle(center, r, muted);
      final ring = Paint()
        ..color = parcel.biome.edgeColor.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(center, r, ring);
      // lock indicator
      final lockPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
      canvas.drawCircle(center, r * 0.35, lockPaint);
      final lockBar = Paint()
        ..color = const Color(0xFF7A6F95)
        ..strokeWidth = 1.4;
      canvas.drawLine(
        Offset(center.dx, center.dy - r * 0.18),
        Offset(center.dx, center.dy + r * 0.18),
        lockBar,
      );
      return;
    }

    // Owned: soft glow halo + biome-tinted disc + landmark dot.
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          parcel.biome.surfaceColor.withValues(alpha: 0.7),
          parcel.biome.surfaceColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 1.9));
    canvas.drawCircle(center, r * 1.9, halo);

    final disc = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(parcel.biome.surfaceColor, Colors.white, 0.35)!,
          parcel.biome.surfaceColor,
          parcel.biome.edgeColor,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, disc);

    // Tiny landmark "park" dot if the parcel has facilities.
    final park = parcel.park;
    if (park != null && park.facilities.isNotEmpty) {
      final landmark = Paint()..color = Colors.white;
      canvas.drawCircle(
        Offset(center.dx, center.dy - r * 0.1),
        r * 0.18,
        landmark,
      );
      final dot = Paint()..color = parcel.biome.edgeColor;
      canvas.drawCircle(
        Offset(center.dx, center.dy - r * 0.1),
        r * 0.10,
        dot,
      );
    }
  }

  void _paintHighlight(Canvas canvas, Offset c, double r) {
    final id = selectedParcelId ?? hoveredParcelId;
    if (id == null) return;
    final hit = hitMap[id];
    if (hit == null) return;
    // Pulsing ring around the focus parcel.
    final pulseR = hit.radius + 4 + 4 * pulse;
    final ring = Paint()
      ..color = Colors.white.withValues(alpha: (1 - pulse) * 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(hit.center, pulseR, ring);
  }

  @override
  bool shouldRepaint(covariant GlobePainter old) => true;
}

class ParcelHit {
  final Offset center;
  final double radius;
  const ParcelHit({required this.center, required this.radius});
}
