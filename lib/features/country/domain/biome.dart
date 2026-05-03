import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Biomes a parcel can have (per DESIGN.md §6.3).
///
/// MVP only uses biomes for visual differentiation. v1+ wires gameplay
/// effects (guest preferences, facility synergies).
enum Biome { sweetGarden, cloud, forest, ocean, starlight, meadow }

extension BiomeVisuals on Biome {
  String get displayName => switch (this) {
        Biome.sweetGarden => '스위트 가든',
        Biome.cloud => '구름 마을',
        Biome.forest => '숲속 어드벤처',
        Biome.ocean => '오션 베이',
        Biome.starlight => '스타라이트',
        Biome.meadow => '풀밭',
      };

  String get emoji => switch (this) {
        Biome.sweetGarden => '🌸',
        Biome.cloud => '☁️',
        Biome.forest => '🌲',
        Biome.ocean => '🌊',
        Biome.starlight => '✨',
        Biome.meadow => '🌿',
      };

  /// Surface color of the parcel patch on the globe.
  Color get surfaceColor => switch (this) {
        Biome.sweetGarden => const Color(0xFFFFC8DD),
        Biome.cloud => const Color(0xFFCDE7FF),
        Biome.forest => const Color(0xFFB6E2C2),
        Biome.ocean => const Color(0xFF9FD6E0),
        Biome.starlight => const Color(0xFFCDB4F6),
        Biome.meadow => const Color(0xFFD9F0B0),
      };

  /// Slightly darker shade for the rim/shadow on the globe.
  Color get edgeColor => switch (this) {
        Biome.sweetGarden => const Color(0xFFE8A8C0),
        Biome.cloud => const Color(0xFFA8C8E5),
        Biome.forest => const Color(0xFF8FBE9E),
        Biome.ocean => const Color(0xFF7DBCC8),
        Biome.starlight => const Color(0xFFA890D8),
        Biome.meadow => const Color(0xFFB8D08A),
      };

  /// Background gradient when entered as a parcel (sky tone).
  List<Color> get parcelSkyGradient => switch (this) {
        Biome.sweetGarden => const [Color(0xFFFFE5EC), Color(0xFFFFC8DD)],
        Biome.cloud => const [Color(0xFFE7F5FF), Color(0xFFCDE7FF)],
        Biome.forest => const [Color(0xFFE8F5E9), Color(0xFFC2E2C8)],
        Biome.ocean => const [Color(0xFFE0F4F7), Color(0xFFB8DCE5)],
        Biome.starlight => const [Color(0xFF2D2954), Color(0xFF6B5BA8)],
        Biome.meadow => const [Color(0xFFF1FAEB), Color(0xFFD9F0B0)],
      };

  /// Ground tint for isometric tiles inside the parcel.
  Color get groundTint => switch (this) {
        Biome.sweetGarden => const Color(0xFFF6D4DF),
        Biome.cloud => PastelColors.grass,
        Biome.forest => const Color(0xFFC2DFCB),
        Biome.ocean => const Color(0xFFD3EAEA),
        Biome.starlight => const Color(0xFFC9BEE8),
        Biome.meadow => const Color(0xFFE5F1C5),
      };
}
