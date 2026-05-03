import 'facility.dart';

/// MVP facility catalog (per design doc §164.2).
///
/// Numbers loosely follow §153.1 balance table. These are tuning targets;
/// the real balance sheet (§116) lives outside code in production.
class FacilityCatalog {
  FacilityCatalog._();

  static const carousel = FacilityMaster(
    id: 'carousel_001',
    name: '미니 회전목마',
    emoji: '🎠',
    category: FacilityCategory.attraction,
    sizeX: 3,
    sizeY: 3,
    unlockLevel: 1,
    buildCost: 500,
    basePricePerRide: 25,
    baseIncomePerMin: 25,
    maintenancePerMin: 3,
    capacity: 6,
    cycleTimeSec: 8.0,
    excitement: 35,
    fear: 5,
    nausea: 3,
    themeTags: ['sweet', 'family', 'pastel'],
    generatesTrash: false,
  );

  static const cottonCandy = FacilityMaster(
    id: 'cotton_candy_001',
    name: '솜사탕 가게',
    emoji: '🍭',
    category: FacilityCategory.shop,
    sizeX: 1,
    sizeY: 1,
    unlockLevel: 1,
    buildCost: 350,
    basePricePerRide: 15,
    baseIncomePerMin: 18,
    maintenancePerMin: 2,
    capacity: 1,
    cycleTimeSec: 4.0,
    excitement: 5,
    fear: 0,
    nausea: 0,
    themeTags: ['sweet', 'family'],
    generatesTrash: true,
  );

  static const restroom = FacilityMaster(
    id: 'restroom_001',
    name: '기본 화장실',
    emoji: '🚻',
    category: FacilityCategory.amenity,
    sizeX: 1,
    sizeY: 1,
    unlockLevel: 3,
    buildCost: 400,
    basePricePerRide: 0,
    baseIncomePerMin: 0,
    maintenancePerMin: 4,
    capacity: 2,
    cycleTimeSec: 6.0,
    excitement: 0,
    fear: 0,
    nausea: 0,
    themeTags: ['amenity'],
    generatesTrash: false,
  );

  static const bench = FacilityMaster(
    id: 'bench_001',
    name: '벤치',
    emoji: '🪑',
    category: FacilityCategory.decoration,
    sizeX: 1,
    sizeY: 1,
    unlockLevel: 1,
    buildCost: 50,
    basePricePerRide: 0,
    baseIncomePerMin: 0,
    maintenancePerMin: 0,
    capacity: 2,
    cycleTimeSec: 10.0,
    excitement: 0,
    fear: 0,
    nausea: 0,
    themeTags: ['rest'],
    generatesTrash: false,
  );

  static const trashBin = FacilityMaster(
    id: 'trash_bin_001',
    name: '쓰레기통',
    emoji: '🗑️',
    category: FacilityCategory.amenity,
    sizeX: 1,
    sizeY: 1,
    unlockLevel: 1,
    buildCost: 80,
    basePricePerRide: 0,
    baseIncomePerMin: 0,
    maintenancePerMin: 0,
    capacity: 0,
    cycleTimeSec: 0,
    excitement: 0,
    fear: 0,
    nausea: 0,
    themeTags: ['cleanliness'],
    generatesTrash: false,
  );

  static const tree = FacilityMaster(
    id: 'tree_001',
    name: '나무',
    emoji: '🌳',
    category: FacilityCategory.decoration,
    sizeX: 1,
    sizeY: 1,
    unlockLevel: 1,
    buildCost: 40,
    basePricePerRide: 0,
    baseIncomePerMin: 0,
    maintenancePerMin: 0,
    capacity: 0,
    cycleTimeSec: 0,
    excitement: 0,
    fear: 0,
    nausea: 0,
    themeTags: ['nature', 'rest'],
    generatesTrash: false,
  );

  static const flower = FacilityMaster(
    id: 'flower_001',
    name: '꽃 화단',
    emoji: '🌸',
    category: FacilityCategory.decoration,
    sizeX: 1,
    sizeY: 1,
    unlockLevel: 1,
    buildCost: 30,
    basePricePerRide: 0,
    baseIncomePerMin: 0,
    maintenancePerMin: 0,
    capacity: 0,
    cycleTimeSec: 0,
    excitement: 0,
    fear: 0,
    nausea: 0,
    themeTags: ['nature', 'photo'],
    generatesTrash: false,
  );

  static const all = <FacilityMaster>[
    carousel,
    cottonCandy,
    restroom,
    bench,
    trashBin,
    tree,
    flower,
  ];

  static FacilityMaster? byId(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }
}
