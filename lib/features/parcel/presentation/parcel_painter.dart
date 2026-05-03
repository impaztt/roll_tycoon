import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../construction/application/build_mode_controller.dart';
import '../../country/domain/biome.dart';
import '../../guest/domain/guest.dart';
import '../../park/domain/facility.dart';
import '../../park/domain/park.dart';
import '../../park/domain/tile.dart';
import 'iso_projection.dart';

/// Renders the inside of a single parcel — the actual amusement park.
///
/// Replaces the old top-down emoji grid with a proper isometric scene:
/// - Diamond ground tiles with biome-tinted gradient
/// - Path tiles slightly lighter
/// - Facilities as iso "blocks" (top + 2 lit faces) with a pop of color
/// - Guests/staff as small capsule + face
/// - In build mode, an overlay shows hover tile + valid/invalid feedback
class ParcelPainter extends CustomPainter {
  final Park park;
  final Biome biome;
  final String? selectedFacilityId;
  final TileCoord? hoveredTile;
  final BuildSelection? buildSelection;
  final bool isValidPlacement;

  /// Where grid (0,0) lands on the canvas, in screen pixels.
  final Offset origin;
  final double cameraScale;

  ParcelPainter({
    required this.park,
    required this.biome,
    required this.selectedFacilityId,
    required this.hoveredTile,
    required this.buildSelection,
    required this.isValidPlacement,
    required this.origin,
    required this.cameraScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(cameraScale);

    _paintGroundShadow(canvas);
    _paintGround(canvas);
    _paintEntranceMarker(canvas);
    _paintHoverHighlight(canvas);
    _paintTrash(canvas);
    _paintFacilities(canvas);
    _paintGuestsAndStaff(canvas);

    canvas.restore();
  }

  void _paintGroundShadow(Canvas canvas) {
    // Soft drop shadow under the entire parcel — parcel "floats" on the planet.
    final corners = [
      IsoProjection.project(0, 0),
      IsoProjection.project(park.width.toDouble(), 0),
      IsoProjection.project(park.width.toDouble(), park.height.toDouble()),
      IsoProjection.project(0, park.height.toDouble()),
    ];
    final shadow = Path()..moveTo(corners[0].dx, corners[0].dy + 12);
    for (var i = 1; i < corners.length; i++) {
      shadow.lineTo(corners[i].dx, corners[i].dy + 12);
    }
    shadow.close();
    canvas.drawPath(
      shadow,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  void _paintGround(Canvas canvas) {
    for (var y = 0; y < park.height; y++) {
      for (var x = 0; x < park.width; x++) {
        final kind = park.tiles[y][x];
        final gx = x.toDouble();
        final gy = y.toDouble();
        final base = switch (kind) {
          TileKind.grass => biome.groundTint,
          TileKind.path => PastelColors.path,
          TileKind.facility => biome.groundTint, // overpainted by facility
          TileKind.entrance => PastelColors.accent,
        };
        final tint = ((x + y) % 2 == 0) ? base : darken(base, 0.04);
        final p = Paint()..color = tint;
        canvas.drawPath(diamondPath(gx, gy), p);
        // outline
        canvas.drawPath(
          diamondPath(gx, gy),
          Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.white.withValues(alpha: 0.18)
            ..strokeWidth = 0.7,
        );
      }
    }
  }

  void _paintEntranceMarker(Canvas canvas) {
    final ent = TileCoord(park.width ~/ 2, 0);
    final block = IsoBlock.build(
        ent.x.toDouble(), ent.y.toDouble(), 1, 1, 0.25);
    canvas.drawPath(block.top, Paint()..color = PastelColors.accent);
    canvas.drawPath(block.right,
        Paint()..color = darken(PastelColors.accent, 0.12));
    canvas.drawPath(block.left,
        Paint()..color = lighten(PastelColors.accent, 0.06));
  }

  void _paintHoverHighlight(Canvas canvas) {
    final h = hoveredTile;
    if (h == null) return;
    if (h.x < 0 || h.x >= park.width || h.y < 0 || h.y >= park.height) return;
    final master = switch (buildSelection) {
      FacilitySelection(:final master) => master,
      _ => null,
    };
    final sx = master?.sizeX ?? 1;
    final sy = master?.sizeY ?? 1;
    final color = isValidPlacement
        ? PastelColors.success.withValues(alpha: 0.55)
        : PastelColors.danger.withValues(alpha: 0.55);
    for (var dy = 0; dy < sy; dy++) {
      for (var dx = 0; dx < sx; dx++) {
        canvas.drawPath(
          diamondPath((h.x + dx).toDouble(), (h.y + dy).toDouble()),
          Paint()..color = color,
        );
      }
    }
  }

  void _paintTrash(Canvas canvas) {
    final brown = const Color(0xFF8B6F47);
    for (final t in park.trash.values) {
      final p = IsoProjection.project(
          t.position.x + 0.5, t.position.y + 0.5, 0);
      canvas.drawCircle(p, 4, Paint()..color = brown);
    }
  }

  void _paintFacilities(Canvas canvas) {
    // Painters need to draw facilities back-to-front so closer ones overlap.
    final sorted = park.facilities.values.toList()
      ..sort((a, b) {
        final aD = a.origin.x + a.origin.y;
        final bD = b.origin.x + b.origin.y;
        return aD.compareTo(bD);
      });

    for (final f in sorted) {
      _paintOneFacility(canvas, f);
    }
  }

  void _paintOneFacility(Canvas canvas, PlacedFacility f) {
    final cat = f.master.category;
    final isAttraction = cat == FacilityCategory.attraction;
    final isShop = cat == FacilityCategory.shop;
    final isAmenity = cat == FacilityCategory.amenity;
    final isDecor = cat == FacilityCategory.decoration;

    Color top;
    Color side;
    double height;

    switch (cat) {
      case FacilityCategory.attraction:
        top = const Color(0xFFFFB5A7);
        side = const Color(0xFFE89186);
        height = 1.4;
        break;
      case FacilityCategory.shop:
        top = const Color(0xFFFFD8A8);
        side = const Color(0xFFE0B485);
        height = 0.9;
        break;
      case FacilityCategory.amenity:
        top = const Color(0xFFA8D8EA);
        side = const Color(0xFF80B5C9);
        height = 0.7;
        break;
      case FacilityCategory.decoration:
        top = const Color(0xFFB8E0A1);
        side = const Color(0xFF95C079);
        height = 0.5;
        break;
      case FacilityCategory.staffRoom:
        top = const Color(0xFFCDB4F6);
        side = const Color(0xFFA890D8);
        height = 0.8;
        break;
      case FacilityCategory.path:
        return;
    }

    if (f.instanceId == selectedFacilityId) {
      top = lighten(top, 0.08);
      side = lighten(side, 0.05);
    }

    final block = IsoBlock.build(
      f.origin.x.toDouble(),
      f.origin.y.toDouble(),
      f.master.sizeX,
      f.master.sizeY,
      height,
    );

    // Right face = darker (faces away from light)
    canvas.drawPath(block.right, Paint()..color = darken(side, 0.06));
    // Left face = mid
    canvas.drawPath(block.left, Paint()..color = side);
    // Top face = brightest with subtle radial highlight
    canvas.drawPath(block.top, Paint()..color = top);

    // Type indicator on top — a roof shape for attractions, awning for shops.
    if (isAttraction) {
      _paintRoof(canvas, f, height, top);
    } else if (isShop) {
      _paintAwning(canvas, f, height, top);
    } else if (isAmenity) {
      _paintAmenityCap(canvas, f, height, top);
    } else if (isDecor) {
      _paintDecorTuft(canvas, f, height, top);
    }

    // Selection halo
    if (f.instanceId == selectedFacilityId) {
      final ringPath = Path();
      final corners = [
        IsoProjection.project(f.origin.x.toDouble(), f.origin.y.toDouble()),
        IsoProjection.project(
            (f.origin.x + f.master.sizeX).toDouble(), f.origin.y.toDouble()),
        IsoProjection.project((f.origin.x + f.master.sizeX).toDouble(),
            (f.origin.y + f.master.sizeY).toDouble()),
        IsoProjection.project(
            f.origin.x.toDouble(), (f.origin.y + f.master.sizeY).toDouble()),
      ];
      ringPath.moveTo(corners[0].dx, corners[0].dy);
      for (var i = 1; i < corners.length; i++) {
        ringPath.lineTo(corners[i].dx, corners[i].dy);
      }
      ringPath.close();
      canvas.drawPath(
        ringPath,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }

    // Status badge — show queue count for attractions
    if (isAttraction || isShop) {
      final queueCount = 0;
      // (Real queue count comes from outside — left as future hook)
      if (queueCount > 0) {
        // placeholder
      }
    }
  }

  void _paintRoof(Canvas canvas, PlacedFacility f, double h, Color top) {
    // Conical roof for attractions (회전목마, etc.)
    final centerGround = IsoProjection.project(
      f.origin.x + f.master.sizeX / 2,
      f.origin.y + f.master.sizeY / 2,
      h,
    );
    final apex = Offset(centerGround.dx, centerGround.dy - 24);
    final left = IsoProjection.project(f.origin.x.toDouble(),
        f.origin.y + f.master.sizeY.toDouble(), h);
    final right = IsoProjection.project(
      (f.origin.x + f.master.sizeX).toDouble(),
      f.origin.y.toDouble(),
      h,
    );
    final back = IsoProjection.project(
      f.origin.x.toDouble(),
      f.origin.y.toDouble(),
      h,
    );
    final front = IsoProjection.project(
      (f.origin.x + f.master.sizeX).toDouble(),
      (f.origin.y + f.master.sizeY).toDouble(),
      h,
    );

    final roofLeft = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(back.dx, back.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
    final roofFront = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(front.dx, front.dy)
      ..close();
    final roofRight = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(front.dx, front.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    final roofBack = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(back.dx, back.dy)
      ..close();

    final roofColor = lighten(top, 0.04);
    canvas.drawPath(roofBack,
        Paint()..color = darken(roofColor, 0.05));
    canvas.drawPath(roofRight,
        Paint()..color = darken(roofColor, 0.10));
    canvas.drawPath(roofLeft, Paint()..color = roofColor);
    canvas.drawPath(roofFront,
        Paint()..color = lighten(roofColor, 0.04));

    // Flag pole + flag
    canvas.drawCircle(apex, 2.5, Paint()..color = const Color(0xFFFFD46B));
  }

  void _paintAwning(Canvas canvas, PlacedFacility f, double h, Color top) {
    final left = IsoProjection.project(
        f.origin.x.toDouble(), (f.origin.y + 1).toDouble(), h + 0.05);
    final right = IsoProjection.project(
        (f.origin.x + f.master.sizeX).toDouble(),
        (f.origin.y + 1).toDouble(),
        h + 0.05);
    final r = Rect.fromPoints(left, Offset(right.dx, right.dy + 6));
    canvas.drawRect(
      r,
      Paint()..color = const Color(0xFFE89186),
    );
  }

  void _paintAmenityCap(
      Canvas canvas, PlacedFacility f, double h, Color top) {
    final c = IsoProjection.project(
      f.origin.x + f.master.sizeX / 2,
      f.origin.y + f.master.sizeY / 2,
      h + 0.1,
    );
    canvas.drawCircle(c, 6, Paint()..color = lighten(top, 0.1));
  }

  void _paintDecorTuft(
      Canvas canvas, PlacedFacility f, double h, Color top) {
    // Multiple small bobbles for trees/flowers
    final c = IsoProjection.project(
      f.origin.x + 0.5,
      f.origin.y + 0.5,
      h,
    );
    final tuftColor = const Color(0xFF7FB39B);
    canvas.drawCircle(c, 7, Paint()..color = tuftColor);
    canvas.drawCircle(
      Offset(c.dx - 4, c.dy - 6),
      5,
      Paint()..color = lighten(tuftColor, 0.05),
    );
    canvas.drawCircle(
      Offset(c.dx + 4, c.dy - 4),
      4,
      Paint()..color = lighten(tuftColor, 0.08),
    );
  }

  void _paintGuestsAndStaff(Canvas canvas) {
    for (final g in park.guests.values) {
      _paintCapsule(canvas, g.position, _guestColor(g));
    }
    for (final s in park.staff.values) {
      _paintCapsule(canvas, s.position, const Color(0xFFCDB4F6));
    }
  }

  Color _guestColor(Guest g) => switch (g.type) {
        GuestType.family => const Color(0xFFFFD46B),
        GuestType.teen => const Color(0xFF7DBCC8),
        GuestType.general => const Color(0xFFFFB5A7),
      };

  void _paintCapsule(Canvas canvas, TileCoord pos, Color color) {
    final base = IsoProjection.project(pos.x + 0.5, pos.y + 0.5, 0);
    final body = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(base.dx, base.dy - 8), width: 10, height: 14));
    canvas.drawPath(body, Paint()..color = color);
    canvas.drawPath(
        body,
        Paint()
          ..color = darken(color, 0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);
    // little eye dots
    final eye = Paint()..color = const Color(0xFF3A3A3A);
    canvas.drawCircle(Offset(base.dx - 1.4, base.dy - 11), 0.9, eye);
    canvas.drawCircle(Offset(base.dx + 1.4, base.dy - 11), 0.9, eye);
  }

  @override
  bool shouldRepaint(covariant ParcelPainter old) => true;
}
