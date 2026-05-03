import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart' show HSLColor;

/// Standard isometric projection for the parcel grid.
///
/// Tile (x,y) at elevation z renders to screen as a diamond. We use the
/// classic 2:1 isometric ratio (cos30 : sin30 ≈ 0.866 : 0.5) which gives
/// the cozy RCT 1/2 silhouette without the extreme oblique of dimetric.
class IsoProjection {
  static const double tileWidth = 56;
  static const double tileHeight = 28; // half of width — 2:1 iso ratio

  /// Convert (gridX, gridY, gridZ) → 2D screen offset relative to (0,0,0).
  /// gridZ is elevation in tile units (1 = one full tile cube).
  static Offset project(double gx, double gy, [double gz = 0]) {
    final sx = (gx - gy) * (tileWidth / 2);
    final sy = (gx + gy) * (tileHeight / 2) - gz * tileHeight;
    return Offset(sx, sy);
  }

  /// Reverse projection of a screen point (no elevation) back to grid coords.
  /// Used for tap → tile resolution.
  static Offset unproject(Offset screen) {
    final gx = (screen.dx / (tileWidth / 2) + screen.dy / (tileHeight / 2)) / 2;
    final gy = (screen.dy / (tileHeight / 2) - screen.dx / (tileWidth / 2)) / 2;
    return Offset(gx, gy);
  }
}

/// Build the four corners of the diamond for tile (gx, gy) on the ground plane.
List<Offset> diamondCorners(double gx, double gy) {
  return [
    IsoProjection.project(gx, gy), // top
    IsoProjection.project(gx + 1, gy), // right
    IsoProjection.project(gx + 1, gy + 1), // bottom
    IsoProjection.project(gx, gy + 1), // left
  ];
}

/// Build a Path for a 1x1 tile diamond.
Path diamondPath(double gx, double gy) {
  final corners = diamondCorners(gx, gy);
  final p = Path()..moveTo(corners[0].dx, corners[0].dy);
  for (var i = 1; i < corners.length; i++) {
    p.lineTo(corners[i].dx, corners[i].dy);
  }
  p.close();
  return p;
}

/// Build an iso "block" (cube-like) for a facility footprint of (sx, sy)
/// rising to height [height] tile-units. Returns three faces (top, left,
/// right) as separate paths so they can be lit differently.
class IsoBlock {
  final Path top;
  final Path left;
  final Path right;
  IsoBlock({required this.top, required this.left, required this.right});

  static IsoBlock build(double gx, double gy, int sx, int sy, double height) {
    final topNW = IsoProjection.project(gx, gy, height);
    final topNE = IsoProjection.project(gx + sx.toDouble(), gy, height);
    final topSE =
        IsoProjection.project(gx + sx.toDouble(), gy + sy.toDouble(), height);
    final topSW =
        IsoProjection.project(gx, gy + sy.toDouble(), height);
    final botSE =
        IsoProjection.project(gx + sx.toDouble(), gy + sy.toDouble(), 0);
    final botSW = IsoProjection.project(gx, gy + sy.toDouble(), 0);
    final botNE = IsoProjection.project(gx + sx.toDouble(), gy, 0);

    final top = Path()
      ..moveTo(topNW.dx, topNW.dy)
      ..lineTo(topNE.dx, topNE.dy)
      ..lineTo(topSE.dx, topSE.dy)
      ..lineTo(topSW.dx, topSW.dy)
      ..close();

    final right = Path()
      ..moveTo(topNE.dx, topNE.dy)
      ..lineTo(topSE.dx, topSE.dy)
      ..lineTo(botSE.dx, botSE.dy)
      ..lineTo(botNE.dx, botNE.dy)
      ..close();

    final left = Path()
      ..moveTo(topSE.dx, topSE.dy)
      ..lineTo(topSW.dx, topSW.dy)
      ..lineTo(botSW.dx, botSW.dy)
      ..lineTo(botSE.dx, botSE.dy)
      ..close();

    return IsoBlock(top: top, left: left, right: right);
  }
}

/// Lighten/darken helpers — the iso renderer brightens the top and the
/// left face, darkens the right, to fake directional light from upper-left.
Color lighten(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
      .toColor();
}

Color darken(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
      .toColor();
}

/// Approximate radians for 30°, used in places where exact iso angle matters.
const double iso30 = math.pi / 6;
