/// Core gameplay constants.
///
/// Numbers come from design doc §164.1 (grid size), §153 (balance examples).
/// Centralized so the balance team can tune without hunting through code.
class GameConstants {
  GameConstants._();

  // World size (per §164.1)
  static const int worldWidth = 20;
  static const int worldHeight = 20;
  static const int initialOpenWidth = 12;
  static const int initialOpenHeight = 12;

  // Game tick — simulation runs ~10 fps to keep mobile cool.
  // Each tick advances simulation by tickSeconds of in-game time.
  static const Duration tickInterval = Duration(milliseconds: 200);
  static const double tickSeconds = 0.2;

  // Economy starting state
  static const int startingCoin = 5000;
  static const int startingGem = 50;
  static const int startingHeart = 0;

  // Park entrance position (always present, players can't move it in MVP)
  static const int entranceX = 10;
  static const int entranceY = 0;

  // Guest spawning
  static const double guestSpawnIntervalSeconds = 3.0;
  static const int maxConcurrentGuests = 50;

  // Satisfaction & cleanliness baselines
  static const int initialSatisfaction = 75;
  static const int initialCleanliness = 90;

  // Trash cleanup
  static const double trashSpawnPerShopPerSecond = 0.02; // ~1 trash per 50s per shop
  static const int trashCleanlinessImpact = 2;
}
