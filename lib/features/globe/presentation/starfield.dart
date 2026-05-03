import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Slow-drifting star/particle background for the globe view.
///
/// Static layer; each star is generated once with a deterministic seed and
/// re-used across paints, with phase animated by the listener.
class StarfieldPainter extends CustomPainter {
  final double phase; // 0..1, advanced by the parent's animation

  final List<_Star> _stars;

  StarfieldPainter({required this.phase, int count = 80, int seed = 7})
      : _stars = _generate(count, seed);

  static List<_Star> _generate(int count, int seed) {
    final r = math.Random(seed);
    return List.generate(
      count,
      (_) => _Star(
        x: r.nextDouble(),
        y: r.nextDouble(),
        radius: r.nextDouble() * 1.4 + 0.4,
        twinklePhase: r.nextDouble(),
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final s in _stars) {
      final blink =
          0.45 + 0.55 * (math.sin((phase + s.twinklePhase) * math.pi * 2) * 0.5 + 0.5);
      p.color = Colors.white.withValues(alpha: blink * 0.7);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.radius,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StarfieldPainter old) => old.phase != phase;
}

class _Star {
  final double x;
  final double y;
  final double radius;
  final double twinklePhase;
  _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.twinklePhase,
  });
}
