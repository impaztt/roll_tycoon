import 'dart:math' as math;

/// Minimal 3D vector for the globe renderer.
///
/// We don't pull in `vector_math` — Flutter ships it transitively, but
/// keeping a tiny purpose-built vec3 here makes the math in
/// [GlobePainter] read like the design doc instead of like generic algebra.
class Vec3 {
  final double x;
  final double y;
  final double z;
  const Vec3(this.x, this.y, this.z);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  /// Convert lat/lon (radians) on a unit sphere to a Cartesian point.
  /// Lat=0,Lon=0 lands on the +Z face (the camera looks down -Z),
  /// which puts the "front" of the globe toward the viewer.
  static Vec3 fromLatLon(double lat, double lon) {
    final cosLat = math.cos(lat);
    return Vec3(
      cosLat * math.sin(lon),
      math.sin(lat),
      cosLat * math.cos(lon),
    );
  }

  /// Rotate around the Y axis (longitude / spin).
  Vec3 rotateY(double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Vec3(c * x + s * z, y, -s * x + c * z);
  }

  /// Rotate around the X axis (latitude / pitch).
  Vec3 rotateX(double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Vec3(x, c * y - s * z, s * y + c * z);
  }

  Vec3 scaled(double s) => Vec3(x * s, y * s, z * s);
}
